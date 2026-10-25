import 'dart:io';

import '../cli/help.dart';
import '../cli/output.dart';
import '../cli/process.dart';

/// `ww clean`（原 `lib/sh/clean.sh`）。
///
/// 行为照旧：`--lock` 删锁文件、`--pod` 清 Pods 并跑 pod update、
/// 然后 `flutter clean` + `flutter pub get`。改成 Dart 后 `--lock` / `--pod`
/// 这些参数才真正能从 `ww` 传进来（以前 ArgParser 直接拒绝）。
class CleanCommand {
  CleanCommand({this.root = '.', this.runner = const SystemProcessRunner()});

  final String root;
  final ProcessRunner runner;
  static const int maxPodRetries = 30;

  Future<int> run(List<String> args) async {
    var platform = 'all';
    var lock = false;
    var pod = false;

    for (final arg in args) {
      switch (arg) {
        case '--help':
          printHelp();
          return 0;
        case '--version':
          printVersion();
          return 0;
        case '--debug':
          // 调试开关只影响日志级别，Dart 侧没有更细的日志
          break;
        case '--lock':
          lock = true;
          break;
        case '--pod':
          pod = true;
          break;
        case 'android':
        case 'ios':
        case 'all':
          platform = arg;
          break;
        default:
          Cli.error('未知参数: $arg');
          printHelp(asError: true);
          return 2;
      }
    }

    if (pod && platform == 'android') {
      Cli.error('--pod 选项只能用于 iOS 平台');
      printHelp(asError: true);
      return 2;
    }

    if (!runner.which('flutter')) {
      Cli.error('flutter 命令不可用，请确保已正确安装');
      return 1;
    }
    if ((platform == 'ios' || platform == 'all') && !runner.which('pod')) {
      Cli.info('pod 命令不可用，相关操作可能会失败');
    }

    if (lock) {
      _cleanLockFiles(platform);
    }
    if (pod) {
      _cleanPods();
    }

    if (!await _flutter(['clean'])) {
      _printFooter();
      return 1;
    }
    if (!await _flutter(['pub', 'get'])) {
      _printFooter();
      return 1;
    }
    if (pod || (lock && platform != 'android')) {
      if (!await _podUpdate()) {
        _printFooter();
        return 1;
      }
    }

    Cli.info('✅ 清理完成！');
    _printFooter();
    return 0;
  }

  void _cleanLockFiles(String platform) {
    if (platform == 'android' || platform == 'all') {
      _deleteFile('$root/pubspec.lock');
    }
    if (platform == 'ios' || platform == 'all') {
      _deleteFile('$root/ios/Podfile.lock');
    }
  }

  void _cleanPods() {
    _deleteDirectory('$root/ios/Pods');
    _deleteFile('$root/ios/Podfile.lock');
  }

  void _deleteFile(String path) {
    final file = File(path);
    final name = path.split('/').last;
    if (!file.existsSync()) {
      Cli.info('$name 文件不存在，跳过删除');
      return;
    }
    Cli.info('删除 $name 文件...');
    file.deleteSync();
    Cli.info('$name 文件删除成功');
  }

  void _deleteDirectory(String path) {
    final dir = Directory(path);
    final name = path.split('/').last;
    if (!dir.existsSync()) {
      Cli.info('$name 目录不存在，跳过删除');
      return;
    }
    Cli.info('删除 $name 目录...');
    dir.deleteSync(recursive: true);
    Cli.info('$name 目录删除成功');
  }

  Future<bool> _flutter(List<String> args) async {
    Cli.info('执行 flutter ${args.join(' ')}...');
    final status = await _run('flutter', args);
    if (status != 0) {
      Cli.error('flutter ${args.join(' ')} 执行失败');
      return false;
    }
    Cli.info('flutter ${args.join(' ')} 执行成功');
    return true;
  }

  Future<bool> _podUpdate() async {
    final iosDir = Directory('$root/ios');
    if (!iosDir.existsSync()) {
      Cli.error('未找到 ios 目录，跳过 pod update');
      return true;
    }

    for (var attempt = 1; attempt <= maxPodRetries; attempt++) {
      Cli.info(
        attempt == 1 ? '执行 pod update...' : '执行 pod update（第 $attempt 次重试）...',
      );
      final code = await _run('pod', ['update'], workingDirectory: iosDir.path);
      if (code == 0) {
        Cli.info('pod update 执行成功');
        return true;
      }
      Cli.error('pod update 执行失败');
    }

    Cli.error('pod update 多次执行失败，已达到最大重试次数');
    return false;
  }

  Future<int> _run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    return runner.start(
      executable,
      args,
      workingDirectory: workingDirectory ?? root,
    );
  }

  void _printFooter() {}

  void printVersion() {
    print('ww clean');
    print('Description: 清理 Flutter 应用的构建文件并执行 flutter pub get');
  }

  void printHelp({bool asError = false}) {
    final buffer = StringBuffer()
      ..writeln('使用方法: ww clean [选项] [平台]')
      ..writeln('平台:')
      ..writeln('  android    清理 Android 构建文件')
      ..writeln('  ios        清理 iOS 构建文件')
      ..writeln('  all        清理所有平台构建文件（默认）')
      ..writeln('选项:')
      ..writeln('  --help     显示此帮助信息')
      ..writeln('  --version  显示版本信息')
      ..writeln('  --debug    启用调试模式')
      ..writeln('  --lock     清理锁文件（pubspec.lock 或 Podfile.lock）')
      ..writeln('  --pod      清理 iOS Pods（仅适用于 iOS 平台）');
    (asError ? stderr : stdout).write(buffer);
  }
}

/// 处理 common 命令
/// [arguments] - 命令参数

/// 处理 clean 命令
/// [arguments] - 命令参数
Future<int> handleCleanCommand(List<String> arguments) async {
  // 无参数时只打印帮助：`ww clean` 曾经会立刻清空所有构建产物
  if (arguments.isEmpty) {
    final help = commandHelp('clean');
    if (help != null) {
      print(help);
    }
    return 0;
  }
  return CleanCommand().run(arguments);
}
