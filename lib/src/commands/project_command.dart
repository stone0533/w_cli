import 'dart:io';

/// `ww project`（原 `lib/sh/project.sh`）。
///
/// 目前只有一个动作：`--update` = `flutter pub upgrade` + 把 Gradle wrapper
/// 指向推荐的 8.0 版本。改成 Dart 后 Windows 也能用（原来依赖 bash）。
class ProjectCommand {
  ProjectCommand({this.root = '.'});

  final String root;

  static const String recommendedGradleVersion = '8.0';

  Future<int> run(List<String> args) async {
    if (args.isEmpty) {
      printHelp();
      return 0;
    }

    var result = 0;
    for (final arg in args) {
      switch (arg) {
        case '--update':
          print('${'=' * 54}\nFlutter 项目管理脚本运行开始\n${'=' * 54}');
          final status = await _update();
          print(
            '${'=' * 54}\nFlutter 项目管理脚本运行结束 '
            '${DateTime.now().toString().substring(0, 19)}\n${'=' * 54}',
          );
          if (status != 0) {
            return status;
          }
          break;
        case '--help':
          printHelp();
          return 0;
        case '--version':
          printVersion();
          return 0;
        default:
          stderr.writeln('未知参数: $arg');
          printHelp(asError: true);
          return 2;
      }
    }
    return result;
  }

  Future<int> _update() async {
    if (!_available('flutter')) {
      stderr.writeln('Flutter 未安装，请先安装 Flutter');
      return 1;
    }

    final flutterVersion = await _flutterVersion();
    stdout.writeln('使用当前 Flutter 版本: $flutterVersion');

    if (!await _updatePub()) {
      return 1;
    }
    if (!await _updateGradle()) {
      return 1;
    }

    stdout.writeln('项目更新完成！');
    return 0;
  }

  Future<bool> _updatePub() async {
    stdout.writeln('正在升级 pub 依赖...');
    if (!File('$root/pubspec.yaml').existsSync()) {
      stderr.writeln('未找到 pubspec.yaml 文件，当前目录可能不是 Flutter 项目');
      return false;
    }

    if (await _run('flutter', ['pub', 'upgrade']) != 0) {
      stderr.writeln('pub 依赖升级失败');
      return false;
    }
    stdout.writeln('pub 依赖升级成功');
    return true;
  }

  Future<bool> _updateGradle() async {
    stdout.writeln('正在升级 Gradle 版本...');

    final androidDir = Directory('$root/android');
    if (!androidDir.existsSync()) {
      stdout.writeln('未找到 android 目录，跳过 Gradle 升级');
      return true;
    }

    final wrapper = File('$root/android/gradle/wrapper/gradle-wrapper.properties');
    if (!wrapper.existsSync()) {
      stderr.writeln('未找到 gradle-wrapper.properties 文件');
      return false;
    }

    final lines = wrapper.readAsLinesSync();
    final current = lines.firstWhere(
      (line) => line.startsWith('distributionUrl='),
      orElse: () => '',
    );
    final currentVersion =
        RegExp(r'gradle-(.*)-all\.zip').firstMatch(current)?.group(1) ?? '未知';
    stdout.writeln('当前 Gradle 版本: $currentVersion');
    stdout.writeln('推荐 Gradle 版本: $recommendedGradleVersion');

    final updated = lines
        .map(
          (line) => line.startsWith('distributionUrl=')
              ? 'distributionUrl=https://services.gradle.org/distributions/'
                  'gradle-$recommendedGradleVersion-all.zip'
              : line,
        )
        .join('\n');
    wrapper.writeAsStringSync(updated.isEmpty ? '$updated\n' : '$updated\n');
    stdout.writeln('Gradle 版本更新成功');
    return true;
  }

  Future<String> _flutterVersion() async {
    final result = await Process.run(
      'flutter',
      ['--version'],
      workingDirectory: root,
      runInShell: true,
    );
    final firstLine = result.stdout.toString().split('\n').first;
    final parts = firstLine.split(' ');
    return parts.length > 1 ? parts[1] : '未知';
  }

  Future<int> _run(String executable, List<String> args) async {
    final process = await Process.start(
      executable,
      args,
      workingDirectory: root,
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  static bool _available(String name) {
    try {
      return Process.runSync('which', [name], runInShell: true).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  void printVersion() {
    print('ww project');
    print('Description: 更新 Flutter 项目的依赖和配置');
  }

  void printHelp({bool asError = false}) {
    final buffer = StringBuffer()
      ..writeln('使用方法: ww project [选项]')
      ..writeln('选项:')
      ..writeln('  --update      # 更新 Flutter 项目依赖和配置')
      ..writeln('  --help        # 显示帮助信息')
      ..writeln('  --version     # 显示版本信息')
      ..writeln('')
      ..writeln('示例:')
      ..writeln('  ww project --update  # 更新项目依赖和配置');
    (asError ? stderr : stdout).write(buffer);
  }
}
