import 'dart:io';
import 'dart:convert';
import 'src/version.dart';
import 'src/resources.dart';
import 'src/api/api_cli.dart';

export 'src/api/api_cli.dart';
import 'src/api/api_generator.dart';

/// 获取当前版本号
/// 从自动生成的版本文件中读取版本号
String getVersionFromPubspec() {
  return version;
}

/// 获取脚本文件的路径
/// 从嵌入的资源文件中提取到临时目录
/// [scriptName] - 脚本文件名称
/// 返回脚本文件的临时路径
Future<String> getScriptPath(String scriptName) async {
  try {
    // 从资源文件中提取到临时文件
    final resourcePath = 'lib/sh/$scriptName';
    final tempPath = await Resources.extractResourceToTempFile(
      resourcePath,
      scriptName,
    );
    return tempPath;
  } catch (e) {
    throw FileSystemException('Failed to extract script: $e');
  }
}

/// 找不到 bash 时的提示（纯函数，方便测试）。
///
/// 非 Windows 上 bash 本来就该有，属于环境损坏，只给一句短的；
/// Windows 上脚本命令需要 Git Bash 或 WSL，要说清楚。
String? bashMissingHint(String scriptName, {required bool isWindows}) {
  if (!isWindows) {
    return '找不到 bash，无法执行 $scriptName（macOS/Linux 自带 bash，请检查 PATH）';
  }
  return 'Windows 上执行 $scriptName 需要 bash：请安装 Git Bash 或使用 WSL，'
      '或改用不依赖脚本的命令（如 ww api）。';
}

/// 执行脚本文件并实时显示输出
/// [scriptName] - 脚本文件名称
/// [arguments] - 传递给脚本的参数
/// [successMessage] - 执行成功时显示的消息
/// [failureMessage] - 执行失败时显示的消息
/// 返回脚本的退出码（0 表示成功），由调用方决定是否向上传递
Future<int> executeScript(
  String scriptName,
  List<String> arguments,
  String successMessage,
  String failureMessage,
) async {
  try {
    // 获取脚本路径（从资源文件提取）
    final scriptPath = await getScriptPath(scriptName);
    // print(
    //   'Executing script: $scriptPath with arguments: ${arguments.join(' ')}',
    // );

    Process process;
    // 把包版本注入脚本环境，脚本的 --version 因此不再各自维护一份版本号
    final env = {...Platform.environment, 'WW_VERSION': getVersionFromPubspec()};
    try {
      // 所有脚本都是 bash 脚本：Windows 上同样走 bash（Git Bash / WSL），
      // 没有 bash 时会在下面的 ProcessException 分支里给出明确提示
      process = await Process.start(
        'bash',
        [scriptPath, ...arguments],
        environment: env,
      );
    } on ProcessException {
      final hint = bashMissingHint(scriptName, isWindows: Platform.isWindows);
      if (hint != null) {
        print(hint);
      }
      return 1;
    }

    // 实时显示标准输出
    // 用 Utf8Decoder 做流式解码：多字节字符（中文）跨 chunk 边界时不会被截断
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          final output = chunk.trimRight();
          if (output.isNotEmpty) {
            print(output);
          }
        });

    // 实时显示错误输出
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          final output = chunk.trimRight();
          if (output.isNotEmpty) {
            print('Error: $output');
          }
        });

    // 等待进程完成并获取退出码
    final exitCode = await process.exitCode;
    // 等输出流排空，避免末尾提示与脚本输出交错
    await stdoutDone;
    await stderrDone;

    if (exitCode == 0) {
      if (successMessage.isNotEmpty) {
        print('\n✅ $successMessage');
      }
    } else {
      print('\n❌ $failureMessage with exit code: $exitCode');
    }
    return exitCode;
  } catch (e) {
    print('\n❌ Error executing script: $e');
    return 1;
  }
}

/// 处理错误信息，提供更详细的错误日志
/// [error] - 错误对象
/// [context] - 错误上下文
void handleError(dynamic error, String context) {
  print('\n❌ Error in $context: $error');

  if (error is FileSystemException) {
    print('   File system error: ${error.path}');
    if (error.message.isNotEmpty) {
      print('   Message: ${error.message}');
    }
    print('   Suggestion:');
    print('   - Check if the file or directory exists');
    print('   - Verify you have permission to access it');
    print('   - Ensure the path is correct');
  } else if (error is ProcessException) {
    print('   Process error: ${error.executable} ${error.arguments.join(' ')}');
    print('   Message: ${error.message}');
    print('   Suggestion:');
    print('   - Check if the command is installed');
    print('   - Verify the command is accessible in your PATH');
    print('   - Ensure you have permission to execute the command');
  } else if (error is FormatException) {
    print('   Format error: ${error.message}');
    if (error.source != null) {
      print('   Source: ${error.source}');
    }
    print('   Suggestion:');
    print('   - Check the input format');
    print('   - Ensure all required arguments are provided');
    print('   - Refer to the help documentation for correct usage');
  } else if (error is ArgumentError) {
    print('   Argument error: ${error.name}');
    print('   Suggestion:');
    print('   - Check the command arguments');
    print('   - Ensure all required arguments are provided');
    print('   - Use --help to see the correct usage');
  } else {
    print('   Unknown error type: ${error.runtimeType}');
    print('   Suggestion:');
    print('   - Try again with different parameters');
    print('   - Check your internet connection if applicable');
    print('   - Contact the maintainer if the issue persists');
  }

  print('   Stack trace:');
  print(StackTrace.current);
}

/// 验证项目名称是否有效
/// 项目名称必须非空且以小写字母开头
/// [projectName] - 项目名称
/// 返回验证结果
bool validateProjectName(String projectName) {
  if (projectName.isEmpty) {
    print('❌ Error: Project name is required');
    print('   Usage: ww create project name');
    return false;
  }

  if (!RegExp(r'^[a-z]').hasMatch(projectName)) {
    print('❌ Error: Project name must start with a lowercase letter');
    return false;
  }

  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(projectName)) {
    print(
      '❌ Error: Project name can only contain lowercase letters, numbers, and underscores',
    );
    return false;
  }

  return true;
}

/// 处理 create 命令
/// [arguments] - 命令参数
Future<int> handleCreateCommand(List<String> arguments) async {
  String subcommand;
  List<String> subArgs;

  if (arguments.isEmpty) {
    // 默认行为：create project
    subcommand = 'project';
    subArgs = [];
  } else {
    subcommand = arguments[0];
    subArgs = arguments.sublist(1);
  }

  if (subcommand == 'project' || subcommand == 'p') {
    if (subArgs.isEmpty) {
      print('❌ Error: Project name is required');
      print('   Usage: ww create|c project|p name');
      return 2;
    }
    final projectName = subArgs[0];
    return await handleCreateProject(projectName);
  } else {
    print('❌ Error: Unknown create subcommand: $subcommand');
    print('   Usage: ww create|c project|p name');
    return 2;
  }
}

/// 处理项目创建
/// [projectName] - 项目名称
Future<int> handleCreateProject(String projectName) async {
  // 验证项目名称
  if (!validateProjectName(projectName)) {
    return 2;
  }

  print('\n🚀 Creating Flutter project: $projectName');
  try {
    // 执行脚本并实时显示输出
    return await executeScript(
      'setup.sh',
      [projectName],
      'Project created successfully!',
      'Project creation failed',
    );
  } catch (e) {
    handleError(e, 'project creation');
    return 1;
  }
}

/// 处理页面创建
/// [arguments] - 命令参数
Future<void> handleCreatePage(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No page name specified');
    print('   Usage: ww create page name');
    return;
  }
  final pageName = arguments[0];
  print('\n🚀 Creating page: $pageName');
  print('   Note: Page creation functionality is not yet implemented');
}

/// 处理屏幕创建
/// [arguments] - 命令参数
Future<void> handleCreateScreen(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No screen name specified');
    print('   Usage: ww create screen name');
    return;
  }
  final screenName = arguments[0];
  print('\n🚀 Creating screen: $screenName');
  print('   Note: Screen creation functionality is not yet implemented');
}

/// 处理控制器创建
/// [arguments] - 命令参数
Future<void> handleCreateController(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No controller name specified');
    print('   Usage: ww create controller name');
    return;
  }
  final controllerName = arguments[0];
  print('\n🚀 Creating controller: $controllerName');
  print('   Note: Controller creation functionality is not yet implemented');
}

/// 处理视图创建
/// [arguments] - 命令参数
Future<void> handleCreateView(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No view name specified');
    print('   Usage: ww create view name');
    return;
  }
  final viewName = arguments[0];
  print('\n🚀 Creating view: $viewName');
  print('   Note: View creation functionality is not yet implemented');
}

/// 处理提供者创建
/// [arguments] - 命令参数
Future<void> handleCreateProvider(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No provider name specified');
    print('   Usage: ww create provider name');
    return;
  }
  final providerName = arguments[0];
  print('\n🚀 Creating provider: $providerName');
  print('   Note: Provider creation functionality is not yet implemented');
}

/// 处理初始化命令
Future<void> handleInitCommand() async {
  print('\n🚀 Initializing project structure');
  print('   Note: Init functionality is not yet implemented');
}

/// 处理 API 代码生成命令
/// [arguments] - 命令参数
Future<int> handleApiCommand(List<String> arguments, {bool debug = false}) async {
  final ApiInvocation invocation;
  try {
    invocation = resolveApiArgs(arguments);
  } on ApiUsageError catch (error) {
    stderr.writeln(error.message);
    return 2;
  }

  print('\n🚀 Running API code generation');

  // client.dart -> mixin / repository 走 Dart 侧（见 docs/adr/0001）
  if (invocation.mode == ApiMode.generate) {
    try {
      return await ApiGenerator().generate(force: invocation.force);
    } catch (e) {
      handleError(e, 'API code generation');
      return 1;
    }
  }

  // init / models 仍是 api.sh 负责的那一半
  final scriptArgs = <String>[
    invocation.mode == ApiMode.init ? 'init' : 'models',
    if (invocation.force) '--force',
    if (debug) '--debug',
  ];

  try {
    return await executeScript(
      'api.sh',
      scriptArgs,
      'API code generation completed successfully!',
      'API code generation failed',
    );
  } catch (e) {
    handleError(e, 'API code generation');
    return 1;
  }
}

/// 处理本地化文件生成
/// [arguments] - 命令参数
Future<void> handleGenerateLocales(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No locales directory specified');
    print('   Usage: ww generate locales directory');
    return;
  }
  final localesDir = arguments[0];
  print('\n🚀 Generating locales from: $localesDir');
  print('   Note: Locales generation functionality is not yet implemented');
}

/// 处理模型生成
/// [arguments] - 命令参数
Future<void> handleGenerateModel(List<String> arguments) async {
  print('\n🚀 Generating model');
  print('   Note: Model generation functionality is not yet implemented');
}

/// 处理包安装命令
/// [arguments] - 命令参数
Future<void> handleInstallCommand(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No package specified');
    print('   Usage: ww install package1 [package2 ...]');
    return;
  }
  final packages = arguments.join(' ');
  print('\n🚀 Installing packages: $packages');
  print('   Note: Package installation functionality is not yet implemented');
}

/// 处理包移除命令
/// [arguments] - 命令参数
Future<void> handleRemoveCommand(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No package specified');
    print('   Usage: ww remove package1 [package2 ...]');
    return;
  }
  final packages = arguments.join(' ');
  print('\n🚀 Removing packages: $packages');
  print('   Note: Package removal functionality is not yet implemented');
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
  // print('\n🚀 Running Flutter build');
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
  print('\n🚀 Managing Flutter project');
  try {
    // 执行脚本并实时显示输出
    return await executeScript(
      'project.sh',
      arguments,
      'Project operation completed successfully!',
      'Project operation failed',
    );
  } catch (e) {
    handleError(e, 'project');
    return 1;
  }
}

/// 处理打开命令
/// [arguments] - 命令参数
Future<int> handleOpenCommand(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No subcommand specified for open');
    print('   Usage: ww open [ios|i|android|a|build|b|root|r]');
    return 2;
  }

  final subcommand = arguments[0];
  String target;

  // 处理别名
  switch (subcommand) {
    case 'ios':
    case 'i':
      target = 'ios';
      break;
    case 'android':
    case 'a':
      target = 'android';
      break;
    case 'build':
    case 'b':
      target = 'build';
      break;
    case 'root':
    case 'r':
      target = 'root';
      break;
    default:
      print('❌ Error: Unknown open subcommand: $subcommand');
      print('   Usage: ww open [ios|i|android|a|build|b|root|r]');
      return 2;
  }

  print('\n🚀 Opening $target');
  try {
    // 执行脚本并实时显示输出
    return await executeScript(
      'open.sh',
      [target],
      'Opened $target successfully!',
      'Failed to open $target',
    );
  } catch (e) {
    handleError(e, 'open $target');
    return 1;
  }
}

/// 单元测试辅助函数
/// 验证版本号格式是否正确
/// [version] - 版本号
/// 返回验证结果
bool isValidVersion(String version) {
  return RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version);
}

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
Future<int> handleCommonCommand(List<String> arguments) async {
  print('\n🚀 Running common commands');
  try {
    // 执行脚本并实时显示输出
    return await executeScript(
      'common.sh',
      arguments,
      'Common command completed successfully!',
      'Common command failed',
    );
  } catch (e) {
    handleError(e, 'common command');
    return 1;
  }
}

/// 处理 clean 命令
/// [arguments] - 命令参数
Future<int> handleCleanCommand(List<String> arguments) async {
  print('\n🚀 Running Flutter clean');
  try {
    // 执行脚本并实时显示输出
    return await executeScript(
      'clean.sh',
      arguments,
      'Clean completed successfully!',
      'Clean failed',
    );
  } catch (e) {
    handleError(e, 'clean');
    return 1;
  }
}

/// 单元测试辅助函数
/// 验证项目名称是否有效
/// [projectName] - 项目名称
/// 返回验证结果
bool isValidProjectName(String projectName) {
  return validateProjectName(projectName);
}
