import 'dart:io';

import 'package:path/path.dart' as p;

/// 解析本项目该用的 w_tools 导入 URI。
///
/// **不能写死 `package:w_tools/w.dart`**：项目切到「具体子包 + 自己的聚合入口」后，
/// meta 包已经不在依赖里，生成出来的代码会直接编译不过（29 个 error）。
///
/// 判定顺序：
/// 1. [barrel] 存在且能从 pubspec 读到 `name` → `package:<name>/app/w/toolkit.dart`
/// 2. 否则 → `package:w_tools/w.dart`（老的、还在用 meta 包的项目）
///
/// 与 `api.sh` 的 `resolve_w_tools_import` 保持同一套规则，两条生成路径不能各说各话。
String resolveWtoolsImport({
  String projectRoot = '.',
  String barrel = 'lib/app/w/toolkit.dart',
}) {
  final barrelFile = File(p.join(projectRoot, barrel));
  if (!barrelFile.existsSync()) return 'package:w_tools/w.dart';

  final name = readPackageName(projectRoot);
  if (name == null || name.isEmpty) return 'package:w_tools/w.dart';

  final barrelInLib = p.posix.joinAll(p.posix.split(barrel).skip(1));
  return 'package:$name/$barrelInLib';
}

/// 从 `pubspec.yaml` 读 `name:`（不引 yaml 依赖，单行正则足够）。
String? readPackageName(String projectRoot) {
  final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;

  for (final line in pubspec.readAsLinesSync()) {
    final match = RegExp(r'^name:\s*(\S+)').firstMatch(line);
    if (match != null) return match.group(1)!.trim();
  }
  return null;
}
