import 'dart:io';

/// `ww open`（原 `lib/sh/open.sh`）。
///
/// 与旧脚本的差异（都是修 bug）：
/// - 支持 help 里早就写着的短别名（`i` / `a` / `b` / `r`），以前只认全名
/// - 打开失败返回非零：旧脚本在 `main` 末尾继续打印分隔线，退出码永远是 0
class OpenCommand {
  OpenCommand({this.root = '.'});

  final String root;

  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.first == '--help') {
      printHelp();
      return 0;
    }
    if (args.first == '--version') {
      printVersion();
      return 0;
    }
    if (args.length > 1) {
      stderr.writeln('参数过多: ${args.join(' ')}');
      printHelp(asError: true);
      return 2;
    }

    final target = args.first;
    final label = _label(target);
    if (label == null) {
      stderr.writeln('未知参数: $target');
      printHelp(asError: true);
      return 2;
    }

    print('${'=' * 54}\n打开$label\n${'=' * 54}');
    final status = await _open(target);
    print(
      '${'=' * 54}\n打开$label完成 '
      '${DateTime.now().toString().substring(0, 19)}\n${'=' * 54}',
    );
    return status;
  }

  String? _label(String target) {
    switch (target) {
      case 'ios':
      case 'i':
        return ' iOS 项目';
      case 'android':
      case 'a':
        return ' Android 项目';
      case 'build':
      case 'b':
        return '构建目录';
      case 'root':
      case 'r':
        return '根目录';
      default:
        return null;
    }
  }

  Future<int> _open(String target) async {
    switch (target) {
      case 'ios':
      case 'i':
        return _openIos();
      case 'android':
      case 'a':
        return _openAndroid();
      case 'build':
      case 'b':
        return _openDirectory('$root/w_build', '构建目录');
      case 'root':
      case 'r':
        return _openDirectory(root, '根目录');
      default:
        return 2;
    }
  }

  Future<int> _openIos() async {
    final workspace = Directory('$root/ios/Runner.xcworkspace');
    if (!workspace.existsSync()) {
      stderr.writeln('iOS 项目 workspace 文件不存在: ${workspace.path}');
      return 1;
    }
    if (!Platform.isMacOS) {
      stderr.writeln('此功能仅在 macOS 上可用');
      return 1;
    }

    stdout.writeln('用 Xcode 打开 iOS 项目...');
    return _run('open', ['-a', 'Xcode', workspace.path], 'iOS 项目');
  }

  Future<int> _openAndroid() async {
    final androidDir = Directory('$root/android');
    if (!androidDir.existsSync()) {
      stderr.writeln('Android 项目目录不存在: ${androidDir.path}');
      return 1;
    }

    stdout.writeln('用 Android Studio 打开 Android 项目...');
    if (Platform.isMacOS) {
      return _run('open', [
        '-a',
        'Android Studio',
        androidDir.path,
      ], 'Android 项目');
    }
    if (Platform.isLinux) {
      if (!_available('studio.sh')) {
        stderr.writeln('Android Studio 命令未找到，请确保已正确安装并添加到 PATH');
        return 1;
      }
      return _run('studio.sh', [androidDir.path], 'Android 项目');
    }
    stderr.writeln('此功能仅在 macOS 和 Linux 上可用');
    return 1;
  }

  Future<int> _openDirectory(String target, String label) async {
    if (!Directory(target).existsSync()) {
      stderr.writeln('$label不存在: $target');
      return 1;
    }

    final String opener;
    if (Platform.isMacOS) {
      opener = 'open';
    } else if (Platform.isLinux) {
      opener = 'xdg-open';
    } else {
      stderr.writeln('此功能仅在 macOS 和 Linux 上可用');
      return 1;
    }

    if (!_available(opener)) {
      stderr.writeln('$opener 命令未找到，请确保已正确安装');
      return 1;
    }

    stdout.writeln('用 Finder 打开$label...');
    return _run(opener, [target], label);
  }

  Future<int> _run(String executable, List<String> args, String label) async {
    final code = await Process.run(
      executable,
      args,
      runInShell: true,
    ).then((result) => result.exitCode);

    if (code == 0) {
      stdout.writeln('$label已成功打开');
    } else {
      stderr.writeln('打开$label失败');
    }
    return code;
  }

  static bool _available(String name) {
    try {
      return Process.runSync('which', [name], runInShell: true).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  void printVersion() {
    print('ww open');
    print('Description: 用于打开 Flutter 项目的不同部分');
  }

  void printHelp({bool asError = false}) {
    final buffer = StringBuffer()
      ..writeln('使用方法: ww open [ios|i|android|a|build|b|root|r]')
      ..writeln('选项:')
      ..writeln('  ios, i      用 Xcode 打开 iOS 项目')
      ..writeln('  android, a  用 Android Studio 打开 Android 项目')
      ..writeln('  build, b    用文件管理器打开构建目录（w_build）')
      ..writeln('  root, r     用文件管理器打开根目录')
      ..writeln('  --help      显示此帮助信息')
      ..writeln('  --version   显示版本信息');
    (asError ? stderr : stdout).write(buffer);
  }
}
