#!/bin/bash

# ======================================================
# lib.sh - w_cli 脚本共享库
#
# 这个文件不单独执行，只被其它脚本 source：
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib.sh"
#
# 严格模式由调用方声明为 `set -eo pipefail`。
# 刻意不启用 `set -u`：macOS 自带的 bash 3.2 在 set -u 下展开空数组
# 会直接报 `unbound variable`，而本套脚本大量使用数组作为参数列表。
# ======================================================

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# 调试开关：DEBUG 与 DEBUG_MODE 是历史上两个名字
DEBUG="${DEBUG:-false}"
DEBUG_MODE="${DEBUG_MODE:-$DEBUG}"

ww::debug_enabled() {
  [ "$DEBUG" = "true" ] || [ "$DEBUG_MODE" = "true" ]
}

# 日志：统一用 printf 的格式串，消息里出现 % 也不会破坏输出
log_info() {
  printf '%s[INFO]%s %s\n' "$GREEN" "$NC" "$1"
}

log_warn() {
  printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$1" >&2
}

log_error() {
  printf '%s[ERROR]%s %s\n' "$RED" "$NC" "$1" >&2
}

log_success() {
  printf '%s[OK]%s %s\n' "$GREEN" "$NC" "$1"
}

# 调试信息走 stderr：stdout 留给脚本产物（api.sh 会把生成结果重定向到文件）
log_debug() {
  if ww::debug_enabled; then
    printf '%s[DEBUG]%s %s\n' "$BLUE" "$NC" "$1" >&2
  fi
}

command_available() {
  command -v "$1" > /dev/null 2>&1
}

# 失败即退出：所有脚本的唯一出口
ww::die() {
  log_error "${1:-未知错误}"
  exit "${2:-1}"
}

# 依赖检查
ww::require() {
  local cmd="$1"
  local hint="${2:-请先安装 ${1}}"
  if ! command_available "$cmd"; then
    ww::die "$hint" 1
  fi
}

# 版本号由 Dart 侧通过 WW_VERSION 注入（来自 pubspec），脚本内不再各写一份
ww::version() {
  printf '%s' "${WW_VERSION:-dev}"
}

ww::show_version() {
  local description="${1:-}"
  printf '%s %s\n' "$(basename "${0:-w_cli}")" "$(ww::version)"
  if [ -n "$description" ]; then
    printf 'Description: %s\n' "$description"
  fi
}

# 用法错误：打印帮助到 stderr 并以 2 退出（区别于运行失败）
ww::usage_error() {
  local message="$1"
  log_error "$message"
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" >&2
  fi
  exit 2
}

# 直接执行一条命令；参数按数组传递，不经过 eval
ww::run() {
  log_debug "执行: $*"
  "$@"
}

# 带超时执行命令；成功返回命令退出码，超时返回 124（与 GNU timeout 一致）
ww::run_with_timeout() {
  local timeout_seconds="$1"
  shift

  log_debug "执行（超时 ${timeout_seconds}s）: $*"

  if command_available timeout; then
    timeout "$timeout_seconds" "$@"
    return $?
  fi
  if command_available gtimeout; then
    gtimeout "$timeout_seconds" "$@"
    return $?
  fi

  # macOS 默认没有 timeout/gtimeout，用一个 bash 看门狗兜底
  "$@" &
  local child=$!
  local waited=0
  while kill -0 "$child" 2> /dev/null; do
    if [ "$waited" -ge "$timeout_seconds" ]; then
      log_warn "命令超时（${timeout_seconds}s），正在终止进程 $child"
      kill -TERM "$child" 2> /dev/null || true
      sleep 2
      kill -KILL "$child" 2> /dev/null || true
      wait "$child" 2> /dev/null || true
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$child"
  return $?
}
