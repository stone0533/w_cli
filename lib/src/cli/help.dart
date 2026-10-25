/// 每个命令自己的 `--help`。
///
/// 之前 `ww build --help` 打印的是全局帮助、`ww build`（无参数）打印的是
/// build.sh 的英文 usage——两种来源、两种语言。这里给每个命令一份简短的
/// 中文说明 + 参数表，`ww <cmd> --help` 和无参数时都打印它。
library;

/// 命令帮助；未知命令返回 null。
String? commandHelp(String name) => _help[_canonical(name)];

String _canonical(String name) {
  const aliases = {
    'c': 'create',
    'a': 'api',
    'u': 'update',
    'su': 'self-update',
    'b': 'build',
    'p': 'project',
    'o': 'open',
    'cl': 'clean',
  };
  return aliases[name] ?? name;
}

const Map<String, String> _help = {
  'create': '''
用法: ww create [project|p] <name> [--force]

创建 Flutter 工程：flutter create + 依赖 + 目录 + 工程文件 + API 层 + git。

参数:
  <name>        项目名（小写字母开头，只含小写字母/数字/下划线）
  --force       目标目录已存在时覆盖（默认拒绝）''',
  'api': '''
用法: ww api [子命令] [选项]

子命令:
  (无) | generate   根据 client.dart 生成 data_source_mixin.dart / repository.dart
  init              初始化 lib/app/data 与五个骨架文件
  models            从 w_json/*.json 生成 lib/app/data/models/*.dart

选项:
  --force           models：忽略增量全量重生成；generate：覆盖手写成员
  -d, --debug       调试日志''',
  'build': '''
用法: ww build [apk|aab|ios]... [选项]

选项:
  --uat                   UAT 模式（文件名带时间戳）
  --fresh                 构建前清理 w_build/ 里本工具的旧产物（旧名 --clean）
  --open                  构建完打开输出目录
  --name=<name>           产物文件名中的应用名（默认取目录名）
  --export-options=<file> iOS 导出配置（默认 w_build/ios.plist）
  -d, --debug             调试日志

环境变量: OUTPUT_DIR / PARALLEL_BUILD / MIN_BUILD_SIZE / ENABLE_NOTIFICATIONS''',
  'clean': '''
用法: ww clean [android|ios|all] [选项]

参数:
  (无)              打印本帮助（不会清空任何东西）
  all               清理所有平台（默认动作需要显式写出）

选项:
  --lock            删除锁文件（pubspec.lock / Podfile.lock）
  --pod             删除 ios/Pods 并执行 pod update（仅 iOS）
  -d, --debug       调试日志''',
  'open': '''
用法: ww open [ios|i|android|a|build|b|root|r]

目标:
  ios, i        Xcode 打开 ios/Runner.xcworkspace（仅 macOS）
  android, a    Android Studio 打开 android/
  build, b      文件管理器打开 w_build/
  root, r       文件管理器打开项目根目录''',
  'run': '''
用法: ww run [任务名] [--dry-run]

读取项目根的 .ww/tasks（一行一条 `名字 = 命令`），列出或执行任务。
命令走 bash -c（Windows 是 cmd /c），支持 && / cd / 管道；退出码原样透传。''',
  'fmt': '''
用法: ww fmt [路径...] [--check]

执行 dart format（默认 `.`）。
给路径则只格式化那些路径；`--check` 只检查不改文件（CI 用）。''',
  'get': '''
用法: ww get

执行 flutter pub get。''',
  'pod': '''
用法: ww pod

执行 pod install --project-directory=ios（仅 macOS / Linux 有意义）。
不需要手动 cd 到 ios/。''',
  'analyze': '''
用法: ww analyze [-- <flags>]

执行 flutter analyze。额外 flag 写在 `--` 之后，例如 `ww analyze -- --fatal-infos`。''',
  'add': '''
用法: ww add <包>... [--dev]

执行 flutter pub add。`--dev` 会改写成 pub 的 `dev:` 前缀：
  ww add dio              → flutter pub add dio
  ww add build_runner --dev → flutter pub add dev:build_runner''',
  'fix': '''
用法: ww fix

执行 dart fix --apply。''',
  'watch': '''
用法: ww watch

执行 dart run build_runner watch --delete-conflicting-outputs。
长驻进程，不设超时；Ctrl+C 退出（退出码 130）。''',
  'doctor': '''
用法: ww doctor

检查本工具依赖的环境：flutter / dart / pod、pubspec.yaml、ios/、android/、.ww/tasks。
必需项缺失退出 1。''',
  'test': '''
用法: ww test [目标...] [-- <flags>]

执行 flutter test（默认跑全部；给路径则只跑那些文件）。
额外 flag 写在 `--` 之后，例如 `ww test -- --coverage`。''',
  'l10n': '''
用法: ww l10n

执行 flutter gen-l10n。''',
  'outdated': '''
用法: ww outdated

执行 flutter pub outdated。''',
  'deps': '''
用法: ww deps upgrade

升级项目依赖（flutter pub upgrade）并把 Gradle wrapper 指到 8.0。
等价于旧写法 `ww project --update`。''',
  'project': '''
用法: ww project [选项]

选项:
  --update      升级依赖与 Gradle（旧写法，请改用 ww deps upgrade）''',
  'gen': '''
用法: ww gen [-- <build_runner flags>]

执行 dart run build_runner build --delete-conflicting-outputs（30 分钟超时）。
额外参数写在 `--` 之后会原样转发。''',
  'self-update': '''
用法: ww self-update

把 w_cli 自身升级到 pub 上的最新版本（dart pub global activate w_cli）。''',
  'update': '''
用法: ww update（旧名，请改用 ww self-update）

把 w_cli 自身升级到 pub 上的最新版本。''',
};
