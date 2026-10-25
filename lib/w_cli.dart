/// `w_cli` 的公开出口。
///
/// 真正的能力都在 `src/` 下，这里只做 re-export，方便：
///
/// - `bin/w_cli.dart` 统一从 `package:w_cli/w_cli.dart` 取命令处理器
/// - 外部脚本按需复用其中的工具（例如 [ProcessRunner]、[Cli]、[executeScript]）
///
/// 想了解命令与行为，看 `docs/commands.md`；想了解设计取舍，看 `docs/adr/`。
library;

import 'src/version.dart';

export 'src/api/api_cli.dart';
// 保持 package:w_cli/w_cli.dart 的公开面（测试与 bin 都在用）
export 'src/cli/output.dart';
export 'src/cli/process.dart';
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
