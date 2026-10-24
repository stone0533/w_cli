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
snake=$(bash -c ". '$SH/api.sh'; to_snake_case 'userName'" 2>/dev/null | tail -1)
assert_eq "to_snake_case 驼峰转蛇形" "user_name_result.dart" "$snake"

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
echo "== 7. client.dart 解析与产物生成 =="
tmp_proj="$(mktemp -d)"
mkdir -p "$tmp_proj/lib/app/data/sources/remote" "$tmp_proj/lib/app/data/models"
cp "$FIXTURES/client_nested.expected" "$tmp_proj/lib/app/data/sources/client.dart"
printf 'class UserResult {}\n' > "$tmp_proj/lib/app/data/models/user.dart"
printf 'class OrderResult {}\n' > "$tmp_proj/lib/app/data/models/order.dart"

methods_dump="$( cd "$tmp_proj" && bash -c ". '$SH/api.sh'; parse_client" 2>/dev/null )"

# 用脚本文件而不是嵌套 bash -c：方法信息里有空格（Map<String, dynamic>），
# 这里必须按行读到数组里，不能数组字面量直接 $-展开
cat > "$tmp_proj/gen_mixin.sh" << 'GEN'
#!/bin/bash
. "$1"
m=()
while IFS= read -r line; do
  if [ -n "$line" ]; then m+=("$line"); fi
done < <(parse_client)
generate_remote_datasource "${m[@]}"
GEN
cat > "$tmp_proj/gen_files.sh" << 'GEN'
#!/bin/bash
. "$1"
m=()
while IFS= read -r line; do
  if [ -n "$line" ]; then m+=("$line"); fi
done < <(parse_client)
update_files "${m[@]}"
GEN
chmod +x "$tmp_proj/gen_mixin.sh" "$tmp_proj/gen_files.sh"
assert_contains "Map 返回类型不被截断" "getProfile|Map<String, dynamic>" "$methods_dump"
assert_contains "List<T> 保留类型实参" "getUsers|List<UserResult>" "$methods_dump"
assert_contains "@Query 保留名字与类型" "page:int;size:int" "$methods_dump"

mixin_out="$( cd "$tmp_proj" && bash gen_mixin.sh "$SH/api.sh" 2>/dev/null )"
assert_contains "接口保留 Map 泛型" "Future<Map<String, dynamic>> getProfile(" "$mixin_out"
assert_contains "两个 @Query 用 int 类型" "int page," "$mixin_out"
assert_contains "两个 @Query 名字不重复" "int size," "$mixin_out"
if printf '%s' "$mixin_out" | grep -qE 'Map<String, dynamic> queries'; then
  fail "@Query 不再被当成 Map 参数" "仍生成了 Map<String, dynamic> queries"
else
  pass "@Query 不再被当成 Map 参数"
fi

# 生成物必须是合法 Dart（有 dart 时才断言，CI 的 shell job 里装了 dart）
if command -v dart > /dev/null 2>&1; then
  printf '%s\n' "$mixin_out" > "$tmp_proj/mixin.dart"
  if ( cd "$tmp_proj" && dart format mixin.dart > /dev/null 2>&1 ); then
    pass "生成物是合法 Dart"
  else
    fail "生成物是合法 Dart" "$( cd "$tmp_proj" && dart format mixin.dart 2>&1 | head -3 )"
  fi
else
  pass "生成物是合法 Dart（跳过：环境里没有 dart）"
fi

# Dart 关键字作字段名时，字段名要合法（@JsonKey 里保留原名）
kw_out="$( cd "$tmp_proj" && bash -c ". '$SH/api.sh'; generate_model_class '{\"class\":\"x\",\"1st\":1}' Kw kw.dart" 2>/dev/null )"
assert_contains "关键字字段名加后缀" "String? class_;" "$kw_out"
assert_contains "数字开头字段名加前缀" "int? f_1st;" "$kw_out"
assert_contains "JsonKey 保留原始字段名" "@JsonKey(name: 'class')" "$kw_out"

# 正常路径：update_files 写入产物
printf 'OLD\n' > "$tmp_proj/lib/app/data/sources/remote/data_source_mixin.dart"
( cd "$tmp_proj" && bash gen_files.sh "$SH/api.sh" > /dev/null 2>&1 )
assert_contains "update_files 写入生成物" "IAppRemoteDataSource" \
  "$(cat "$tmp_proj/lib/app/data/sources/remote/data_source_mixin.dart" 2>/dev/null)"

# 失败路径：dart 校验不通过时，已有产物必须原样保留
mkdir -p "$tmp_proj/broken-bin"
printf '#!/bin/bash\nexit 65\n' > "$tmp_proj/broken-bin/dart"
chmod +x "$tmp_proj/broken-bin/dart"
printf 'KEEP-ME\n' > "$tmp_proj/lib/app/data/sources/remote/data_source_mixin.dart"
( cd "$tmp_proj" && PATH="$tmp_proj/broken-bin:$PATH" \
  bash gen_files.sh "$SH/api.sh" > /dev/null 2>&1 )
assert_contains "校验失败时保留原有产物" "KEEP-ME" \
  "$(cat "$tmp_proj/lib/app/data/sources/remote/data_source_mixin.dart" 2>/dev/null)"
rm -rf "$tmp_proj"

echo
if [ "$FAILS" -eq 0 ]; then
  printf '全部通过：%d 项\n' "$TOTAL"
  exit 0
fi
printf '失败 %d 项 / 共 %d 项\n' "$FAILS" "$TOTAL"
exit 1
