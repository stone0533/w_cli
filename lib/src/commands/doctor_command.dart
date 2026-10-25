import 'dart:io';

import '../cli/process.dart';
import '../version.dart';

/// `ww doctor`：检查本工具依赖的环境。
///
/// 比 `flutter doctor` 更窄——只看 `ww` 自己会用到的：flutter / dart / pod、
/// 当前目录是不是一个 Flutter 工程。缺失的项给安装提示，不直接失败。
class DoctorCommand {
  DoctorCommand({this.root = '.', this.runner = const SystemProcessRunner()});

  final String root;
  final ProcessRunner runner;

  Future<int> run() async {
    var ok = true;
    stdout.writeln('ww $version');
    stdout.writeln('');

    ok &= _checkTool('flutter', required: true);
    ok &= _checkTool('dart', required: true);
    _checkTool(
      'pod',
      required: false,
      hint: 'macOS 上执行 brew install cocoapods',
    );
    ok &= _checkFile('pubspec.yaml', required: true, hint: '当前目录不是 Flutter 工程');
    _checkDirectory(
      'ios',
      required: false,
      hint: '没有 ios/ 目录，ww pod / ww build ios 不适用',
    );
    _checkDirectory(
      'android',
      required: false,
      hint: '没有 android/ 目录，ww build apk 不适用',
    );
    _checkFile('.ww/tasks', required: false, hint: '没有 .ww/tasks，ww run 无任务可用');

    stdout.writeln('');
    if (!ok) {
      stderr.writeln('有必需项缺失，请先修复上面标 ✗ 的项');
      return 1;
    }
    stdout.writeln('环境检查通过');
    return 0;
  }

  bool _checkTool(String name, {required bool required, String? hint}) {
    final present = runner.which(name);
    stdout.writeln('${present ? '✓' : (required ? '✗' : '-')} $name');
    if (!present && hint != null) {
      stdout.writeln('    提示: $hint');
    }
    return present || !required;
  }

  bool _checkFile(String path, {required bool required, required String hint}) {
    final present = File('$root/$path').existsSync();
    stdout.writeln('${present ? '✓' : (required ? '✗' : '-')} $path');
    if (!present) {
      stdout.writeln('    提示: $hint');
    }
    return present || !required;
  }

  void _checkDirectory(
    String path, {
    required bool required,
    required String hint,
  }) {
    final present = Directory('$root/$path').existsSync();
    stdout.writeln('${present ? '✓' : (required ? '✗' : '-')} $path/');
    if (!present) {
      stdout.writeln('    提示: $hint');
    }
  }
}
