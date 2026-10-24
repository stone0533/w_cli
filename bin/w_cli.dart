import 'dart:io';

import 'package:args/args.dart';
import 'package:w_cli/w_cli.dart' as w;
import 'package:w_cli/src/resources.dart' as resources;

/// 主函数 - 处理命令行参数并执行相应的命令
Future<void> main(List<String> arguments) async {
  // 初始化命令行参数解析器
  final parser = ArgParser()
    ..addCommand('create')
    ..addCommand('c') // 别名
    ..addCommand('api')
    ..addCommand('a') // 别名
    ..addCommand('update')
    ..addCommand('u') // 别名
    ..addCommand('build')
    ..addCommand('b') // 别名
    ..addCommand('project')
    ..addCommand('p') // 别名
    ..addCommand('open')
    ..addCommand('o') // 别名
    ..addCommand('common')
    ..addCommand('co') // 别名
    ..addCommand('clean')
    ..addCommand('cl') // 别名
    ..addFlag('version', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

  // api / a：子命令用位置参数（generate / init / models），这里只声明修饰符
  for (final name in ['api', 'a']) {
    final command = parser.commands[name];
    if (command != null) {
      command
        ..addFlag('force', negatable: false)
        ..addFlag('debug', abbr: 'd', negatable: false);
    }
  }

  // 为 build 命令添加选项
  final buildCommand = parser.commands['build'];
  if (buildCommand != null) {
    buildCommand
      ..addFlag('uat', abbr: 'u', negatable: false)
      ..addFlag('clean', abbr: 'c', negatable: false)
      ..addFlag('open', abbr: 'o', negatable: false);
  }

  // 为 b 命令（build 的别名）添加选项
  final bCommand = parser.commands['b'];
  if (bCommand != null) {
    bCommand
      ..addFlag('uat', abbr: 'u', negatable: false)
      ..addFlag('clean', abbr: 'c', negatable: false)
      ..addFlag('open', abbr: 'o', negatable: false);
  }

  // 为 project 命令添加选项
  final projectCommand = parser.commands['project'];
  if (projectCommand != null) {
    projectCommand.addFlag('update', negatable: false);
  }

  // 为 p 命令（project 的别名）添加选项
  final pCommand = parser.commands['p'];
  if (pCommand != null) {
    pCommand.addFlag('update', negatable: false);
  }

  try {
    final results = parser.parse(arguments);

    // 处理版本命令
    if (results.wasParsed('version')) {
      final version = w.getVersionFromPubspec();
      if (version.isNotEmpty) {
        print('ww version $version');
      } else {
        print('ww version (unknown)');
      }
      return;
    }

    // 处理帮助命令或无参数情况
    if (results.wasParsed('help') || arguments.isEmpty) {
      showHelp();
      return;
    }

    final command = results.command;
    if (command == null) {
      print('Error: No command specified');
      exitCode = 2;
      return;
    }

    // 处理不同的命令
    // 每个 handler 返回子进程退出码：脚本失败必须让 ww 也失败，
    // 否则 CI 与 `ww build && ./upload.sh` 这类串联都会误判为成功。
    switch (command.name) {
      case 'create':
      case 'c':
        exitCode = await w.handleCreateCommand(command.arguments);
        break;
      case 'api':
      case 'a':
        exitCode = await w.handleApiCommand(
          command.arguments,
          debug: command['debug'] as bool,
        );
        break;
      case 'update':
      case 'u':
        exitCode = await w.handleUpdateCommand();
        break;
      case 'build':
      case 'b':
        // 构建参数列表：从 rest 参数中提取平台类型，再添加 flags
        final buildArgs = <String>[
          ...command.rest.where((arg) => arg == 'apk' || arg == 'aab' || arg == 'ios'),
          if (command['uat'] as bool) '--uat',
          if (command['clean'] as bool) '--clean',
          if (command['open'] as bool) '--open',
        ];
        exitCode = await w.handleBuildCommand(buildArgs);
        break;
      case 'project':
      case 'p':
        // 构建参数列表：从 rest 参数提取位置参数，再添加 flags
        final projectArgs = <String>[
          ...command.rest,
          if (command['update'] as bool) '--update',
        ];
        exitCode = await w.handleProjectCommand(projectArgs);
        break;
      case 'open':
      case 'o':
        exitCode = await w.handleOpenCommand(command.arguments);
        break;
      case 'common':
      case 'co':
        exitCode = await w.handleCommonCommand(command.arguments);
        break;
      case 'clean':
      case 'cl':
        exitCode = await w.handleCleanCommand(command.arguments);
        break;
      default:
        print('Error: Unknown command: ${command.name}');
        exitCode = 2;
    }
  } on FormatException catch (e) {
    // 参数解析失败（例如未知选项）属于用法错误，用 2 区分于运行时失败。
    // 旧写法（--init / --models / --full）在这里给一句指路，而不是原始异常。
    final hint = w.legacyFlagHint(e.message);
    if (hint != null) {
      print(hint);
    } else {
      print('Error: $e');
    }
    exitCode = 2;
  } catch (e) {
    print('Error: $e');
    exitCode = 1;
  } finally {
    // 清理临时文件
    resources.Resources.cleanupTempFiles();
  }
}

/// 显示帮助信息
void showHelp() {
  print('ww - A command-line tool for Flutter projects');
  print('');
  print('Usage:');
  print(
    '  ww create|c project|p name           # Create a new Flutter project',
  );
  print('  ww api|a [generate]                  # Generate API code');
  print(
    '  ww api|a init                        # Initialize API directory structure',
  );
  print(
    '  ww api|a models                      # Generate model files from JSON',
  );
  print(
    '  ww api|a models --force              # Force full regeneration of models',
  );
  print(
    '  ww api|a generate --force            # Overwrite hand-written members',
  );
  print(
    '  ww update|u                          # Update w_cli to the latest version',
  );
  print('  ww build|b [apk|aab|ios] [options]   # Build Flutter app');
  print(
    '  ww project|p --update                # Update Flutter project dependencies and configuration',
  );
  print(
    '  ww open|o [ios|i|android|a|build|b|root|r]  # Open project directories',
  );
  print('  ww common|co [drbb] [options]        # Run common commands');
  print('  ww clean|cl [options] [platform]     # Clean Flutter project');
  print('  ww -v, --version                     # Show version information');
  print('  ww -h, --help                        # Show this help message');
  print('');
  print('Build Options:');
  print('  --uat, -u      # Build in UAT mode with timestamp');
  print('  --clean, -c    # Clear build directory before building');
  print('  --open, -o     # Open output directory in Finder after build');
  print('');
  print('Examples:');
  print('  # Create project');
  print('  ww create project my_app');
  print('  ww c p my_app');
  print('');
  print('  # API generation');
  print('  ww api                      # Generate API code');
  print('  ww api init                 # Initialize API directory structure');
  print('  ww api models               # Generate model files from JSON');
  print('  ww api models --force       # Force full regeneration of models');
  print('  ww api --force              # 覆盖 repository.dart 中检测到的手写成员');
  print('');
  print('  # Build commands');
  print('  ww build apk                # Build APK in production mode');
  print('  ww build apk aab            # Build APK and AAB in production mode');
  print('  ww build apk --uat          # Build APK in UAT mode');
  print(
    '  ww build apk aab ios --uat --clean  # Build all platforms in UAT mode',
  );
  print(
    '  ww b apk -u -o              # Build APK in UAT mode and open output',
  );
  print(
    '  ww b apk aab -c -o          # Build APK and AAB with clean and open',
  );
  print('');
  print('  # Project management');
  print(
    '  ww project --update         # Update project dependencies and configuration',
  );
  print(
    '  ww p --update               # Update project dependencies and configuration',
  );
  print('');
  print('  # Open commands');
  print('  ww open ios                 # Open iOS project in Xcode');
  print(
    '  ww open android             # Open Android project in Android Studio',
  );
  print('  ww o i                      # Open iOS project (using alias)');
  print('  ww o a                      # Open Android project (using alias)');
  print('');
  print('  # Common commands');
  print('  ww common drbb              # Run build_runner build');
  print('  ww co drbb --debug          # Run with debug mode');
  print('');
  print('  # Clean commands');
  print('  ww clean                    # Clean all platforms');
  print('  ww clean android            # Clean Android build files');
  print('  ww clean ios                # Clean iOS build files');
  print('  ww clean --lock             # Clean with lock files');
  print('  ww clean ios --pod          # Clean iOS with Pods');
  print('  ww cl                       # Clean all platforms (using alias)');
  print('');
  print('Aliases:');
  print('  create    -> c');
  print('  update    -> u');
  print('  build     -> b');
  print('  project   -> p');
  print('  open      -> o');
  print('  api       -> a');
  print('  common    -> co');
  print('  clean     -> cl');
  print('  ios       -> i');
  print('  android   -> a');
  print('  build     -> b');
  print('  root      -> r');
  print('');
  print('Default behaviors:');
  print('  ww create     -> ww create project');
}
