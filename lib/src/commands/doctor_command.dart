import 'dart:io';

import '../cli/output.dart';

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
    Cli.info('ww $version');
    Cli.info('');

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
    _reportSigningSource();

    Cli.info('');
    if (!ok) {
      Cli.error('有必需项缺失，请先修复上面标 ✗ 的项');
      return 1;
    }
    Cli.info('环境检查通过');
    return 0;
  }

  /// iOS 签名配置从哪来（不真正解析，只报告来源）
  void _reportSigningSource() {
    final candidates = [
      ('w_build/ios.plist', '个人覆盖'),
      ('ios/ExportOptions.plist', '团队共用（可提交）'),
    ];
    for (final (path, label) in candidates) {
      if (File('$root/$path').existsSync()) {
        Cli.info('✓ iOS 签名：$label（$path）');
        return;
      }
    }

    final pbxproj = File('$root/ios/Runner.xcodeproj/project.pbxproj');
    if (pbxproj.existsSync()) {
      final content = pbxproj.readAsStringSync();
      final team = RegExp(
        r'DEVELOPMENT_TEAM = ([A-Z0-9]+);',
      ).firstMatch(content)?.group(1);
      if (team != null) {
        Cli.info('✓ iOS 签名：零配置（自动探测 team $team）');
      } else {
        Cli.info('- iOS 签名：未配置（需 --team= 或 ios/ExportOptions.plist）');
      }
      return;
    }
    Cli.info('- iOS 签名：无 ios 工程，跳过');
  }

  bool _checkTool(String name, {required bool required, String? hint}) {
    final present = runner.which(name);
    Cli.info('${present ? '✓' : (required ? '✗' : '-')} $name');
    if (!present && hint != null) {
      Cli.info('    提示: $hint');
    }
    return present || !required;
  }

  bool _checkFile(String path, {required bool required, required String hint}) {
    final present = File('$root/$path').existsSync();
    Cli.info('${present ? '✓' : (required ? '✗' : '-')} $path');
    if (!present) {
      Cli.info('    提示: $hint');
    }
    return present || !required;
  }

  void _checkDirectory(
    String path, {
    required bool required,
    required String hint,
  }) {
    final present = Directory('$root/$path').existsSync();
    Cli.info('${present ? '✓' : (required ? '✗' : '-')} $path/');
    if (!present) {
      Cli.info('    提示: $hint');
    }
  }
}
