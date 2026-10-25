#!/bin/bash
# lib/sh 的 shell 测试：不依赖 bats，直接 bash 跑，失败即非零退出
#
#   bash test/shell/run.sh
#
# 覆盖：脚本退出码契约、脚本可被 source、lib.sh 的超时/版本、
# 目录保护、clean.sh 的参数校验、build.sh 的纯函数与端到端。
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
assert_eq "build.sh --help 退出 0" 0 "$(run_with_alarm bash "$SH/build.sh" --help)"
assert_eq "build.sh --version 退出 0" 0 "$(run_with_alarm bash "$SH/build.sh" --version)"

# build.sh 自己校验参数，语义是"运行失败"(1)
assert_eq "build.sh 未知参数退出 1" 1 "$(run_script build.sh --definitely-not-an-option)"
assert_eq "build.sh 未知参数退出 1" 1 "$(run_script build.sh --definitely-not-an-option)"

echo
echo "== 2. 脚本不以可执行文件身份运行也能工作（ww 用 bash 调用） =="
noexec_dir="$(mktemp -d)"
cp "$SH/lib.sh" "$SH/build.sh" "$noexec_dir/"
chmod -x "$noexec_dir"/*.sh
( cd "$noexec_dir" && bash build.sh --version ) > /dev/null 2>&1
assert_eq "不可执行的 build.sh --version 退出 0" 0 "$?"
rm -rf "$noexec_dir"

echo
echo "== 3. 内置动词走 TaskRunner =="
common_root="$(mktemp -d)"
mkdir -p "$common_root/bin"
cat > "$common_root/bin/dart" <<'STUB'
#!/bin/bash
echo "dart $*" >> "$COMMON_LOG"
if [ "$1" = "format" ]; then exec "$REAL_DART" "$@"; fi
exit "${COMMON_EXIT:-0}"
STUB
cat > "$common_root/bin/flutter" <<'STUB'
#!/bin/bash
echo "flutter $*" >> "$COMMON_LOG"
exit "${COMMON_EXIT:-0}"
STUB
chmod +x "$common_root/bin/dart" "$common_root/bin/flutter"

run_verb() { # 参数...
  : > "$common_root/calls.log"
  ( cd "$common_root" && CI=true REAL_DART="$(command -v dart)" \
      COMMON_LOG="$common_root/calls.log" COMMON_EXIT="${COMMON_EXIT:-0}" \
      PATH="$common_root/bin:$PATH" \
      "$(command -v dart)" run "$ROOT/bin/w_cli.dart" "$@" ) > /dev/null 2>&1
}

run_verb gen
assert_eq "ww gen 退出 0" 0 "$?"
assert_contains "ww gen 调用了 build_runner" \
  "run build_runner build --delete-conflicting-outputs" "$(cat "$common_root/calls.log")"

COMMON_EXIT=1 run_verb gen
assert_eq "build_runner 失败会透传退出码" 1 "$?"

# 额外参数：位置参数替换目标，flag 走 -- 
run_verb fmt lib/app
assert_contains "ww fmt <路径> 替换默认目标" "dart format lib/app" "$(cat "$common_root/calls.log")"

run_verb analyze -- --fatal-infos
assert_contains "ww analyze -- 之后的 flag 透传" "flutter analyze --fatal-infos" "$(cat "$common_root/calls.log")"

# ww common 已移除
run_verb common drbb
assert_eq "ww common 已移除（退出 2）" 2 "$?"
rm -rf "$common_root"

echo
echo "== 4. 生成文本只在 Dart（lib/sh 里没有 cat > *.dart） =="
assert_eq "lib/sh 不再写任何 .dart" "absent" \
  "$(grep -lq 'cat > .*\.dart' "$SH"/*.sh && echo present || echo absent)"

echo
echo "== 5. 脚本可以被 source（不执行 main） =="


echo
echo "== 6. lib.sh 单元 =="
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
echo "== 7. ww create 的目录保护与失败清理（Dart 实现） =="
create_work="$(mktemp -d)"
mkdir -p "$create_work/bin" "$create_work/demo"
printf 'precious\n' > "$create_work/demo/keep.txt"
cat > "$create_work/bin/flutter" << 'STUB'
#!/bin/bash
case "$1" in
  --version) echo "Flutter 3.24.0 • channel stable"; exit 0 ;;
  create)
    name="${@: -1}"; mkdir -p "$name/lib"
    # 真实的 flutter create 会写一个「dependencies 里有 flutter 依赖」的 pubspec，
    # assets 必须插到顶部 flutter: 配置段，而不是这个依赖里
    cat > "$name/pubspec.yaml" << YAML
name: $name
environment:
  sdk: ^3.10.0

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
YAML
    printf 'include: package:flutter_lints/flutter.yaml\n' > "$name/analysis_options.yaml"
    exit "${CREATE_EXIT:-0}" ;;
  *) exit 0 ;;
esac
STUB
cat > "$create_work/bin/dart" << 'STUB'
#!/bin/bash
exit 0
STUB
cat > "$create_work/bin/git" << 'STUB'
#!/bin/bash
exit 0
STUB
chmod +x "$create_work/bin/flutter" "$create_work/bin/dart" "$create_work/bin/git"

run_create() { # 参数...
  ( cd "$create_work" && CI=true PATH="$create_work/bin:$PATH" \
      "$(command -v dart)" run "$ROOT/bin/w_cli.dart" create project "$@" ) > /dev/null 2>&1
}

run_create demo
assert_eq "已存在目录且没有 --force 时退出非零" 1 "$?"

# 省略 project 也能建（新写法）
CREATE_EXIT=0 run_create plain_name
assert_eq "ww create <name> 省略 project 也能用" 0 "$?"
assert_eq "已存在的目录被保留" "precious" "$(cat "$create_work/demo/keep.txt" 2>/dev/null)"

run_create ok_app
assert_eq "正常创建退出 0" 0 "$?"
assert_eq "assets 落在 flutter 配置段（不在 dependencies 里）" "present" \
  "$(awk '/^flutter:$/{influtter=1} influtter && /^  assets:$/{found=1} END{exit !found}' \
      "$create_work/ok_app/pubspec.yaml" && echo present || echo absent)"
assert_eq "flutter 依赖没被动过" "present" \
  "$(grep -q 'sdk: flutter' "$create_work/ok_app/pubspec.yaml" && echo present || echo absent)"
assert_eq "analysis_options 插入了 analyzer" "present" \
  "$(grep -q 'analyzer:' "$create_work/ok_app/analysis_options.yaml" && echo present || echo absent)"

CREATE_EXIT=1 run_create fresh_app
assert_eq "flutter create 失败时退出非零" 1 "$?"
assert_eq "失败时清理本次创建的目录" "gone" \
  "$([ -d "$create_work/fresh_app" ] && echo present || echo gone)"
rm -rf "$create_work"

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
assert_eq "version_ge 忽略 -pre 后缀" 0 "$(ver_ge "$SH/build.sh" 3.10.0-1.pre 3.10.0)"
assert_eq "version_ge 忽略 +build 元数据" 0 "$(ver_ge "$SH/build.sh" 3.10.0+2 3.10.0)"
esc="$(bash -c '. "$1"; escape_applescript "a\b\"c"' _ "$SH/build.sh" 2>/dev/null | tail -1)"
assert_eq "AppleScript 转义反斜杠与引号" 'a\\b\"c' "$esc"

vp() { # 脚本 参数...
  bash -c '. "$1"; shift; if validate_parameters "$@"; then echo 0; else echo 1; fi' _ "$@" 2>/dev/null | tail -1
}
assert_eq "validate_parameters apk" 0 "$(vp "$SH/build.sh" apk)"
assert_eq "validate_parameters 无参数" 1 "$(vp "$SH/build.sh")"
assert_eq "validate_parameters 未知参数" 1 "$(vp "$SH/build.sh" bogus)"

fn_out="$(bash -c '. "$1"; APP_NAME=demo; TIMESTAMP=2026_0101_010101; VERSION_FOR_FILENAME=1.0.0; UAT_MODE=false; generate_filename apk apk ""' _ "$SH/build.sh" 2>/dev/null | tail -1)"
assert_eq "generate_filename 生产模式" "w_build/demo_live_1.0.0.apk" "$fn_out"

echo
echo "== 10. build.sh 端到端（stub flutter） =="
build_root="$(mktemp -d)"
mkdir -p "$build_root/bin" "$build_root/demo/android"
cat > "$build_root/bin/flutter" << 'STUB'
#!/bin/bash
case "$1" in
  --version) echo "Flutter 3.24.0 • channel stable"; exit 0 ;;
  build)
    case "$2" in
      apk) mkdir -p build/app/outputs/flutter-apk; head -c 20000 /dev/zero > build/app/outputs/flutter-apk/app-release.apk ;;
      appbundle) mkdir -p build/app/outputs/bundle/release; head -c 20000 /dev/zero > build/app/outputs/bundle/release/app-release.aab ;;
    esac
    exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$build_root/bin/flutter"
printf 'name: demo\nversion: 1.2.3\n' > "$build_root/demo/pubspec.yaml"

run_build_sh() { # 参数...（在 demo 工程里跑）
  ( cd "$build_root/demo" && PATH="$build_root/bin:$PATH" bash "$SH/build.sh" "$@" ) > /dev/null 2>&1
}

# 1) 非法参数 + --clean：不能先删掉上次的产物
mkdir -p "$build_root/demo/w_build"
head -c 100 /dev/zero > "$build_root/demo/w_build/demo_live_1.2.3.apk"
run_build_sh apk bogus --clean
assert_eq "非法参数退出 1" 1 "$?"
assert_eq "非法参数不会清掉上次产物" "present" \
  "$([ -f "$build_root/demo/w_build/demo_live_1.2.3.apk" ] && echo present || echo gone)"

# 2) --help 放在任意位置都只打印帮助，不进入构建
rm -rf "$build_root/demo/w_build"
run_build_sh apk --help
assert_eq "--help（非首位）退出 0" 0 "$?"
assert_eq "--help 不创建输出目录" "absent" \
  "$([ -d "$build_root/demo/w_build" ] && echo present || echo absent)"

# 3) 成功构建：产物 + build.log
run_build_sh apk
assert_eq "构建成功退出 0" 0 "$?"
assert_eq "产物已生成" "present" \
  "$([ -f "$build_root/demo/w_build/demo_live_1.2.3.apk" ] && echo present || echo gone)"
assert_contains "构建日志已写入" "Built APK" \
  "$(cat "$build_root/demo/w_build/build.log" 2>/dev/null)"

# 4) --name= 生效，旧写法 -name: 被拒绝
run_build_sh apk --name=MyApp
assert_eq "--name= 构建成功" 0 "$?"
assert_eq "--name= 影响产物文件名" "present" \
  "$([ -f "$build_root/demo/w_build/MyApp_live_1.2.3.apk" ] && echo present || echo gone)"
run_build_sh apk -name:OldStyle
assert_eq "旧写法 -name: 退出 2" 2 "$?"
assert_contains "旧写法指路 --name=" "--name=<name>" \
  "$( cd "$build_root/demo" && PATH="$build_root/bin:$PATH" bash "$SH/build.sh" apk -name:OldStyle 2>&1 )"

# 5) 重复平台只构建一次
run_build_sh apk apk
assert_eq "重复平台退出 0" 0 "$?"
assert_eq "重复平台只构建一次" 1 \
  "$( cd "$build_root/demo" && PATH="$build_root/bin:$PATH" bash "$SH/build.sh" apk apk 2>&1 | grep -c '=== Building APK ===' )"

# 6) iOS：plist 取值不能把证书名里的空格压掉
plist_dir="$(mktemp -d)"
plist_fixture="$plist_dir/ios.plist"
cat > "$plist_fixture" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>ABC123DEF4</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Apple Distribution: My Company (GHI567JKL8)</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.example.demo</key>
        <string>AppStore Profile</string>
    </dict>
</dict>
</plist>
PLIST
plist_value() { # 文件 key
  bash -c '. "$1"; get_plist_value "$2" "$3"' _ "$SH/build.sh" "$1" "$2" 2>/dev/null | tail -1
}
plist_valid() { # 文件
  bash -c '. "$1"; validate_ios_plist "$2"' _ "$SH/build.sh" "$1" > /dev/null 2>&1
  echo $?
}
assert_eq "证书名保留空格" "Apple Distribution: My Company (GHI567JKL8)" \
  "$(plist_value "$plist_dir/ios.plist" signingCertificate)"
assert_eq "method 取值正常" "app-store" "$(plist_value "$plist_dir/ios.plist" method)"
assert_eq "手动签名配置校验通过" 0 "$(plist_valid "$plist_dir/ios.plist")"

sed 's/ABC123DEF4//' "$plist_dir/ios.plist" > "$plist_dir/no_team.plist"
assert_eq "缺 teamID 校验失败" 1 "$(plist_valid "$plist_dir/no_team.plist")"

sed 's/My Company/YOUR_COMPANY_NAME/' "$plist_dir/ios.plist" > "$plist_dir/placeholder.plist"
assert_eq "未替换的 YOUR_ 占位符校验失败" 1 "$(plist_valid "$plist_dir/placeholder.plist")"

# 7) iOS 端到端：签名参数与导出流程（stub flutter + xcodebuild）
ios_root="$(mktemp -d)"
mkdir -p "$ios_root/bin" "$ios_root/demo/ios"
cat > "$ios_root/bin/flutter" << 'STUB'
#!/bin/bash
case "$1" in
  --version) echo "Flutter 3.24.0 • channel stable"; exit 0 ;;
  build)
    mkdir -p build/ios/iphoneos/Runner.app
    printf 'plist\n' > build/ios/iphoneos/Runner.app/Info.plist
    printf 'bin\n' > build/ios/iphoneos/Runner.app/Runner
    exit 0 ;;
  *) exit 0 ;;
esac
STUB
cat > "$ios_root/bin/xcodebuild" << 'STUB'
#!/bin/bash
echo "xcodebuild $*" >> "$XCODE_LOG"
if [ "$1" = "-exportArchive" ]; then
  while [ $# -gt 0 ]; do
    if [ "$1" = "-exportPath" ]; then mkdir -p "$2"; printf 'ipa\n' > "$2/Runner.ipa"; fi
    shift
  done
fi
exit 0
STUB
chmod +x "$ios_root/bin/flutter" "$ios_root/bin/xcodebuild"
printf 'name: demo\nversion: 1.2.3\n' > "$ios_root/demo/pubspec.yaml"
mkdir -p "$ios_root/demo/w_build"
cp "$plist_fixture" "$ios_root/demo/w_build/ios.plist"

run_ios() {
  ( cd "$ios_root/demo" && XCODE_LOG="$ios_root/xcode.log" PATH="$ios_root/bin:$PATH" \
      bash "$SH/build.sh" ios ) > /dev/null 2>&1
}
run_ios
assert_eq "iOS 构建成功" 0 "$?"
assert_eq "iOS 产物已生成" "present" \
  "$([ -f "$ios_root/demo/w_build/demo_live_1.2.3.ipa" ] && echo present || echo gone)"
assert_contains "手动签名把证书名原样传给 xcodebuild" \
  "-codeSignIdentity Apple Distribution: My Company (GHI567JKL8)" \
  "$(cat "$ios_root/xcode.log" 2>/dev/null)"
assert_contains "导出使用 ios.plist" "-exportOptionsPlist w_build/ios.plist" \
  "$(cat "$ios_root/xcode.log" 2>/dev/null)"
assert_eq "archive 父目录已创建" "present" \
  "$([ -d "$ios_root/demo/build/ios/archive" ] && echo present || echo gone)"
rm -rf "$ios_root" "$plist_dir"

# 8) 失败清理不再动输出目录里的成品
head -c 100 /dev/zero > "$build_root/demo/w_build/keep_live_9.9.9.apk"
( cd "$build_root/demo" && bash -c ". '$SH/build.sh'; cleanup_failed_build apk" ) > /dev/null 2>&1
assert_eq "失败清理保留输出目录里的成品" "present" \
  "$([ -f "$build_root/demo/w_build/keep_live_9.9.9.apk" ] && echo present || echo gone)"

# 9) 无参数 = 帮助（ww clean 曾经一按回车就清空产物）
noarg_root="$(mktemp -d)"
mkdir -p "$noarg_root/keep"
printf 'precious\n' > "$noarg_root/keep/model.apk"
noarg() { ( cd "$noarg_root" && CI=true "$(command -v dart)" run "$ROOT/bin/w_cli.dart" "$@" ) > /dev/null 2>&1; }

noarg clean
assert_eq "ww clean 无参数退出 0" 0 "$?"
assert_eq "ww clean 无参数不删任何东西" "precious" \
  "$(cat "$noarg_root/keep/model.apk" 2>/dev/null)"

noarg build
assert_eq "ww build 无参数打印帮助并退出 0" 0 "$?"
rm -rf "$noarg_root"

# 10) 内置短命令（fmt / get / pod / analyze）
tasks_root="$(mktemp -d)"
mkdir -p "$tasks_root/bin"
cat > "$tasks_root/bin/dart" << 'STUB'
#!/bin/bash
echo "dart $*" >> "$TASKS_LOG"
if [ "$1" = "format" ]; then exec "$REAL_DART" "$@"; fi
exit "${TASKS_EXIT:-0}"
STUB
cat > "$tasks_root/bin/flutter" << 'STUB'
#!/bin/bash
echo "flutter $*" >> "$TASKS_LOG"
exit "${TASKS_EXIT:-0}"
STUB
chmod +x "$tasks_root/bin/dart" "$tasks_root/bin/flutter"

run_ww_task() { # 参数...
  : > "$tasks_root/calls.log"
  ( cd "$tasks_root" && CI=true REAL_DART="$(command -v dart)" \
      TASKS_LOG="$tasks_root/calls.log" TASKS_EXIT="${TASKS_EXIT:-0}" \
      PATH="$tasks_root/bin:$PATH" \
      "$(command -v dart)" run "$ROOT/bin/w_cli.dart" "$@" ) > /dev/null 2>&1
}

run_ww_task fmt
assert_eq "ww fmt 退出 0" 0 "$?"
assert_contains "ww fmt 调 dart format ." "dart format ." "$(cat "$tasks_root/calls.log")"

run_ww_task get
assert_contains "ww get 调 flutter pub get" "flutter pub get" "$(cat "$tasks_root/calls.log")"

TASKS_EXIT=2 run_ww_task analyze
assert_eq "ww analyze 透传退出码" 2 "$?"
rm -rf "$tasks_root"

# 11) ww build 的参数透传：--name / 未知参数
run_ww_build() { # 参数...（在 demo 工程里跑 ww build）
  ( cd "$build_root/demo" && CI=true PATH="$build_root/bin:$PATH" \
      "$(command -v dart)" run "$ROOT/bin/w_cli.dart" build "$@" ) > /dev/null 2>&1
}
rm -rf "$build_root/demo/w_build"
run_ww_build apk --name=WwName
assert_eq "ww build --name 退出 0" 0 "$?"
assert_eq "ww build --name 进产物文件名" "present" \
  "$([ -f "$build_root/demo/w_build/WwName_live_1.2.3.apk" ] && echo present || echo gone)"
run_ww_build apk --bogus-option
assert_eq "ww build 未知参数退出 2" 2 "$?"

# 12) 并行构建：Android 内部串行、失败会传播
run_build_parallel() { # 参数...（PARALLEL_BUILD=true）
  ( cd "$build_root/demo" && PARALLEL_BUILD=true PATH="$build_root/bin:$PATH" \
      bash "$SH/build.sh" "$@" ) > /dev/null 2>&1
}
rm -rf "$build_root/demo/w_build" "$build_root/demo/build"
run_build_parallel apk aab
assert_eq "并行构建（apk+aab）成功" 0 "$?"
assert_eq "并行构建两个产物都在" "present" \
  "$([ -f "$build_root/demo/w_build/demo_live_1.2.3.apk" ] && [ -f "$build_root/demo/w_build/demo_live_1.2.3.aab" ] && echo present || echo gone)"
assert_contains "Android 内部串行提示" "Android 内部串行" \
  "$( cd "$build_root/demo" && PARALLEL_BUILD=true PATH="$build_root/bin:$PATH" bash "$SH/build.sh" apk aab 2>&1 )"

# 13) MIN_BUILD_SIZE 可配：阈值超过产物大小时失败且不落产物
rm -rf "$build_root/demo/w_build" "$build_root/demo/build"
( cd "$build_root/demo" && MIN_BUILD_SIZE=999999 PATH="$build_root/bin:$PATH" \
    bash "$SH/build.sh" apk ) > /dev/null 2>&1
assert_eq "产物小于 MIN_BUILD_SIZE 时构建失败" 1 "$?"
assert_eq "失败的产物不会进输出目录" "gone" \
  "$([ -f "$build_root/demo/w_build/demo_live_1.2.3.apk" ] && echo present || echo gone)"

rm -rf "$build_root"

echo
echo "== 11. init 已迁到 Dart（ww api init） =="
scaffold_root="$(mktemp -d)"
mkdir -p "$scaffold_root/bin" "$scaffold_root/demo/lib/app/w"
printf '#!/bin/bash\nexit 0\n' > "$scaffold_root/bin/flutter"
chmod +x "$scaffold_root/bin/flutter"
printf '// barrel\n' > "$scaffold_root/demo/lib/app/w/toolkit.dart"
cat > "$scaffold_root/demo/pubspec.yaml" << 'YAML'
name: demo
dependencies:
  retrofit: ^4.0.0
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
  retrofit_generator: ^8.0.0
YAML

( cd "$scaffold_root/demo" && CI=true PATH="$scaffold_root/bin:$PATH" \
    dart run "$ROOT/bin/w_cli.dart" api init ) > /dev/null 2>&1
assert_eq "ww api init 退出 0" 0 "$?"
assert_eq "ww api init 产出五个骨架文件" "5" \
  "$(find "$scaffold_root/demo/lib/app/data" -name '*.dart' | wc -l | tr -d ' ')"
assert_eq "ww api init 建了 w_json 目录" "present" \
  "$([ -d "$scaffold_root/demo/w_json" ] && echo present || echo absent)"

# models 也走 Dart 了：产物与 shell 版本一致这件事由 test/models_test.dart 盯着，
# 这里只验证 CLI 串起来了
mkdir -p "$scaffold_root/demo/w_json"
printf '{"id":1,"name":"x"}\n' > "$scaffold_root/demo/w_json/user.json"
mkdir -p "$scaffold_root/demo/bin"
cat > "$scaffold_root/demo/bin/dart" << 'STUB'
#!/bin/bash
if [ "$1" = "format" ]; then exec "$REAL_DART" "$@"; fi
exit 0
STUB
chmod +x "$scaffold_root/demo/bin/dart"
( cd "$scaffold_root/demo" && CI=true REAL_DART="$(command -v dart)" \
    PATH="$scaffold_root/demo/bin:$scaffold_root/bin:$PATH" \
    "$(command -v dart)" run "$ROOT/bin/w_cli.dart" api models ) > /dev/null 2>&1
assert_eq "ww api models 退出 0" 0 "$?"
assert_eq "ww api models 产出模型文件" "present" \
  "$([ -f "$scaffold_root/demo/lib/app/data/models/user.dart" ] && echo present || echo gone)"
rm -rf "$scaffold_root"

echo
if [ "$FAILS" -eq 0 ]; then
  printf '全部通过：%d 项\n' "$TOTAL"
  exit 0
fi
printf '失败 %d 项 / 共 %d 项\n' "$FAILS" "$TOTAL"
exit 1
