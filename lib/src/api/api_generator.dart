import 'dart:io';

import 'client_parser.dart';
import 'generated_file_guard.dart';
import 'client_renderer.dart';
import 'project_imports.dart';
import '../cli/output.dart';

/// 生成 `data_source_mixin.dart` 与 `repository.dart`。
///
/// 取代 `api.sh` 里用 shell 正则做的那一套：解析走 [parseApiClient]，
/// 渲染走 [renderRemoteDataSource] / [renderRepository]，这里只负责 I/O。
class ApiGenerator {
  ApiGenerator({
    this.clientPath = 'lib/app/data/sources/client.dart',
    this.dataSourcePath = 'lib/app/data/sources/remote/data_source.dart',
    this.mixinPath = 'lib/app/data/sources/remote/data_source_mixin.dart',
    this.repositoryPath = 'lib/app/data/sources/repository.dart',
    this.modelsDir = 'lib/app/data/models',
    DateTime? now,
  }) : _now = now;

  final String clientPath;
  final String dataSourcePath;
  final String mixinPath;
  final String repositoryPath;
  final String modelsDir;
  final DateTime? _now;

  /// 返回进程退出码：0 成功，1 失败。
  ///
  /// [force] 为 true 时忽略「检测到手写成员」的保护，直接覆盖。
  Future<int> generate({bool force = false}) async {
    final clientFile = File(clientPath);
    if (!clientFile.existsSync()) {
      Cli.error('文件不存在: $clientPath');
      return 1;
    }

    final List<ApiMethod> methods;
    try {
      methods = parseApiClient(clientFile.readAsStringSync());
    } on ApiParseException catch (error) {
      Cli.error('解析 $clientPath 失败：$error');
      return 1;
    }

    if (methods.isEmpty) {
      Cli.error('未解析到任何 API 方法：$clientPath');
      return 1;
    }

    Cli.detail('解析到 ${methods.length} 个 API 方法：');
    for (final method in methods) {
      Cli.detail('  - ${method.name} -> ${method.returnType}');
    }

    final modelFiles = _modelFilesFor(methods);
    final existing = _existingMethods();
    final header = renderHeader(_timestamp());

    final mixin = renderRemoteDataSource(
      header: header,
      methods: methods,
      existingMethods: existing,
      modelFiles: modelFiles,
    );
    final repository = renderRepository(
      header: header,
      methods: methods,
      modelFiles: modelFiles,
      // 探测本项目的 w_tools 入口：项目切到子包后 meta 包不在依赖里，
      // 写死会导致生成的 repository.dart 编译不过。
      wtoolsImport: resolveWtoolsImport(),
    );

    if (!force) {
      final blocked = _handwritten(<String, String>{
        mixinPath: mixin,
        repositoryPath: repository,
      });
      if (blocked.isNotEmpty) {
        _reportHandwritten(blocked);
        return 1;
      }
    }

    _writeAtomically(mixinPath, mixin);
    _writeAtomically(repositoryPath, repository);

    Cli.detail('已更新: $mixinPath');
    Cli.detail('已更新: $repositoryPath');
    return 0;
  }

  /// 生成器不认识的成员（= 手写内容）；返回 路径 -> 成员名。
  Map<String, Set<String>> _handwritten(Map<String, String> generated) {
    final blocked = <String, Set<String>>{};

    for (final entry in generated.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) {
        continue;
      }

      final added = handwrittenMembers(
        existingContent: file.readAsStringSync(),
        generatedContent: entry.value,
      );
      if (added.isNotEmpty) {
        blocked[entry.key] = added;
      }
    }

    return blocked;
  }

  void _reportHandwritten(Map<String, Set<String>> blocked) {
    Cli.error('检测到手写成员，已拒绝覆盖（确认要覆盖请加 --force）：');
    for (final entry in blocked.entries) {
      Cli.error('  ${entry.key}: ${entry.value.join(', ')}');
    }
    Cli.error('建议把业务方法放进扩展（extension），或先备份再 --force 覆盖。');
  }

  Set<String> _existingMethods() {
    final file = File(dataSourcePath);
    if (!file.existsSync()) {
      return const {};
    }
    return extractFutureMethodNames(file.readAsStringSync());
  }

  List<String> _modelFilesFor(List<ApiMethod> methods) {
    final files = <String>[];

    for (final method in methods) {
      var type = method.returnType;

      // List<T> 用 T 去找模型文件
      final listMatch = RegExp(r'^List<(.+)>$').firstMatch(type);
      if (listMatch != null) {
        type = listMatch.group(1)!;
      }

      if (_isBasicType(type) || type.contains('<') || type.contains('>')) {
        continue;
      }

      final file = _findModelFile(type);
      if (file != null && !files.contains(file)) {
        files.add(file);
      }
    }

    return files;
  }

  /// 模型类名 -> 模型文件名。与 `api.sh` 的 `to_snake_case` 行为一致：
  /// 先试 `<snake>_result.dart`，再试 `<snake>.dart`，最后按内容里的 `class` 声明找。
  String? _findModelFile(String className) {
    final base = className.replaceFirst(RegExp(r'Result$'), '');
    final snake = snakeCase(base);

    for (final candidate in ['${snake}_result.dart', '$snake.dart']) {
      if (File('$modelsDir/$candidate').existsSync()) {
        return candidate;
      }
    }

    final dir = Directory(modelsDir);
    if (!dir.existsSync()) {
      return null;
    }

    final pattern = RegExp(
      r'(^|\s)class\s+' +
          RegExp.escape(className) +
          r'(\s|\{|extends|implements)',
    );
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (pattern.hasMatch(entity.readAsStringSync())) {
        return entity.uri.pathSegments.last;
      }
    }

    return null;
  }

  void _writeAtomically(String path, String content) {
    final file = File(path);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    // 先写临时文件再改名：中途失败不会留下半截产物
    final temp = File('$path.tmp.$pid');
    try {
      temp.writeAsStringSync(content);
      temp.renameSync(path);
    } catch (error) {
      if (temp.existsSync()) {
        temp.deleteSync();
      }
      rethrow;
    }
  }

  String _timestamp() {
    final now = _now ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  static bool _isBasicType(String type) {
    const basics = {
      'dynamic',
      'void',
      'bool',
      'int',
      'double',
      'String',
      'num',
      'Map',
      'List',
      'Set',
      'Object',
      'DateTime',
    };
    return basics.contains(type);
  }
}

/// 驼峰 -> 蛇形（`UserResult` -> `user_result`）。
String snakeCase(String input) {
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
