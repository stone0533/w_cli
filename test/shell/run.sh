#!/bin/bash
# lib/sh 的 shell 测试：不依赖 bats，直接 bash 跑，失败即非零退出
#
#   bash test/shell/run.sh
#
# 覆盖：脚本退出码契约、脚本可被 source、lib.sh 的超时/版本、setup.sh 的
# 目录保护、api.sh 的代码生成黄金文件、clean.sh 的参数校验。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SH="$ROOT/lib/sh"
FIXTURES="$ROOT/test/shell/fixtures"
STUBS="$ROOT/test/shell/stubs"

TOTAL=0
FAILS=0

pass() {
  TOTAL=$((TOTAL + 1))
  printf '  ok    %s\n' "$1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAILS=$((FAILS + 1))
  printf '  FAIL  %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '        %s\n' "$2"
  fi
}

assert_eq() { # 描述 期望 实际
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1" "expected [$2], got [$3]"
  fi
}

assert_contains() { # 描述 期望子串 实际
  case "$3" in
    *"$2"*) pass "$1" ;;
    *) fail "$1" "missing [$2] in output" ;;
  esac
}

run_script() { # 脚本 参数...  -> 回显退出码
  local script="$1"
  shift
  ( cd "$ROOT" && bash "$SH/$script" "$@" ) > /dev/null 2>&1
  printf '%s' "$?"
}

# 用 alarm 兜底：脚本若卡住，测试不会永远等下去
run_with_alarm() {
  perl -e 'alarm 120; exec @ARGV' -- "$@" > /dev/null 2>&1
  printf '%s' "$?"
}

echo "== 1. 退出码契约 =="
for script in api build clean common open project setup; do
  assert_eq "$script.sh --help 退出 0" 0 "$(run_with_alarm bash "$SH/$script.sh" --help)"
  assert_eq "$script.sh --version 退出 0" 0 "$(run_with_alarm bash "$SH/$script.sh" --version)"
done

# build.sh 自己校验参数，语义是"运行失败"(1)；其余脚本把未知参数当用法错误(2)
for script in api clean common open project setup; do
  assert_eq "$script.sh 未知参数退出 2" 2 "$(run_script "$script.sh" --definitely-not-an-option)"
done
assert_eq "build.sh 未知参数退出 1" 1 "$(run_script build.sh --definitely-not-an-option)"

echo
echo "== 2. 脚本可以被 source（不执行 main） =="
for script in api clean common open project setup; do
  out=$(
    bash -c "set -eo pipefail; . '$SH/$script.sh'; echo sourced" 2>&1 | tail -1
  )
  assert_eq "$script.sh 可 source" "sourced" "$out"
done

echo
echo "== 3. lib.sh 单元 =="
assert_eq "ww::version 默认 dev" "dev" "$(
  bash -c ". '$SH/lib.sh'; ww::version"
)"
assert_eq "ww::version 读取 WW_VERSION" "9.9.9" "$(
  WW_VERSION=9.9.9 bash -c ". '$SH/lib.sh'; ww::version"
)"
assert_eq "超时返回 124" 124 "$(
  bash -c ". '$SH/lib.sh'; ww::run_with_timeout 1 sleep 10" > /dev/null 2>&1
  echo $?
)"
assert_eq "成功后透传退出码 0" 0 "$(
  bash -c ". '$SH/lib.sh'; ww::run_with_timeout 5 true" > /dev/null 2>&1
  echo $?
)"
assert_eq "失败后透传退出码 3" 3 "$(
  bash -c ". '$SH/lib.sh'; ww::run_with_timeout 5 bash -c 'exit 3'" > /dev/null 2>&1
  echo $?
)"

echo
echo "== 4. setup.sh 不会删除已存在的目录 =="
tmp_work="$(mktemp -d)"
mkdir -p "$tmp_work/demo"
printf 'precious\n' > "$tmp_work/demo/keep.txt"
(
  cd "$tmp_work" || exit 1
  PATH="$STUBS:$PATH" bash "$SH/setup.sh" demo > /dev/null 2>&1
)
guard_exit=$?
assert_eq "已存在目录时退出非零" 1 "$guard_exit"
assert_eq "已存在目录被保留" "precious" "$(cat "$tmp_work/demo/keep.txt" 2>/dev/null)"
rm -rf "$tmp_work"

# 失败时应该清理本次创建的项目目录（依赖安装由 stub 故意失败）
tmp_work="$(mktemp -d)"
(
  cd "$tmp_work" || exit 1
  PATH="$STUBS:$PATH" bash "$SH/setup.sh" demo > /dev/null 2>&1
)
create_exit=$?
assert_eq "中途失败时退出非零" 1 "$create_exit"
if [ -d "$tmp_work/demo" ]; then
  fail "失败时清理本次创建的项目目录" "demo 仍然存在"
else
  pass "失败时清理本次创建的项目目录"
fi
rm -rf "$tmp_work"

echo
echo "== 5. api.sh 代码生成（黄金文件） =="
snake=$(bash -c ". '$SH/api.sh'; to_snake_case 'userName'" 2>/dev/null | tail -1)
assert_eq "to_snake_case 驼峰转蛇形" "user_name_result.dart" "$snake"

generated="$(mktemp)"
bash -c ". '$SH/api.sh'; generate_model_class \"\$(cat '$FIXTURES/demo.json')\" Demo" \
  > "$generated" 2>/dev/null
if diff -u "$FIXTURES/demo_model.expected" "$generated" > /dev/null 2>&1; then
  pass "generate_model_class 与黄金文件一致"
else
  fail "generate_model_class 与黄金文件一致" "$(diff -u "$FIXTURES/demo_model.expected" "$generated" | head -5)"
fi
rm -f "$generated"

echo
echo "== 6. clean.sh 参数校验 =="
assert_eq "--pod 与 android 同时使用退出 2" 2 "$(run_script clean.sh --pod android)"

echo
if [ "$FAILS" -eq 0 ]; then
  printf '全部通过：%d 项\n' "$TOTAL"
  exit 0
fi
printf '失败 %d 项 / 共 %d 项\n' "$FAILS" "$TOTAL"
exit 1
