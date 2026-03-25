#!/bin/bash

# ======================================================
# common.sh - 通用脚本工具
# Version: 1.0.0
# Last Updated: 2026-03-24
# Author: Stone
# Description: 提供通用的脚本工具函数
# ======================================================

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# 配置选项
DEBUG=false

# 辅助函数：检查命令是否可用
command_available() {
  command -v "$1" &> /dev/null
}

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

log_debug() {
  if [[ "$DEBUG" = true ]]; then
    printf "${BLUE}[DEBUG]${NC} %s\n" "$1"
  fi
}

# 显示版本信息
show_version() {
  echo "common.sh version: 1.0.0"
  echo "Last updated: 2026-03-24"
  echo "Description: 提供通用的脚本工具函数"
  exit 0
}

# 显示帮助信息
show_help() {
  echo "通用脚本工具"
  echo ""
  echo "使用方法: $0 [命令] [选项]"
  echo "命令:"
  echo "  drbb           执行 dart run build_runner build --delete-conflicting-outputs"
  echo "选项:"
  echo "  -d, --debug    启用调试模式"
  echo "  --version      显示脚本版本信息"
  echo "  --help         显示帮助信息"
  echo ""
  echo "使用示例:"
  echo "  $0 drbb                # 执行 build_runner build 命令"
  echo "  $0 -d drbb             # 启用调试模式执行"
  echo "  $0 --debug drbb        # 启用调试模式执行"
  exit 0
}

# 执行 build_runner build 命令
drbb() {
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d|--debug)
        DEBUG=true
        shift
        ;;
      *)
        log_error "未知参数: $1"
        return 1
        ;;
    esac
  done
  
  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}执行 build_runner build 命令...${NC}\n"
  printf "${GREEN}======================================================${NC}\n"
  if [[ "$DEBUG" = true ]]; then
    log_debug "Debug mode enabled"
  fi
  
  # 检查 dart 命令是否可用
  if command_available dart; then
    log_debug "使用 dart 命令"
    dart run build_runner build --delete-conflicting-outputs
  elif command_available flutter; then
    log_debug "使用 flutter 命令"
    flutter pub run build_runner build --delete-conflicting-outputs
  else
    log_error "Dart 和 Flutter 命令都不可用"
    return 1
  fi
  
  if [ $? -eq 0 ]; then
    printf "${GREEN}======================================================${NC}\n"
    printf "${GREEN}build_runner build 执行成功!${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
    printf "${GREEN}======================================================${NC}\n"
    return 0
  else
    printf "${RED}======================================================${NC}\n"
    printf "${RED}build_runner build 执行失败!${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
    printf "${RED}======================================================${NC}\n"
    return 1
  fi
}

# 主函数
main() {
  # 检查是否需要显示帮助或版本信息
  if [[ $# -gt 0 ]]; then
    case $1 in
      --version|--help)
        # 直接执行，不打印分割线
        case $1 in
          --version)
            show_version
            ;;
          --help)
            show_help
            ;;
        esac
        exit 0
      ;;
    esac
  else
    # 直接执行，不打印分割线
    show_help
    exit 0
  fi
  
  # 解析命令行参数
  if [[ $# -gt 0 ]]; then
    case $1 in
      drbb)
        shift
        drbb "$@"
        result=$?
        ;;
      -d|--debug)
        DEBUG=true
        if [[ $# -gt 0 ]]; then
          shift
          case $1 in
            drbb)
              shift
              drbb --debug "$@"
              result=$?
              ;;
            *)
              show_help
              result=0
              ;;
          esac
        else
          show_help
          result=0
        fi
        ;;
      *)
        log_error "未知命令: $1"
        show_help
        result=1
        ;;
    esac
  fi
  
  exit $result
}

# 如果直接执行脚本，调用主函数
if [ "$0" = "$BASH_SOURCE" ]; then
    main "$@"
fi