#!/bin/bash
set -eo pipefail

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# 配置变量
# 输出目录，默认在当前目录创建 w_build 文件夹
OUTPUT_DIR="${OUTPUT_DIR:-w_build}"

# 是否启用调试模式，默认禁用
DEBUG_MODE="${DEBUG_MODE:-false}"

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
}

# 追加一行到构建日志（$OUTPUT_DIR/build.log）。
# 记日志失败不该影响构建结果，所以吞掉错误。
log_to_file() {
  local line="$1"
  local log_file="${OUTPUT_DIR:-w_build}/build.log"
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line" >> "$log_file" 2>/dev/null || true
}

# 只清理本工具产出的文件。
# OUTPUT_DIR 里还放着用户自己的东西（例如 w_build/ios.plist 签名配置），
# 以前 `rm -rf $OUTPUT_DIR/*` 会把它们一起删掉。
clean_output_directory() {
  local dir="$1"
  local removed=0
  local artifact=""

  if [ ! -d "$dir" ]; then
    return 0
  fi

  while IFS= read -r artifact; do
    rm -f -- "$artifact"
    removed=$((removed + 1))
  done < <(find "$dir" -maxdepth 1 -type f \( \
    -name '*_live_*' -o -name '*_uat_*' \
    -o -name '.last_build_*' -o -name 'build.log' \) 2>/dev/null)

  log_info "已清理 $removed 个上次构建产物（目录里的其它文件保留）"
}

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
  
  # 只清理本次构建的中间产物。$OUTPUT_DIR 里可能是上一次成功的成品，
  # 失败的这一次根本还没往里写过东西，不该去动它。
  case "$platform" in
    "apk")
      rm -f "build/app/outputs/flutter-apk/app-release.apk" 2>/dev/null
      log_debug "已清理 APK 失败产物"
      ;;
    "aab")
      rm -f "build/app/outputs/bundle/release/app-release.aab" 2>/dev/null
      log_debug "已清理 AAB 失败产物"
      ;;
    "ios")
      rm -rf "build/ios/iphoneos/Runner.app" 2>/dev/null
      rm -f "build/ios/iphoneos/Runner.ipa" 2>/dev/null
      log_debug "已清理 iOS 失败产物"
      ;;
    *)
      log_warn "未知平台: ${platform}，跳过清理"
      ;;
  esac
}

PARALLEL_BUILD="${PARALLEL_BUILD:-false}"

# 构建产物最小大小（字节），低于这个值视为构建失败
MIN_BUILD_SIZE="${MIN_BUILD_SIZE:-10240}"

# 是否启用构建通知，默认启用
# 构建完成后会发送系统通知
ENABLE_NOTIFICATIONS="${ENABLE_NOTIFICATIONS:-true}"

# 版本比较函数 (纯 bash 实现，兼容性更好)
# version_ge <current_version> <required_version>
# 返回 0 表示 current_version >= required_version
version_ge() {
  # 3.10.0-1.pre / 3.10.0+build 这类版本只比前三段数字
  local current="${1%%+*}"
  current="${current%%-*}"
  local required="${2%%+*}"
  required="${required%%-*}"
  
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
  
  log_debug "当前 Flutter 版本: $current_version"
  
  # 比较版本号（使用纯 bash 实现）
  if version_ge "$current_version" "$required_version"; then
    log_debug "Flutter 版本满足要求 (>= $required_version)"
  else
    log_warn "Flutter 版本低于推荐版本: $current_version < $required_version"
    log_warn "建议升级到 Flutter $required_version 或更高版本"
  fi
}

# 检查项目依赖
check_dependencies() {
  log_debug "检查项目依赖..."
  
  # 检查是否为 Flutter 项目
  if [ ! -f "pubspec.yaml" ]; then
    log_error "未找到 pubspec.yaml，当前目录不是 Flutter 项目"
    return 1
  fi
  
  # 检查是否需要执行 pub get
  if [ ! -d ".dart_tool" ]; then
    log_info "首次构建，安装依赖（flutter pub get）..."
    if ! flutter pub get; then
      log_error "flutter pub get 执行失败"
      return 1
    fi
  else
    log_debug "依赖已安装"
  fi
  
  return 0
}

# 构建前完整性检查
pre_build_check() {
  log_debug "执行构建前完整性检查..."
  
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
  
  log_debug "完整性检查通过"
  return 0
}

# 环境检查
check_environment() {
  log_debug "检查构建环境..."
  
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
    log_debug "aapt 已找到: $(which aapt)"
  fi
  
  # 检查 iOS 工具（仅在 macOS 上）
  if [ "$(uname)" == "Darwin" ]; then
    if command -v xcodebuild &> /dev/null; then
      log_debug "Xcode 构建工具已找到"
    else
      log_warn "Xcode 构建工具未找到，iOS 构建可能失败"
    fi
  elif [ "$(uname)" == "Linux" ]; then
    log_info "Linux 系统检测到，仅支持 Android 构建"
  else
    log_warn "未知系统，仅支持 Android 构建"
  fi
  
  log_debug "环境检查完成"
  return 0
}

# 发送通知
# 转义 AppleScript 字符串字面量：反斜杠和双引号
escape_applescript() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

send_notification() {
  if [ "$ENABLE_NOTIFICATIONS" != "true" ]; then
    return 0
  fi
  
  local message="$1"
  local title="Flutter 构建"

  if [ "$(uname)" == "Darwin" ]; then
    # osascript 的字符串要自己转义反斜杠与双引号
    local escaped_message=$(escape_applescript "$message")
    local escaped_title=$(escape_applescript "$title")
    osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\"" 2>/dev/null || true
  elif command -v notify-send &> /dev/null; then
    # notify-send 走 argv，不需要转义
    notify-send "$title" "$message" 2>/dev/null || true
  fi
}

# 显示帮助信息
show_help() {
  log_info "用法: ww build [apk] [aab] [ios] [选项]   （或 bash lib/sh/build.sh ...）"
  log_info "Options:"
  log_info "  --uat                      # Build in UAT mode with timestamp"
  log_info "  --fresh                    # 构建前清理输出目录里本工具的旧产物（旧名 --clean）"
  log_info "  --open                     # Open output directory in Finder after build"
  log_info "  --debug                    # Enable debug mode with verbose logging"
  log_info "  --version                  # Show script version information"
  log_info "  --help                     # Show this help message"
  log_info "  --name=<name>              # Specify app name for output files"
  log_info "iOS 签名（优先级从高到低）:"
  log_info "  1. 命令行参数: --method= --team= --bundle-id= --cert= --profile= --automatic --manual"
  log_info "  2. w_build/ios.plist            # 个人覆盖（不提交）"
  log_info "  3. ios/ExportOptions.plist      # 团队共用（可提交）"
  log_info "  4. 零配置: 从 ios/Runner.xcodeproj 读 DEVELOPMENT_TEAM，按自动签名构建"
  log_info ""
  log_info "  例: ww build ios                                    # 本地/测试，无需配置"
  log_info "      ww build ios --method=ad-hoc                    # 换分发方式"
  log_info "      ww build ios --method=app-store --team=ABC123DEF4 \\"
  log_info "                   --bundle-id=com.x.y --cert=\"Apple Distribution: X (ID)\" --profile=\"Profile 名\""
  log_info "Environment variables:"
  log_info "  PARALLEL_BUILD=true         # Enable parallel builds"
  log_info "  ENABLE_NOTIFICATIONS=true   # Enable build notifications"
  log_info "Examples:"
  log_info "  ./build.sh apk                # Build APK in production mode"
  log_info "  ./build.sh apk aab            # Build APK and AAB in production mode"
  log_info "  ./build.sh apk --uat          # Build APK in UAT mode"
  log_info "  ./build.sh --version          # Show script version"
  log_info "  ./build.sh --help             # Show this help message"
  log_info "  PARALLEL_BUILD=true ./build.sh apk aab # Build APK and AAB in parallel"
  log_info "  ./build.sh apk aab ios --uat --clean # Build all platforms in UAT mode and clear build directory"
  log_info "  ./build.sh ios                 # Build iOS，自动查找 w_build/ios.plist 进行签名"
}

# 改进的版本号提取
get_version() {
  local version_file="pubspec.yaml"
  
  if [ ! -f "$version_file" ]; then
    log_error "pubspec.yaml not found"
    return 1
  fi
  
  local version=$(grep '^version:' "$version_file" | awk '{print $2}' | tr -d '"'"'")
  
  if [ -z "$version" ]; then
    log_error "Failed to extract version from pubspec.yaml"
    return 1
  fi
  
  # 验证版本号格式
  if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'; then
    log_error "Invalid version format: $version"
    return 1
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
    return 1
  fi
  
  # 检查磁盘空间（至少需要 1GB）
  local available_space=$(df -k "$OUTPUT_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
  if [ -n "$available_space" ] && [ "$available_space" -lt 1048576 ]; then
    log_warn "Low disk space: $(( available_space / 1024 )) MB available"
  fi
  
  log_debug "Configuration validated successfully"
}

# 删除已存在的文件
delete_existing_file() {
  local target_file="$1"
  
  if [ ! -f "$target_file" ]; then
    return 0
  fi
  
  # 直接删除已存在的文件
  rm -f "$target_file"
  log_info "覆盖已存在的文件: $target_file"
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
  local source_path="$2"

  local package_type_upper=$(echo "$package_type" | tr '[:lower:]' '[:upper:]')
  local -a build_command

  # 直接用 argv，不再拼一条命令字符串再拆回来
  case "$package_type" in
    apk) build_command=(flutter build apk --release) ;;
    aab) build_command=(flutter build appbundle --release) ;;
    *)
      log_error "不支持的 Android 构建类型: $package_type"
      return 1
      ;;
  esac

  log_info "=== Building $package_type_upper ==="

  # 记录开始时间
  local start_time=$(date +%s)
  
  # 执行构建命令（使用数组避免命令注入，设置超时时间为 30 分钟）
  log_info "执行构建命令..."
  log_debug "完整命令: ${build_command[*]}"
  local timeout=1800  # 30 分钟
  local build_status=0
  run_build_step "构建 $package_type_upper" "$timeout" "${build_command[@]}" || build_status=$?
  if [ "$build_status" -ne 0 ]; then
    # 124 的超时文案由 run_build_step 打印，这里只补失败原因
    if [ "$build_status" -ne 124 ]; then
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
  log_debug "构建耗时: ${duration}s"
  
  # 验证构建产物完整性
  if ! verify_build_output "$source_path" "$MIN_BUILD_SIZE"; then
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
  
  log_info "$package_type_upper 构建成功: $(pwd)/$output_file ($file_size)"
  
  log_to_file "Built $package_type_upper: $output_file ($file_size) in ${duration}s"
  return 0
}

# 从 plist 里取一个 key 的字符串值
get_plist_value() {
  local plist_file="$1"
  local key="$2"
  # 取 <key>key</key> 后面那一行的 <string>value</string>。
  # 只去掉标签和首尾空白——证书名里带空格（"Apple Distribution: My Company (ABC)"），
  # 以前用 tr -d '[:space:]' 会把它压成 "AppleDistribution:MyCompany(ABC)"，
  # 传给 xcodebuild -codeSignIdentity 必然签不过。
  # macOS 自带 plutil：一条命令搞定，且不挑 <key>/<string> 是否同一行
  if command_available plutil; then
    local raw
    raw=$(plutil -extract "$key" raw -o - "$plist_file" 2>/dev/null)
    if [ -n "$raw" ]; then
      printf '%s\n' "$raw"
      return 0
    fi
  fi

  # 兜底：awk 同时认「同一行」与「分行」两种写法（Linux 上没有 plutil）
  awk -v key="$key" '
    index($0, "<key>" key "</key>") {
      rest = substr($0, index($0, "<key>" key "</key>") + length("<key>" key "</key>"))
      if (match(rest, /<string>[^<]*<\/string>/)) {
        value = substr(rest, RSTART + 8, RLENGTH - 17)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
      if (getline line > 0 && match(line, /<string>[^<]*<\/string>/)) {
        value = substr(line, RSTART + 8, RLENGTH - 17)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    }
  ' "$plist_file"
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
  
  # 获取 signingStyle 值（缺省按 manual 处理，与 build_ios 保持一致）
  local signingstyle_value=$(get_plist_value "$plist_file" "signingStyle")
  if [ "$has_signingstyle" -eq 0 ]; then
    log_debug "ios.plist 未声明 signingStyle，按 manual 处理"
  fi
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
  # 只说「哪个 key 还是占位符」，不再把整行 XML 打出来（那对使用者没有信息量）
  local -a placeholder_keys=()
  local token label
  # 同一字段可能对应多个占位符 token（如证书名 + 证书 ID），这里去重
  local seen_labels=" "
  for token in $(grep -o "YOUR_[A-Z_]*" "$plist_file" 2>/dev/null | sort -u); do
    case "$token" in
      YOUR_TEAM_ID) label="teamID" ;;
      YOUR_COMPANY_NAME | YOUR_CERTIFICATE_ID) label="signingCertificate" ;;
      YOUR_BUNDLE_ID) label="provisioningProfiles 的 bundle id" ;;
      YOUR_PROVISIONING_PROFILE_NAME) label="provisioningProfiles 的 profile 名称" ;;
      *) label="$token" ;;
    esac
    case "$seen_labels" in
      *" $label "*) ;;
      *)
        seen_labels="$seen_labels$label "
        placeholder_keys+=("$label")
        ;;
    esac
  done

  if [ ${#placeholder_keys[@]} -gt 0 ]; then
    # 自动签名下 Xcode 自己管证书与 profile，这两项留着也不影响（导出前会被剔除）
    local auto_only_cert_placeholders=false
    if [ "$signingstyle_value" = "automatic" ]; then
      auto_only_cert_placeholders=true
      for token in "${placeholder_keys[@]}"; do
        case "$token" in
          signingCertificate | provisioningProfiles*) ;;
          *) auto_only_cert_placeholders=false ;;
        esac
      done
    fi

    if [ "$auto_only_cert_placeholders" = "true" ]; then
      log_warn "ios.plist 是自动签名，signingCertificate / provisioningProfiles 的占位符会被忽略"
      log_info "  需要填写的是 teamID（10 位）"
    else
      log_warn "ios.plist 还有未替换的占位符，请填写这些项后重新构建:"
      local item
      for item in "${placeholder_keys[@]}"; do
        log_warn "  - $item"
      done
      log_info "取值的办法:"
      log_info "  teamID              → App Store Connect → Membership → Team ID（10 位）"
      log_info "  signingCertificate  → security find-identity -v -p codesigning"
      log_info "  bundle id           → grep -m1 PRODUCT_BUNDLE_IDENTIFIER ios/Runner.xcodeproj/project.pbxproj"
      log_info "  profile 名称        → Apple Developer → Profiles（与 bundle id 对应）"
      log_info "想先在本机跑通，可以把 signingStyle 改成 automatic，只填 teamID"
      has_error=true
    fi
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
  
  log_debug "ios.plist 文件验证通过"
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

# 从 Xcode 工程里读一项配置（DEVELOPMENT_TEAM / PRODUCT_BUNDLE_IDENTIFIER）
xcodeproj_value() {
  local key="$1"
  local pbxproj="ios/Runner.xcodeproj/project.pbxproj"
  [ -f "$pbxproj" ] || return 1
  local value
  value=$(grep -m1 "$key = " "$pbxproj" 2>/dev/null | sed 's/.*= *//; s/;.*//; s/^"//; s/"$//')
  [ -n "$value" ] || return 1
  printf '%s' "$value"
}

# 合成一份 ExportOptions（不写用户目录，放临时目录）
write_synthesized_options() {
  local target="$1"

  local method="${CLI_METHOD:-${SYNTH_METHOD:-development}}"
  local style="${CLI_SIGNING_STYLE:-${SYNTH_STYLE:-automatic}}"
  local team="${CLI_TEAM:-${SYNTH_TEAM:-}}"
  local bundle_id="${CLI_BUNDLE_ID:-${SYNTH_BUNDLE_ID:-}}"

  {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    printf '%s\n' '<plist version="1.0">'
    printf '%s\n' '<dict>'
    printf '    <key>method</key>\n    <string>%s</string>\n' "$method"
    printf '    <key>signingStyle</key>\n    <string>%s</string>\n' "$style"
    if [ -n "$team" ]; then
      printf '    <key>teamID</key>\n    <string>%s</string>\n' "$team"
    fi
    if [ "$style" = "manual" ]; then
      if [ -n "${CLI_CERT:-}" ]; then
        printf '    <key>signingCertificate</key>\n    <string>%s</string>\n' "$CLI_CERT"
      fi
      if [ -n "$bundle_id" ] && [ -n "${CLI_PROFILE:-}" ]; then
        printf '    <key>provisioningProfiles</key>\n    <dict>\n'
        printf '        <key>%s</key>\n        <string>%s</string>\n' "$bundle_id" "$CLI_PROFILE"
        printf '    </dict>\n'
      fi
    fi
    printf '%s\n' '</dict>'
    printf '%s\n' '</plist>'
  } > "$target"
}

# 解析签名配置：CLI > w_build/ios.plist（个人覆盖）> ios/ExportOptions.plist（可提交）
# > 自动探测（automatic + development）。结果写入全局 ${export_options_file}。
resolve_export_options() {
  # 1) 显式 --export-options 最优先
  if [ -n "$EXPORT_OPTIONS_PLIST" ]; then
    if [ -f "$EXPORT_OPTIONS_PLIST" ]; then
      export_options_file="$EXPORT_OPTIONS_PLIST"
      SIGNING_SOURCE="--export-options 指定的文件"
      log_info "使用命令行指定的 Export Options: $export_options_file"
      return 0
    fi
    log_error "命令行指定的 Export Options 文件不存在: $EXPORT_OPTIONS_PLIST"
    return 1
  fi

  # 2) 只要给了任一覆盖参数，就合成一份（不动用户文件）
  if [ -n "$CLI_METHOD$CLI_TEAM$CLI_BUNDLE_ID$CLI_CERT$CLI_PROFILE$CLI_SIGNING_STYLE" ]; then
    # 没显式给的，仍然从 Xcode 工程推断
    SYNTH_TEAM="${CLI_TEAM:-$(xcodeproj_value DEVELOPMENT_TEAM || true)}"
    SYNTH_BUNDLE_ID="${CLI_BUNDLE_ID:-$(xcodeproj_value PRODUCT_BUNDLE_IDENTIFIER || true)}"

    # 签名方式只由 --automatic / --manual 决定；--method 只换分发方式。
    # 默认自动签名（Xcode 自己能处理 development/ad-hoc/app-store）。
    SYNTH_STYLE="${CLI_SIGNING_STYLE:-automatic}"

    # 手动签名但没给证书/profile：先试试本机探测（唯一匹配才采用）
    if [ "$SYNTH_STYLE" = "manual" ]; then
      if [ -z "$CLI_CERT" ] || [ -z "$CLI_PROFILE" ]; then
        DETECTED_CERT=""
        DETECTED_PROFILE=""
        if autodetect_signing; then
          [ -z "$CLI_CERT" ] && CLI_CERT="$DETECTED_CERT"
          [ -z "$CLI_PROFILE" ] && CLI_PROFILE="$DETECTED_PROFILE"
        fi
      fi
    fi
    local options_dir
    options_dir=$(mktemp -d)
    TEMP_DIRS+=("$options_dir")
    local synthesized="$options_dir/ExportOptions.plist"
    write_synthesized_options "$synthesized"
    export_options_file="$synthesized"
    SIGNING_SOURCE="命令行参数（--method/--team/--cert/--profile）"
    log_info "使用命令行签名参数（未修改任何配置文件）"
    return 0
  fi

  # 3) 配置文件：个人覆盖优先，其次可提交的那份
  local candidate
  for candidate in "$OUTPUT_DIR/ios.plist" "ios/ExportOptions.plist"; do
    if [ -f "$candidate" ]; then
      export_options_file="$candidate"
      SIGNING_SOURCE="配置文件 $candidate"
      return 0
    fi
  done

  # 4) 零配置：从 Xcode 工程推断（automatic + development）
  local team bundle_id
  team=$(xcodeproj_value DEVELOPMENT_TEAM) || true
  bundle_id=$(xcodeproj_value PRODUCT_BUNDLE_IDENTIFIER) || true
  if [ -n "$team" ]; then
    SYNTH_TEAM="$team"
    SYNTH_BUNDLE_ID="${bundle_id:-}"
    local options_dir
    options_dir=$(mktemp -d)
    TEMP_DIRS+=("$options_dir")
    local synthesized="$options_dir/ExportOptions.plist"
    write_synthesized_options "$synthesized"
    export_options_file="$synthesized"
    SIGNING_SOURCE="自动探测（ios/Runner.xcodeproj 的 DEVELOPMENT_TEAM）"
    log_info "未找到签名配置，按自动签名构建: team=$team bundle=${bundle_id:-未知} method=development"
    return 0
  fi

  # 5) 什么都没有：生成模板并给出明确指引
  local template_path="$OUTPUT_DIR/ios.plist"
  if [ ! -f "$template_path" ]; then
    generate_ios_plist_template "$template_path" || return 1
  fi
  log_error "无法确定签名配置：没有 ios/ExportOptions.plist，工程里也没读到 DEVELOPMENT_TEAM"
  log_info "三种做法（任选其一）:"
  log_info "  ww build ios --team=ABC123DEF4                    # 只用自动签名"
  log_info "  ww build ios --method=app-store --team=... --bundle-id=... --cert=... --profile=..."
  log_info "  编辑 ${template_path}（或提交 ios/ExportOptions.plist 给团队共用）"
  return 1
}

# 探测本机的分发证书与匹配的 Provisioning Profile
# 只在「唯一匹配」时采用；多个候选时打印出来，让用户用 --cert / --profile 指定
autodetect_signing() {
  command_available security || return 1
  command_available plutil || return 1

  local bundle_id="${CLI_BUNDLE_ID:-${SYNTH_BUNDLE_ID:-}}"
  if [ -z "$bundle_id" ]; then
    bundle_id=$(xcodeproj_value PRODUCT_BUNDLE_IDENTIFIER || true)
  fi

  # 证书：优先 Apple Distribution，其次 Apple Development
  local -a certs=()
  local cert
  while IFS= read -r cert; do
    [ -n "$cert" ] && certs+=("$cert")
  done < <(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Distribution[^"]*\)"/\1/p; s/.*"\(Apple Development[^"]*\)"/\1/p' \
    | sort -u)

  if [ ${#certs[@]} -eq 0 ]; then
    log_debug "没有找到 Apple Distribution / Development 证书"
    return 1
  fi
  if [ ${#certs[@]} -gt 1 ]; then
    log_warn "找到多个签名证书，请用 --cert= 指定（或只保留一个有效的）:"
    local item
    for item in "${certs[@]}"; do
      log_warn "  - $item"
    done
    return 1
  fi
  DETECTED_CERT="${certs[0]}"

  # Profile：按 bundle id 过滤（拿不到 bundle id 时只用证书）
  local profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
  local -a profiles=()
  if [ -z "$bundle_id" ]; then
    log_debug "不知道 bundle id，跳过 profile 探测"
    return 0
  fi
  if [ -d "$profile_dir" ]; then
    local file name file_bundle
    for file in "$profile_dir"/*.mobileprovision; do
      [ -f "$file" ] || continue
      name=$(security cms -D -i "$file" 2>/dev/null | plutil -extract Name raw -o - - 2>/dev/null) || continue
      file_bundle=$(security cms -D -i "$file" 2>/dev/null | plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null) || continue
      case "$file_bundle" in
        *."$bundle_id") profiles+=("$name") ;;
      esac
    done
  fi

  if [ ${#profiles[@]} -eq 0 ]; then
    log_warn "没有找到匹配 $bundle_id 的 Provisioning Profile"
    return 0
  fi
  if [ ${#profiles[@]} -gt 1 ]; then
    log_warn "找到多个匹配的 Profile，请用 --profile= 指定:"
    local item
    for item in "${profiles[@]}"; do
      log_warn "  - $item"
    done
    return 0
  fi
  DETECTED_PROFILE="${profiles[0]}"
  log_info "自动探测到证书与 Profile: $DETECTED_CERT / $DETECTED_PROFILE"
  return 0
}

# 生成一份可提交的签名配置（ios/ExportOptions.plist）
save_signing_config() {
  local team bundle style method
  team="${CLI_TEAM:-$(xcodeproj_value DEVELOPMENT_TEAM || true)}"
  bundle="${CLI_BUNDLE_ID:-$(xcodeproj_value PRODUCT_BUNDLE_IDENTIFIER || true)}"
  style="${CLI_SIGNING_STYLE:-automatic}"
  method="${CLI_METHOD:-development}"

  if [ -z "$team" ]; then
    log_error "读不到 DEVELOPMENT_TEAM，请加 --team=<10 位 Team ID>"
    return 1
  fi

  local cert="$CLI_CERT" profile="$CLI_PROFILE"
  if [ "$style" = "manual" ]; then
    if [ -z "$cert" ] || [ -z "$profile" ]; then
      DETECTED_CERT=""
      DETECTED_PROFILE=""
      autodetect_signing || true
      [ -z "$cert" ] && cert="$DETECTED_CERT"
      [ -z "$profile" ] && profile="$DETECTED_PROFILE"
    fi
    if [ -z "$cert" ] || [ -z "$profile" ] || [ -z "$bundle" ]; then
      log_error "手动签名需要 --cert / --profile / bundle id，且要能在本机探测或显式提供"
      log_info "  --cert=\"Apple Distribution: 公司名 (ID)\""
      log_info "  --profile=\"Profile 名称\""
      log_info "  --bundle-id=com.example.app"
      return 1
    fi
  fi

  local target="ios/ExportOptions.plist"
  local tmp
  tmp=$(mktemp)
  {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    printf '%s\n' '<plist version="1.0">'
    printf '%s\n' '<dict>'
    printf '    <key>method</key>\n    <string>%s</string>\n' "$method"
    printf '    <key>signingStyle</key>\n    <string>%s</string>\n' "$style"
    printf '    <key>teamID</key>\n    <string>%s</string>\n' "$team"
    if [ "$style" = "manual" ]; then
      printf '    <key>signingCertificate</key>\n    <string>%s</string>\n' "$cert"
      printf '    <key>provisioningProfiles</key>\n    <dict>\n'
      printf '        <key>%s</key>\n        <string>%s</string>\n' "$bundle" "$profile"
      printf '    </dict>\n'
    fi
    printf '%s\n' '</dict>'
    printf '%s\n' '</plist>'
  } > "$tmp"

  printf '\n将写入 %s:\n' "$target"
  sed 's/^/    /' "$tmp"
  printf '\n'

  if [ "$DRY_RUN" = "true" ]; then
    log_info "--dry-run：未写入任何文件"
    rm -f "$tmp"
    return 0
  fi

  if [ -f "$target" ] && [ "$FORCE_SAVE" != "true" ]; then
    log_error "$target 已存在，加 --force 覆盖（或先 --dry-run 看看会写成什么）"
    rm -f "$tmp"
    return 1
  fi

  if [ ! -d ios ]; then
    log_error "当前目录没有 ios/，请确认在 Flutter 工程根目录"
    rm -f "$tmp"
    return 1
  fi

  cp "$tmp" "$target" || { rm -f "$tmp"; log_error "写入失败: $target"; return 1; }
  rm -f "$tmp"
  log_info "已写入 ${target}（可提交给团队共用）"
  log_info "之后 ww build ios 会优先使用它；改动用 ww build ios --show-config 确认"
  return 0
}

# 打印生效的签名配置（不构建）
show_signing_config() {
  SIGNING_SOURCE=""
  export_options_file=""
  log_info "平台: ios · 版本: $(get_version 2>/dev/null || echo 未知)"
  if ! resolve_export_options; then
    log_error "无法确定签名配置"
    return 1
  fi

  local method style team cert bundle profile
  method=$(get_plist_value "$export_options_file" "method")
  style=$(get_plist_value "$export_options_file" "signingStyle")
  team=$(get_plist_value "$export_options_file" "teamID")
  cert=$(get_plist_value "$export_options_file" "signingCertificate")
  bundle=$(xcodeproj_value PRODUCT_BUNDLE_IDENTIFIER || true)
  profile=""
  if [ "$style" = "manual" ] && [ -n "$bundle" ] && command_available plutil; then
    profile=$(plutil -extract "provisioningProfiles.$bundle" raw -o - "$export_options_file" 2>/dev/null || true)
  fi

  printf '\n生效的 iOS 签名配置（来源: %s）\n' "${SIGNING_SOURCE:-未知}"
  printf '  method              %s\n' "${method:-未知}"
  printf '  signingStyle        %s\n' "${style:-manual}"
  printf '  teamID              %s\n' "${team:-未知}"
  printf '  bundle id           %s\n' "${bundle:-未知}"
  printf '  signingCertificate  %s\n' "${cert:-（自动签名不需要）}"
  printf '  profile             %s\n' "${profile:-（自动签名不需要，或未按 bundle id 配置）}"
  printf '\n'

  local rc=0
  if ! validate_ios_plist "$export_options_file" > /dev/null 2>&1; then
    validate_ios_plist "$export_options_file"
    rc=1
  fi
  return "$rc"
}

# 构建 iOS
build_ios() {
  log_debug "=== 构建 iOS ==="
  
  # 记录开始时间
  local start_time=$(date +%s)
  
  # 解析签名配置：CLI > w_build/ios.plist > ios/ExportOptions.plist > 自动探测
  export_options_file=""
  if ! resolve_export_options; then
    cleanup_failed_build "ios"
    return 1
  fi
  if ! validate_ios_plist "$export_options_file"; then
    log_error "签名配置校验未通过，构建终止"
    cleanup_failed_build "ios"
    return 1
  fi

  # 只生成构建配置（Generated.xcconfig / .flutter-plugins-dependencies），不编译。
  # xcodebuild archive 自己会跑 Flutter 的 build phase（AOT + 资源打包），
  # 这里若跑完整 build 等于把同一份代码编译两遍——实测多花 40%~60% 的时间。
  local -a flutter_config_command=("flutter" "build" "ios" "--release" "--no-codesign" "--config-only")

  log_debug "生成 Flutter 构建配置..."
  log_debug "完整命令: ${flutter_config_command[*]}"

  local timeout=1800  # 30 分钟
  local build_status=0
  run_build_step "生成 Flutter 构建配置" "$timeout" "${flutter_config_command[@]}" || build_status=$?
  if [ "$build_status" -ne 0 ]; then
    # 124 的超时文案由 run_build_step 打印，这里只补失败原因
    if [ "$build_status" -ne 124 ]; then
      log_error "生成 Flutter 构建配置失败"
      log_error "错误原因可能包括:"
      log_error "  1. Flutter 环境未正确配置"
      log_error "  2. Xcode 未安装或版本不兼容"
      log_error "  3. 依赖包缺失 (运行: flutter pub get)"
      log_error "请检查上述问题后重试"
    fi
    cleanup_failed_build "ios"
    return 1
  fi
  
  # 使用 xcodebuild 导出 IPA
  log_debug "使用 xcodebuild 导出 IPA..."
  
  # 创建临时导出目录
  local export_dir=$(mktemp -d)
  TEMP_DIRS+=("$export_dir")
  
  # 执行 xcodebuild 导出命令
  local xcodebuild_command=(
    "xcodebuild"
    "-quiet"
    "-exportArchive"
    "-archivePath" "build/ios/archive/Runner.xcarchive"
    "-exportPath" "$export_dir"
    "-exportOptionsPlist" "$export_options_file"
  )
  
  log_debug "xcodebuild 命令: ${xcodebuild_command[*]}"
  
  # 获取签名方式（缺省 manual，与 validate_ios_plist 一致）
  local signing_style=$(get_plist_value "$export_options_file" "signingStyle")
  signing_style=${signing_style:-manual}
  local team_id=$(get_plist_value "$export_options_file" "teamID")
  
  log_debug "签名方式: $signing_style / 团队: $team_id"

  # 自动签名时 Xcode 自己管证书与 profile；模板里的占位符会让导出失败，
  # 这里用一份剔除了这两项的副本（不改用户的 ios.plist）
  if [ "$signing_style" = "automatic" ] && command_available plutil; then
    local sanitized_options="$export_dir/ExportOptions.plist"
    if cp "$export_options_file" "$sanitized_options"; then
      plutil -remove signingCertificate "$sanitized_options" 2>/dev/null || true
      plutil -remove provisioningProfiles "$sanitized_options" 2>/dev/null || true
      export_options_file="$sanitized_options"
      log_debug "自动签名：已从导出配置中移除 signingCertificate / provisioningProfiles"
    fi
  fi
  
  # 首先需要创建 archive
  local archive_command=(
    "xcodebuild"
    "-quiet"
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
  
  # -archivePath 的父目录不会自动创建，缺了 xcodebuild 会直接失败
  mkdir -p build/ios/archive

  log_info "Archive（xcodebuild）..."
  log_debug "Archive 命令: ${archive_command[*]}"
  if ! run_build_step "Xcode Archive" "$timeout" "${archive_command[@]}"; then
    log_error "Xcode Archive 创建失败"
    cleanup_failed_build "ios"
    return 1
  fi
  
  # 自动签名导出让 Xcode 自己更新 profile
  if [ "$signing_style" = "automatic" ]; then
    xcodebuild_command+=("-allowProvisioningUpdates")
  fi

  log_info "导出 IPA..."
  if ! run_build_step "xcodebuild 导出 IPA" "$timeout" "${xcodebuild_command[@]}"; then
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
  log_debug "构建耗时: ${duration}s"
  
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
  
  log_debug "找到导出的 IPA 文件: $exported_ipa"
  
  # 验证 archive 里的 Runner.app 关键文件（不再依赖第一遍构建的 build/ios/iphoneos）
  local archived_app_path="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
  if [ ! -f "$archived_app_path/Info.plist" ]; then
    log_error "Runner.app 缺少 Info.plist 文件: $archived_app_path"
    cleanup_failed_build "ios"
    return 1
  fi
  
  if [ ! -f "$archived_app_path/Runner" ]; then
    log_error "Runner.app 缺少可执行文件: $archived_app_path"
    cleanup_failed_build "ios"
    return 1
  fi
  
  log_debug "构建产物验证通过: $archived_app_path"
  
  local ipa_file=$(generate_filename "ios" "ipa" "")
  delete_existing_file "$ipa_file"
  
  # 复制 xcodebuild 导出的 IPA 文件到输出目录
  log_debug "复制 IPA 文件到输出目录..."
  if command -v rsync &> /dev/null; then
    rsync -ah "$exported_ipa" "$ipa_file"
  else
    cp "$exported_ipa" "$ipa_file"
  fi
  
  local file_size=$(du -h "$ipa_file" | cut -f1)

  # dSYM：崩溃符号化 / 上传 App Store 都需要，跟 IPA 一起放进输出目录，
  # 否则 flutter clean 之后 archive 就没了，想找也找不回来
  local dsym_dir="build/ios/archive/Runner.xcarchive/dSYMs"
  if [ -d "$dsym_dir" ] && [ -n "$(ls -A "$dsym_dir" 2>/dev/null)" ]; then
    local dsym_zip="${ipa_file%.ipa}.dSYMs.zip"
    delete_existing_file "$dsym_zip"
    local dsym_zip_abs="$(pwd)/$dsym_zip"
    if command_available ditto; then
      ditto -c -k --sequesterRsrc --keepParent "$dsym_dir" "$dsym_zip_abs" 2>/dev/null || true
    else
      ( cd "$(dirname "$dsym_dir")" && zip -qr "$dsym_zip_abs" "$(basename "$dsym_dir")" ) || true
    fi
    if [ -f "$dsym_zip" ]; then
      log_info "dSYM: $(pwd)/$dsym_zip ($(du -h "$dsym_zip" | cut -f1))"
    else
      log_warn "dSYM 打包失败（不影响 IPA）"
    fi
  else
    log_debug "没有 dSYM 目录，跳过"
  fi

  local method_value
  method_value=$(get_plist_value "$export_options_file" "method")
  local bundle_id
  bundle_id=$(xcodeproj_value PRODUCT_BUNDLE_IDENTIFIER || true)

  log_info "iOS 构建成功: $(pwd)/$ipa_file ($file_size)"
  log_info "  签名 $signing_style · method ${method_value:-未知} · team $team_id · bundle ${bundle_id:-未知} · 用时 ${duration}s"
  log_to_file "Built iOS: $ipa_file ($file_size) in ${duration}s"
  
  return 0
}

# 跑一个构建步骤：超时、去颜色、统一超时文案
# 参数: 标签 超时秒数 命令...
# 返回: 子进程退出码（124 = 超时）
run_build_step() {
  local label="$1"
  local timeout="$2"
  shift 2

  log_debug "命令: $*"

  local log_file="$OUTPUT_DIR/build.log"
  local LOUD_OUTPUT=false
  if ww::debug_enabled; then LOUD_OUTPUT=true; fi
  local raw
  raw=$(mktemp)

  local status=0
  if ww::debug_enabled; then
    # -d：实时显示全部输出（同时落盘）
    if ! ww::run_with_timeout "$timeout" "$@" 2>&1 | ww::strip_ansi | tee "$raw"; then
      status=${PIPESTATUS[0]}
    fi
  else
    if ! ww::run_with_timeout "$timeout" "$@" 2>&1 | ww::strip_ansi > "$raw"; then
      status=${PIPESTATUS[0]}
    fi
  fi

  local lines
  lines=$(wc -l < "$raw" | tr -d ' ')
  {
    printf '===== %s (%s) =====\n' "$label" "$(date '+%H:%M:%S')"
    cat "$raw"
  } >> "$log_file" 2>/dev/null || true

  if [ "$status" -eq 0 ]; then
    # 正常构建只透传警告：xcodebuild/gradle 的逐行日志对使用者没有价值
    [ "$LOUD_OUTPUT" = "true" ] || grep -E '(^|[[:space:]])(warning|warning:|error:|error )|\*\* ARCHIVE|\*\* EXPORT|^note:' "$raw" \
      | head -20 | sed 's/^/    /' || true
    log_debug "$label 输出 ${lines} 行 → ${log_file}"
  else
    log_error "$label 失败（完整日志: ${log_file}，末尾 20 行如下）"
    tail -20 "$raw" | sed 's/^/    /'
  fi

  rm -f "$raw"
  if [ "$status" -eq 124 ]; then
    log_error "$label 超时（超过 ${timeout}s）"
  fi
  return "$status"
}

# 运行时页脚（开始 / 结束各一处，内容不同）
print_footer() {
  printf '%s=== 完成（%s）===%s\n' "$GREEN" "$(date '+%H:%M:%S')" "$NC"
  if [ -f "$OUTPUT_DIR/build.log" ] && ! ww::debug_enabled; then
    log_info "构建细节: $OUTPUT_DIR/build.log（-d 可实时显示）"
  fi
}

# 支持的平台（加平台只改这里 + build_platform）
is_valid_platform() {
  case "$1" in
    apk | aab | ios) return 0 ;;
    *) return 1 ;;
  esac
}

# 平台 -> 构建产物路径（apk/aab 用；ios 的产物由 xcodebuild 导出）
platform_output_path() {
  case "$1" in
    apk) printf '%s' "build/app/outputs/flutter-apk/app-release.apk" ;;
    aab) printf '%s' "build/app/outputs/bundle/release/app-release.aab" ;;
    *) return 1 ;;
  esac
}

# 验证参数
validate_parameters() {
  local has_platform=false
  
  for arg in "$@"; do
    case "$arg" in
      --uat|--clean|--open|--debug|--help|--version)
        ;;
      --name=*|--export-options=*)
        ;;
      --method=*|--team=*|--bundle-id=*|--cert=*|--profile=*)
        ;;
      --automatic|--manual|--show-config|--save-config|--dry-run|--force)
        ;;
      *)
        if is_valid_platform "$arg"; then
          has_platform=true
        else
          log_error "Invalid parameter: $arg"
          return 1
        fi
        ;;
    esac
  done
  
  if [ "$has_platform" == "false" ]; then
    log_error "No platform specified. Please use: apk, aab, or ios"
    return 1
  fi
  
  return 0
}
# 解析命令行参数：只填全局变量，不执行构建动作
parse_args() {
  # 检查参数是否正确
  if [ $# -lt 1 ]; then
    show_help
    ARGS_HANDLED=true
    return 0
  fi

  # 检查帮助参数
  if [ "$1" == "--help" ]; then
    show_help
    ARGS_HANDLED=true
    return 0
  fi

  # 检查版本参数
  if [ "$1" == "--version" ]; then
    log_info "build.sh version: $(ww::version)"
    log_info "Description: Flutter application packaging script"
    log_info "Features:"
    log_info "  - Support Android APK, AAB and iOS IPA packaging"
    log_info "  - Support production and UAT modes"
    log_info "  - App store requirement checking"
    log_info "  - File backup and version management"
    log_info "  - Detailed logging and error handling"
    log_info "  - Parallel build support"
    log_info "  - Build notifications"
    ARGS_HANDLED=true
    return 0
  fi


  # 检查参数
  UAT_MODE=false
  CLEAR_MODE=false
  OPEN_MODE=false
  PLATFORMS=()
  APP_NAME=""
  CODE_SIGN_IDENTITY=""
  PROVISIONING_PROFILE=""
  EXPORT_OPTIONS_PLIST=""
  # iOS 签名覆盖（命令行 > 配置文件 > 自动探测）
  CLI_METHOD=""
  CLI_TEAM=""
  CLI_BUNDLE_ID=""
  CLI_CERT=""
  CLI_PROFILE=""
  CLI_SIGNING_STYLE=""
  SHOW_CONFIG=false
  SAVE_CONFIG=false
  DRY_RUN=false
  FORCE_SAVE=false
  for arg in "$@"; do
    case "$arg" in
      "apk"|"aab"|"ios")
        case " ${PLATFORMS[*]:-} " in
          *" $arg "*)
            log_warn "平台重复，忽略: $arg"
            ;;
          *)
            PLATFORMS+=("$arg")
            ;;
        esac
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
        ARGS_HANDLED=true
        return 0
        ;;
      "--debug")
        DEBUG_MODE=true
        log_info "启用调试模式"
        ;;
      --name=* )
        APP_NAME="${arg#--name=}"
        # 去掉首尾空格，中间的空格保留（文件名允许空格）
        APP_NAME=$(printf '%s' "$APP_NAME" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [ -z "$APP_NAME" ]; then
          log_error "--name 参数不能为空"
          show_help >&2
          return 2
        fi
        # 验证参数不包含路径分隔符
        if [[ "$APP_NAME" == *"/"* ]]; then
          log_error "--name 参数不允许包含路径分隔符: $APP_NAME"
          return 1
        fi
        ;;
      --method=* )
        CLI_METHOD="${arg#--method=}"
        ;;
      --team=* )
        CLI_TEAM="${arg#--team=}"
        ;;
      --bundle-id=* )
        CLI_BUNDLE_ID="${arg#--bundle-id=}"
        ;;
      --cert=* )
        CLI_CERT="${arg#--cert=}"
        ;;
      --profile=* )
        CLI_PROFILE="${arg#--profile=}"
        ;;
      --show-config )
        SHOW_CONFIG=true
        ;;
      --save-config )
        SAVE_CONFIG=true
        ;;
      --dry-run )
        DRY_RUN=true
        ;;
      --force )
        FORCE_SAVE=true
        ;;
      --automatic )
        CLI_SIGNING_STYLE="automatic"
        ;;
      --manual )
        CLI_SIGNING_STYLE="manual"
        ;;
      --export-options=* )
        EXPORT_OPTIONS_PLIST="${arg#--export-options=}"
        if [ -z "$EXPORT_OPTIONS_PLIST" ]; then
          log_error "--export-options 参数不能为空"
          show_help >&2
          return 2
        fi
        # 防止路径遍历攻击
        if [[ "$EXPORT_OPTIONS_PLIST" == *".."* ]]; then
          log_error "不允许使用路径遍历: $EXPORT_OPTIONS_PLIST"
          return 1
        fi
        # 如果指定的是纯文件名（不含路径分隔符），则在 OUTPUT_DIR 中查找
        if [[ "$EXPORT_OPTIONS_PLIST" != */* ]]; then
          EXPORT_OPTIONS_PLIST="$OUTPUT_DIR/$EXPORT_OPTIONS_PLIST"
        fi
        ;;
      -name:*|--name:*|-export-options:*|--export-options:*)
        log_error "旧写法已废弃: $arg"
        case "$arg" in
          -name:*|--name:*) log_info "请改用：--name=<name>" ;;
          *) log_info "请改用：--export-options=<file>" ;;
        esac
        return 2
        ;;
    esac
  done

}

# 构建前的准备：版本号、环境检查、输出目录
prepare_build() {
    TIMESTAMP=$(date +"%Y_%m%d_%H%M%S")

  # 获取版本号
  VERSION="$(get_version)" || return 1
  # 移除版本号中的 + 号，用于文件名
  VERSION_FOR_FILENAME=$(printf '%s' "$VERSION" | tr '+' '-')

  # 一行标题（原来 3 行分隔线 + 3 行信息）
  local mode_label="PROD"
  [ "$UAT_MODE" == "true" ] && mode_label="UAT $TIMESTAMP"
  printf '%s=== 构建 %s %s (%s) ===%s\n' "$GREEN" "${PLATFORMS[*]:-无}" "$VERSION" "$mode_label" "$NC"

  # 环境检查
  if ! check_environment; then
    log_error "环境检查失败，无法继续构建"
    return 1
  fi

  # 检查项目依赖
  if ! check_dependencies; then
    log_error "依赖检查失败，无法继续构建"
    return 1
  fi

  # 构建前完整性检查
  if ! pre_build_check; then
    log_error "完整性检查失败，无法继续构建"
    return 1
  fi

  # 创建输出目录
  log_debug "创建输出目录: $OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"

  # 验证配置
  validate_config

  # 清空输出目录（只删本工具的产物，保留 ios.plist 这类用户文件）
  if [ "$CLEAR_MODE" == "true" ]; then
    log_warn "清理输出目录里的旧产物: $OUTPUT_DIR"
    clean_output_directory "$OUTPUT_DIR"
  fi

}

# 真正执行构建
# 单平台构建分发（并行与串行共用）
build_platform() {
  local platform="$1"
  case "$platform" in
    apk | aab)
      local source_path
      source_path="$(platform_output_path "$platform")" || return 1
      build_android_package "$platform" "$source_path"
      ;;
    ios)
      build_ios
      ;;
    *)
      log_error "无效参数: $platform. 请使用: apk, aab, 或 ios"
      return 1
      ;;
  esac
}

run_build() {
  # 参数已经由 main 校验过；这里只管构建
  # 根据参数执行打包命令
  BUILD_FAILURE=false

  # 并行构建：Android 的 apk/aab 共用 .dart_tool 与 Gradle 构建目录，必须串行；
  # 真正能并行的是「Android 组」与「iOS」之间。
  if [ "$PARALLEL_BUILD" == "true" ] && [ ${#PLATFORMS[@]} -gt 1 ]; then
    log_info "启用并行构建模式（Android 内部串行，iOS 与 Android 并行）"

    local temp_dir
    temp_dir=$(mktemp -d)

    local -a android_platforms=()
    local has_ios=false
    for platform in "${PLATFORMS[@]}"; do
      case "$platform" in
        apk|aab) android_platforms+=("$platform") ;;
        ios) has_ios=true ;;
      esac
    done

    if [ ${#android_platforms[@]} -gt 0 ]; then
      (
        for platform in "${android_platforms[@]}"; do
          status=0
          build_platform "$platform" || status=$?
          printf '%s\n' "$status" > "$temp_dir/status_$platform.txt"
        done
      ) &
    fi

    if [ "$has_ios" = true ]; then
      (
        status=0
        build_ios || status=$?
        printf '%s\n' "$status" > "$temp_dir/status_ios.txt"
      ) &
    fi

    wait

    for platform in "${PLATFORMS[@]}"; do
      local platform_status
      platform_status=$(cat "$temp_dir/status_$platform.txt" 2>/dev/null || echo 1)
      if [ "$platform_status" -ne 0 ]; then
        log_error "${platform} 构建失败（退出码 ${platform_status}）"
        BUILD_FAILURE=true
      fi
    done

    rm -rf "$temp_dir"
  else
    # 串行构建
    for platform in "${PLATFORMS[@]}"; do
      if ! build_platform "$platform"; then
        BUILD_FAILURE=true
      fi
    done
  fi

  if [ "$BUILD_FAILURE" == "true" ]; then
    log_error "部分构建失败!"
    send_notification "构建失败，请检查错误信息"
    print_footer
    return 1
  fi

  log_debug "=== 打包完成！ ==="
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

  print_footer
}

# 入口：只有直接执行时才跑，被 source 时只提供函数（方便测试）
main() {
  ARGS_HANDLED=false
  parse_args "$@"

  if [[ "$ARGS_HANDLED" = true ]]; then
    return 0
  fi

  # --save-config：生成可提交的 ios/ExportOptions.plist
  if [ "$SAVE_CONFIG" = "true" ]; then
    save_signing_config
    return $?
  fi

  # --show-config：只打印生效的签名配置，不构建
  if [ "$SHOW_CONFIG" = "true" ]; then
    show_signing_config
    return $?
  fi

  # 参数校验必须在任何会删除东西的动作（--clean、建输出目录）之前
  if ! validate_parameters "$@"; then
    return 1
  fi

  # 只有真的要构建时才装清理 trap，source 不会污染调用者的 shell
  trap cleanup EXIT

  # 注意：这里不能写成 `prepare_build || return 1`——`||` 会关掉函数体内的
  # errexit，前面辛苦加的 set -e 就白费了。函数内部自己 log_error + return。
  prepare_build
  run_build "$@"

  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
