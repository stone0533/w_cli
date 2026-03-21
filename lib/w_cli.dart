import 'dart:io';
import 'dart:convert';
import 'src/version.dart';
import 'src/resources.dart';

/// 获取当前版本号
/// 从自动生成的版本文件中读取版本号
String getVersionFromPubspec() {
  return version;
}

/// 获取脚本文件的路径
/// 从嵌入的资源文件中提取到临时目录
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

/// 执行脚本文件并实时显示输出
/// [scriptName] - 脚本文件名称
/// [arguments] - 传递给脚本的参数
/// [successMessage] - 执行成功时显示的消息
/// [failureMessage] - 执行失败时显示的消息
Future<void> executeScript(
  String scriptName,
  List<String> arguments,
  String successMessage,
  String failureMessage,
) async {
  try {
    // 获取脚本路径（从资源文件提取）
    final scriptPath = await getScriptPath(scriptName);
    print(
      'Executing script: $scriptPath with arguments: ${arguments.join(' ')}',
    );

    Process process;
    if (Platform.isWindows) {
      // 在 Windows 上使用 PowerShell 执行脚本
      process = await Process.start('powershell.exe', [
        '-File',
        scriptPath,
        ...arguments,
      ]);
    } else {
      // 在 macOS 和 Linux 上使用 bash 执行脚本
      process = await Process.start('bash', [scriptPath, ...arguments]);
    }

    // 实时显示标准输出
    process.stdout.listen((List<int> data) {
      final output = utf8.decode(data).trimRight();
      if (output.isNotEmpty) {
        print(output);
      }
    });

    // 实时显示错误输出
    process.stderr.listen((List<int> data) {
      final output = utf8.decode(data).trimRight();
      if (output.isNotEmpty) {
        print('Error: $output');
      }
    });

    // 等待进程完成并获取退出码
    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      if (successMessage.isNotEmpty) {
        print('\n✅ $successMessage');
      }
    } else {
      print('\n❌ $failureMessage with exit code: $exitCode');
    }
  } catch (e) {
    print('\n❌ Error executing script: $e');
  }
}

/// 处理错误信息，提供更详细的错误日志
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
Future<void> handleCreateCommand(List<String> arguments) async {
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
      return;
    }
    final projectName = subArgs[0];
    await handleCreateProject(projectName);
  } else {
    print('❌ Error: Unknown create subcommand: $subcommand');
    print('   Usage: ww create|c project|p name');
  }
}

/// 处理项目创建
Future<void> handleCreateProject(String projectName) async {
  // 验证项目名称
  if (!validateProjectName(projectName)) {
    return;
  }

  print('\n🚀 Creating Flutter project: $projectName');
  try {
    // 执行脚本并实时显示输出
    await executeScript(
      'setup_project.sh',
      ['--name', projectName],
      'Project created successfully!',
      'Project creation failed',
    );
  } catch (e) {
    handleError(e, 'project creation');
  }
}

/// 处理页面创建
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

/// 处理 generate 命令
Future<void> handleGenerateCommand(List<String> arguments) async {
  String subcommand;
  List<String> subArgs;

  if (arguments.isEmpty) {
    // 默认行为：generate api
    subcommand = 'api';
    subArgs = [];
  } else {
    subcommand = arguments[0];
    subArgs = arguments.sublist(1);
  }

  if (subcommand == 'api' || subcommand == 'a') {
    await handleGenerateApi(subArgs);
  } else {
    print('❌ Error: Unknown generate subcommand: $subcommand');
    print('   Usage: ww generate|g api|a [options]');
  }
}

/// 处理本地化文件生成
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
Future<void> handleGenerateModel(List<String> arguments) async {
  print('\n🚀 Generating model');
  print('   Note: Model generation functionality is not yet implemented');
}

/// 处理包安装命令
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
Future<void> handleUpdateCommand() async {
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
    process.stdout.listen((List<int> data) {
      print(utf8.decode(data));
    });

    // 实时显示错误输出
    process.stderr.listen((List<int> data) {
      print('Error: ${utf8.decode(data)}');
    });

    // 等待进程完成并获取退出码
    final exitCode = await process.exitCode;
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
  } catch (e) {
    handleError(e, 'update');
    print('   Please try again or check your internet connection.');
  }
}

/// 处理 API 代码生成
Future<void> handleGenerateApi(List<String> arguments) async {
  print('\n🚀 Running API code generation');
  try {
    // 执行脚本并实时显示输出
    await executeScript(
      'api_gen.sh',
      arguments,
      'API code generation completed successfully!',
      'API code generation failed',
    );
  } catch (e) {
    handleError(e, 'API code generation');
  }
}

/// 处理构建命令
Future<void> handleBuildCommand(List<String> arguments) async {
  print('\n🚀 Running Flutter build');
  try {
    // 执行脚本并实时显示输出
    await executeScript(
      'build.sh',
      arguments,
      'Build completed successfully!',
      'Build failed',
    );
  } catch (e) {
    handleError(e, 'build');
  }
}

/// 处理打开命令
Future<void> handleOpenCommand(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('❌ Error: No subcommand specified for open');
    print('   Usage: ww open [ios|i|android|a|build|b|root|r]');
    return;
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
      return;
  }

  print('\n🚀 Opening $target');
  try {
    // 执行脚本并实时显示输出
    await executeScript(
      'open.sh',
      [target],
      'Opened $target successfully!',
      'Failed to open $target',
    );
  } catch (e) {
    handleError(e, 'open $target');
  }
}

/// 单元测试辅助函数
/// 验证版本号格式是否正确
bool isValidVersion(String version) {
  return RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version);
}

/// 单元测试辅助函数
/// 验证脚本路径是否存在
Future<bool> scriptExists(String scriptName) async {
  try {
    await getScriptPath(scriptName);
    return true;
  } catch (e) {
    return false;
  }
}

/// 单元测试辅助函数
/// 验证项目名称是否有效
bool isValidProjectName(String projectName) {
  return validateProjectName(projectName);
}
