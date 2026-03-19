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
    ..addFlag('version', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

  try {
    final results = parser.parse(arguments);
    
    if (results.wasParsed('version')) {
      print('w version 1.0.0');
      return;
    }
    
    if (results.wasParsed('help') || arguments.isEmpty) {
      print('w - A command-line tool for Flutter projects');
      print('');
      print('Usage:');
      print('  w create [command]');
      print('  w init');
      print('  w generate [command]');
      print('  w install [package]');
      print('  w remove [package]');
      print('  w update');
      print('  w generate api [options]');
      print('  w build [apk|aab|ios] [options]');
      print('  w -v, --version');
      print('  w -h, --help');
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
      default:
        print('Error: Unknown command: ${command.name}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
