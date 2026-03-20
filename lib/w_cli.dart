import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

/// 获取当前版本号
/// 注意：每次提交前需要手动修改此版本号
String getVersionFromPubspec() {
  return '1.0.13';
}

/// 获取脚本文件的路径
/// 支持 macOS 和 Windows 系统
String getScriptPath(String scriptName) {
  // 尝试不同的路径组合
  List<String> possiblePaths = [];
  
  // 获取用户主目录（适配 macOS 和 Windows）
  String? homeDir;
  if (Platform.isMacOS || Platform.isLinux) {
    homeDir = Platform.environment['HOME'];
  } else if (Platform.isWindows) {
    homeDir = Platform.environment['USERPROFILE'];
  }
  
  if (homeDir != null) {
    // 从 pubspec.yaml 读取当前版本号
    final currentVersion = getVersionFromPubspec();
    if (currentVersion.isNotEmpty) {
      // 遍历所有 hosted 源目录
      final hostedDir = Directory(path.join(homeDir, '.pub-cache', 'hosted'));
      if (hostedDir.existsSync()) {
        final hostedSources = hostedDir.listSync(followLinks: false);
        for (var source in hostedSources) {
          if (source is Directory) {
            // 查找当前版本的 w_cli 目录
            final currentVersionDir = Directory(path.join(source.path, 'w_cli-$currentVersion'));
            if (currentVersionDir.existsSync()) {
              possiblePaths.add(path.join(currentVersionDir.path, 'lib', 'sh', scriptName));
            }
          }
        }
      }
    }
  }
  
  // 尝试所有可能的路径
  for (String scriptPath in possiblePaths) {
    final scriptFile = File(scriptPath);
    if (scriptFile.existsSync()) {
      // 直接添加执行权限，不进行检查
      try {
        Process.runSync('chmod', ['+x', scriptPath]);
      } catch (e) {
        print('Warning: Failed to add execution permission to script: $e');
      }
      return scriptPath;
    }
  }
  
  // 如果仍然不存在，抛出错误
  throw FileSystemException('Script file not found.', possiblePaths.isNotEmpty ? possiblePaths.first : '');
}

void handleCreateCommand(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No subcommand specified for create');
    print('Usage: ww create project name');
    return;
  }

  final subcommand = arguments[0];
  if (subcommand == 'project') {
    if (arguments.length < 2) {
      print('Error: Project name is required');
      print('Usage: ww create project name');
      return;
    }
    final projectName = arguments[1];
    handleCreateProject(projectName);
  } else {
    print('Error: Unknown create subcommand: $subcommand');
    print('Usage: ww create project name');
  }
}

void handleCreateProject(String projectName) {
  // 验证项目名称格式
  if (projectName.isEmpty) {
    print('Error: Project name is required');
    print('Usage: ww create project name');
    return;
  }
  
  // 验证项目名称是否以小写字母开头
  if (!RegExp(r'^[a-z]').hasMatch(projectName)) {
    print('Error: Project name must start with a lowercase letter');
    return;
  }
  
  print('Creating Flutter project: $projectName');
  // Get the absolute path to the setup_project.sh script
  final setupScriptPath = getScriptPath('setup_project.sh');
  // Execute the setup_project.sh script with project name argument and real-time output
  try {
    final process = Process.start('bash', [setupScriptPath, '--project-name', projectName]);
    process.then((p) {
      p.stdout.listen((List<int> data) {
        print(utf8.decode(data));
      });
      p.stderr.listen((List<int> data) {
        print('Error: ${utf8.decode(data)}');
      });
      p.exitCode.then((code) {
        if (code != 0) {
          print('Project creation failed with exit code: $code');
        }
      });
    });
  } catch (e) {
    print('Error executing setup script: $e');
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
  print('Updating w_cli...');
  try {
    // 升级到最新版本
    final updateResult = Process.runSync('dart', ['pub', 'global', 'activate', 'w_cli']);
    
    // 检查更新是否成功
    if (updateResult.exitCode == 0) {
      print('Update completed successfully!');
      print('Current version: ${getVersionFromPubspec()}');
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
  final apiScriptPath = getScriptPath('api_gen.sh');
  // Execute the api_gen.sh script with real-time output
  try {
    final process = Process.start('bash', [apiScriptPath, ...arguments]);
    process.then((p) {
      p.stdout.listen((List<int> data) {
        print(utf8.decode(data));
      });
      p.stderr.listen((List<int> data) {
        print('Error: ${utf8.decode(data)}');
      });
      p.exitCode.then((code) {
        if (code != 0) {
          print('API code generation failed with exit code: $code');
        }
      });
    });
  } catch (e) {
    print('Error executing API generation script: $e');
  }
}

void handleBuildCommand(List<String> arguments) {
  print('Running Flutter build');
  // Get the absolute path to the build.sh script
  final buildScriptPath = getScriptPath('build.sh');
  // Execute the build.sh script with real-time output
  try {
    final process = Process.start('bash', [buildScriptPath, ...arguments]);
    process.then((p) {
      p.stdout.listen((List<int> data) {
        print(utf8.decode(data));
      });
      p.stderr.listen((List<int> data) {
        print('Error: ${utf8.decode(data)}');
      });
      p.exitCode.then((code) {
        if (code != 0) {
          print('Build failed with exit code: $code');
        }
      });
    });
  } catch (e) {
    print('Error executing build script: $e');
  }
}

void handleOpenCommand(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Error: No subcommand specified for open');
    print('Usage: ww open [ios|android|build]');
    return;
  }

  final subcommand = arguments[0];
  if (subcommand == 'ios' || subcommand == 'android' || subcommand == 'build') {
    print('Opening $subcommand');
    // Get the absolute path to the open.sh script
    final openScriptPath = getScriptPath('open.sh');
    // Execute the open.sh script with the specified subcommand
    try {
      final process = Process.start('bash', [openScriptPath, subcommand]);
      process.then((p) {
        p.stdout.listen((List<int> data) {
          print(utf8.decode(data));
        });
        p.stderr.listen((List<int> data) {
          print('Error: ${utf8.decode(data)}');
        });
        p.exitCode.then((code) {
          if (code != 0) {
            print('Open failed with exit code: $code');
          }
        });
      });
    } catch (e) {
      print('Error executing open script: $e');
    }
  } else {
    print('Error: Unknown open subcommand: $subcommand');
    print('Usage: ww open [ios|android|build]');
  }
}


