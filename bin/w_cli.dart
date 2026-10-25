import 'dart:io';

import 'package:args/args.dart';
import 'package:w_cli/w_cli.dart' as w;
import 'package:w_cli/src/cli/command_spec.dart' as cli_spec;
import 'package:w_cli/src/cli/output.dart';
import 'package:w_cli/src/cli/help.dart' as cli_help;
import 'package:w_cli/src/resources.dart' as resources;

/// 主函数 - 处理命令行参数并执行相应的命令
Future<void> main(List<String> arguments) async {
  // 初始化命令行参数解析器
  final parser = ArgParser()
    ..addFlag('version', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false)
    // 全局 -d：`ww -d <命令>` 与 `ww <命令> -d` 都支持
    ..addFlag('debug', abbr: 'd', negatable: false);

  // 命令名、别名、flag/option 声明全部来自这一张表
  final specs = cli_spec.commandSpecs();
  for (final spec in specs) {
    for (final name in spec.allNames) {
      final command = parser.addCommand(name);
      for (final flag in spec.flags) {
        flag.register(command);
      }
      // 所有命令都支持 -d / --debug（以前只有 api / build 声明了）
      if (!spec.flags.any((flag) => flag.name == 'debug')) {
        command.addFlag('debug', abbr: 'd', negatable: false);
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

    // -d / --debug 打开详细输出：全局（ww -d …）或命令级（ww … -d）都算
    final rootDebug = results.wasParsed('debug') && results['debug'] == true;
    final commandDebug =
        command.options.contains('debug') && command['debug'] == true;
    if (rootDebug || commandDebug) {
      Cli.verbose = true;
    }

    // 按命令表分派：每个 handler 返回子进程退出码
    final spec = specs.firstWhere(
      (candidate) => candidate.allNames.contains(command.name),
      orElse: () => specs.first,
    );
    if (!spec.allNames.contains(command.name)) {
      Cli.error('Unknown command: ${command.name}');
      return;
    }

    // 开始/结束横幅由 Dart 侧统一打（build 自己有一套，跳过）
    if (spec.framed) {
      final tail = command.rest.isEmpty ? '' : ' ${command.rest.join(' ')}';
      Cli.begin('ww ${command.name}$tail');
    }
    exitCode = await spec.run(command);
    if (spec.framed) {
      Cli.end(code: exitCode);
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
  print('用法:');
  for (final spec in cli_spec.commandSpecs()) {
    print('  ${spec.usage}');
  }
  print('');
  print('全局: -h/--help 显示帮助 · -v/--version 版本 · -d/--debug 详细输出');
  print('');
  print('构建参数（ww build）:');
  print('  --uat  UAT 模式（文件名带时间戳）      --fresh  构建前清旧产物（旧名 --clean）');
  print('  --open 构建后打开输出目录             --name=<名>  自定义产物名');
  print('  --export-options=<文件>  iOS 导出配置');
  print('');
  print('iOS 签名（优先级从高到低）:');
  print(
    '  1. --method= --team= --bundle-id= --cert= --profile= --automatic --manual',
  );
  print('  2. w_build/ios.plist（个人覆盖）     3. ios/ExportOptions.plist（可提交）');
  print('  4. 从 ios/Runner.xcodeproj 读 DEVELOPMENT_TEAM（零配置）');
  print('  查看当前生效配置: ww build ios --show-config');
  print('');
  print(
    '环境变量: OUTPUT_DIR / PARALLEL_BUILD / MIN_BUILD_SIZE / ENABLE_NOTIFICATIONS',
  );
  print('          WW_TASK_TIMEOUT（秒，0 = 不限时）');
  print('');
  print('示例:');
  print('  ww create my_app              # 建工程');
  print('  ww api models --force         # 全量重生成模型');
  print('  ww build apk ios --uat        # 打包');
  print('  ww deps gradle --to=9.1.0     # 升 Gradle（默认只报告）');
  print('  ww ios setup                  # 生成可提交的签名配置');
  print('');
  print('别名: create/c  api/a  build/b  clean/cl  open/o  project/p  update/u');
}
