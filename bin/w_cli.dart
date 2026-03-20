import 'package:args/args.dart';
import 'package:w_cli/w_cli.dart' as w;

void main(List<String> arguments) {
  final parser = ArgParser()
   ..addCommand('create')
    ..addCommand('init') 
    ..addCommand('generate')
    ..addCommand('install')
    ..addCommand('remove')
    ..addCommand('update')
    ..addCommand('build')
    ..addCommand('open')
    ..addFlag('version', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

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
      print('  ww init');
      print('  ww generate [command]');
      print('  ww install [package]');
      print('  ww remove [package]');
      print('  ww update');
      print('  ww generate api [options]');
      print('  ww build [apk|aab|ios] [--uat] [--clean]');
      print('  Options:');
      print('    --uat          # Build in UAT mode with timestamp');
      print('    --clean        # Clear build directory before building');
      print('  Examples:');
      print('    ww build apk                # Build APK in production mode');
      print('    ww build apk aab            # Build APK and AAB in production mode');
      print('    ww build apk --uat          # Build APK in UAT mode');
      print('    ww build apk aab ios --uat --clean # Build all platforms in UAT mode and clear build directory');
      print('  ww open [ios|android|build]');
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
        w.handleCreateCommand(command.arguments);
        break;
      case 'init':
        w.handleInitCommand();
        break;
      case 'generate':
        w.handleGenerateCommand(command.arguments);
        break;
      case 'install':
        w.handleInstallCommand(command.arguments);
        break;
      case 'remove':
        w.handleRemoveCommand(command.arguments);
        break;
      case 'update':
        w.handleUpdateCommand();
        break;
      case 'build':
        w.handleBuildCommand(command.arguments);
        break;
      case 'open':
        w.handleOpenCommand(command.arguments);
        break;
      default:
        print('Error: Unknown command: ${command.name}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
