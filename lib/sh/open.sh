#!/bin/bash

# ======================================================
# open.sh - Flutter 项目打开脚本
# Version: 1.0.0
# Last Updated: 2026-03-20
# Author: Stone
# Description: 用于打开 Flutter 项目的不同部分
# ======================================================

# 项目根目录
PROJECT_ROOT="$(pwd)"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
  printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

log_warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_error() {
  printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# 显示帮助信息
show_help() {
  echo "使用方法: ./open.sh [ios|android|build]"
  echo "选项:"
  echo "  ios        用 Xcode 打开 iOS 项目"
  echo "  android    用 Android Studio 打开 Android 项目"
  echo "  build      用 Finder 打开构建目录"
  echo "  --help     显示此帮助信息"
  exit 0
}

# 打开 iOS 项目
open_ios() {
  local workspace_path="$PROJECT_ROOT/ios/Runner.xcworkspace"
  
  if [[ -d "$workspace_path" ]]; then
    log_info "用 Xcode 打开 iOS 项目..."
    if [[ "$(uname)" == "Darwin" ]]; then
      open -a Xcode "$workspace_path"
      if [[ $? -eq 0 ]]; then
        log_info "iOS 项目已成功打开"
      else
        log_error "打开 iOS 项目失败"
        return 1
      fi
    else
      log_error "此功能仅在 macOS 上可用"
      return 1
    fi
  else
    log_error "iOS 项目 workspace 文件不存在: $workspace_path"
    return 1
  fi
  
  return 0
}

# 打开 Android 项目
open_android() {
  local android_path="$PROJECT_ROOT/android"
  
  if [[ -d "$android_path" ]]; then
    log_info "用 Android Studio 打开 Android 项目..."
    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS
      open -a "Android Studio" "$android_path"
      if [[ $? -eq 0 ]]; then
        log_info "Android 项目已成功打开"
      else
        log_error "打开 Android 项目失败"
        return 1
      fi
    elif [[ "$(uname)" == "Linux" ]]; then
      # Linux
      if command -v studio.sh &> /dev/null; then
        studio.sh "$android_path"
        if [[ $? -eq 0 ]]; then
          log_info "Android 项目已成功打开"
        else
          log_error "打开 Android 项目失败"
          return 1
        fi
      else
        log_error "Android Studio 命令未找到，请确保已正确安装并添加到 PATH"
        return 1
      fi
    else
      log_error "此功能仅在 macOS 和 Linux 上可用"
      return 1
    fi
  else
    log_error "Android 项目目录不存在: $android_path"
    return 1
  fi
  
  return 0
}

# 打开构建目录
open_build() {
  local build_path="$PROJECT_ROOT/../build"
  
  if [[ -d "$build_path" ]]; then
    log_info "用 Finder 打开构建目录..."
    if [[ "$(uname)" == "Darwin" ]]; then
      open "$build_path"
      if [[ $? -eq 0 ]]; then
        log_info "构建目录已成功打开"
      else
        log_error "打开构建目录失败"
        return 1
      fi
    elif [[ "$(uname)" == "Linux" ]]; then
      # Linux
      if command -v xdg-open &> /dev/null; then
        xdg-open "$build_path"
        if [[ $? -eq 0 ]]; then
          log_info "构建目录已成功打开"
        else
          log_error "打开构建目录失败"
          return 1
        fi
      else
        log_error "xdg-open 命令未找到，请确保已正确安装"
        return 1
      fi
    else
      log_error "此功能仅在 macOS 和 Linux 上可用"
      return 1
    fi
  else
    log_error "构建目录不存在: $build_path"
    return 1
  fi
  
  return 0
}

# 主函数
main() {
  # 检查参数
  if [[ $# -ne 1 ]]; then
    show_help
  fi
  
  case "$1" in
    "ios")
      open_ios
      ;;
    "android")
      open_android
      ;;
    "build")
      open_build
      ;;
    "--help")
      show_help
      ;;
    *)
      log_error "未知参数: $1"
      show_help
      ;;
  esac
  
  return $?
}

# 执行主函数
main "$@"
