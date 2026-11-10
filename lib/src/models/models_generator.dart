import 'dart:convert';
import 'dart:io';

import '../cli/output.dart';

import '../tools/build_runner.dart';
import 'model_renderer.dart';
import '../cli/process.dart';

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
    this.runner = const SystemProcessRunner(),
  });

  final String root;
  final String jsonDir;
  final String modelsDir;
  final bool force;
  final bool runBuildRunner;

  /// 测试里可以关掉 `dart format`，直接比对渲染结果
  final bool formatOutput;
  final ProcessRunner runner;

  static const String _header =
      '// **************************************************************************\n'
      '// Auto-generated file. Do not edit manually.\n'
      '// **************************************************************************';

  final List<({String temp, String target})> _pending = [];

  /// 同一类诊断只报一次（多份主模型可能触发同一条）。
  final Set<String> _diagnostics = {};

  /// 返回进程退出码：0 成功，1 失败。
  Future<int> generate() async {
    final base = root == '.' ? '' : '$root/';
    final pubspec = File('${base}pubspec.yaml');
    if (!pubspec.existsSync()) {
      Cli.error('文件不存在: ${pubspec.path}');
      return 1;
    }

    if (!await _ensureDependencies(pubspec)) {
      return 1;
    }

    Directory('$base$jsonDir').createSync(recursive: true);
    Directory('$base$modelsDir').createSync(recursive: true);

    final jsonFiles =
        Directory('$base$jsonDir')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    if (jsonFiles.isEmpty) {
      Cli.error('未找到 json 文件: $jsonDir');
      return 1;
    }

    Cli.detail('找到 ${jsonFiles.length} 个 json 文件');
    for (final file in jsonFiles) {
      Cli.detail('  - ${_basename(file.path)}');
    }

    final configFile = File('$base$jsonDir/w_json.config');
    final specs = _parseConfig(configFile, '$base$jsonDir');
    if (specs == null) {
      return 1;
    }
    final samples = _loadSamples(specs);
    if (samples == null) {
      return 1;
    }
    final groups = _groupSamples(samples);
    final standalones = _buildStandalones(groups);

    // 独立类先落盘：主模型的增量检查要靠磁盘上的 mtime
    if (groups.isNotEmpty) {
      Cli.detail('生成配置文件声明的独立类...');
      if (!_generateStandalones(groups, configFile, base, standalones)) {
        return 1;
      }
      if (!await _flush()) {
        return 1;
      }
    }

    final targets = _collectTargets(jsonFiles, configFile, base);
    if (targets == null) {
      return 0; // 全部是最新的
    }

    Cli.detail('开始转换 json 文件为 dart 文件...');
    for (final target in targets) {
      final jsonText = File(target.jsonPath).readAsStringSync();
      Object? data;
      try {
        data = jsonDecode(jsonText);
      } on FormatException catch (error) {
        Cli.error('解析 JSON 失败: ${_basename(target.jsonPath)} ($error)');
        return 1;
      }

      final content = _assembleFile(
        className: '${_cap(target.name)}Result',
        data: data,
        partName: target.dartName,
        standalones: standalones,
        sourceName: _basename(target.jsonPath),
      );
      _enqueue(target.dartPath, content);
    }

    final generatedCount = targets.length;
    if (!await _flush()) {
      return 1;
    }
    Cli.ok('生成 $generatedCount 个模型文件 → $modelsDir');

    if (!_verifyGeneratedModels()) {
      return 1;
    }

    if (runBuildRunner) {
      await _runBuildRunner();
    }

    return 0;
  }

  Future<bool> _ensureDependencies(File pubspec) async {
    final content = pubspec.readAsStringSync();
    const required = {
      'json_annotation': false,
      'json_serializable': true,
      'build_runner': true,
    };

    for (final entry in required.entries) {
      if (content.contains('${entry.key}:')) {
        Cli.detail('${entry.key} 依赖已存在');
        continue;
      }
      Cli.detail('添加 ${entry.key} 依赖...');
      final tool = runner.which('flutter') ? 'flutter' : 'dart';
      final args = ['pub', 'add', if (entry.value) '--dev', entry.key];
      final result = await runner.run(tool, args, workingDirectory: root);
      if (result.exitCode != 0) {
        Cli.error('添加 ${entry.key} 失败，请手动执行: $tool ${args.join(' ')}');
        return false;
      }
    }
    return true;
  }

  /// 配置：`# ClassName` 行声明类名，其下每行 `file.json node.path` 是该类的一份样例。
  ///
  /// 返回 null 表示配置有错（缺类名行、JSON 文件不存在），调用方直接失败，
  /// 不带着坏配置继续跑。
  List<_Spec>? _parseConfig(File config, String jsonDirPath) {
    final specs = <_Spec>[];
    if (!config.existsSync()) {
      Cli.detail('配置文件不存在: ${config.path}，跳过自定义类生成');
      return specs;
    }
    Cli.detail('读取配置文件: ${config.path}');

    var currentClass = '';
    var ok = true;
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
        Cli.error('配置行缺少类名（上一行应为 # ClassName）: $line');
        ok = false;
        continue;
      }

      final path = '$jsonDirPath/$jsonFile';
      if (!File(path).existsSync()) {
        Cli.error('JSON 文件不存在: $path');
        ok = false;
        continue;
      }
      specs.add(_Spec(currentClass, path, node));
    }
    return ok ? specs : null;
  }

  /// 取出每份样例的节点内容（数组取首元素），按 (类名, 文件, 节点) 去重。
  ///
  /// 返回 null 表示有样例取不到节点，调用方直接失败。
  List<_Sample>? _loadSamples(List<_Spec> specs) {
    final seen = <String>{};
    final samples = <_Sample>[];
    var ok = true;

    for (final spec in specs) {
      final id =
          '${spec.className}\u0000${spec.jsonPath}\u0000${spec.nodePath}';
      if (!seen.add(id)) {
        continue;
      }
      final data = _extractNode(spec);
      if (data == null) {
        ok = false;
        continue;
      }
      if (data.isEmpty) {
        // 空对象样例不会贡献形状，但也不该让整个生成失败（老行为允许）。
        Cli.detail(
          '  ~ ${spec.className}: ${_basename(spec.jsonPath)} '
          '${spec.nodePath} 是空对象，不贡献字段',
        );
      }
      samples.add(_Sample(spec, data));
    }
    return ok ? samples : null;
  }

  /// 节点路径必须落到一个对象；落到数组时取首元素（`xxxList.json data.List` 的写法）。
  Map<String, dynamic>? _extractNode(_Spec spec) {
    Object? current;
    try {
      current = jsonDecode(File(spec.jsonPath).readAsStringSync());
    } on FormatException catch (error) {
      Cli.error('解析 JSON 失败: ${_basename(spec.jsonPath)} ($error)');
      return null;
    }

    final walked = <String>[];
    for (final part in spec.nodePath.split('.')) {
      walked.add(part);
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        Cli.error(
          '类 ${spec.className} 的配置行取不到节点: '
          '${_basename(spec.jsonPath)} ${spec.nodePath}'
          '（在 ${walked.join('.')} 处中断）',
        );
        return null;
      }
    }

    if (current is List) {
      if (current.isEmpty) {
        Cli.error(
          '类 ${spec.className} 的样例是空数组，无法推断结构: '
          '${_basename(spec.jsonPath)} ${spec.nodePath}',
        );
        return null;
      }
      final first = current.first;
      if (first is! Map<String, dynamic>) {
        Cli.error(
          '类 ${spec.className} 的样例数组元素不是对象: '
          '${_basename(spec.jsonPath)} ${spec.nodePath}',
        );
        return null;
      }
      Cli.detail(
        '  ~ ${spec.className}: ${_basename(spec.jsonPath)} '
        '${spec.nodePath} 取数组首元素',
      );
      return first;
    }

    if (current is! Map<String, dynamic>) {
      Cli.error(
        '类 ${spec.className} 的样例节点不是对象（是 ${current.runtimeType}）: '
        '${_basename(spec.jsonPath)} ${spec.nodePath}',
      );
      return null;
    }
    return current;
  }

  /// 同类名的多份样例归在一起（保持配置里的出现顺序）。
  Map<String, List<_Sample>> _groupSamples(List<_Sample> samples) {
    final groups = <String, List<_Sample>>{};
    for (final sample in samples) {
      (groups[sample.spec.className] ??= []).add(sample);
    }
    return groups;
  }

  /// 匹配用：每个类登记它**每一份**样例的键集合。
  ///
  /// 列表元素与详情对象只差几个字段时，两边都能命中同一个类。
  List<StandaloneClass> _buildStandalones(Map<String, List<_Sample>> groups) =>
      [
        for (final entry in groups.entries)
          StandaloneClass(entry.key, [
            for (final sample in entry.value) sample.keys,
          ]),
      ];

  bool _generateStandalones(
    Map<String, List<_Sample>> groups,
    File configFile,
    String base,
    List<StandaloneClass> standalones,
  ) {
    final configTime = configFile.existsSync()
        ? configFile.lastModifiedSync()
        : null;

    for (final entry in groups.entries) {
      final className = entry.key;
      final samples = entry.value;
      final dartName = _snakeCase(className);
      final dartPath = '$base$modelsDir/$dartName.dart';
      final dartFile = File(dartPath);

      if (!force && dartFile.existsSync()) {
        var newest = samples.first.jsonTime;
        for (final sample in samples.skip(1)) {
          if (sample.jsonTime.isAfter(newest)) {
            newest = sample.jsonTime;
          }
        }
        if (configTime != null && configTime.isAfter(newest)) {
          newest = configTime;
        }
        if (!newest.isAfter(dartFile.lastModifiedSync())) {
          Cli.detail('  - $dartName.dart (无需更新)');
          continue;
        }
      }

      final merged = _mergeSamples(className, samples);
      if (merged == null) {
        return false;
      }

      _enqueue(
        dartPath,
        _assembleFile(
          className: className,
          data: merged,
          partName: dartName,
          standalones: standalones,
          sourceName: _sampleLabels(samples),
        ),
      );
      Cli.detail('  ~ $dartName.dart (生成/更新)');
    }
    return true;
  }

  String _sampleLabels(List<_Sample> samples) {
    final labels = <String>[];
    for (final sample in samples) {
      final label = _basename(sample.spec.jsonPath);
      if (!labels.contains(label)) {
        labels.add(label);
      }
    }
    return labels.join(' + ');
  }

  /// 把同一个类名下的多份样例合并成一个节点。
  ///
  /// 键取并集：第一份样例的键序优先，后面样例的新键按出现顺序追加——样例一致
  /// 时合并结果与单份完全相同，产物逐字节不变。类型冲突直接失败，不猜。
  Map<String, dynamic>? _mergeSamples(String className, List<_Sample> samples) {
    final conflicts = <String>[];
    final merged = _mergeObjectMaps(
      samples: [
        for (final sample in samples)
          (file: _basename(sample.spec.jsonPath), value: sample.data),
      ],
      path: '',
      conflicts: conflicts,
    );
    if (conflicts.isEmpty) {
      return merged;
    }

    Cli.error('独立类 $className 的样例无法合并，已放弃生成：');
    for (final conflict in conflicts) {
      Cli.error('  - $conflict');
    }
    Cli.error('  请统一 w_json.config 里 $className 各样例的字段类型');
    return null;
  }

  Map<String, dynamic> _mergeObjectMaps({
    required List<({String file, Map<String, dynamic> value})> samples,
    required String path,
    required List<String> conflicts,
  }) {
    final keys = <String>[];
    final seen = <String>{};
    for (final sample in samples) {
      for (final key in sample.value.keys) {
        if (seen.add(key)) {
          keys.add(key);
        }
      }
    }

    final merged = <String, dynamic>{};
    for (final key in keys) {
      final entries = <({String file, Object? value})>[
        for (final sample in samples)
          if (sample.value.containsKey(key))
            (file: sample.file, value: sample.value[key]),
      ];
      merged[key] = _mergeValues(
        path: path.isEmpty ? key : '$path.$key',
        entries: entries,
        conflicts: conflicts,
      );
    }
    return merged;
  }

  Object? _mergeValues({
    required String path,
    required List<({String file, Object? value})> entries,
    required List<String> conflicts,
  }) {
    final nonNull = entries.where((entry) => entry.value != null).toList();
    if (nonNull.isEmpty) {
      return null;
    }

    final objects = nonNull
        .where((entry) => entry.value is Map<String, dynamic>)
        .toList();
    if (objects.length == nonNull.length) {
      return _mergeObjectMaps(
        samples: [
          for (final entry in objects)
            (file: entry.file, value: entry.value as Map<String, dynamic>),
        ],
        path: path,
        conflicts: conflicts,
      );
    }

    final lists = nonNull.where((entry) => entry.value is List).toList();
    if (lists.length == nonNull.length) {
      return _mergeLists(path: path, entries: lists, conflicts: conflicts);
    }

    if (_hasTypeConflict(nonNull)) {
      conflicts.add('$path 的字段类型不一致（${_describeTypes(nonNull)}）');
      return null;
    }
    return nonNull.first.value;
  }

  Object? _mergeLists({
    required String path,
    required List<({String file, Object? value})> entries,
    required List<String> conflicts,
  }) {
    // 渲染只看首元素，合并也只合并首元素；样例里的空数组不贡献结构。
    final objects = <({String file, Map<String, dynamic> value})>[];
    final others = <({String file, Object? value})>[];
    for (final entry in entries) {
      final list = entry.value as List;
      if (list.isEmpty) {
        continue;
      }
      final first = list.first;
      if (first is Map<String, dynamic>) {
        objects.add((file: entry.file, value: first));
      } else {
        others.add((file: entry.file, value: first));
      }
    }

    if (objects.isNotEmpty && others.isNotEmpty) {
      conflicts.add('$path 的元素在不同样例里一个是对象、一个是标量');
      return null;
    }

    if (objects.isNotEmpty) {
      return [
        _mergeObjectMaps(
          samples: objects,
          path: '$path[0]',
          conflicts: conflicts,
        ),
      ];
    }

    if (others.isNotEmpty) {
      if (_hasTypeConflict(others)) {
        conflicts.add('$path 的元素类型不一致（${_describeTypes(others)}）');
        return null;
      }
      return [others.first.value];
    }

    return <dynamic>[];
  }

  static bool _hasTypeConflict(List<({String file, Object? value})> entries) {
    final categories = <String>{};
    for (final entry in entries) {
      categories.add(_category(entry.value));
    }
    return categories.length > 1;
  }

  static String _describeTypes(List<({String file, Object? value})> entries) {
    final seen = <String>{};
    final parts = <String>[];
    for (final entry in entries) {
      final category = _category(entry.value);
      if (!seen.add('${entry.file}:$category')) {
        continue;
      }
      parts.add('${entry.file} 是 $category');
    }
    return parts.join('、');
  }

  static String _category(Object? value) {
    if (value is Map) {
      return 'object';
    }
    if (value is List) {
      return 'array';
    }
    if (value is bool) {
      return 'bool';
    }
    if (value is num) {
      return 'number';
    }
    if (value is String) {
      return 'string';
    }
    return 'unknown';
  }

  /// 增量判断；返回 null 表示全部最新。
  List<({String jsonPath, String dartPath, String dartName, String name})>?
  _collectTargets(List<File> jsonFiles, File configFile, String base) {
    final configTime = configFile.existsSync()
        ? configFile.lastModifiedSync()
        : null;
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

    final all =
        <({String jsonPath, String dartPath, String dartName, String name})>[];
    final changed =
        <({String jsonPath, String dartPath, String dartName, String name})>[];

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
        Cli.detail('  + $name.json -> $dartName.dart (新建)');
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
        Cli.detail('  ~ $name.json -> $dartName.dart (已更新)');
        changed.add(entry);
      } else {
        Cli.detail('  - $name.json -> $dartName.dart (无需更新)');
      }
    }

    if (force) {
      Cli.detail('全量模式: 重新生成所有 ${all.length} 个文件...');
      return all;
    }

    if (changed.isEmpty) {
      Cli.ok('所有模型文件都是最新的，无需重新生成');
      return null;
    }

    Cli.detail('需要更新 ${changed.length} 个文件');
    return changed;
  }

  String _assembleFile({
    required String className,
    required Object? data,
    required String partName,
    required List<StandaloneClass> standalones,
    required String sourceName,
  }) {
    final modelContent = renderModelClasses(
      className,
      data,
      standalones,
      sourceName: sourceName,
      onDiagnostic: _reportDiagnostic,
    ).join('\n\n');

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

  /// 渲染期诊断（例如"差点命中独立类"）走这里，默认可见、同一句只报一次。
  void _reportDiagnostic(String message) {
    if (_diagnostics.add(message)) {
      Cli.warn(message);
    }
  }

  /// 一次 format 校验全部临时文件，全合法才落盘。
  Future<bool> _flush() async {
    if (_pending.isEmpty) {
      return true;
    }

    if (formatOutput && runner.which('dart')) {
      Cli.detail('校验生成的代码...');
      final result = await runner.run('dart', [
        'format',
        ..._pending.map((entry) => entry.temp),
      ]);
      if (result.exitCode != 0) {
        for (final entry in _pending) {
          File(entry.temp).deleteSync();
        }
        _pending.clear();
        Cli.error('生成的模型不是合法 Dart，已放弃写入（原有文件未改动）');
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
      Cli.error('生成的模型文件自检未通过：');
      for (final problem in problems) {
        Cli.error(problem);
      }
      return false;
    }

    Cli.detail('生成自检通过：无重复 import / 无重复 class');
    return true;
  }

  Future<void> _runBuildRunner() async {
    Cli.detail('执行 build_runner build...');
    final status = await BuildRunner(root: root).run();
    if (status != 0) {
      Cli.error('build_runner build 失败（退出码 $status）');
      return;
    }
    Cli.detail('build_runner build 执行完成');
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

/// `w_json.config` 里的一行：`# ClassName` 之下的一份样例。
class _Spec {
  const _Spec(this.className, this.jsonPath, this.nodePath);

  final String className;
  final String jsonPath;
  final String nodePath;
}

/// 样例取出来的节点内容（数组已取首元素）。
class _Sample {
  _Sample(this.spec, this.data);

  final _Spec spec;
  final Map<String, dynamic> data;

  List<String> get keys => data.keys.toList()..sort();

  DateTime get jsonTime => File(spec.jsonPath).lastModifiedSync();
}
