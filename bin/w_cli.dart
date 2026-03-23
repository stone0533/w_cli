import 'package:args/args.dart';
import 'package:w_cli/w_cli.dart' as w;
import 'package:w_cli/src/resources.dart' as resources;

Future<void> main(List<String> arguments) async {
  // 原始执行逻辑
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
    ..addFlag('version', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

  // Get the build command parser and add options to it
  final buildCommand = parser.commands['build'];
  if (buildCommand != null) {
    buildCommand
      ..addFlag('uat', abbr: 'u', negatable: false)
      ..addFlag('clean', abbr: 'c', negatable: false)
      ..addFlag('open', abbr: 'o', negatable: false);
  }

  try {
    final results = parser.parse(arguments);

    if (results.wasParsed('version')) {
      final version = w.getVersionFromPubspec();
      if (version.isNotEmpty) {
        print('ww version $version');
      } else {
        print('ww version (unknown)');
      }
      return;
    }

    if (results.wasParsed('help') || arguments.isEmpty) {
      print('ww - A command-line tool for Flutter projects');
      print('');
      print('Usage:');
      print(
        '  ww create|c project|p name       # Create a new Flutter project',
      );
      print(
        '  ww api|a generate|g [options]    # Generate API code',
      );
      print(
        '  ww update|u                      # Update w_cli to the latest version',
      );
      print('  ww build|b [apk|aab|ios] [--uat|-u] [--clean|-c] [--open|-o]');
      print('  Options:');
      print('    --uat, -u      # Build in UAT mode with timestamp');
      print('    --clean, -c    # Clear build directory before building');
      print('    --open, -o     # Open output directory in Finder after build');
      print('  ww project|p --update            # Update Flutter project dependencies and configuration');
      print('  Options:');
      print('    --update       # Update Flutter project dependencies and configuration');
      print('  Examples:');
      print('    ww build apk                # Build APK in production mode');
      print(
        '    ww build apk aab            # Build APK and AAB in production mode',
      );
      print('    ww build apk --uat          # Build APK in UAT mode');
      print(
        '    ww build apk aab ios --uat --clean # Build all platforms in UAT mode and clear build directory',
      );
      print('    ww b apk -u -o              # Build APK in UAT mode and open output directory');
      print('    ww b apk aab -c -o          # Build APK and AAB with clean and open output directory');
      print('    ww p --update               # Update Flutter project dependencies and configuration');
      print('  ww open|o [ios|i|android|a|build|b|root|r]');
      print('  ww -v, --version');
      print('  ww -h, --help');
      print('');
      print('Aliases:');
      print('  create    -> c');
      print('  generate  -> g');
      print('  update    -> u');
      print('  build     -> b');
      print('  project   -> p');
      print('  open      -> o');
      print('  api       -> a');
      print('  ios       -> i');
      print('  android   -> a');
      print('  build     -> b');
      print('  root      -> r');
      print('');
      print('Default behaviors:');
      print('  ww create     -> ww create project');
      print('  ww api        -> ww api generate');
      print('  ww a          -> ww a generate');
      return;
    }

    final command = results.command;
    if (command == null) {
      print('Error: No command specified');
      return;
    }

    switch (command.name) {
      case 'create':
      case 'c':
        await w.handleCreateCommand(command.arguments);
        break;
      case 'api':
      case 'a':
        await w.handleGenerateCommand(command.arguments);
        break;
      case 'update':
      case 'u':
        await w.handleUpdateCommand();
        break;
      case 'build':
      case 'b':
        // 构建参数列表，包括平台和选项
        final buildArgs = List<String>.from(command.arguments);
        if (command['uat'] as bool) {
          buildArgs.add('--uat');
        }
        if (command['clean'] as bool) {
          buildArgs.add('--clean');
        }
        if (command['open'] as bool) {
          buildArgs.add('--open');
        }
        await w.handleBuildCommand(buildArgs);
        break;
      case 'project':
      case 'p':
        await w.handleProjectCommand(command.arguments);
        break;
      case 'open':
      case 'o':
        await w.handleOpenCommand(command.arguments);
        break;
      default:
        print('Error: Unknown command: ${command.name}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    // 清理临时文件
    resources.Resources.cleanupTempFiles();
  }
}
