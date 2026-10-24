#!/bin/bash
# lib/sh 的 shell 测试：不依赖 bats，直接 bash 跑，失败即非零退出
#
#   bash test/shell/run.sh
#
# 覆盖：脚本退出码契约、脚本可被 source、lib.sh 的超时/版本、setup.sh 的
# 目录保护、api.sh 的代码生成黄金文件、clean.sh 的参数校验。
set -uo pipefail

# dart/flutter 在受限环境（HOME 不可写）会因遥测文件写入失败而返回非零，
# 让它们按 CI 模式跑，避免把环境问题误判成生成物不合法
export CI="${CI:-true}"

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

run_script() { # 脚本 参数...  -> 回显退出码（在仓库根目录执行）
  local script="$1"
  shift
  ( cd "$ROOT" && bash "$SH/$script" "$@" ) > /dev/null 2>&1
  printf '%s' "$?"
}

run_script_in() { # 目录 脚本 参数... -> 回显退出码（在指定目录执行）
  local dir="$1"
  local script="$2"
  shift 2
  ( cd "$dir" && bash "$SH/$script" "$@" ) > /dev/null 2>&1
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
  if [ "$script" = "setup" ]; then
    # setup.sh 参数出错时会往当前目录写 setup_error.log，所以放到临时目录里跑，
    # 免得给仓库根留下垃圾文件
    tmp_dir="$(mktemp -d)"
    status="$(run_script_in "$tmp_dir" setup.sh --definitely-not-an-option)"
    rm -rf "$tmp_dir"
  else
    status="$(run_script "$script.sh" --definitely-not-an-option)"
  fi
  assert_eq "$script.sh 未知参数退出 2" 2 "$status"
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
generated="$(mktemp)"
bash -c ". '$SH/api.sh'; generate_model_class \"\$(cat '$FIXTURES/demo.json')\" Demo" \
  > "$generated" 2>/dev/null
# 比较的是渲染器的原始输出：与 dart 版本无关，确定性最好
if diff -u "$FIXTURES/demo_model.expected" "$generated" > /dev/null 2>&1; then
  pass "generate_model_class 与黄金文件一致"
else
  fail "generate_model_class 与黄金文件一致" "$(diff -u "$FIXTURES/demo_model.expected" "$generated" | head -8)"
fi
rm -f "$generated"

# 键含单引号：不能把 python -c 打崩、也不能丢字段，生成的 Dart 必须合法
quote_out="$(bash -c ". '$SH/api.sh'; generate_model_class \"{\\\"it's\\\":1,\\\"ok\\\":2}\" Quoted" 2>/dev/null)"
assert_eq "键含单引号时字段不丢（2 个）" 2 "$(printf '%s' "$quote_out" | grep -c '@JsonKey(name:')"
if command -v dart > /dev/null 2>&1; then
  quote_file="$(mktemp)"
  printf '%s\n' "$quote_out" > "$quote_file"
  if dart format "$quote_file" > /dev/null 2>&1; then
    pass "键含单引号时生成物合法"
  else
    fail "键含单引号时生成物合法" "$(dart format "$quote_file" 2>&1 | head -2)"
  fi
  rm -f "$quote_file"
fi

# 键含空格：一个键不能被拆成两个字段
space_out="$(bash -c ". '$SH/api.sh'; generate_model_class \"{\\\"user name\\\":\\\"x\\\",\\\"ok\\\":1}\" Spaced" 2>/dev/null)"
assert_eq "键含空格时字段数不变（2 个）" 2 "$(printf '%s' "$space_out" | grep -c '@JsonKey(name:')"
assert_contains "键含空格时保留原始键名" "user name" "$space_out"

# 嵌套对象与对象数组
nested_out="$(bash -c ". '$SH/api.sh'; generate_model_class \"{\\\"profile\\\":{\\\"a\\\":1},\\\"roles\\\":[{\\\"code\\\":\\\"a\\\"}]}\" Foo" 2>/dev/null)"
assert_contains "嵌套对象生成子类" "class FooProfile" "$nested_out"
assert_contains "对象数组生成 List 子类" "List<FooRoles>" "$nested_out"

# 端到端：--models 的文件装配（头部 + import + part）也要是合法 Dart
if command -v dart > /dev/null 2>&1; then
  e2e="$(mktemp -d)"
  mkdir -p "$e2e/w_json" "$e2e/lib/app/data/models"
  printf 'name: demo\ndependencies:\n  json_annotation: ^4.9.0\ndev_dependencies:\n  json_serializable: ^6.8.0\n  build_runner: ^2.4.0\n' > "$e2e/pubspec.yaml"
  cat > "$e2e/w_json/tricky.json" << 'JSON'
{"it's": true, "user name": "x", "ok": 2}
JSON
  ( cd "$e2e" && bash -c ". '$SH/api.sh'; run_build_runner() { :; }; generate_models" > /dev/null 2>&1 )
  tricky_file="$e2e/lib/app/data/models/tricky.dart"
  if [ -f "$tricky_file" ] && dart format --output=none "$tricky_file" > /dev/null 2>&1; then
    pass "--models 产出的文件是合法 Dart"
  else
    fail "--models 产出的文件是合法 Dart" "$(cd "$e2e" && dart format --output=none "$tricky_file" 2>&1 | head -3)"
  fi
  assert_eq "--models 保留三个字段" 3 "$(grep -c '@JsonKey(name:' "$tricky_file" 2>/dev/null || echo 0)"
  rm -rf "$e2e"
fi

# 批量落盘：N 个模型只起一次 dart format（性能回归）
if command -v dart > /dev/null 2>&1; then
  batch="$(mktemp -d)"
  mkdir -p "$batch/w_json" "$batch/lib/app/data/models" "$batch/bin"
  printf 'name: demo\ndependencies:\n  json_annotation: ^4.9.0\ndev_dependencies:\n  json_serializable: ^6.8.0\n  build_runner: ^2.4.0\n' > "$batch/pubspec.yaml"
  for i in 1 2 3; do printf '{"id":%s}\n' "$i" > "$batch/w_json/m$i.json"; done
  cat > "$batch/bin/dart" << EOF
#!/bin/bash
echo "\$1" >> "$batch/dart-calls.log"
if [ "\$1" = "format" ]; then exec "$(command -v dart)" "\$@"; fi
exit 0
EOF
  chmod +x "$batch/bin/dart"
  ( cd "$batch" && PATH="$batch/bin:$PATH" bash -c ". '$SH/api.sh'; run_build_runner() { :; }; generate_models" > /dev/null 2>&1 )
  assert_eq "3 个模型只调一次 dart format" 1 "$(grep -c '^format$' "$batch/dart-calls.log" 2>/dev/null || echo 0)"
  assert_eq "批量落盘产出 3 个文件" 3 "$(ls "$batch/lib/app/data/models" | wc -l | tr -d ' ')"

  # 其中一个模型生成的 Dart 非法时，整批都不落盘（不留下生成了一半的目录）
  bad="$(mktemp -d)"
  mkdir -p "$bad/w_json" "$bad/lib/app/data/models"
  printf 'name: demo\ndependencies:\n  json_annotation: ^4.9.0\ndev_dependencies:\n  json_serializable: ^6.8.0\n  build_runner: ^2.4.0\n' > "$bad/pubspec.yaml"
  printf '{"id":1}\n' > "$bad/w_json/ok1.json"
  printf '{"id":2}\n' > "$bad/w_json/1bad.json"
  ( cd "$bad" && bash -c ". '$SH/api.sh'; run_build_runner() { :; }; generate_models" > /dev/null 2>&1 )
  bad_exit=$?
  assert_eq "模型非法时退出非零" 1 "$bad_exit"
  assert_eq "非法批次不留下任何产物" 0 "$(ls "$bad/lib/app/data/models" | wc -l | tr -d ' ')"
  rm -rf "$batch" "$bad"
fi

# 独立类之间互相引用：两种声明顺序都要补 import
for order in customer-first order-first; do
  e2e="$(mktemp -d)"
  mkdir -p "$e2e/w_json" "$e2e/lib/app/data/models"
  printf 'name: demo\ndependencies:\n  json_annotation: ^4.9.0\ndev_dependencies:\n  json_serializable: ^6.8.0\n  build_runner: ^2.4.0\n' > "$e2e/pubspec.yaml"
  cat > "$e2e/w_json/order.json" << 'JSON'
{"data":{"order":{"id":1,"customer":{"cid":7,"name":"n"}}}}
JSON
  cat > "$e2e/w_json/customer.json" << 'JSON'
{"data":{"customer":{"cid":7,"name":"n"}}}
JSON
  if [ "$order" = "customer-first" ]; then
    printf '# Customer\ncustomer.json data.customer\n# Order\norder.json data.order\n' > "$e2e/w_json/w_json.config"
  else
    printf '# Order\norder.json data.order\n# Customer\ncustomer.json data.customer\n' > "$e2e/w_json/w_json.config"
  fi
  ( cd "$e2e" && bash -c ". '$SH/api.sh'; run_build_runner() { :; }; generate_models" > /dev/null 2>&1 )
  order_file="$e2e/lib/app/data/models/order.dart"
  if grep -qE '(^|[^A-Za-z])Customer\? customer' "$order_file" 2>/dev/null; then
    pass "独立类引用命中（${order}）"
  else
    fail "独立类引用命中（${order}）" "order.dart 没有复用 Customer"
  fi
  if grep -q "import './customer.dart'" "$order_file" 2>/dev/null; then
    pass "独立类引用补 import（${order}）"
  else
    fail "独立类引用补 import（${order}）" "order.dart 缺少 import"
  fi
  rm -rf "$e2e"
done

# 每个模型只起一次 python3（性能票的验收）
py_dir="$(mktemp -d)"
cat > "$py_dir/python3" << EOF
#!/bin/bash
echo x >> "$py_dir/calls.log"
exec "$(command -v python3)" "\$@"
EOF
chmod +x "$py_dir/python3"
PATH="$py_dir:$PATH" bash -c ". '$SH/api.sh'; generate_model_class \"{\\\"a\\\":1,\\\"b\\\":2,\\\"c\\\":3,\\\"d\\\":{\\\"e\\\":4}}\" Perf" > /dev/null 2>&1
assert_eq "每个模型只起一次 python3" 1 "$(wc -l < "$py_dir/calls.log" | tr -d ' ')"
rm -rf "$py_dir"

echo
echo "== 6. clean.sh 参数校验 =="
assert_eq "--pod 与 android 同时使用退出 2" 2 "$(run_script clean.sh --pod android)"

echo
echo "== 8. build.sh 可 source 与纯函数 =="
src_out="$(bash -c 'set -eo pipefail; . "$1"; echo SOURCED' _ "$SH/build.sh" 2>&1 | tail -1)"
assert_eq "build.sh 可 source 且不执行构建" "SOURCED" "$src_out"

trap_out="$(bash -c '. "$1"; trap -p EXIT' _ "$SH/build.sh" 2>/dev/null)"
assert_eq "source 不安装 EXIT trap" "" "$trap_out"

ver_ge() { # 脚本 当前版本 要求版本
  bash -c '. "$1"; if version_ge "$2" "$3"; then echo 0; else echo 1; fi' _ "$1" "$2" "$3" 2>/dev/null | tail -1
}
assert_eq "version_ge 3.10.0 >= 3.9.0" 0 "$(ver_ge "$SH/build.sh" 3.10.0 3.9.0)"
assert_eq "version_ge 3.9.0 < 3.10.0" 1 "$(ver_ge "$SH/build.sh" 3.9.0 3.10.0)"
assert_eq "version_ge 1.0.0 >= 1.0.0" 0 "$(ver_ge "$SH/build.sh" 1.0.0 1.0.0)"

vp() { # 脚本 参数...
  bash -c '. "$1"; shift; if validate_parameters "$@"; then echo 0; else echo 1; fi' _ "$@" 2>/dev/null | tail -1
}
assert_eq "validate_parameters apk" 0 "$(vp "$SH/build.sh" apk)"
assert_eq "validate_parameters 无参数" 1 "$(vp "$SH/build.sh")"
assert_eq "validate_parameters 未知参数" 1 "$(vp "$SH/build.sh" bogus)"

fn_out="$(bash -c '. "$1"; APP_NAME=demo; TIMESTAMP=2026_0101_010101; VERSION_FOR_FILENAME=1.0.0; UAT_MODE=false; generate_filename apk apk ""' _ "$SH/build.sh" 2>/dev/null | tail -1)"
assert_eq "generate_filename 生产模式" "w_build/demo_live_1.0.0.apk" "$fn_out"

echo
echo "== 9. api.sh 生成自检（verify_generated_models） =="
vgm_dir="$(mktemp -d)"
vgm() { # 目录 -> 退出码
  bash -c ". '$SH/api.sh'; verify_generated_models '$1'" > /dev/null 2>&1
  echo $?
}

mkdir -p "$vgm_dir/clean" "$vgm_dir/dup_import" "$vgm_dir/dup_class"
printf "import 'a.dart';\nimport 'b.dart';\n\nclass A {}\nclass B {}\n" > "$vgm_dir/clean/model.dart"
printf "import 'a.dart';\nimport 'a.dart';\n\nclass A {}\n" > "$vgm_dir/dup_import/model.dart"
printf "import 'a.dart';\n\nclass A {}\nclass A {}\n" > "$vgm_dir/dup_class/model.dart"

assert_eq "自检：干净目录通过" 0 "$(vgm "$vgm_dir/clean")"
assert_eq "自检：重复 import 被拦下" 1 "$(vgm "$vgm_dir/dup_import")"
assert_eq "自检：重复 class 被拦下" 1 "$(vgm "$vgm_dir/dup_class")"
assert_eq "自检：目录不存在时跳过" 0 "$(vgm "$vgm_dir/does-not-exist")"
rm -rf "$vgm_dir"

echo
if [ "$FAILS" -eq 0 ]; then
  printf '全部通过：%d 项\n' "$TOTAL"
  exit 0
fi
printf '失败 %d 项 / 共 %d 项\n' "$FAILS" "$TOTAL"
exit 1
