import 'package:args/args.dart';
import 'package:w_cli/w_cli.dart' as w;
import 'package:w_cli/src/resources.dart' as resources;

Future<void> main(List<String> arguments) async {
  // 原始执行逻辑
  final parser = ArgParser()
   ..addCommand('create')
    ..addCommand('generate')
    ..addCommand('update')
    ..addCommand('build')
    ..addCommand('open')
    ..addFlag('version', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

  // Get the build command parser and add options to it
  final buildCommand = parser.commands['build'];
  if (buildCommand != null) {
    buildCommand
      ..addFlag('uat', negatable: false)
      ..addFlag('clean', negatable: false);
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
      print('  ww create project name');
      print('  ww generate api [options]');
      print('  ww update');
      print('  ww build [apk|aab|ios] [--uat] [--clean]');
      print('  Options:');
      print('    --uat          # Build in UAT mode with timestamp');
      print('    --clean        # Clear build directory before building');
      print('  Examples:');
      print('    ww build apk                # Build APK in production mode');
      print('    ww build apk aab            # Build APK and AAB in production mode');
      print('    ww build apk --uat          # Build APK in UAT mode');
      print('    ww build apk aab ios --uat --clean # Build all platforms in UAT mode and clear build directory');
      print('  ww open [ios|android|build|root]');
      print('  ww -v, --version');
      print('  ww -h, --help');
      return;
    }
    
    final command = results.command;
    if (command == null) {
      print('Error: No command specified');
      return;
    }
    
    switch (command.name) {
      case 'create':
        await w.handleCreateCommand(command.arguments);
        break;
      case 'generate':
        await w.handleGenerateCommand(command.arguments);
        break;
      case 'update':
        await w.handleUpdateCommand();
        break;
      case 'build':
        // 构建参数列表，包括平台和选项
        final buildArgs = List<String>.from(command.arguments);
        if (command['uat'] as bool) {
          buildArgs.add('--uat');
        }
        if (command['clean'] as bool) {
          buildArgs.add('--clean');
        }
        await w.handleBuildCommand(buildArgs);
        break;
      case 'open':
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
