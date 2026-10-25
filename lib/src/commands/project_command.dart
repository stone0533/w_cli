import 'dart:io';

import '../cli/capture.dart';
import '../cli/output.dart';
import '../cli/process.dart';

/// `ww deps`：依赖与工程脚手架的升级。
///
/// 两件事**分开**做（以前 `ww project --update` 把两者绑在一起，还无条件把
/// Gradle 写成 8.0——对 Flutter 3.4x 的新工程等于降级）：
///
/// - `ww deps upgrade [--major] [--dry-run] [--pod]`：只动 pub 依赖
/// - `ww deps gradle [--to=x.y.z] [--force]`：只动 gradle-wrapper，
///   默认只报告；`--to` 低于当前版本会被拒绝（除非 `--force`）
class ProjectCommand {
  ProjectCommand({this.root = '.', this.runner = const SystemProcessRunner()});

  final String root;
  final ProcessRunner runner;

  /// pub 依赖升级
  Future<int> pubUpgrade({
    bool major = false,
    bool dryRun = false,
    bool pod = false,
  }) async {
    if (!runner.which('flutter')) {
      Cli.error('Flutter 未安装，请先安装 Flutter');
      return 1;
    }
    if (!File('$root/pubspec.yaml').existsSync()) {
      Cli.error('未找到 pubspec.yaml，当前目录可能不是 Flutter 项目');
      return 1;
    }

    final version = await _flutterVersion();
    Cli.info('Flutter $version');

    if (dryRun) {
      return _reportOutdated();
    }

    Cli.info(major ? '升级依赖（含大版本）...' : '升级依赖...');
    final args = <String>['pub', 'upgrade', if (major) '--major-versions'];
    final output = await runCaptured(
      runner,
      'flutter',
      args,
      root: root,
      logName: 'deps.log',
    );
    if (output.code != 0) {
      captureTail(output.text);
      return output.code;
    }

    final changed = _countChanged(output.text);
    Cli.ok(changed > 0 ? '升级了 $changed 个依赖' : '依赖已是最新');

    if (pod && File('$root/ios/Podfile').existsSync()) {
      Cli.info('刷新 iOS Pods...');
      final podCode = await runCaptured(
        runner,
        'pod',
        ['install', '--project-directory=ios'],
        root: root,
        logName: 'pod.log',
      );
      if (podCode.code != 0) {
        captureTail(podCode.text);
        return podCode.code;
      }
      Cli.ok('Pods 已刷新');
    } else if (File('$root/ios/Podfile').existsSync()) {
      Cli.info('提示: iOS 的 Pods 可能已过期，接着跑 ww pod 或加 --pod');
    }

    return 0;
  }

  /// Gradle wrapper：默认只报告，`--to` 才写文件
  Future<int> gradle({String? to, bool force = false}) async {
    final wrapper = File(
      '$root/android/gradle/wrapper/gradle-wrapper.properties',
    );
    if (!wrapper.existsSync()) {
      Cli.warn('没有 android/gradle/wrapper/gradle-wrapper.properties，跳过');
      return 0;
    }

    final content = wrapper.readAsStringSync();
    final match = RegExp(
      r'gradle-([0-9][0-9.]*)-(all|bin)\.zip',
    ).firstMatch(content);
    if (match == null) {
      Cli.error('无法从 gradle-wrapper.properties 解析出版本');
      Cli.info('  当前内容: ${_distributionLine(content)}');
      return 1;
    }

    final current = match.group(1)!;
    final kind = match.group(2)!;
    Cli.info('当前 Gradle: $current ($kind)');

    if (to == null || to.isEmpty) {
      Cli.info('只检测未修改；要升级请加 --to=<版本>，例如 --to=9.1.0');
      return 0;
    }
    _checkVersionShape(to);

    final cmp = _compareVersions(to, current);
    if (cmp == 0) {
      Cli.ok('已经是 $to，未改动');
      return 0;
    }
    if (cmp < 0 && !force) {
      Cli.error('目标版本 $to 低于当前 $current，会降级；确需降级请加 --force');
      return 1;
    }

    final line =
        'distributionUrl=https\\://services.gradle.org/distributions/'
        'gradle-$to-$kind.zip';
    final updated = content.replaceAll(
      RegExp(r'^distributionUrl=.*$', multiLine: true),
      line,
    );
    wrapper.writeAsStringSync(updated);
    Cli.ok('Gradle 已更新: $current → $to（保留 $kind）');
    Cli.info('提示: Gradle 大版本升级后建议跑一次 ww clean 再构建');
    return 0;
  }

  Future<int> _reportOutdated() async {
    Cli.info('检查可升级的依赖（不修改任何文件）...');
    final output = await runCaptured(
      runner,
      'flutter',
      ['pub', 'outdated'],
      root: root,
      logName: 'outdated.log',
    );
    if (output.code != 0) {
      captureTail(output.text);
      return output.code;
    }
    for (final line in output.text.split('\n').take(20)) {
      Cli.detail(line);
    }
    Cli.ok('详细清单: $root/w_build/outdated.log');
    return 0;
  }

  int _countChanged(String text) {
    final pattern = RegExp(r'^\s*[>+]\s+\S+\s+\S+.*\(was ', multiLine: true);
    return pattern.allMatches(text).length;
  }

  String _distributionLine(String content) {
    for (final line in content.split('\n')) {
      if (line.startsWith('distributionUrl=')) {
        return line;
      }
    }
    return '（没有 distributionUrl 行）';
  }

  void _checkVersionShape(String version) {
    if (!RegExp(r'^\d+\.\d+(\.\d+)?$').hasMatch(version)) {
      Cli.warn('`$version` 不像 Gradle 版本号（示例: 9.1.0），仍按原样写入');
    }
  }

  /// 语义化比较：返回负 / 零 / 正
  int _compareVersions(String a, String b) {
    List<int> parts(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final left = parts(a);
    final right = parts(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) {
        return l - r;
      }
    }
    return 0;
  }

  Future<String> _flutterVersion() async {
    final result = await runner.run('flutter', [
      '--version',
    ], workingDirectory: root);
    final firstLine = result.stdout.toString().split('\n').first;
    final parts = firstLine.split(' ');
    return parts.length > 1 ? parts[1] : '未知';
  }
}
