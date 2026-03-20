#!/bin/bash

# ======================================================
# clean.sh - Flutter 应用清理脚本
# Version: 1.0.0
# Last Updated: 2026-03-20
# Author: Stone
# Description: 清理 Flutter 应用的构建文件并执行 flutter pub get
# ======================================================

# 配置选项 - 可以通过环境变量覆盖
MAX_RETRIES=30         # 最大重试次数

# 颜色定义 - 仅在支持的终端中使用
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  GREEN=''
  YELLOW=''
  RED=''
  BLUE=''
  NC=''
fi

# 项目根目录
PROJECT_ROOT="$(pwd)"

# 操作系统检测
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
  Darwin)  OS="macos" ;;
  Linux)   OS="linux" ;;
  CYGWIN*) OS="cygwin" ;;
  MINGW*)  OS="mingw" ;;
  *)       OS="unknown" ;;
esac

# 日志函数
log_info() {
  printf "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') %s\n" "$1"
}

log_warn() {
  printf "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') %s\n" "$1"
}

log_error() {
  printf "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') %s\n" "$1" >&2
}

log_debug() {
  printf "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') %s\n" "$1"
}

# 检查命令是否可用
check_command() {
  local cmd="$1"
  local required="$2"
  
  if ! command -v "$cmd" &> /dev/null; then
    if [[ "$required" == "true" ]]; then
      log_error "$cmd 命令不可用，请确保已正确安装"
      return 1
    else
      log_warn "$cmd 命令不可用，相关操作可能会失败"
      return 0
    fi
  fi
  return 0
}

# 显示帮助信息
show_help() {
  echo "使用方法: ./clean.sh [选项] [平台]"
  echo "平台:"
  echo "  android    清理 Android 构建文件"
  echo "  ios        清理 iOS 构建文件"
  echo "  all        清理所有平台构建文件（默认）"
  echo "选项:"
  echo "  --help     显示此帮助信息"
  echo "  --lock     清理锁文件（pubspec.lock 或 Podfile.lock）"
  echo "  --pod      清理 iOS Pods（仅适用于 iOS 平台）"
  exit 0
}

# 解析命令行参数
parse_args() {
  # 默认值
  PLATFORM="all"
  LOCK=false
  POD=false
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        show_help
        ;;
      --lock)
        LOCK=true
        shift
        ;;
      --pod)
        POD=true
        shift
        ;;
      android|ios|all)
        PLATFORM="$1"
        shift
        ;;
      *)
        log_error "未知参数: $1"
        show_help
        ;;
    esac
  done
  
  # 检查 --pod 选项是否只用于 iOS 平台
  if [[ "$POD" == true && "$PLATFORM" != "ios" && "$PLATFORM" != "all" ]]; then
    log_error "--pod 选项只能用于 iOS 平台"
    show_help
  fi
}

# 删除文件（跨平台兼容）
delete_file() {
  local file_path="$1"
  local file_name="$(basename "$file_path")"
  
  if [[ -f "$file_path" ]]; then
    log_info "删除 $file_name 文件..."
    rm -f "$file_path"
    if [[ $? -eq 0 ]]; then
      log_info "$file_name 文件删除成功"
    else
      log_error "$file_name 文件删除失败"
      return 1
    fi
  else
    log_warn "$file_name 文件不存在，跳过删除"
  fi
  return 0
}

# 删除目录（跨平台兼容）
delete_directory() {
  local dir_path="$1"
  local dir_name="$(basename "$dir_path")"
  
  if [[ -d "$dir_path" ]]; then
    log_info "删除 $dir_name 目录..."
    rm -rf "$dir_path"
    if [[ $? -eq 0 ]]; then
      log_info "$dir_name 目录删除成功"
    else
      log_error "$dir_name 目录删除失败"
      return 1
    fi
  else
    log_warn "$dir_name 目录不存在，跳过删除"
  fi
  return 0
}

# 清理锁文件
clean_lock_files() {
  case "$PLATFORM" in
    "android")
      # 清理 Android 锁文件
      delete_file "$PROJECT_ROOT/pubspec.lock"
      ;;
    "ios")
      # 清理 iOS 锁文件
      delete_file "$PROJECT_ROOT/ios/Podfile.lock"
      ;;
    "all")
      # 清理所有平台锁文件
      delete_file "$PROJECT_ROOT/pubspec.lock"
      delete_file "$PROJECT_ROOT/ios/Podfile.lock"
      ;;
  esac
}

# 清理 iOS Pods
clean_pods() {
  # 清理 iOS Pods 目录
  delete_directory "$PROJECT_ROOT/ios/Pods"
  
  # 清理 Podfile.lock 文件
  delete_file "$PROJECT_ROOT/ios/Podfile.lock"
}

# 执行 pod update
run_pod_update() {
  # 切换到 iOS 目录
  cd "$PROJECT_ROOT/ios"
  
  # 执行 pod update，最多重试 $MAX_RETRIES 次
  local retry_count=0
  local success=false
  
  while [[ $retry_count -lt $MAX_RETRIES ]]; do
    retry_count=$((retry_count + 1))
    
    if [[ $retry_count -eq 1 ]]; then
      log_info "执行 pod update..."
    else
      log_info "执行 pod update（第 $retry_count 次重试）..."
    fi
    
    if pod update; then
      log_info "pod update 执行成功"
      success=true
      break
    else
      log_error "pod update 执行失败"
      # 不等待，直接重试
      if [[ $retry_count -eq $MAX_RETRIES ]]; then
        log_error "pod update 多次执行失败，已达到最大重试次数"
      fi
    fi
  done
  
  # 切换回项目根目录
  cd "$PROJECT_ROOT"
  
  if [[ "$success" == false ]]; then
    return 1
  fi
  
  return 0
}

# 清理构建文件
clean_build_files() {
  # 执行 flutter clean 命令
  log_info "执行 flutter clean 命令..."
  if flutter clean; then
    log_info "flutter clean 执行成功"
  else
    log_error "flutter clean 执行失败"
    return 1
  fi
  
  return 0
}

# 更新依赖
update_dependencies() {
  log_info "执行 flutter pub get..."
  if flutter pub get; then
    log_info "flutter pub get 执行成功"
    return 0
  else
    log_error "flutter pub get 执行失败"
    return 1
  fi
}

# 主函数
main() {
  # 解析命令行参数
  parse_args "$@"
  
  # 检查环境
  log_info "检查构建环境..."
  log_info "操作系统: $OS"
  
  # 检查 flutter 命令（必需）
  if ! check_command "flutter" "true"; then
    exit 1
  fi
  
  # 检查 pod 命令（仅在需要时）
  if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
    check_command "pod" "false"
  fi
  
  # 添加运行开始分隔线
  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}Flutter 应用清理脚本运行开始${NC}\n"
  printf "${GREEN}======================================================${NC}\n"
  
  # 清理锁文件（如果启用）
  if [[ "$LOCK" == true ]]; then
    clean_lock_files
  fi
  
  # 清理 iOS Pods（如果启用）
  if [[ "$POD" == true ]]; then
    clean_pods
  fi
  
  # 清理构建文件
  if ! clean_build_files; then
    # 添加运行结束分隔线
    printf "${GREEN}======================================================${NC}\n"
    printf "${GREEN}Flutter 应用清理脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
    printf "${GREEN}======================================================${NC}\n"
    exit 1
  fi
  
  # 更新依赖
  if ! update_dependencies; then
    # 添加运行结束分隔线
    printf "${GREEN}======================================================${NC}\n"
    printf "${GREEN}Flutter 应用清理脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
    printf "${GREEN}======================================================${NC}\n"
    exit 1
  fi
  
  # 执行 pod update（如果启用）
  if [[ "$POD" == true || ("$LOCK" == true && ("$PLATFORM" == "ios" || "$PLATFORM" == "all")) ]]; then
    if ! run_pod_update; then
      # 添加运行结束分隔线
      printf "${GREEN}======================================================${NC}\n"
      printf "${GREEN}Flutter 应用清理脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
      printf "${GREEN}======================================================${NC}\n"
      exit 1
    fi
  fi
  
  log_info "✅ 清理完成！"
  
  # 添加运行结束分隔线
  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}Flutter 应用清理脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
  printf "${GREEN}======================================================${NC}\n"
}

# 执行主函数
main "$@"
