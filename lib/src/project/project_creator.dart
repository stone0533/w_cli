import 'dart:io';

import '../api/scaffolder.dart';
import '../tools/build_runner.dart';
import 'project_scaffolder.dart';
import 'pubspec_editor.dart';

/// `ww create project <name>` 的完整实现（ADR-0002：`lib/sh/setup.sh` 的最后一块）。
///
/// 步骤与旧脚本一一对应：检查 → flutter create → 依赖 → 目录 → w_tools 分包 →
/// 写文件（[ProjectScaffolder] / [ApiScaffolder]）→ build_runner → 格式化 →
/// analysis_options → git → 健康检查 → 打开项目。
///
/// 与 shell 版本的差异（都是修 bug，不是改行为）：
/// - assets 配置的兜底路径不再用 `sed -i ''`（只在 macOS 有效），改在 Dart 里重写
/// - 失败清理只在「本次创建了目录」时执行
class ProjectCreator {
  ProjectCreator({
    required this.name,
    this.force = false,
    this.apiBaseUrl = 'https://api.example.com',
    this.runBuildRunner = true,
    this.openAfterCreate = true,
  });

  final String name;
  final bool force;
  final String apiBaseUrl;
  final bool runBuildRunner;
  final bool openAfterCreate;

  static const String _org = 'com.sampras';
  static const List<String> _wToolsSubpackages = [
    'core',
    'app',
    'form',
    'ui',
    'api',
    'toast',
    'qr',
  ];

  static const List<String> _directories = [
    'assets/fonts',
    'assets/images',
    'lib/app/components',
    'lib/app/utils',
    'lib/app/services',
    'lib/app/data/models',
    'lib/app/data/sources',
    'lib/app/data/sources/remote',
    'test',
    '.github/workflows',
    'w_json',
  ];

  bool _createdByUs = false;

  Future<int> run() async {
    if (name.isEmpty) {
      stderr.writeln('项目名称为空');
      return 2;
    }

    final status = await _runSteps();
    if (status != 0 && _createdByUs) {
      stdout.writeln('清理本次创建的目录: $name');
      final dir = Directory(name);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
    return status;
  }

  Future<int> _runSteps() async {
    if (!_available('flutter')) {
      stderr.writeln('Flutter 未安装或未添加到 PATH');
      return 1;
    }
    stdout.writeln('Flutter 已安装');

    if (Directory(name).existsSync()) {
      if (!force) {
        stderr.writeln('目标目录已存在: $name（如需覆盖请加 --force）');
        return 1;
      }
      stdout.writeln('目标目录已存在，--force 已启用，将覆盖: $name');
      Directory(name).deleteSync(recursive: true);
    }

    print('=${'=' * 53}\nFlutter 项目初始化脚本运行开始\n${'=' * 54}');

    // 1. flutter create
    _createdByUs = true;
    stdout.writeln('使用 flutter create 创建项目...');
    final createCode = await _runDirect(
      'flutter',
      // `-i swift` 已废弃（Swift 是唯一选项），带上只会多一条 deprecation 警告
      ['create', '--org', _org, '-a', 'kotlin', name],
    );
    if (createCode != 0) {
      stderr.writeln('flutter create 失败（退出码 $createCode）');
      return 1;
    }
    stdout.writeln('项目创建完成');

    // 2. 依赖
    if (!await _installDependencies()) {
      return 1;
    }

    // 3. 目录
    stdout.writeln('创建目录结构...');
    for (final dir in _directories) {
      Directory('$name/$dir').createSync(recursive: true);
    }
    stdout.writeln('目录结构创建完成');

    // 4. w_tools 分包 + assets
    if (!await _addWToolsDependencies()) {
      return 1;
    }

    // 5. w_tools 接入骨架（不可用时由 ProjectScaffolder 兜底写 toolkit）
    stdout.writeln('生成 w_tools 接入骨架...');
    final wToolsCode =
        await _runInProject('dart', ['run', 'w_tools_cli:init']);
    if (wToolsCode == 0) {
      stdout.writeln('已通过 w_tools_cli:init 生成接入骨架');
    } else {
      stdout.writeln('w_tools_cli:init 不可用，改为写入最小可用的聚合入口');
    }

    // 6. 工程文件（main / home / routes / CI / .env / toolkit）
    stdout.writeln('创建核心文件...');
    ProjectScaffolder(root: name, apiBaseUrl: apiBaseUrl).run();

    // 7. API 层
    stdout.writeln('生成 API 层...');
    final apiStatus = ApiScaffolder(root: name).run();
    if (apiStatus != 0) {
      return apiStatus;
    }

    // 8. build_runner
    if (runBuildRunner) {
      final buildStatus = await BuildRunner(root: name).run();
      if (buildStatus != 0) {
        return buildStatus;
      }
    }

    // 9. 格式化 + analysis_options
    await _runInProject('dart', ['format', '.']);
    stdout.writeln('代码格式化完成');
    _updateAnalysisOptions();

    // 10. git
    await _initializeGit();

    // 11. 健康检查
    _healthCheck();

    print('=${'=' * 53}\nFlutter 项目初始化脚本运行结束\n${'=' * 54}');
    stdout.writeln('项目已成功初始化: $name');

    if (openAfterCreate) {
      _openProject();
    }
    return 0;
  }

  Future<bool> _installDependencies() async {
    stdout.writeln('安装项目依赖包...');
    if (!File('$name/pubspec.yaml').existsSync()) {
      stderr.writeln('pubspec.yaml 文件不存在，请先创建项目');
      return false;
    }

    final groups = <List<String>>[
      [
        'pub', 'add', 'get', 'dio', 'flutter_screenutil', 'flutter_form_builder',
        'form_builder_validators', 'json_annotation:^4.9.0',
      ],
      ['pub', 'add', 'retrofit:4.9.0'],
      [
        'pub', 'add', '--dev', 'build_runner', 'json_serializable',
        'retrofit_generator:^9.7.0', 'w_tools_cli',
      ],
    ];

    for (final args in groups) {
      final code = await _runInProject('flutter', args);
      if (code != 0) {
        stderr.writeln('依赖安装失败: flutter ${args.join(' ')}');
        return false;
      }
    }

    stdout.writeln('依赖包安装完成');
    return true;
  }

  Future<bool> _addWToolsDependencies() async {
    stdout.writeln('配置 w_tools 分包依赖...');

    for (final pkg in _wToolsSubpackages) {
      final code = await _runInProject(
        'flutter',
        ['pub', 'add', 'w_tools_$pkg:^1.0.0'],
      );
      if (code != 0) {
        stderr.writeln('添加依赖失败: w_tools_$pkg');
        return false;
      }
    }

    final cliCode =
        await _runInProject('flutter', ['pub', 'add', '--dev', 'w_tools_cli']);
    if (cliCode != 0) {
      stdout.writeln('添加 w_tools_cli 失败（不影响编译，但缺少 doctor）');
    }

    _ensureAssetsConfig();
    stdout.writeln('w_tools 分包依赖配置完成（未包含 w_tools_map）');
    return true;
  }

  /// 在 `flutter:` 配置段里补 assets（纯函数在 pubspec_editor.dart，便于单测）。
  void _ensureAssetsConfig() {
    final pubspec = File('$name/pubspec.yaml');
    if (!pubspec.existsSync()) {
      return;
    }
    final updated = ensureAssets(pubspec.readAsStringSync());
    if (updated != pubspec.readAsStringSync()) {
      pubspec.writeAsStringSync(updated);
      stdout.writeln('已补充 assets 配置');
    }
  }

  void _updateAnalysisOptions() {
    final file = File('$name/analysis_options.yaml');
    if (!file.existsSync()) {
      stderr.writeln('analysis_options.yaml 文件不存在');
      return;
    }

    final content = file.readAsStringSync();
    if (content.contains('analyzer:')) {
      stdout.writeln('analyzer 配置已存在，跳过');
      return;
    }

    const anchor = 'include: package:flutter_lints/flutter.yaml';
    if (!content.contains(anchor)) {
      stdout.writeln('未找到 flutter_lints 的 include，跳过 analyzer 配置');
      return;
    }

    final updated = content.replaceFirst(
      anchor,
      '$anchor\n\n'
      'analyzer:\n'
      '  exclude:\n'
      '    - "lib/app/routes/app_routes.dart"  '
      '# Exclude auto-generated routes file to avoid naming convention warnings',
    );
    file.writeAsStringSync(updated);
    stdout.writeln('已添加 analyzer 配置到 analysis_options.yaml');
  }

  Future<void> _initializeGit() async {
    if (!Directory(name).existsSync()) {
      return;
    }
    stdout.writeln('初始化 Git 仓库...');
    await _runInProject('git', ['init']);

    final gitignore = File('$name/.gitignore');
    if (!gitignore.existsSync()) {
      gitignore.writeAsStringSync('');
    }
    if (!gitignore.readAsStringSync().contains('w_build/')) {
      gitignore.writeAsStringSync('${gitignore.readAsStringSync()}w_build/\n');
    }

    await _runInProject('git', ['add', '.']);
    await _runInProject('git', ['commit', '-m', 'Initial commit']);
    stdout.writeln('Git 仓库初始化完成');
  }

  void _healthCheck() {
    stdout.writeln('执行项目健康检查...');

    if (File('$name/pubspec.yaml').existsSync()) {
      stdout.writeln('✓ pubspec.yaml 存在');
    } else {
      stderr.writeln('✗ pubspec.yaml 不存在');
    }

    for (final dir in _directories) {
      if (Directory('$name/$dir').existsSync()) {
        stdout.writeln('✓ $dir 目录存在');
      } else {
        stderr.writeln('✗ $dir 目录不存在');
      }
    }

    stdout.writeln('项目健康检查完成');
  }

  void _openProject() {
    if (!Directory(name).existsSync()) {
      return;
    }
    if (_available('trae')) {
      stdout.writeln('使用 trae 打开项目');
      Process.runSync('trae', [name], runInShell: true);
    } else if (_available('studio')) {
      stdout.writeln('使用 Android Studio 打开项目');
      Process.runSync('studio', [name], runInShell: true);
    } else {
      stdout.writeln('未找到 trae / studio，跳过打开项目');
    }
  }

  Future<int> _runInProject(String executable, List<String> args) {
    return _runDirect(executable, args, workingDirectory: name);
  }

  Future<int> _runDirect(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      args,
      workingDirectory: workingDirectory,
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
}
