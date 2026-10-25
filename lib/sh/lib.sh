#!/bin/bash

# ======================================================
# lib.sh - build.sh 的共享库
#
# 这个文件不单独执行，只被 build.sh source：
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib.sh"
#
# 2026-10 起其余脚本都迁到了 Dart（ADR-0002），这里只保留 build.sh 用到的东西：
# 日志、DEBUG 开关、版本号、带超时的命令执行。
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

# 调试信息走 stderr：stdout 留给脚本产物
log_debug() {
  if ww::debug_enabled; then
    printf '%s[DEBUG]%s %s\n' "$BLUE" "$NC" "$1" >&2
  fi
}

# 去掉 Flutter / xcodebuild 输出里的 ANSI 颜色码（四处调用，抽出来）
ww::strip_ansi() {
  sed 's/\x1B\[[0-9;]*[mK]//g'
}

command_available() {
  command -v "$1" > /dev/null 2>&1
}

# 失败即退出：所有脚本的唯一出口

# 依赖检查

# 版本号由 Dart 侧通过 WW_VERSION 注入（来自 pubspec），脚本内不再各写一份
ww::version() {
  printf '%s' "${WW_VERSION:-dev}"
}

# 用法错误：打印帮助到 stderr 并以 2 退出（区别于运行失败）

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
