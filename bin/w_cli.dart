import 'dart:io';

import 'package:args/args.dart';
import 'package:w_cli/w_cli.dart' as w;
import 'package:w_cli/src/cli/command_spec.dart' as cli_spec;
import 'package:w_cli/src/cli/help.dart' as cli_help;
import 'package:w_cli/src/resources.dart' as resources;

/// 主函数 - 处理命令行参数并执行相应的命令
Future<void> main(List<String> arguments) async {
  // 初始化命令行参数解析器
  final parser = ArgParser()
    ..addFlag('version', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

  // 命令名、别名、flag/option 声明全部来自这一张表
  final specs = cli_spec.commandSpecs();
  for (final spec in specs) {
    for (final name in spec.allNames) {
      final command = parser.addCommand(name);
      for (final flag in spec.flags) {
        flag.register(command);
      }
      for (final option in spec.options) {
        option.register(command);
      }
    }
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

    final command = results.command;

    // --help 命中某个命令时打印该命令的帮助，否则打印全局帮助
    if (results.wasParsed('help') || arguments.isEmpty) {
      final name = command?.name;
      if (name != null) {
        final help = cli_help.commandHelp(name);
        if (help != null) {
          print(help);
          return;
        }
      }
      showHelp();
      return;
    }
    if (command == null) {
      if (arguments.isNotEmpty) {
        print('Error: Unknown command: ${arguments.first}');
        print('   Run `ww --help` to see available commands.');
      } else {
        print('Error: No command specified');
      }
      exitCode = 2;
      return;
    }

    // 按命令表分派：每个 handler 返回子进程退出码
    final spec = specs.firstWhere(
      (candidate) => candidate.allNames.contains(command.name),
      orElse: () => specs.first,
    );
    if (!spec.allNames.contains(command.name)) {
      print('Error: Unknown command: ${command.name}');
      exitCode = 2;
      return;
    }
    exitCode = await spec.run(command);
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
    '  ww create|c [project|p] <name>       # Create a new Flutter project',
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
    '  ww deps upgrade                      # Update project dependencies and Gradle',
  );
  print('  ww project|p --update                # 旧名，请改用 ww deps upgrade');
  print(
    '  ww open|o [ios|i|android|a|build|b|root|r]  # Open project directories',
  );
  print('  ww gen [-- <flags>]                  # Run build_runner');
  print('  ww fmt | get | pod | analyze         # 常用长命令的短写法');
  print('  ww run [任务名]                      # 执行 .ww/tasks 里的任务');
  print('  ww clean|cl [options] [platform]     # Clean Flutter project');
  print('  ww -v, --version                     # Show version information');
  print('  ww -h, --help                        # Show this help message');
  print('');
  print('Build Options:');
  print('  --uat, -u              # Build in UAT mode with timestamp');
  print(
    '  --fresh                # Clear build directory before building (was --clean)',
  );
  print(
    '  --open, -o             # Open output directory in Finder after build',
  );
  print('  --name=<name>          # App name used in output file names');
  print(
    '  --export-options=<f>   # iOS export options plist (default w_build/ios.plist)',
  );
  print('  --debug, -d            # Verbose debug logging');
  print('');
  print('Examples:');
  print('  # Create project');
  print('  ww create my_app');
  print('  ww c my_app');
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
  print('  ww clean all                # Clean all platforms');
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
