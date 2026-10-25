import 'dart:io';

import '../api/api_cli.dart';
import '../api/api_generator.dart';
import '../api/scaffolder.dart';
import '../cli/output.dart';
import '../cli/script_runner.dart';
import '../models/models_generator.dart';

/// 验证项目名称是否有效
/// 项目名称必须非空且以小写字母开头
/// [projectName] - 项目名称
/// 返回验证结果

/// 当前目录看起来是不是一个 Flutter 工程：
/// pubspec.yaml 里有 flutter: 段，或者存在 lib/main.dart
bool _isFlutterProject() {
  final pubspec = File('pubspec.yaml');
  if (pubspec.existsSync()) {
    final content = pubspec.readAsStringSync();
    if (RegExp(r'^flutter:', multiLine: true).hasMatch(content)) {
      return true;
    }
  }
  return File('lib/main.dart').existsSync();
}

/// 处理 API 代码生成命令
/// [arguments] - 命令参数
Future<int> handleApiCommand(
  List<String> arguments, {
  bool debug = false,
}) async {
  final ApiInvocation invocation;
  try {
    invocation = resolveApiArgs(arguments);
  } on ApiUsageError catch (error) {
    Cli.error(error.message);
    return 2;
  }

  // 在非工程目录里跑会在仓库根长出 lib/app/ —— 直接拒绝，别留垃圾
  if (invocation.mode != ApiMode.models && !_isFlutterProject()) {
    Cli.error(
      '当前目录不是 Flutter 工程（没有 pubspec.yaml 的 flutter: 段，也没有 lib/main.dart）',
    );
    Cli.error('  请在工程根目录执行，或先 ww create <name>');
    return 1;
  }

  Cli.detail('API 代码生成');

  // 目录初始化（ADR-0002 Phase 1：Dart 实现）
  if (invocation.mode == ApiMode.init) {
    try {
      return ApiScaffolder().run();
    } catch (e) {
      handleError(e, 'API directory initialization');
      return 1;
    }
  }

  // client.dart -> mixin / repository 走 Dart 侧（见 doc/adr/0001）
  if (invocation.mode == ApiMode.generate) {
    try {
      return await ApiGenerator().generate(force: invocation.force);
    } catch (e) {
      handleError(e, 'API code generation');
      return 1;
    }
  }

  // JSON -> 模型（ADR-0002 Phase 3：Dart 实现）
  try {
    return await ModelsGenerator(force: invocation.force).generate();
  } catch (e) {
    handleError(e, 'Model generation');
    return 1;
  }
}
