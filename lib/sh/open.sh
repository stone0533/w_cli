#!/bin/bash
set -eo pipefail

# ======================================================
# open.sh - Flutter 项目打开脚本
# Description: 用于打开 Flutter 项目的不同部分
# Author: Stone
# ======================================================
#
# 使用方法：
#   bash open.sh [ios|android|build|root] [选项]
#
# 选项：
#   --help     显示帮助信息
#   --version  显示脚本版本信息

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# 项目根目录
PROJECT_ROOT="$(pwd)"

# 显示版本信息
show_version() {
  ww::show_version "用于打开 Flutter 项目的不同部分"
}

# 显示帮助信息
show_help() {
  echo "使用方法: ./open.sh [ios|android|build|root]"
  echo "选项:"
  echo "  ios        用 Xcode 打开 iOS 项目"
  echo "  android    用 Android Studio 打开 Android 项目"
  echo "  build      用 Finder 打开构建目录"
  echo "  root       用 Finder 打开根目录"
  echo "  --help     显示此帮助信息"
  echo "  --version  显示脚本版本信息"
}

# 选一个可用的系统打开命令
pick_opener() {
  case "$(uname)" in
    Darwin) printf '%s' "open" ;;
    Linux) printf '%s' "xdg-open" ;;
    *) return 1 ;;
  esac
}

# 执行打开动作：唯一的 "成功/失败" 判定点，调用方不再自己看 $?
run_opener() {
  local label="$1"
  shift
  if "$@"; then
    log_info "${label}已成功打开"
  else
    log_error "打开${label}失败"
    return 1
  fi
}

# 用 Finder / 文件管理器打开一个目录
open_directory() {
  local target="$1"
  local label="$2"

  if [[ ! -d "$target" ]]; then
    log_error "${label}不存在: $target"
    return 1
  fi

  local opener
  if ! opener="$(pick_opener)"; then
    log_error "此功能仅在 macOS 和 Linux 上可用"
    return 1
  fi
  if ! command_available "$opener"; then
    log_error "$opener 命令未找到，请确保已正确安装"
    return 1
  fi

  log_info "用 Finder 打开${label}..."
  run_opener "$label" "$opener" "$target"
}

# 打开 iOS 项目
open_ios() {
  local workspace_path="$PROJECT_ROOT/ios/Runner.xcworkspace"

  if [[ ! -d "$workspace_path" ]]; then
    log_error "iOS 项目 workspace 文件不存在: $workspace_path"
    return 1
  fi
  if [[ "$(uname)" != "Darwin" ]]; then
    log_error "此功能仅在 macOS 上可用"
    return 1
  fi

  log_info "用 Xcode 打开 iOS 项目..."
  run_opener "iOS 项目" open -a Xcode "$workspace_path"
}

# 打开 Android 项目
open_android() {
  local android_path="$PROJECT_ROOT/android"

  if [[ ! -d "$android_path" ]]; then
    log_error "Android 项目目录不存在: $android_path"
    return 1
  fi

  log_info "用 Android Studio 打开 Android 项目..."
  case "$(uname)" in
    Darwin)
      run_opener "Android 项目" open -a "Android Studio" "$android_path"
      ;;
    Linux)
      if ! command_available studio.sh; then
        log_error "Android Studio 命令未找到，请确保已正确安装并添加到 PATH"
        return 1
      fi
      run_opener "Android 项目" studio.sh "$android_path"
      ;;
    *)
      log_error "此功能仅在 macOS 和 Linux 上可用"
      return 1
      ;;
  esac
}

# 打开构建目录
open_build() {
  open_directory "$PROJECT_ROOT/w_build" "构建目录"
}

# 打开根目录
open_root() {
  open_directory "$PROJECT_ROOT" "根目录"
}

# 主函数
main() {
  if [[ $# -ne 1 ]]; then
    show_help
    exit 0
  fi

  case "$1" in
    "ios")
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      printf '%s打开 iOS 项目%s\n' "$GREEN" "$NC"
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      open_ios
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      printf '%s打开 iOS 项目完成%s %s\n' "$GREEN" "$NC" "$(date '+%Y-%m-%d %H:%M:%S')"
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      ;;
    "android")
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      printf '%s打开 Android 项目%s\n' "$GREEN" "$NC"
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      open_android
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      printf '%s打开 Android 项目完成%s %s\n' "$GREEN" "$NC" "$(date '+%Y-%m-%d %H:%M:%S')"
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      ;;
    "build")
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      printf '%s打开构建目录%s\n' "$GREEN" "$NC"
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      open_build
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      printf '%s打开构建目录完成%s %s\n' "$GREEN" "$NC" "$(date '+%Y-%m-%d %H:%M:%S')"
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      ;;
    "root")
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      printf '%s打开根目录%s\n' "$GREEN" "$NC"
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      open_root
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      printf '%s打开根目录完成%s %s\n' "$GREEN" "$NC" "$(date '+%Y-%m-%d %H:%M:%S')"
      printf '%s======================================================%s\n' "$GREEN" "$NC"
      ;;
    "--help")
      show_help
      exit 0
      ;;
    "--version")
      show_version
      exit 0
      ;;
    *)
      log_error "未知参数: $1"
      show_help >&2
      exit 2
      ;;
  esac
}

# 只有直接执行时才跑 main，被 source 时只提供函数（方便测试）
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
