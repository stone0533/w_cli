import 'dart:io';
import 'dart:convert';
import 'src/version.dart';
import 'src/cli/script_runner.dart';
import 'src/cli/help.dart';
import 'src/cli/output.dart';
import 'src/cli/validators.dart';
import 'src/api/api_cli.dart';

export 'src/api/api_cli.dart';
// 保持 package:w_cli/w_cli.dart 的公开面（测试与 bin 都在用）
export 'src/cli/script_runner.dart';
export 'src/cli/validators.dart';
import 'src/api/api_generator.dart';
import 'src/api/scaffolder.dart';
import 'src/models/models_generator.dart';
import 'src/commands/clean_command.dart';
import 'src/commands/open_command.dart';
import 'src/commands/project_command.dart';
import 'src/project/project_creator.dart';

/// 获取当前版本号
/// 从自动生成的版本文件中读取版本号
String getVersionFromPubspec() {
  return version;
}

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

/// 处理 create 命令
/// [arguments] - 命令参数
Future<int> handleCreateCommand(
  List<String> arguments, {
  bool force = false,
}) async {
  // 两种写法都接受：`ww create my_app` 与 `ww create project my_app`
  final rest = [...arguments];
  if (rest.isNotEmpty && (rest.first == 'project' || rest.first == 'p')) {
    rest.removeAt(0);
  }

  if (rest.isEmpty) {
    print('❌ Error: Project name is required');
    print('   Usage: ww create|c [project|p] <name>');
    return 2;
  }

  return await handleCreateProject(rest.first, force: force);
}

/// 处理项目创建
/// [projectName] - 项目名称
Future<int> handleCreateProject(
  String projectName, {
  bool force = false,
}) async {
  if (!validateProjectName(projectName)) {
    return 2;
  }

  print('\n🚀 Creating Flutter project: $projectName');
  try {
    return await ProjectCreator(name: projectName, force: force).run();
  } catch (e) {
    handleError(e, 'project creation');
    return 1;
  }
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
    stderr.writeln(error.message);
    return 2;
  }

  // 在非工程目录里跑会在仓库根长出 lib/app/ —— 直接拒绝，别留垃圾
  if (invocation.mode != ApiMode.models && !_isFlutterProject()) {
    stderr.writeln(
      '当前目录不是 Flutter 工程（没有 pubspec.yaml 的 flutter: 段，也没有 lib/main.dart）',
    );
    stderr.writeln('  请在工程根目录执行，或先 ww create <name>');
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

/// 处理更新命令
Future<int> handleUpdateCommand() async {
  print('\n🚀 Updating w_cli...');
  try {
    // 升级到最新版本
    final process = await Process.start('dart', [
      'pub',
      'global',
      'activate',
      'w_cli',
    ]);

    // 实时显示标准输出
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          print(chunk.trimRight());
        });

    // 实时显示错误输出
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          print('Error: ${chunk.trimRight()}');
        });

    // 等待进程完成并获取退出码
    final exitCode = await process.exitCode;
    await stdoutDone;
    await stderrDone;

    if (exitCode == 0) {
      print('\n✅ Update completed successfully!');
      print('   Current version: ${getVersionFromPubspec()}');
      print(
        '   Note: You may need to restart your terminal for the changes to take effect.',
      );
    } else {
      print('\n❌ Update failed with exit code: $exitCode');
      print('   Please try again or check your internet connection.');
    }
    return exitCode;
  } catch (e) {
    handleError(e, 'update');
    print('   Please try again or check your internet connection.');
    return 1;
  }
}

/// 处理构建命令
/// [arguments] - 命令参数
Future<int> handleBuildCommand(List<String> arguments) async {
  // 无参数时打印 ww 自己的帮助，而不是 build.sh 的英文 usage
  if (arguments.isEmpty) {
    final help = commandHelp('build');
    if (help != null) {
      print(help);
    }
    return 0;
  }

  try {
    // 执行脚本并实时显示输出
    return await executeScript(
      'build.sh',
      arguments,
      'Build completed successfully!',
      'Build failed',
    );
  } catch (e) {
    handleError(e, 'build');
    return 1;
  }
}

/// 处理项目管理命令
/// [arguments] - 命令参数
Future<int> handleProjectCommand(List<String> arguments) async {
  return ProjectCommand().run(arguments);
}

/// 处理打开命令
/// [arguments] - 命令参数
Future<int> handleOpenCommand(List<String> arguments) async {
  return OpenCommand().run(arguments);
}

/// 单元测试辅助函数
/// 验证版本号格式是否正确
/// [version] - 版本号
/// 返回验证结果

/// 单元测试辅助函数
/// 验证脚本路径是否存在
/// [scriptName] - 脚本文件名称
/// 返回验证结果
Future<bool> scriptExists(String scriptName) async {
  try {
    await getScriptPath(scriptName);
    return true;
  } catch (e) {
    return false;
  }
}

/// 处理 common 命令
/// [arguments] - 命令参数

/// 处理 clean 命令
/// [arguments] - 命令参数
Future<int> handleCleanCommand(List<String> arguments) async {
  // 无参数时只打印帮助：`ww clean` 曾经会立刻清空所有构建产物
  if (arguments.isEmpty) {
    final help = commandHelp('clean');
    if (help != null) {
      print(help);
    }
    return 0;
  }
  return CleanCommand().run(arguments);
}

/// 单元测试辅助函数
/// 验证项目名称是否有效
/// [projectName] - 项目名称
/// 返回验证结果
