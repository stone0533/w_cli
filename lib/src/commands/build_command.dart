import '../cli/help.dart';
import '../cli/script_runner.dart';

/// 处理构建命令
/// [arguments] - 命令参数
Future<int> handleBuildCommand(List<String> arguments) async {
  // 无参数时打印 ww 自己的帮助，而不是 build.sh 的英文 usage
  if (arguments.isEmpty) {
    final help = commandHelp('build');
    if (help != null) {
      print(help);
    }
    return 0;
  }

  try {
    // 执行脚本并实时显示输出
    return await executeScript(
      'build.sh',
      arguments,
      'Build completed successfully!',
      'Build failed',
    );
  } catch (e) {
    handleError(e, 'build');
    return 1;
  }
}
