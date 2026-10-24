import 'dart:convert';
import 'dart:io';

import 'model_renderer.dart';

/// `ww api models` 的 Dart 实现（ADR-0002 Phase 3）。
///
/// 与迁移前的 `api.sh models`（已删除，见 ADR-0002）一一对应：依赖检查、独立类、增量判断、批量落盘、
/// 重复 import/class 自检、build_runner。产物必须与 shell 版本逐字节一致
/// （`test/fixtures/models/raw/` 是闸门）。
class ModelsGenerator {
  ModelsGenerator({
    this.root = '.',
    this.jsonDir = 'w_json',
    this.modelsDir = 'lib/app/data/models',
    this.force = false,
    this.runBuildRunner = true,
    this.formatOutput = true,
  });

  final String root;
  final String jsonDir;
  final String modelsDir;
  final bool force;
  final bool runBuildRunner;

  /// 测试里可以关掉 `dart format`，直接比对渲染结果
  final bool formatOutput;

  static const String _header = '// **************************************************************************\n'
      '// Auto-generated file. Do not edit manually.\n'
      '// **************************************************************************';

  final List<({String temp, String target})> _pending = [];

  /// 返回进程退出码：0 成功，1 失败。
  Future<int> generate() async {
    final base = root == '.' ? '' : '$root/';
    final pubspec = File('${base}pubspec.yaml');
    if (!pubspec.existsSync()) {
      stderr.writeln('文件不存在: ${pubspec.path}');
      return 1;
    }

    if (!_ensureDependencies(pubspec)) {
      return 1;
    }

    Directory('$base$jsonDir').createSync(recursive: true);
    Directory('$base$modelsDir').createSync(recursive: true);

    final jsonFiles = Directory('$base$jsonDir')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (jsonFiles.isEmpty) {
      stderr.writeln('未找到 json 文件: $jsonDir');
      return 1;
    }

    stdout.writeln('找到 ${jsonFiles.length} 个 json 文件:');
    for (final file in jsonFiles) {
      stdout.writeln('  - ${_basename(file.path)}');
    }

    final configFile = File('$base$jsonDir/w_json.config');
    final specs = _parseConfig(configFile, '$base$jsonDir');
    final standalones = _loadStandalones(specs);

    // 独立类先落盘：主模型的增量检查要靠磁盘上的 mtime
    if (specs.isNotEmpty) {
      stdout.writeln('生成配置文件声明的独立类...');
      if (!_generateStandalones(specs, standalones, configFile, base)) {
        return 1;
      }
      if (!_flush()) {
        return 1;
      }
    }

    final targets = _collectTargets(jsonFiles, configFile, base);
    if (targets == null) {
      return 0; // 全部是最新的
    }

    stdout.writeln('开始转换 json 文件为 dart 文件...');
    for (final target in targets) {
      final jsonText = File(target.jsonPath).readAsStringSync();
      Object? data;
      try {
        data = jsonDecode(jsonText);
      } on FormatException catch (error) {
        stderr.writeln('解析 JSON 失败: ${_basename(target.jsonPath)} ($error)');
        return 1;
      }

      final content = _assembleFile(
        className: '${_cap(target.name)}Result',
        data: data,
        partName: target.dartName,
        standalones: standalones,
      );
      _enqueue(target.dartPath, content);
    }

    if (!_flush()) {
      return 1;
    }

    if (!_verifyGeneratedModels()) {
      return 1;
    }

    if (runBuildRunner) {
      _runBuildRunner();
    }

    stdout.writeln('✅ 模型文件生成完成！');
    return 0;
  }

  bool _ensureDependencies(File pubspec) {
    final content = pubspec.readAsStringSync();
    const required = {
      'json_annotation': false,
      'json_serializable': true,
      'build_runner': true,
    };

    for (final entry in required.entries) {
      if (content.contains('${entry.key}:')) {
        stdout.writeln('${entry.key} 依赖已存在');
        continue;
      }
      stdout.writeln('添加 ${entry.key} 依赖...');
      final tool = _commandAvailable('flutter') ? 'flutter' : 'dart';
      final args = ['pub', 'add', if (entry.value) '--dev', entry.key];
      final result = Process.runSync(
        tool,
        args,
        workingDirectory: root,
        runInShell: true,
      );
      if (result.exitCode != 0) {
        stderr.writeln('添加 ${entry.key} 失败，请手动执行: $tool ${args.join(' ')}');
        return false;
      }
    }
    return true;
  }

  bool _commandAvailable(String name) {
    try {
      return Process.runSync('which', [name], runInShell: true).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// 配置：`# ClassName` 行声明类名，下一行 `file.json node.path` 声明来源
  List<({String className, String jsonPath, String node})> _parseConfig(
    File config,
    String jsonDirPath,
  ) {
    final specs = <({String className, String jsonPath, String node})>[];
    if (!config.existsSync()) {
      stdout.writeln('配置文件不存在: ${config.path}，跳过自定义类生成');
      return specs;
    }
    stdout.writeln('读取配置文件: ${config.path}');

    var currentClass = '';
    for (final line in config.readAsLinesSync()) {
      if (line.trim().isEmpty) {
        continue;
      }
      final singleLine = line.trimLeft();
      if (singleLine.startsWith('#')) {
        currentClass = singleLine.substring(1).trim();
        continue;
      }

      final match = RegExp(r'^(\S+)\s+(.+)$').firstMatch(line);
      if (match == null) {
        continue;
      }
      final jsonFile = match.group(1)!;
      final node = match.group(2)!;
      if (currentClass.isEmpty) {
        stderr.writeln('跳过配置行，缺少类名: $line');
        continue;
      }

      final path = '$jsonDirPath/$jsonFile';
      if (!File(path).existsSync()) {
        stderr.writeln('JSON 文件不存在: $path');
        continue;
      }
      specs.add((className: currentClass, jsonPath: path, node: node));
    }
    return specs;
  }

  List<StandaloneClass> _loadStandalones(
    List<({String className, String jsonPath, String node})> specs,
  ) {
    final loaded = <StandaloneClass>[];
    for (final spec in specs) {
      final node = _extractNode(spec.jsonPath, spec.node);
      if (node == null) {
        continue;
      }
      loaded.add(StandaloneClass(spec.className, node.keys.toList()..sort()));
    }
    return loaded;
  }

  Map<String, dynamic>? _extractNode(String jsonPath, String nodePath) {
    Object? current;
    try {
      current = jsonDecode(File(jsonPath).readAsStringSync());
    } on FormatException {
      return null;
    }
    for (final part in nodePath.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current is Map<String, dynamic> ? current : null;
  }

  bool _generateStandalones(
    List<({String className, String jsonPath, String node})> specs,
    List<StandaloneClass> standalones,
    File configFile,
    String base,
  ) {
    final seen = <String>{};

    for (final spec in specs) {
      if (!seen.add(spec.className)) {
        continue;
      }
      final dartName = _snakeCase(spec.className);
      final dartPath = '$base$modelsDir/$dartName.dart';
      final dartFile = File(dartPath);

      if (!force && dartFile.existsSync()) {
        final jsonTime = File(spec.jsonPath).lastModifiedSync();
        final configTime =
            configFile.existsSync() ? configFile.lastModifiedSync() : jsonTime;
        final dartTime = dartFile.lastModifiedSync();
        if (!jsonTime.isAfter(dartTime) && !configTime.isAfter(dartTime)) {
          stdout.writeln('  - $dartName.dart (无需更新)');
          continue;
        }
      }

      final node = _extractNode(spec.jsonPath, spec.node);
      if (node == null) {
        stderr.writeln('无法提取节点内容: ${spec.node}');
        continue;
      }

      _enqueue(
        dartPath,
        _assembleFile(
          className: spec.className,
          data: node,
          partName: dartName,
          standalones: standalones,
        ),
      );
      stdout.writeln('  ~ $dartName.dart (生成/更新)');
    }
    return true;
  }

  /// 增量判断；返回 null 表示全部最新。
  List<({String jsonPath, String dartPath, String dartName, String name})>?
      _collectTargets(
    List<File> jsonFiles,
    File configFile,
    String base,
  ) {
    final configTime =
        configFile.existsSync() ? configFile.lastModifiedSync() : null;
    final referenced = <String>{};

    // 配置里引用过的 json：配置比产物新时也要重生成
    if (configFile.existsSync()) {
      for (final line in configFile.readAsLinesSync()) {
        final match = RegExp(r'^(\S+\.json)\s+').firstMatch(line);
        if (match != null) {
          referenced.add(match.group(1)!);
        }
      }
    }

    final all = <({String jsonPath, String dartPath, String dartName, String name})>[];
    final changed = <({String jsonPath, String dartPath, String dartName, String name})>[];

    for (final file in jsonFiles) {
      final name = _basename(file.path).replaceFirst(RegExp(r'\.json$'), '');
      final dartName = _snakeCase(name);
      final entry = (
        jsonPath: file.path,
        dartPath: '$base$modelsDir/$dartName.dart',
        dartName: dartName,
        name: name,
      );
      all.add(entry);

      if (force) {
        changed.add(entry);
        continue;
      }

      final dartFile = File(entry.dartPath);
      if (!dartFile.existsSync()) {
        stdout.writeln('  + $name.json -> $dartName.dart (新建)');
        changed.add(entry);
        continue;
      }

      final jsonTime = file.lastModifiedSync();
      final dartTime = dartFile.lastModifiedSync();
      var needUpdate = jsonTime.isAfter(dartTime);

      if (!needUpdate &&
          configTime != null &&
          referenced.contains('$name.json') &&
          configTime.isAfter(dartTime)) {
        needUpdate = true;
      }

      if (needUpdate) {
        stdout.writeln('  ~ $name.json -> $dartName.dart (已更新)');
        changed.add(entry);
      } else {
        stdout.writeln('  - $name.json -> $dartName.dart (无需更新)');
      }
    }

    if (force) {
      stdout.writeln('全量模式: 重新生成所有 ${all.length} 个文件...');
      return all;
    }

    if (changed.isEmpty) {
      stdout.writeln('✅ 所有模型文件都是最新的，无需重新生成');
      return null;
    }

    stdout.writeln('需要更新 ${changed.length} 个文件');
    return changed;
  }

  String _assembleFile({
    required String className,
    required Object? data,
    required String partName,
    required List<StandaloneClass> standalones,
  }) {
    final modelContent =
        renderModelClasses(className, data, standalones).join('\n\n');

    final buffer = StringBuffer()
      ..write('$_header\n\n')
      ..write("import 'package:json_annotation/json_annotation.dart';\n\n");

    // 独立类互相引用时补 import（排除自身，按配置顺序去重）
    final emitted = <String>{};
    for (final standalone in standalones) {
      if (standalone.name == className || !emitted.add(standalone.name)) {
        continue;
      }
      final pattern = RegExp(
        '(^|[^A-Za-z0-9_])${RegExp.escape(standalone.name)}([^A-Za-z0-9_]|\$)',
      );
      if (pattern.hasMatch(modelContent)) {
        buffer.write("import './${_snakeCase(standalone.name)}.dart';\n");
      }
    }

    buffer
      ..write("part '$partName.g.dart';\n\n")
      ..write(modelContent);

    return buffer.toString();
  }

  void _enqueue(String target, String content) {
    final temp = File('$target.tmp.$pid');
    temp.parent.createSync(recursive: true);
    temp.writeAsStringSync(content);
    _pending.add((temp: temp.path, target: target));
  }

  /// 一次 format 校验全部临时文件，全合法才落盘。
  bool _flush() {
    if (_pending.isEmpty) {
      return true;
    }

    if (formatOutput && _commandAvailable('dart')) {
      stdout.writeln('校验生成的代码...');
      final result = Process.runSync(
        'dart',
        ['format', ..._pending.map((entry) => entry.temp)],
        runInShell: true,
      );
      if (result.exitCode != 0) {
        for (final entry in _pending) {
          File(entry.temp).deleteSync();
        }
        _pending.clear();
        stderr.writeln('生成的模型不是合法 Dart，已放弃写入（原有文件未改动）');
        return false;
      }
    }

    for (final entry in _pending) {
      File(entry.temp).renameSync(entry.target);
    }
    _pending.clear();
    return true;
  }

  /// 自检：同一文件内重复 import / 重复 class 都是生成器的 bug
  bool _verifyGeneratedModels() {
    final dir = Directory('${root == '.' ? '' : '$root/'}$modelsDir');
    if (!dir.existsSync()) {
      return true;
    }

    final problems = <String>[];
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      final imports = <String>{};
      final classes = <String>{};
      for (final line in file.readAsLinesSync()) {
        if (line.startsWith('import ')) {
          if (!imports.add(line)) {
            problems.add('${file.path}: 重复 import → $line');
          }
        } else if (line.startsWith('class ')) {
          final name = line.split(' ').elementAtOrNull(1);
          if (name != null && !classes.add(name)) {
            problems.add('${file.path}: 重复 class → $name');
          }
        }
      }
    }

    if (problems.isNotEmpty) {
      stderr.writeln('生成的模型文件自检未通过：');
      for (final problem in problems) {
        stderr.writeln(problem);
      }
      return false;
    }

    stdout.writeln('生成自检通过：无重复 import / 无重复 class');
    return true;
  }

  void _runBuildRunner() {
    stdout.writeln('执行 build_runner build...');
    final tool = _commandAvailable('dart') ? 'dart' : 'flutter';
    final result = Process.runSync(
      tool,
      ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      workingDirectory: root,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      stderr.writeln('build_runner build 失败（退出码 ${result.exitCode}）');
      return;
    }
    stdout.writeln('build_runner build 执行完成');
  }

  static String _basename(String path) => path.split('/').last;

  static String _cap(String name) =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

  /// 驼峰 → 蛇形，与迁移前 `api.sh` 的 snake_name 一致
  static String _snakeCase(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (isUpper && i > 0) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }
}
