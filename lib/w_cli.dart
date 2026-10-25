import 'src/cli/script_runner.dart';
import 'src/version.dart';

export 'src/api/api_cli.dart';
// 保持 package:w_cli/w_cli.dart 的公开面（测试与 bin 都在用）
export 'src/cli/script_runner.dart';
export 'src/cli/validators.dart';
export 'src/commands/api_command.dart';
export 'src/commands/build_command.dart';
export 'src/commands/clean_command.dart';
export 'src/commands/create_command.dart';
export 'src/commands/open_command.dart';
export 'src/commands/update_command.dart';

/// 获取当前版本号
/// 从自动生成的版本文件中读取版本号
String getVersionFromPubspec() {
  return version;
}

/// 单元测试辅助函数
/// 验证版本号格式是否正确
/// [version] - 版本号
/// 返回验证结果

/// 单元测试辅助函数
/// 验证脚本路径是否存在
/// [scriptName] - 脚本文件名称
/// 返回验证结果
Future<bool> scriptExists(String scriptName) async {
  try {
    await getScriptPath(scriptName);
    return true;
  } catch (e) {
    return false;
  }
}

/// 单元测试辅助函数
/// 验证项目名称是否有效
/// [projectName] - 项目名称
/// 返回验证结果
