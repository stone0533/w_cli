import 'dart:io';
import 'package:path/path.dart' as path;

void handleCreateCommand(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No subcommand specified for create');
    print('Usage: ww create [project]');
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
  final scriptPath = Platform.script.path;
  final scriptFile = File(scriptPath);
  final binDir = scriptFile.parent;
  final projectDir = binDir.parent;
  final setupScriptPath = path.join(projectDir.path, 'sh', 'setup_project.sh');
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
    print('Usage: ww generate [locales|model]');
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
  print('Updating ww...');
  try {
    // 升级到最新版本
    final updateResult = Process.runSync('dart', ['pub', 'global', 'activate', 'w_cli']);
    
    // 检查更新是否成功
    if (updateResult.exitCode == 0) {
      print('Update completed successfully!');
      print('Note: You may need to restart your terminal for the changes to take effect.');
    } else {
      print('Update failed!');
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
  final scriptPath = Platform.script.path;
  final scriptFile = File(scriptPath);
  final binDir = scriptFile.parent;
  final projectDir = binDir.parent;
  final apiScriptPath = path.join(projectDir.path, 'sh', 'api_gen.sh');
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
  final scriptPath = Platform.script.path;
  final scriptFile = File(scriptPath);
  final binDir = scriptFile.parent;
  final projectDir = binDir.parent;
  final buildScriptPath = path.join(projectDir.path, 'sh', 'build.sh');
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
  final scriptPath = Platform.script.path;
  final scriptFile = File(scriptPath);
  final binDir = scriptFile.parent;
  final projectDir = binDir.parent;
  final setupScriptPath = path.join(projectDir.path, 'sh', 'setup_project.sh');
  print('Setup script path: $setupScriptPath');
  // Execute the setup_project.sh script
  final result = Process.runSync('bash', [setupScriptPath, ...arguments]);
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Error: ${result.stderr}');
  }
}
