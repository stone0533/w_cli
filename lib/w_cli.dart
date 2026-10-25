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

/// 当前版本号（来自自动生成的 `src/version.dart`）
String getVersionFromPubspec() => version;
