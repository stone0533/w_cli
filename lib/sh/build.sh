#!/bin/bash

# ======================================================
# build.sh - Flutter 应用打包脚本
# 版本管理信息
# Version: 1.0.2
# Last Updated: 2026-05-21
# Author: Stone
# Description: 用于构建 Flutter 应用的多平台打包脚本
# Features:
#   - 支持 Android APK、AAB 和 iOS IPA 打包
#   - 支持生产模式和 UAT 模式
#   - 应用商店要求检查
#   - 详细的日志和错误处理
#   - 支持通过命令行参数指定应用名称
# ======================================================

# 配置变量
# 输出目录，默认在当前目录创建 w_build 文件夹
OUTPUT_DIR="${OUTPUT_DIR:-w_build}"

# 是否启用调试模式，默认禁用
DEBUG_MODE="${DEBUG_MODE:-false}"

# 脚本版本号
SCRIPT_VERSION="1.0.2"

# 脚本最后更新日期
SCRIPT_LAST_UPDATED="2026-05-21"

# 是否启用并行构建，默认禁用
# 启用后可以同时构建多个平台，提高构建速度

# 全局临时目录数组（用于清理）
declare -a TEMP_DIRS=()

# 合并清理函数（避免 trap 冲突）
cleanup() {
  # 清理所有临时目录
  if [ ${#TEMP_DIRS[@]} -gt 0 ]; then
    log_debug "清理临时目录..."
    for dir in "${TEMP_DIRS[@]}"; do
      if [ -d "$dir" ]; then
        rm -rf "$dir"
        log_debug "已清理: $dir"
      fi
    done
    TEMP_DIRS=()
  fi
  
  # 清理单个临时目录（兼容旧代码）
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    log_debug "Cleaning up temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
    TEMP_DIR=""
  fi
}

# 设置全局清理 trap
trap cleanup EXIT

# 验证构建产物完整性
# 参数: file_path min_size_bytes
verify_build_output() {
  local file_path="$1"
  local min_size="${2:-1024}"  # 默认最小 1KB
  
  if [ ! -f "$file_path" ]; then
    log_error "构建产物不存在: $file_path"
    return 1
  fi
  
  # 获取文件大小（兼容 macOS 和 Linux）
  local file_size
  if [ "$(uname)" == "Darwin" ]; then
    file_size=$(stat -f%z "$file_path" 2>/dev/null)
  else
    file_size=$(stat -c%s "$file_path" 2>/dev/null)
  fi
  
  if [ -z "$file_size" ]; then
    log_error "无法获取文件大小: $file_path"
    return 1
  fi
  
  if [ "$file_size" -lt "$min_size" ]; then
    log_error "构建产物不完整: $file_path (大小: ${file_size}bytes，最小要求: ${min_size}bytes)"
    return 1
  fi
  
  log_debug "构建产物验证通过: $file_path (${file_size}bytes)"
  return 0
}

# 清理失败产物
# 参数: platform (apk/aab/ios)
cleanup_failed_build() {
  local platform="$1"
  
  log_info "清理 $platform 失败产物..."
  
  case "$platform" in
    "apk")
      # 清理 APK 相关产物
      rm -f "build/app/outputs/flutter-apk/app-release.apk" 2>/dev/null
      rm -f "$OUTPUT_DIR"/*_live_*.apk 2>/dev/null
      rm -f "$OUTPUT_DIR"/*_uat_*.apk 2>/dev/null
      log_debug "已清理 APK 失败产物"
      ;;
    "aab")
      # 清理 AAB 相关产物
      rm -f "build/app/outputs/bundle/release/app-release.aab" 2>/dev/null
      rm -f "$OUTPUT_DIR"/*_live_*.aab 2>/dev/null
      rm -f "$OUTPUT_DIR"/*_uat_*.aab 2>/dev/null
      log_debug "已清理 AAB 失败产物"
      ;;
    "ios")
      # 清理 iOS 相关产物
      rm -rf "build/ios/iphoneos/Runner.app" 2>/dev/null
      rm -f "build/ios/iphoneos/Runner.ipa" 2>/dev/null
      rm -f "$OUTPUT_DIR"/*_live_*.ipa 2>/dev/null
      rm -f "$OUTPUT_DIR"/*_uat_*.ipa 2>/dev/null
      log_debug "已清理 iOS 失败产物"
      ;;
    *)
      log_warn "未知平台: $platform，跳过清理"
      ;;
  esac
}

# 构建超时处理函数
# 参数: timeout_seconds command...
run_with_timeout() {
  local timeout_seconds="$1"
  shift

  log_debug "执行命令（超时: ${timeout_seconds}s）: $*"

  # 优先用 GNU coreutils 的 timeout / gtimeout；macOS 默认两者都没有，
  # 所以必须有一个不依赖外部工具的实现，超时才不是一句空话。
  if command -v timeout &> /dev/null; then
    timeout "$timeout_seconds" "$@"
    return $?
  fi
  if command -v gtimeout &> /dev/null; then
    gtimeout "$timeout_seconds" "$@"
    return $?
  fi

  "$@" &
  local child=$!
  local waited=0
  while kill -0 "$child" 2>/dev/null; do
    if [ "$waited" -ge "$timeout_seconds" ]; then
      log_warn "命令超时（${timeout_seconds}s），正在终止进程 $child"
      kill -TERM "$child" 2>/dev/null || true
      sleep 2
      kill -KILL "$child" 2>/dev/null || true
      wait "$child" 2>/dev/null || true
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$child"
  return $?
}
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

# 版本比较函数 (纯 bash 实现，兼容性更好)
# version_ge <current_version> <required_version>
# 返回 0 表示 current_version >= required_version
version_ge() {
  local current="$1"
  local required="$2"
  
  # 分割版本号为数组
  IFS='.' read -r -a current_parts <<< "$current"
  IFS='.' read -r -a required_parts <<< "$required"
  
  # 比较每个部分
  local max_index=$(( ${#current_parts[@]} > ${#required_parts[@]} ? ${#current_parts[@]} : ${#required_parts[@]} ))
  
  for ((i=0; i<max_index; i++)); do
    local current_val=${current_parts[$i]:-0}
    local required_val=${required_parts[$i]:-0}
    
    if (( current_val > required_val )); then
      return 0
    elif (( current_val < required_val )); then
      return 1
    fi
  done
  
  return 0
}

# 检查 Flutter 版本
check_flutter_version() {
  local required_version="3.10.0"
  local current_version
  
  # 获取 Flutter 版本号
  current_version=$(flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | cut -d' ' -f2)
  
  if [ -z "$current_version" ]; then
    log_warn "无法获取 Flutter 版本信息"
    return 0
  fi
  
  log_info "当前 Flutter 版本: $current_version"
  
  # 比较版本号（使用纯 bash 实现）
  if version_ge "$current_version" "$required_version"; then
    log_info "Flutter 版本满足要求 (>= $required_version)"
  else
    log_warn "Flutter 版本低于推荐版本: $current_version < $required_version"
    log_warn "建议升级到 Flutter $required_version 或更高版本"
  fi
}

# 检查项目依赖
check_dependencies() {
  log_info "检查项目依赖..."
  
  # 检查是否为 Flutter 项目
  if [ ! -f "pubspec.yaml" ]; then
    log_error "未找到 pubspec.yaml，当前目录不是 Flutter 项目"
    return 1
  fi
  
  # 检查是否需要执行 pub get
  if [ ! -d ".dart_tool" ]; then
    log_info "检测到首次构建，执行 flutter pub get..."
    if ! flutter pub get; then
      log_error "flutter pub get 执行失败"
      return 1
    fi
  else
    log_info "依赖已安装"
  fi
  
  return 0
}

# 构建前完整性检查
pre_build_check() {
  log_info "执行构建前完整性检查..."
  
  # 检查平台目录
  for platform in "${PLATFORMS[@]}"; do
    case "$platform" in
      "apk"|"aab")
        if [ ! -d "android" ]; then
          log_error "未找到 android 目录，无法构建 Android"
          return 1
        fi
        ;;
      "ios")
        if [ ! -d "ios" ]; then
          log_error "未找到 ios 目录，无法构建 iOS"
          return 1
        fi
        ;;
    esac
  done
  
  log_info "完整性检查通过"
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
  
  # 检查 Flutter 版本
  check_flutter_version
  
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
    osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\"" 2>/dev/null || true
  elif command -v notify-send &> /dev/null; then
    # Linux 通知
    notify-send "$escaped_title" "$escaped_message" 2>/dev/null || true
  fi
}

# 检查执行权限（仅在直接执行时检查，source 时跳过）
if [ "$0" = "$BASH_SOURCE" ] && [ ! -x "$0" ]; then
  log_error "Script does not have execution permission."
  log_warn "Please run: chmod +x $0"
  exit 1
fi

# 显示帮助信息
show_help() {
  log_warn "Usage: ./build.sh [apk] [aab] [ios] [--uat] [--clean] [--open] [--debug] [--version] [--help]"
  log_warn "Options:"
  log_info "  --uat                      # Build in UAT mode with timestamp"
  log_info "  --clean                    # Clear build directory before building"
  log_info "  --open                     # Open output directory in Finder after build"
  log_info "  --debug                    # Enable debug mode with verbose logging"
  log_info "  --version                  # Show script version information"
  log_info "  --help                     # Show this help message"
  log_info "  -name:<name>               # Specify app name for output files"
  log_warn "iOS 代码签名配置:"
  log_info "  默认配置: 在 w_build/ 目录下放置 ios.plist 文件"
  log_info "  文件格式: Xcode ExportOptions.plist（XML 格式）"
  log_info "  用途: 指定代码签名证书、Provisioning Profile、团队 ID 等"
  log_info "  多配置支持: 在 w_build/ 目录下放置多个 plist 文件（如 uat.plist）"
  log_info "              使用: ./build.sh ios -export-options:uat.plist"
  log_info "  如果找到 ios.plist，构建时会自动使用它进行代码签名"
  log_warn "Environment variables:"
  log_info "  PARALLEL_BUILD=true         # Enable parallel builds"
  log_info "  ENABLE_NOTIFICATIONS=true   # Enable build notifications"
  log_warn "Examples:"
  log_info "  ./build.sh apk                # Build APK in production mode"
  log_info "  ./build.sh apk aab            # Build APK and AAB in production mode"
  log_info "  ./build.sh apk --uat          # Build APK in UAT mode"
  log_info "  ./build.sh --version          # Show script version"
  log_info "  ./build.sh --help             # Show this help message"
  log_info "  PARALLEL_BUILD=true ./build.sh apk aab # Build APK and AAB in parallel"
  log_info "  ./build.sh apk aab ios --uat --clean # Build all platforms in UAT mode and clear build directory"
  log_info "  ./build.sh ios                 # Build iOS，自动查找 w_build/ios.plist 进行签名"
}

# 检查参数是否正确
if [ $# -lt 1 ]; then
  show_help
  exit 0
fi

# 检查帮助参数
if [ "$1" == "--help" ]; then
  show_help
  exit 0
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
  
  log_debug "Configuration validated successfully"
}

# 获取版本号
VERSION=$(get_version)
# 移除版本号中的 + 号，用于文件名
VERSION_FOR_FILENAME=$(echo $VERSION | tr '+' '-')

# 检查参数
UAT_MODE=false
CLEAR_MODE=false
OPEN_MODE=false
PLATFORMS=()
APP_NAME=""
CODE_SIGN_IDENTITY=""
PROVISIONING_PROFILE=""
EXPORT_OPTIONS_PLIST=""
for arg in "$@"; do
  case "$arg" in
    "apk"|"aab"|"ios")
      PLATFORMS+=($arg)
      ;;
    "--uat")
      UAT_MODE=true
      ;;
    "--clean")
      CLEAR_MODE=true
      ;;
    "--open")
      OPEN_MODE=true
      ;;
    "--help")
      show_help
      ;;
    "--debug")
      DEBUG_MODE=true
      log_info "启用调试模式"
      ;;
    -name:* )
      APP_NAME="${arg#-name:}"
      # 去除首尾空格
      APP_NAME=$(echo "$APP_NAME" | tr -d '[:space:]')
      # 验证参数不为空
      if [ -z "$APP_NAME" ]; then
        log_error "-name 参数不能为空"
        show_help >&2
        exit 2
      fi
      # 验证参数不包含路径分隔符
      if [[ "$APP_NAME" == *"/"* ]]; then
        log_error "-name 参数不允许包含路径分隔符: $APP_NAME"
        exit 1
      fi
      ;;
    -export-options:* )
      EXPORT_OPTIONS_PLIST="${arg#-export-options:}"
      # 去除首尾空格
      EXPORT_OPTIONS_PLIST=$(echo "$EXPORT_OPTIONS_PLIST" | tr -d '[:space:]')
      # 验证参数不为空
      if [ -z "$EXPORT_OPTIONS_PLIST" ]; then
        log_error "-export-options 参数不能为空"
        show_help >&2
        exit 2
      fi
      # 防止路径遍历攻击
      if [[ "$EXPORT_OPTIONS_PLIST" == *".."* ]]; then
        log_error "不允许使用路径遍历: $EXPORT_OPTIONS_PLIST"
        exit 1
      fi
      # 如果指定的是纯文件名（不含路径分隔符），则在 OUTPUT_DIR 中查找
      if [[ "$EXPORT_OPTIONS_PLIST" != */* ]]; then
        EXPORT_OPTIONS_PLIST="$OUTPUT_DIR/$EXPORT_OPTIONS_PLIST"
      fi
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

# 检查项目依赖
if ! check_dependencies; then
  log_error "依赖检查失败，无法继续构建"
  exit 1
fi

# 构建前完整性检查
if ! pre_build_check; then
  log_error "完整性检查失败，无法继续构建"
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

# 删除已存在的文件
delete_existing_file() {
  local target_file="$1"
  
  if [ ! -f "$target_file" ]; then
    return 0
  fi
  
  # 直接删除已存在的文件
  rm -f "$target_file"
  log_warn "删除已存在文件: $target_file"
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
  local build_command_str="$2"
  local source_path="$3"
  
  local package_type_upper=$(echo "$package_type" | tr '[:lower:]' '[:upper:]')
  
  log_info "=== Building $package_type_upper ==="
  
  # 安全验证
  # 确保构建命令是有效的 Flutter 构建命令
  if ! echo "$build_command_str" | grep -qE '^flutter build (apk|appbundle) --release$'; then
    log_error "无效的构建命令: $build_command_str"
    log_error "构建命令必须是: flutter build apk --release 或 flutter build appbundle --release"
    return 1
  fi
  
  # 将命令字符串解析为数组（防止命令注入）
  # 使用 read -a 进行更健壮的解析，支持带空格的参数
  IFS=' ' read -r -a build_command <<< "$build_command_str"
  
  # 检查数组是否为空
  if [ ${#build_command[@]} -eq 0 ]; then
    log_error "构建命令为空"
    return 1
  fi
  
  # 记录开始时间
  local start_time=$(date +%s)
  
  # 执行构建命令（使用数组避免命令注入，设置超时时间为 30 分钟）
  log_info "执行构建命令..."
  log_debug "完整命令: ${build_command[*]}"
  local timeout=1800  # 30 分钟
  run_with_timeout "$timeout" "${build_command[@]}" | sed 's/\x1B\[[0-9;]*[mK]//g'
  # 管道最后一个命令是 sed，必须取 PIPESTATUS[0] 才是构建本身的退出码
  local build_status=${PIPESTATUS[0]}
  if [ "$build_status" -ne 0 ]; then
    local exit_code=$build_status
    if [ "$exit_code" -eq 124 ]; then
      log_error "构建 $package_type_upper 超时（超过 ${timeout}s）"
    else
      log_error "构建 $package_type_upper 失败"
      log_error "错误原因可能包括:"
      log_error "  1. Flutter 环境未正确配置"
      log_error "  2. 依赖包缺失 (运行: flutter pub get)"
      log_error "  3. 代码存在编译错误"
      log_error "  4. 资源文件缺失或损坏"
      log_error "  5. Java 版本不兼容 (建议使用 Java 17)"
      log_error "请检查上述问题后重试"
    fi
    cleanup_failed_build "$package_type"
    return 1
  fi
  
  # 计算构建时间
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_info "构建耗时: ${duration}s"
  
  # 验证构建产物完整性
  if ! verify_build_output "$source_path" 10240; then  # 最小 10KB
    cleanup_failed_build "$package_type"
    return 1
  fi
  
  # 处理构建产物
  local output_file=$(generate_filename "$package_type" "$package_type" "")
  delete_existing_file "$output_file"
  
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
  
  # 创建临时目录并注册到全局数组
  local temp_dir=$(mktemp -d)
  TEMP_DIRS+=("$temp_dir")
  log_debug "创建临时目录: $temp_dir"
  
  mkdir -p "$temp_dir/Payload"
  
  # 复制 Runner.app 到 Payload 目录
  if ! cp -r "$app_path" "$temp_dir/Payload/"; then
    log_error "复制应用包失败"
    return 1
  fi
  
  # 压缩成 IPA 文件
  cd "$temp_dir"
  local abs_ipa_file="$current_dir/$output_path"
  log_warn "正在创建 IPA 文件: $abs_ipa_file"
  
  # 使用安静模式和最大压缩
  if ! zip -qr -9 "$abs_ipa_file" Payload/; then
    log_error "创建 IPA 压缩包失败"
    cd - > /dev/null
    return 1
  fi
  
  cd - > /dev/null
  
  # 验证 IPA 文件
  if [ ! -f "$abs_ipa_file" ]; then
    log_error "IPA 文件未创建"
    return 1
  fi
  
  local file_size=$(du -h "$abs_ipa_file" | cut -f1)
  log_info "IPA 创建成功: $file_size"
  
  return 0
}

# 从 plist 文件中提取字段值
get_plist_value() {
  local plist_file="$1"
  local key="$2"
  # 使用 sed 提取 <key>key</key> 后面的 <string>value</string>
  grep -A1 "<key>$key</key>" "$plist_file" | grep "<string>" | sed 's/<[^>]*>//g' | tr -d '[:space:]'
}

# 验证 ios.plist 文件
validate_ios_plist() {
  local plist_file="$1"
  local has_error=false
  
  if [ ! -f "$plist_file" ]; then
    log_warn "未找到 ios.plist 文件，将自动生成模板"
    return 1
  fi
  
  # 检查是否包含必要字段（使用精确匹配）
  local has_method=$(grep -c "^[[:space:]]*<key>method</key>" "$plist_file")
  local has_teamid=$(grep -c "^[[:space:]]*<key>teamID</key>" "$plist_file")
  local has_signingstyle=$(grep -c "^[[:space:]]*<key>signingStyle</key>" "$plist_file")
  local has_signingcert=$(grep -c "^[[:space:]]*<key>signingCertificate</key>" "$plist_file")
  local has_provisioning=$(grep -c "^[[:space:]]*<key>provisioningProfiles</key>" "$plist_file")
  
  # 获取 signingStyle 值（默认为 manual）
  local signingstyle_value=$(get_plist_value "$plist_file" "signingStyle")
  signingstyle_value=${signingstyle_value:-manual}
  
  # 检查必需字段
  if [ "$has_method" -eq 0 ] || [ "$has_teamid" -eq 0 ]; then
    log_warn "ios.plist 文件缺少必要字段，请检查配置"
    log_info "缺少的字段:"
    [ "$has_method" -eq 0 ] && log_info "  - method"
    [ "$has_teamid" -eq 0 ] && log_info "  - teamID"
    return 1
  fi
  
  # 根据签名方式检查字段
  if [ "$signingstyle_value" = "manual" ]; then
    # 手动签名需要 signingCertificate 和 provisioningProfiles
    if [ "$has_signingcert" -eq 0 ] || [ "$has_provisioning" -eq 0 ]; then
      log_warn "手动签名模式下缺少必要字段"
      [ "$has_signingcert" -eq 0 ] && log_info "  - signingCertificate (手动签名必需)"
      [ "$has_provisioning" -eq 0 ] && log_info "  - provisioningProfiles (手动签名必需)"
      return 1
    fi
  else
    # 自动签名模式，signingCertificate 和 provisioningProfiles 可选
    log_debug "自动签名模式，跳过 signingCertificate 和 provisioningProfiles 验证"
  fi
  
  # 检查字段值是否为空
  local method_value=$(get_plist_value "$plist_file" "method")
  local teamid_value=$(get_plist_value "$plist_file" "teamID")
  local signingcert_value=$(get_plist_value "$plist_file" "signingCertificate")
  
  if [ -z "$method_value" ]; then
    log_warn "method 字段值为空"
    has_error=true
  fi
  
  if [ -z "$teamid_value" ]; then
    log_warn "teamID 字段值为空"
    has_error=true
  fi
  
  # 手动签名模式下检查 signingCertificate
  if [ "$signingstyle_value" = "manual" ] && [ -z "$signingcert_value" ]; then
    log_warn "signingCertificate 字段值为空（手动签名必需）"
    has_error=true
  fi
  
  # 检查字段值是否已修改（不是默认占位符）
  local has_default_value=$(grep -c "YOUR_" "$plist_file")
  if [ "$has_default_value" -gt 0 ]; then
    log_warn "ios.plist 文件中存在未修改的默认值（YOUR_*）"
    log_warn "请修改以下字段后重新构建:"
    grep "YOUR_" "$plist_file" | while read -r line; do
      log_info "  $line"
    done
    has_error=true
  fi
  
  # 检查 method 值是否有效
  if [ -n "$method_value" ] && [ "$method_value" != "app-store" ] && [ "$method_value" != "ad-hoc" ] && [ "$method_value" != "enterprise" ] && [ "$method_value" != "development" ]; then
    log_warn "method 字段值无效: $method_value"
    log_warn "有效值: app-store, ad-hoc, enterprise, development"
    has_error=true
  fi
  
  # 检查 signingStyle 值是否有效
  if [ -n "$signingstyle_value" ] && [ "$signingstyle_value" != "automatic" ] && [ "$signingstyle_value" != "manual" ]; then
    log_warn "signingStyle 字段值无效: $signingstyle_value"
    log_warn "有效值: automatic, manual"
    has_error=true
  fi
  
  # 检查 teamID 格式（10 位字符）
  if [ -n "$teamid_value" ] && ! echo "$teamid_value" | grep -qE '^[A-Z0-9]{10}$'; then
    log_warn "teamID 格式不正确（应为 10 位字符）: $teamid_value"
    has_error=true
  fi
  
  if [ "$has_error" = true ]; then
    return 1
  fi
  
  log_info "ios.plist 文件验证通过"
  return 0
}

# 生成 ios.plist 模板文件
generate_ios_plist_template() {
  local output_file="$1"
  
  # 检查输出目录是否可写
  if [ ! -d "$OUTPUT_DIR" ]; then
    if ! mkdir -p "$OUTPUT_DIR"; then
      log_error "无法创建输出目录: $OUTPUT_DIR"
      log_error "请检查目录权限"
      return 1
    fi
  fi
  
  # 检查目录是否可写
  if [ ! -w "$OUTPUT_DIR" ]; then
    log_error "输出目录不可写: $OUTPUT_DIR"
    log_error "请检查目录权限"
    return 1
  fi
  
  # 检查文件是否已存在，如果存在则备份
  if [ -f "$output_file" ]; then
    local backup_file="${output_file}.backup_$(date +%Y%m%d_%H%M%S)"
    if ! cp "$output_file" "$backup_file"; then
      log_warn "无法备份现有文件: $output_file"
    else
      log_info "已备份现有文件: $backup_file"
    fi
  fi
  
  # 写入模板文件
  if ! cat > "$output_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 分发方式: app-store / ad-hoc / enterprise / development -->
    <key>method</key>
    <string>app-store</string>
    
    <!-- 团队 ID（10 位字符，可在 App Store Connect 查看） -->
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    
    <!-- 签名方式选择说明：
         - automatic（自动签名）：推荐，Xcode自动管理证书和Profile
         - manual（手动签名）：需要手动配置证书和Profile
    -->
    <key>signingStyle</key>
    <string>manual</string>
    
    <!-- ================ 手动签名配置（自动签名时请删除）=============== -->
    <!-- 签名证书名称（使用 security find-identity -v -p codesigning 查看） -->
    <key>signingCertificate</key>
    <string>Apple Distribution: YOUR_COMPANY_NAME (YOUR_CERTIFICATE_ID)</string>
    
    <!-- Provisioning Profile 配置 -->
    <key>provisioningProfiles</key>
    <dict>
        <!-- Bundle ID（与 App Store Connect 中的配置一致） -->
        <key>YOUR_BUNDLE_ID</key>
        <!-- Profile 名称（与 Apple Developer 网站上的名称一致 iOS Team Provisioning Profile: Bundle ID） -->
        <string>YOUR_PROVISIONING_PROFILE_NAME</string>
    </dict>
</dict>
</plist>
EOF
  then
    log_error "无法写入 ios.plist 模板文件: $output_file"
    return 1
  fi
  
  log_info "已生成 ios.plist 模板文件: $output_file"
  log_warn "请修改以下字段后重新构建:"
  log_info "  - teamID: 你的 Apple Developer 团队 ID（10 位字符）"
  log_info "  - signingCertificate: 你的分发证书名称"
  log_info "  - provisioningProfiles/key: 你的应用 Bundle ID"
  log_info "  - provisioningProfiles/value: 你的 Provisioning Profile 名称"
  log_info ""
  log_info "获取团队 ID 和证书名称的命令:"
  log_info "  security find-identity -v -p codesigning"
  log_info "  security find-certificate -a -p | openssl x509 -noout -subject"
  log_info ""
  log_info "示例配置:"
  log_info "  teamID: ABC123DEF4"
  log_info "  signingCertificate: Apple Distribution: My Company (GHI567JKL8)"
  log_info "  provisioningProfiles/key: com.mycompany.myapp"
  log_info "  provisioningProfiles/value: AppStore_MyApp"
}

# 构建 iOS
build_ios() {
  log_info "=== 构建 iOS ==="
  
  # 记录开始时间
  local start_time=$(date +%s)
  
  # 自动查找 ExportOptions.plist（从 OUTPUT_DIR 查找 ios.plist）
  local default_export_options="$OUTPUT_DIR/ios.plist"
  local export_options_file=""
  
  # 优先检查命令行参数
  if [ -n "$EXPORT_OPTIONS_PLIST" ]; then
    if [ -f "$EXPORT_OPTIONS_PLIST" ]; then
      export_options_file="$EXPORT_OPTIONS_PLIST"
      log_info "使用命令行指定的 Export Options: $export_options_file"
    else
      log_warn "命令行指定的 Export Options 文件不存在: $EXPORT_OPTIONS_PLIST"
      log_warn "将尝试自动检测..."
    fi
  fi
  
  # 如果命令行参数未指定或文件不存在，尝试自动检测
  if [ -z "$export_options_file" ]; then
    if [ -f "$default_export_options" ]; then
      # 文件存在，验证内容
      if validate_ios_plist "$default_export_options"; then
        export_options_file="$default_export_options"
        log_info "自动检测到 Export Options: $export_options_file"
      else
        log_error "ios.plist 文件配置不正确，构建终止"
        return 1
      fi
    else
      # 文件不存在，生成模板
      if ! generate_ios_plist_template "$default_export_options"; then
        log_error "无法生成 ios.plist 模板文件，构建终止"
        return 1
      fi
      log_error "请修改 ios.plist 文件后重新运行构建"
      return 1
    fi
  fi
  
  # 使用数组构建 Flutter 构建命令（防止命令注入）
  local -a flutter_build_command=("flutter" "build" "ios" "--release" "--no-codesign")
  
  log_info "执行 Flutter 构建命令..."
  log_debug "完整命令: ${flutter_build_command[*]}"
  
  # 执行 Flutter 构建命令（设置超时时间为 30 分钟）
  local timeout=1800  # 30 分钟
  run_with_timeout "$timeout" "${flutter_build_command[@]}" | sed 's/\x1B\[[0-9;]*[mK]//g'
  local build_status=${PIPESTATUS[0]}
  if [ "$build_status" -ne 0 ]; then
    local exit_code=$build_status
    if [ "$exit_code" -eq 124 ]; then
      log_error "Flutter 构建超时（超过 ${timeout}s）"
    else
      log_error "Flutter 构建失败"
      log_error "错误原因可能包括:"
      log_error "  1. Flutter 环境未正确配置"
      log_error "  2. Xcode 未安装或版本不兼容"
      log_error "  3. 代码存在编译错误"
      log_error "  4. 依赖包缺失 (运行: flutter pub get)"
      log_error "请检查上述问题后重试"
    fi
    cleanup_failed_build "ios"
    return 1
  fi
  
  # 验证构建产物是否存在
  local runner_app_path="build/ios/iphoneos/Runner.app"
  if [ ! -d "$runner_app_path" ]; then
    log_error "Flutter 构建产物不存在: $runner_app_path"
    log_error "Flutter 构建可能未完全成功"
    cleanup_failed_build "ios"
    return 1
  fi
  
  # 使用 xcodebuild 导出 IPA
  log_info "使用 xcodebuild 导出 IPA..."
  
  # 创建临时导出目录
  local export_dir=$(mktemp -d)
  TEMP_DIRS+=("$export_dir")
  
  # 执行 xcodebuild 导出命令
  local xcodebuild_command=(
    "xcodebuild"
    "-exportArchive"
    "-archivePath" "build/ios/archive/Runner.xcarchive"
    "-exportPath" "$export_dir"
    "-exportOptionsPlist" "$export_options_file"
  )
  
  log_debug "xcodebuild 命令: ${xcodebuild_command[*]}"
  
  # 获取签名方式
  local signing_style=$(get_plist_value "$export_options_file" "signingStyle")
  signing_style=${signing_style:-automatic}
  local team_id=$(get_plist_value "$export_options_file" "teamID")
  
  log_info "签名方式: $signing_style"
  log_info "团队 ID: $team_id"
  
  # 首先需要创建 archive
  local archive_command=(
    "xcodebuild"
    "-workspace" "ios/Runner.xcworkspace"
    "-scheme" "Runner"
    "-configuration" "Release"
    "-archivePath" "build/ios/archive/Runner.xcarchive"
    "-allowProvisioningUpdates"
    "archive"
  )
  
  # 如果是自动签名，添加签名参数
  if [ "$signing_style" = "automatic" ]; then
    archive_command+=("-sdk" "iphoneos")
    archive_command+=("-destination" "generic/platform=iOS")
  else
    # 手动签名模式，需要添加证书参数
    local cert_name=$(get_plist_value "$export_options_file" "signingCertificate")
    if [ -n "$cert_name" ]; then
      archive_command+=("-codeSignIdentity" "$cert_name")
    fi
    archive_command+=("-sdk" "iphoneos")
    archive_command+=("-destination" "generic/platform=iOS")
  fi
  
  log_info "创建 Xcode Archive..."
  log_debug "Archive 命令: ${archive_command[*]}"
  if ! run_with_timeout "$timeout" "${archive_command[@]}" 2>&1 | sed 's/\x1B\[[0-9;]*[mK]//g'; then
    log_error "Xcode Archive 创建失败"
    cleanup_failed_build "ios"
    return 1
  fi
  
  log_info "导出 IPA..."
  if ! run_with_timeout "$timeout" "${xcodebuild_command[@]}" 2>&1 | sed 's/\x1B\[[0-9;]*[mK]//g'; then
    log_error "xcodebuild 导出 IPA 失败"
    log_error "错误原因可能包括:"
    log_error "  1. 开发者证书未正确配置"
    log_error "  2. Provisioning Profile 配置错误（确保使用 Distribution 类型）"
    log_error "  3. ios.plist 文件配置不正确"
    log_error "请检查上述问题后重试"
    cleanup_failed_build "ios"
    return 1
  fi
  
  # 计算构建时间
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_info "构建耗时: ${duration}s"
  
  # 查找导出的 IPA 文件（新版本 Xcode 可能使用不同的路径结构）
  local exported_ipa=""
  # 首先尝试标准路径
  if [ -f "$export_dir/Runner.ipa" ]; then
    exported_ipa="$export_dir/Runner.ipa"
  else
    # 在导出目录下查找所有 IPA 文件
    local ipa_files=("$export_dir"/*.ipa)
    if [ -f "${ipa_files[0]}" ]; then
      exported_ipa="${ipa_files[0]}"
    else
      # 在导出目录的子目录中查找
      local found_ipa=$(find "$export_dir" -name "*.ipa" -type f 2>/dev/null | head -1)
      if [ -n "$found_ipa" ]; then
        exported_ipa="$found_ipa"
      fi
    fi
  fi
  
  # 验证导出的 IPA 是否存在
  if [ -z "$exported_ipa" ] || [ ! -f "$exported_ipa" ]; then
    log_error "IPA 文件未生成或未找到"
    log_error "搜索路径: $export_dir"
    cleanup_failed_build "ios"
    return 1
  fi
  
  log_info "找到导出的 IPA 文件: $exported_ipa"
  
  # 验证 Runner.app 内的关键文件（已通过 xcodebuild 验证）
  if [ ! -f "$runner_app_path/Info.plist" ]; then
    log_error "Runner.app 缺少 Info.plist 文件"
    cleanup_failed_build "ios"
    return 1
  fi
  
  if [ ! -f "$runner_app_path/Runner" ]; then
    log_error "Runner.app 缺少可执行文件"
    cleanup_failed_build "ios"
    return 1
  fi
  
  log_info "构建产物验证通过: $runner_app_path"
  
  local ipa_file=$(generate_filename "ios" "ipa" "")
  delete_existing_file "$ipa_file"
  
  # 复制 xcodebuild 导出的 IPA 文件到输出目录
  log_info "复制 IPA 文件到输出目录..."
  if command -v rsync &> /dev/null; then
    rsync -ah "$exported_ipa" "$ipa_file"
  else
    cp "$exported_ipa" "$ipa_file"
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
      --uat|--clean|--open|--debug|--help|--version)
        ;;
      -name:*|--name:*|-export-options:*|--export-options:*)
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
  # 注意：这一段在脚本顶层执行，不能用 local（bash 的 local 只允许出现在函数内）
  build_status=()
  for platform in "${PLATFORMS[@]}"; do
    build_status+=(0)
  done

  # 创建临时文件来存储每个构建的退出状态
  temp_dir=$(mktemp -d)
  status_files=()

  i=0
  for platform in "${PLATFORMS[@]}"; do
    status_file="$temp_dir/status_$i.txt"
    status_files+=("$status_file")
    
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
      exit_code=$(cat "$status_file" 2>/dev/null || echo 1)
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

# 打开输出目录
if [ "$OPEN_MODE" == "true" ]; then
  log_info "正在打开输出目录..."
  if [ "$(uname)" == "Darwin" ]; then
    # macOS 使用 Finder 打开
    open "$OUTPUT_DIR"
  elif command -v xdg-open &> /dev/null; then
    # Linux 使用 xdg-open 打开
    xdg-open "$OUTPUT_DIR"
  elif command -v start &> /dev/null; then
    # Windows 使用 start 打开
    start "$OUTPUT_DIR"
  else
    log_warn "无法打开输出目录: 不支持的操作系统"
  fi
fi

# 添加运行结束分隔线
printf "${GREEN}======================================================${NC}\n"
printf "${GREEN}Flutter 应用打包脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
printf "${GREEN}======================================================${NC}\n"

