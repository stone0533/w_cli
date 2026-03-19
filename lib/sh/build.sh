#!/bin/bash

# ======================================================
# build.sh - Flutter 应用打包脚本
# 版本管理信息
# Version: 1.0.7
# Last Updated: 2026-03-18
# Author: Stone
# Description: 用于构建 Flutter 应用的多平台打包脚本
# Features:
#   - 支持 Android APK、AAB 和 iOS IPA 打包
#   - 支持生产模式和 UAT 模式
#   - 应用商店要求检查
#   - 文件备份和版本管理
#   - 详细的日志和错误处理
#   - 支持通过命令行参数指定应用名称
# ======================================================

# 配置变量
# 输出目录，默认在项目目录的上级目录创建 build 文件夹
OUTPUT_DIR="${OUTPUT_DIR:-../build}"

# 最大备份文件数量，超过此数量会删除最旧的备份
MAX_BACKUP_COUNT="${MAX_BACKUP_COUNT:-10}"

# 是否启用调试模式，默认禁用
DEBUG_MODE="${DEBUG_MODE:-false}"

# 脚本版本号
SCRIPT_VERSION="1.0.7"

# 脚本最后更新日期
SCRIPT_LAST_UPDATED="2026-03-18"

# 是否启用并行构建，默认禁用
# 启用后可以同时构建多个平台，提高构建速度
PARALLEL_BUILD="${PARALLEL_BUILD:-false}"

# 是否启用构建通知，默认启用
# 构建完成后会发送系统通知
ENABLE_NOTIFICATIONS="${ENABLE_NOTIFICATIONS:-true}"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_debug() {
  if [ "$DEBUG_MODE" == "true" ]; then
    printf "${BLUE}[DEBUG]${NC} %s\n" "$1" >&2
  fi
}

log_info() {
  printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

log_warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_error() {
  printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

log_to_file() {
  # 不生成日志文件
  return 0
}

# 环境检查
check_environment() {
  log_info "检查构建环境..."
  
  # 检查 Flutter
  if ! command -v flutter &> /dev/null; then
    log_error "Flutter 未在 PATH 中找到"
    return 1
  fi
  
  # 检查 Dart
  if ! command -v dart &> /dev/null; then
    log_error "Dart 未在 PATH 中找到"
    return 1
  fi
  
  # 检查 Android 工具
  if command -v aapt &> /dev/null; then
    log_info "aapt 已找到: $(which aapt)"
  fi
  
  # 检查 iOS 工具（仅在 macOS 上）
  if [ "$(uname)" == "Darwin" ]; then
    if command -v xcodebuild &> /dev/null; then
      log_info "Xcode 构建工具已找到"
    else
      log_warn "Xcode 构建工具未找到，iOS 构建可能失败"
    fi
  elif [ "$(uname)" == "Linux" ]; then
    log_info "Linux 系统检测到，仅支持 Android 构建"
  else
    log_warn "未知系统，仅支持 Android 构建"
  fi
  
  log_info "环境检查完成"
  return 0
}

# 发送通知
send_notification() {
  if [ "$ENABLE_NOTIFICATIONS" != "true" ]; then
    return 0
  fi
  
  local message="$1"
  local title="Flutter 构建"
  
  # 转义特殊字符
  local escaped_message=$(echo "$message" | sed 's/"/\\"/g')
  local escaped_title=$(echo "$title" | sed 's/"/\\"/g')
  
  if [ "$(uname)" == "Darwin" ]; then
    # macOS 通知
    osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\""
  elif command -v notify-send &> /dev/null; then
    # Linux 通知
    notify-send "$escaped_title" "$escaped_message"
  fi
}

# 自动版本递增
increment_version() {
  local version_file="pubspec.yaml"
  local current_version=$(get_version)
  
  # 解析版本号
  local major=$(echo "$current_version" | cut -d. -f1)
  local minor=$(echo "$current_version" | cut -d. -f2 | cut -d+ -f1)
  local patch=$(echo "$current_version" | cut -d. -f3 | cut -d+ -f1)
  
  # 检查是否包含构建号
  if echo "$current_version" | grep -q "+"; then
    local build=$(echo "$current_version" | cut -d+ -f2)
  else
    local build=0
  fi
  
  # 递增补丁版本
  local new_patch=$((patch + 1))
  local new_version="$major.$minor.$new_patch+$((build + 1))"
  
  # 更新版本号
  sed -i.bak "s/^version:.*/version: $new_version/" "$version_file"
  rm -f "${version_file}.bak"
  
  log_info "版本号已递增至: $new_version"
  echo "$new_version"
}

# 清理临时文件
cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    log_debug "Cleaning up temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
    TEMP_DIR=""
  fi
}

# 注册清理函数
trap cleanup EXIT

# 检查执行权限
if [ ! -x "$0" ]; then
  log_error "Script does not have execution permission."
  log_warn "Please run: chmod +x $0"
  exit 1
fi

# 检查参数是否正确
if [ $# -lt 1 ]; then
  log_warn "Usage: ./build.sh [apk] [aab] [ios] [-uat] [-clear] [--version] [--increment]"
  log_warn "Options:"
  log_info "  -uat          # Build in UAT mode with timestamp"
  log_info "  -clear        # Clear build directory before building"
  log_info "  --version     # Show script version information"
  log_info "  --increment   # Increment version number before building"
  log_warn "Environment variables:"
  log_info "  PARALLEL_BUILD=true         # Enable parallel builds"
  log_info "  ENABLE_NOTIFICATIONS=true   # Enable build notifications"
  log_warn "Examples:"
  log_info "  ./build.sh apk                # Build APK in production mode"
  log_info "  ./build.sh apk aab             # Build APK and AAB in production mode"
  log_info "  ./build.sh apk -uat            # Build APK in UAT mode"
  log_info "  ./build.sh --version           # Show script version"
  log_info "  ./build.sh apk --increment     # Increment version and build APK"
  log_info "  PARALLEL_BUILD=true ./build.sh apk aab # Build APK and AAB in parallel"
  log_info "  ./build.sh apk aab ios -uat -clear # Build all platforms in UAT mode and clear build directory"
  exit 1
fi

# 检查版本参数
if [ "$1" == "--version" ]; then
  log_info "build.sh version: $SCRIPT_VERSION"
  log_info "Last updated: $SCRIPT_LAST_UPDATED"
  log_info "Description: Flutter application packaging script"
  log_info "Features:"
  log_info "  - Support Android APK, AAB and iOS IPA packaging"
  log_info "  - Support production and UAT modes"
  log_info "  - App store requirement checking"
  log_info "  - File backup and version management"
  log_info "  - Detailed logging and error handling"
  log_info "  - Parallel build support"
  log_info "  - Build notifications"
  log_info "  - Automatic version increment"
  exit 0
fi

# 获取当前时间，格式为 yyyy_mmdd_hhmmss
TIMESTAMP=$(date +"%Y_%m%d_%H%M%S")

# 改进的版本号提取
get_version() {
  local version_file="pubspec.yaml"
  
  if [ ! -f "$version_file" ]; then
    log_error "pubspec.yaml not found"
    exit 1
  fi
  
  local version=$(grep '^version:' "$version_file" | awk '{print $2}' | tr -d '"'"'")
  
  if [ -z "$version" ]; then
    log_error "Failed to extract version from pubspec.yaml"
    exit 1
  fi
  
  # 验证版本号格式
  if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'; then
    log_error "Invalid version format: $version"
    exit 1
  fi
  
  log_debug "Extracted version: $version"
  echo "$version"
}

# 验证配置
validate_config() {
  log_debug "Validating configuration..."
  
  # 检查输出目录的父目录是否存在
  local parent_dir=$(dirname "$OUTPUT_DIR")
  if [ "$parent_dir" != "." ] && [ ! -d "$parent_dir" ]; then
    log_error "Output directory parent does not exist: $parent_dir"
    exit 1
  fi
  
  # 检查磁盘空间（至少需要 1GB）
  local available_space=$(df -k "$OUTPUT_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
  if [ -n "$available_space" ] && [ "$available_space" -lt 1048576 ]; then
    log_warn "Low disk space: $(( available_space / 1024 )) MB available"
  fi
  
  # 验证 MAX_BACKUP_COUNT
  if ! echo "$MAX_BACKUP_COUNT" | grep -qE '^[0-9]+$'; then
    log_error "Invalid MAX_BACKUP_COUNT: $MAX_BACKUP_COUNT"
    exit 1
  fi
  
  log_debug "Configuration validated successfully"
}

# 获取版本号
VERSION=$(get_version)
# 移除版本号中的 + 号，用于文件名
VERSION_FOR_FILENAME=$(echo $VERSION | tr '+' '-')

# 检查参数
UAT_MODE=false
CLEAR_MODE=false
INCREMENT_VERSION=false
PLATFORMS=()
APP_NAME=""
for arg in "$@"; do
  case "$arg" in
    "apk"|"aab"|"ios")
      PLATFORMS+=($arg)
      ;;
    "-uat")
      UAT_MODE=true
      ;;
    "-clear")
      CLEAR_MODE=true
      ;;
    "--increment")
      INCREMENT_VERSION=true
      ;;
    -name:*) 
      APP_NAME="${arg#-name:}"
      ;;
  esac
done

# 添加运行开始分隔线
printf "${GREEN}======================================================${NC}\n"
printf "${GREEN}Flutter 应用打包脚本运行开始${NC}\n"
printf "${GREEN}======================================================${NC}\n"

# 显示构建信息
if [ "$UAT_MODE" == "true" ]; then
  log_info "打包模式: UAT"
  log_info "打包时间戳: $TIMESTAMP"
else
  log_info "打包模式: PROD (Versioned)"
  log_info "打包版本: $VERSION"
fi

if [ ${#PLATFORMS[@]} -gt 0 ]; then
  log_info "构建平台: ${PLATFORMS[*]}"
else
  log_info "构建平台: 无"
fi

# 环境检查
if ! check_environment; then
  log_error "环境检查失败，无法继续构建"
  exit 1
fi



# 创建输出目录
log_warn "创建输出目录: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 验证配置
validate_config

# 清空输出目录
if [ "$CLEAR_MODE" == "true" ]; then
  log_warn "清空构建目录: $OUTPUT_DIR"
  rm -rf "$OUTPUT_DIR"/*
fi

# 记录本次生成的文件
GENERATED_FILES=""

# 备份已存在的文件
backup_file() {
  local target_file="$1"
  
  if [ ! -f "$target_file" ]; then
    return 0
  fi
  
  # 清理旧备份，保留最新的 MAX_BACKUP_COUNT 个
  local base_name=$(basename "$target_file")
  local dir_name=$(dirname "$target_file")
  local backup_count=$(ls -1 "$dir_name"/"${base_name}".*.bak 2>/dev/null | wc -l | tr -d ' ')
  
  log_debug "当前备份数量: $backup_count"
  
  if [ "$backup_count" -ge "$MAX_BACKUP_COUNT" ]; then
    local oldest_backup=$(ls -1t "$dir_name"/"${base_name}".*.bak 2>/dev/null | tail -1)
    if [ -n "$oldest_backup" ]; then
      rm -f "$oldest_backup"
      log_warn "移除旧备份: $oldest_backup"
    fi
  fi
  
  # 创建新备份
  local counter=1
  local backup_file="${target_file}.${counter}.bak"
  while [ -f "$backup_file" ]; do
    counter=$((counter + 1))
    backup_file="${target_file}.${counter}.bak"
  done
  
  mv "$target_file" "$backup_file"
  log_warn "备份已存在文件: $target_file -> $backup_file"
}

# 生成文件名
generate_filename() {
  local platform="$1"
  local extension="$2"
  local suffix="$3"
  
  # 默认使用当前目录名作为应用名称，允许通过命令行参数或环境变量指定
  local app_name="${APP_NAME:-$(basename "$(pwd)")}"
  
  if [ "$UAT_MODE" == "true" ]; then
    if [ -n "$suffix" ]; then
      echo "$OUTPUT_DIR/${app_name}_uat_${TIMESTAMP}_${suffix}.${extension}"
    else
      echo "$OUTPUT_DIR/${app_name}_uat_${TIMESTAMP}.${extension}"
    fi
  else
    if [ -n "$suffix" ]; then
      echo "$OUTPUT_DIR/${app_name}_live_${VERSION_FOR_FILENAME}_${suffix}.${extension}"
    else
      echo "$OUTPUT_DIR/${app_name}_live_${VERSION_FOR_FILENAME}.${extension}"
    fi
  fi
}

# 提取 Android 打包公共逻辑
build_android_package() {
  local package_type="$1"
  local build_command="$2"
  local source_path="$3"
  
  local package_type_upper=$(echo "$package_type" | tr '[:lower:]' '[:upper:]')
  
  log_info "=== Building $package_type_upper ==="
  
  # 安全验证
  # 确保构建命令是有效的 Flutter 构建命令
  if ! echo "$build_command" | grep -qE '^flutter build (apk|appbundle) --release$'; then
    log_error "无效的构建命令: $build_command"
    log_error "构建命令必须是: flutter build apk --release 或 flutter build appbundle --release"
    return 1
  fi
  
  # 检查命令中是否包含潜在的危险字符
  if echo "$build_command" | grep -qE ';|\|\||&|\\|`|\$|\*|\?|\[|\]|\{|\}|\(|\)|<|>'; then
    log_error "构建命令包含潜在的危险字符: $build_command"
    return 1
  fi
  
  # 记录开始时间
  local start_time=$(date +%s)
  
  # 执行构建命令
  log_info "执行: $build_command"
  if ! eval "$build_command" | sed 's/\x1B\[[0-9;]*[mK]//g'; then
    log_error "构建 $package_type_upper 失败"
    log_error "请检查 Flutter 环境和项目配置"
    return 1
  fi
  
  # 计算构建时间
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_info "构建耗时: ${duration}s"
  
  # 验证构建产物
  if [ ! -f "$source_path" ]; then
    log_error "构建产物未找到: $source_path"
    return 1
  fi
  
  # 处理构建产物
  local output_file=$(generate_filename "$package_type" "$package_type" "")
  backup_file "$output_file"
  
  # 使用 rsync 或 cp
  if command -v rsync &> /dev/null; then
    rsync -ah "$source_path" "$output_file"
  else
    cp "$source_path" "$output_file"
  fi
  
  local file_size=$(du -h "$output_file" | cut -f1)
  
  # 记录生成的文件
  GENERATED_FILES="$GENERATED_FILES $output_file"
  
  # 记录最后构建时间（用于增量构建）
  echo "$(date +%s)" > "$OUTPUT_DIR/.last_build_$package_type"
  
  log_info "$package_type_upper 构建成功: $(pwd)/$output_file ($file_size)"
  
  log_to_file "Built $package_type_upper: $output_file ($file_size) in ${duration}s"
  return 0
}

# 创建 IPA 文件
create_ipa() {
  local app_path="$1"
  local output_path="$2"
  
  log_warn "正在创建 IPA 文件..."
  
  # 验证 app 路径
  if [ ! -d "$app_path" ]; then
    log_error "应用包未找到: $app_path"
    return 1
  fi
  
  # 验证必需文件
  if [ ! -f "$app_path/Info.plist" ]; then
    log_error "应用包中未找到 Info.plist"
    return 1
  fi
  
  # 确保输出目录存在
  mkdir -p "$OUTPUT_DIR"
  
  # 保存当前目录
  local current_dir=$(pwd)
  
  # 创建临时目录（使用全局变量，以便 cleanup 函数可以清理）
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/Payload"
  
  # 复制 Runner.app 到 Payload 目录
  if ! cp -r "$app_path" "$TEMP_DIR/Payload/"; then
    log_error "复制应用包失败"
    rm -rf "$TEMP_DIR"
    return 1
  fi
  
  # 压缩成 IPA 文件
  cd "$TEMP_DIR"
  local abs_ipa_file="$current_dir/$output_path"
  log_warn "正在创建 IPA 文件: $abs_ipa_file"
  
  # 使用安静模式和最大压缩
  if ! zip -qr -9 "$abs_ipa_file" Payload/; then
    log_error "创建 IPA 压缩包失败"
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    return 1
  fi
  
  cd - > /dev/null
  
  # 验证 IPA 文件
  if [ ! -f "$abs_ipa_file" ]; then
    log_error "IPA 文件未创建"
    rm -rf "$TEMP_DIR"
    return 1
  fi
  
  local file_size=$(du -h "$abs_ipa_file" | cut -f1)
  log_info "IPA 创建成功: $file_size"
  
  rm -rf "$TEMP_DIR"
  TEMP_DIR=""
  
  return 0
}

# 构建 iOS
build_ios() {
  log_info "=== 构建 iOS ==="
  
  # 记录开始时间
  local start_time=$(date +%s)
  
  log_info "执行: flutter build ios --release --no-codesign"
  if ! flutter build ios --release --no-codesign | sed 's/\x1B\[[0-9;]*[mK]//g'; then
    log_error "构建 iOS 失败"
    log_error "请检查 Flutter 环境、Xcode 配置和项目设置"
    log_error "确保已安装 Xcode 并配置了正确的开发者证书"
    return 1
  fi
  
  # 计算构建时间
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_info "构建耗时: ${duration}s"
  
  local ipa_file=$(generate_filename "ios" "ipa" "")
  backup_file "$ipa_file"
  
  if ! create_ipa "build/ios/iphoneos/Runner.app" "$ipa_file"; then
    log_error "创建 IPA 文件失败"
    return 1
  fi
  
  local file_size=$(du -h "$ipa_file" | cut -f1)
  log_info "iOS 构建成功: $(pwd)/$ipa_file ($file_size)"
  log_to_file "Built iOS: $ipa_file ($file_size) in ${duration}s"
  
  # 记录生成的文件
  GENERATED_FILES="$GENERATED_FILES $ipa_file"
  
  # 记录最后构建时间（用于增量构建）
  echo "$(date +%s)" > "$OUTPUT_DIR/.last_build_ios"
  
  return 0
}

# 验证参数
validate_parameters() {
  local has_platform=false
  
  for arg in "$@"; do
    case "$arg" in
      apk|aab|ios)
        has_platform=true
        ;;
      -uat|-clear|--increment)
        ;;
      -name:*) 
        ;;
      *)
        log_error "Invalid parameter: $arg"
        return 1
        ;;
    esac
  done
  
  if [ "$has_platform" == "false" ]; then
    log_error "No platform specified. Please use: apk, aab, or ios"
    return 1
  fi
  
  return 0
}

# 自动版本递增
if [ "$INCREMENT_VERSION" == "true" ]; then
  log_info "正在递增版本号..."
  VERSION=$(increment_version)
  VERSION_FOR_FILENAME=$(echo $VERSION | tr '+' '-')
  log_info "新版本号: $VERSION"
fi

# 验证参数
if ! validate_parameters "$@"; then
  exit 1
fi

# 根据参数执行打包命令
BUILD_FAILURE=false

# 并行构建
if [ "$PARALLEL_BUILD" == "true" ] && [ ${#PLATFORMS[@]} -gt 1 ]; then
  log_info "启用并行构建模式"
  
  # 用于存储构建状态的数组
  local build_status=()
  for platform in "${PLATFORMS[@]}"; do
    build_status+=(0)
  done
  
  # 创建临时文件来存储每个构建的退出状态
  local temp_dir=$(mktemp -d)
  local status_files=()
  
  local i=0
  for platform in "${PLATFORMS[@]}"; do
    local status_file="$temp_dir/status_$i.txt"
    status_files+=($status_file)
    
    case "$platform" in
      "apk")
        (build_android_package "apk" "flutter build apk --release" "build/app/outputs/flutter-apk/app-release.apk"; echo $? > "$status_file") &
        ;;
      "aab")
        (build_android_package "aab" "flutter build appbundle --release" "build/app/outputs/bundle/release/app-release.aab"; echo $? > "$status_file") &
        ;;
      "ios")
        (build_ios; echo $? > "$status_file") &
        ;;
    esac
    i=$((i + 1))
  done
  
  # 等待所有构建完成
  wait
  
  # 检查构建状态
  for status_file in "${status_files[@]}"; do
    if [ -f "$status_file" ]; then
      local exit_code=$(cat "$status_file" 2>/dev/null || echo 1)
      if [ "$exit_code" -ne 0 ]; then
        BUILD_FAILURE=true
        break
      fi
    else
      BUILD_FAILURE=true
      break
    fi
  done
  
  # 清理临时文件
  rm -rf "$temp_dir"
else
  # 串行构建
  for platform in "${PLATFORMS[@]}"; do
    case "$platform" in
      "apk")
        build_android_package "apk" "flutter build apk --release" "build/app/outputs/flutter-apk/app-release.apk"
        if [ $? -ne 0 ]; then
          BUILD_FAILURE=true
        fi
        ;;
      "aab")
        build_android_package "aab" "flutter build appbundle --release" "build/app/outputs/bundle/release/app-release.aab"
        if [ $? -ne 0 ]; then
          BUILD_FAILURE=true
        fi
        ;;
      "ios")
        build_ios
        if [ $? -ne 0 ]; then
          BUILD_FAILURE=true
        fi
        ;;
      *)
        log_error "无效参数: $platform. 请使用: apk, aab, 或 ios"
        BUILD_FAILURE=true
        ;;
    esac
  done
fi

if [ "$BUILD_FAILURE" == "true" ]; then
  log_error "部分构建失败!"
  send_notification "构建失败，请检查错误信息"
  # 添加运行结束分隔线
  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}Flutter 应用打包脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
  printf "${GREEN}======================================================${NC}\n"
  exit 1
fi

log_info "=== 打包完成！ ==="
log_to_file "Packaging completed successfully"

# 发送构建完成通知
send_notification "构建完成，生成了 ${#PLATFORMS[@]} 个文件"

# 添加运行结束分隔线
printf "${GREEN}======================================================${NC}\n"
printf "${GREEN}Flutter 应用打包脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
printf "${GREEN}======================================================${NC}\n"

