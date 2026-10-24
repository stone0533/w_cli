/// `ww api` 的子命令解析（纯函数，方便测试）。
///
/// 语法：
///   ww api                  生成 client.dart 对应的 data_source_mixin / repository
///   ww api generate | g     同上，显式写法
///   ww api init             初始化 lib/app/data 目录与模板
///   ww api models           从 w_json/*.json 生成模型
///   ww api models --force   忽略增量检查，全量重新生成
///
/// 旧的 `--init` / `--models` / `--full` 不再支持，只给一句指路。
library;

enum ApiMode { generate, init, models }

class ApiInvocation {
  const ApiInvocation({required this.mode, this.force = false});

  final ApiMode mode;
  final bool force;
}

/// 用法错误：调用方负责打印并以 2 退出。
class ApiUsageError implements Exception {
  ApiUsageError(this.message);

  final String message;
}

const String apiUsage = '''
用法:
  ww api                      生成 client.dart 对应的数据源与仓库代码
  ww api generate | g         同上（显式写法）
  ww api init                 初始化 lib/app/data 目录与模板文件
  ww api models               从 w_json/*.json 生成模型
  ww api models --force       忽略增量检查，全量重新生成模型
选项:
  --force                     配合 models：全量重新生成
  -d, --debug                 输出调试日志（init / models 传给脚本）''';

/// 把命令行参数解析成 [ApiInvocation]；非法用法抛 [ApiUsageError]。
ApiInvocation resolveApiArgs(List<String> args) {
  final positionals = <String>[];
  var force = false;

  for (final arg in args) {
    switch (arg) {
      case '--force':
        force = true;
        continue;
      case '-d':
      case '--debug':
        // 调试开关由调用方单独处理，这里只跳过
        continue;
      case '--init':
      case '--models':
      case '--full':
        throw ApiUsageError(legacyFlagHintFor(arg)!);
      default:
        if (arg.startsWith('-')) {
          throw ApiUsageError('未知选项: $arg\n\n$apiUsage');
        }
        positionals.add(arg);
    }
  }

  if (positionals.length > 1) {
    throw ApiUsageError('子命令只能给一个，收到: ${positionals.join(' ')}\n\n$apiUsage');
  }

  final mode = switch (positionals.isEmpty ? 'generate' : positionals.single) {
    'generate' || 'g' => ApiMode.generate,
    'init' => ApiMode.init,
    'models' => ApiMode.models,
    final other => throw ApiUsageError('未知子命令: $other\n\n$apiUsage'),
  };

  if (force && mode != ApiMode.models) {
    throw ApiUsageError('--force 只能配合 models 使用\n\n$apiUsage');
  }

  return ApiInvocation(mode: mode, force: force);
}

const Map<String, String> _legacyFlags = {
  '--init': 'ww api init',
  '--models': 'ww api models',
  '--full': 'ww api models --force',
};

/// 旧参数 -> 新写法的一行指路；不是旧参数则返回 null。
String? legacyFlagHint(String message) {
  for (final entry in _legacyFlags.entries) {
    if (message.contains(entry.key)) {
      return legacyFlagHintFor(entry.key);
    }
  }
  return null;
}

String? legacyFlagHintFor(String flag) {
  final replacement = _legacyFlags[flag];
  if (replacement == null) {
    return null;
  }
  return '$flag 已改成子命令，请改用：$replacement';
}
