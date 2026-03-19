import 'dart:io';
import 'package:path/path.dart' as path;

/// 获取脚本文件的路径
String getScriptPath(String scriptName) {
  // 获取当前脚本的路径
  final scriptPath = Platform.script.path;
  final scriptFile = File(scriptPath);
  
  // 尝试不同的路径组合
  List<String> possiblePaths = [];
  
  // 路径1: 本地开发环境 - lib/sh 目录
  final binDir = scriptFile.parent;
  final projectDir = binDir.parent;
  possiblePaths.add(path.join(projectDir.path, 'lib', 'sh', scriptName));
  
  // 路径2: 全局安装环境 - 向上导航到正确的目录
  // 当通过 pub global activate 安装时，路径可能是类似 ~/.pub-cache/global_packages/w_cli/bin/w_cli.dart
  // 所以我们需要向上导航到 w_cli 目录，然后进入 lib/sh
  var currentDir = scriptFile.parent;
  for (int i = 0; i < 5; i++) { // 最多向上导航5级
    possiblePaths.add(path.join(currentDir.path, 'lib', 'sh', scriptName));
    possiblePaths.add(path.join(currentDir.path, 'sh', scriptName));
    currentDir = currentDir.parent;
    if (currentDir.path == '/' || currentDir.path.endsWith(':')) break; // 到达根目录时停止
  }
  
  // 路径3: 直接从 .pub-cache 目录获取
  // 当全局安装时，脚本文件应该在 ~/.pub-cache/global_packages/w_cli/lib/sh/ 目录下
  final homeDir = Platform.environment['HOME'];
  if (homeDir != null) {
    possiblePaths.add(path.join(homeDir, '.pub-cache', 'global_packages', 'w_cli', 'lib', 'sh', scriptName));
  }
  
  // 尝试所有可能的路径
  for (String scriptPath in possiblePaths) {
    final scriptFile = File(scriptPath);
    if (scriptFile.existsSync()) {
      return scriptPath;
    }
  }
  
  // 如果仍然不存在，抛出错误并显示所有尝试的路径
  final errorMessage = 'Script file not found. Tried the following paths:\n' +
      possiblePaths.map((p) => '  - $p').join('\n');
  throw FileSystemException(errorMessage, possiblePaths.first);
}

void handleCreateCommand(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No subcommand specified for create');
    print('Usage: w_cli create [project]');
    return;
  }

  final subcommand = arguments[0];
  switch (subcommand) {
    case 'project':
      handleCreateProject(arguments.sublist(1));
      break;
    default:
      print('Error: Unknown create subcommand: $subcommand');
  }
}

void handleCreateProject(List<String> arguments) {
  print('Creating Flutter project');
  // Get the absolute path to the setup_project.sh script
  final setupScriptPath = getScriptPath('setup_project.sh');
  print('Setup script path: $setupScriptPath');
  // Execute the setup_project.sh script with project name argument if provided
  final result = Process.runSync('bash', [setupScriptPath, ...arguments]);
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Error: ${result.stderr}');
  }
}

void handleCreatePage(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No page name specified');
    return;
  }
  final pageName = arguments[0];
  print('Creating page: $pageName');
  // TODO: Implement page creation logic
}

void handleCreateScreen(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No screen name specified');
    return;
  }
  final screenName = arguments[0];
  print('Creating screen: $screenName');
  // TODO: Implement screen creation logic
}

void handleCreateController(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No controller name specified');
    return;
  }
  final controllerName = arguments[0];
  print('Creating controller: $controllerName');
  // TODO: Implement controller creation logic
}

void handleCreateView(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No view name specified');
    return;
  }
  final viewName = arguments[0];
  print('Creating view: $viewName');
  // TODO: Implement view creation logic
}

void handleCreateProvider(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No provider name specified');
    return;
  }
  final providerName = arguments[0];
  print('Creating provider: $providerName');
  // TODO: Implement provider creation logic
}

void handleInitCommand() {
  print('Initializing project structure');
  // TODO: Implement init logic
}

void handleGenerateCommand(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No subcommand specified for generate');
    print('Usage: w_cli generate [locales|model]');
    return;
  }

  final subcommand = arguments[0];
  switch (subcommand) {
    case 'locales':
      handleGenerateLocales(arguments.sublist(1));
      break;
    case 'model':
      handleGenerateModel(arguments.sublist(1));
      break;
    case 'api':
      handleGenerateApi(arguments.sublist(1));
      break;
    default:
      print('Error: Unknown generate subcommand: $subcommand');
  }
}

void handleGenerateLocales(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No locales directory specified');
    return;
  }
  final localesDir = arguments[0];
  print('Generating locales from: $localesDir');
  // TODO: Implement locales generation logic
}

void handleGenerateModel(List<String> arguments) {
  print('Generating model');
  // TODO: Implement model generation logic
}

void handleInstallCommand(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No package specified');
    return;
  }
  final packages = arguments.join(' ');
  print('Installing packages: $packages');
  // TODO: Implement package installation logic
}

void handleRemoveCommand(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No package specified');
    return;
  }
  final packages = arguments.join(' ');
  print('Removing packages: $packages');
  // TODO: Implement package removal logic
}

void handleUpdateCommand() {
  print('Updating w_cli');
  try {
    // 检查当前激活的版本
    print('Checking current version...');
    final listResult = Process.runSync('dart', ['pub', 'global', 'list']);
    print(listResult.stdout);
    if (listResult.stderr.isNotEmpty) {
      print('Error checking current version: ${listResult.stderr}');
    }
    
    // 升级到最新版本
    print('\nUpdating to latest version...');
    final updateResult = Process.runSync('dart', ['pub', 'global', 'activate', 'w_cli']);
    print(updateResult.stdout);
    
    // 检查更新是否成功
    if (updateResult.exitCode == 0) {
      print('\nUpdate completed successfully!');
    } else {
      print('\nUpdate failed!');
      if (updateResult.stderr.isNotEmpty) {
        print('Error: ${updateResult.stderr}');
      }
      print('Please try again or check your internet connection.');
    }
  } catch (e) {
    print('Error during update: $e');
    print('Please try again or check your internet connection.');
  }
}


void handleGenerateApi(List<String> arguments) {
  print('Running API code generation');
  // Get the absolute path to the api_gen.sh script
  final apiScriptPath = getScriptPath('api_gen.sh');
  // Execute the api_gen.sh script
  final result = Process.runSync('bash', [apiScriptPath, ...arguments]);
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Error: ${result.stderr}');
  }
}

void handleBuildCommand(List<String> arguments) {
  print('Running Flutter build');
  // Get the absolute path to the build.sh script
  final buildScriptPath = getScriptPath('build.sh');
  print('Build script path: $buildScriptPath');
  // Execute the build.sh script
  final result = Process.runSync('bash', [buildScriptPath, ...arguments]);
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Error: ${result.stderr}');
  }
}

void handleSetupCommand(List<String> arguments) {
  print('Running project setup');
  // Get the absolute path to the setup_project.sh script
  final setupScriptPath = getScriptPath('setup_project.sh');
  print('Setup script path: $setupScriptPath');
  // Execute the setup_project.sh script
  final result = Process.runSync('bash', [setupScriptPath, ...arguments]);
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Error: ${result.stderr}');
  }
}
