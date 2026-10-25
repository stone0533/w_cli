import 'dart:io';

/// 统一的终端输出。
///
/// 约定（与 `lib/sh/build.sh` 一致）：
/// - 每个命令有开始/结束标记（[begin] / [end]）
/// - 阶段用 [step]，结果用 [ok]，过程用 [info]，排障细节用 [detail]
/// - [detail] 只在 `-d` / `--verbose` 下显示
/// - 前缀固定 `[INFO]` / `[WARN]` / `[ERROR]`，不用 emoji（成败由退出码与末行说明）
/// - 颜色只在终端（TTY）下输出；`NO_COLOR` 或管道重定向时自动关闭
class Cli {
  Cli._();

  /// `-d` / `--verbose` 打开后显示 detail
  static bool verbose = false;

  /// 是否输出 ANSI 颜色：
  /// - `CLICOLOR_FORCE=1` 强制开（CI 里想看颜色时）
  /// - `NO_COLOR` 强制关
  /// - 默认看是否 TTY（管道重定向时不输出，避免污染日志）
  static bool get color {
    final env = Platform.environment;
    if (env['NO_COLOR'] != null) {
      return false;
    }
    if (env['CLICOLOR_FORCE'] == '1') {
      return true;
    }
    return stdout.supportsAnsiEscapes;
  }

  static const _green = '\x1b[0;32m';
  static const _yellow = '\x1b[1;33m';
  static const _red = '\x1b[0;31m';
  static const _bold = '\x1b[1m';
  static const _reset = '\x1b[0m';

  static String _paint(String code, String text) =>
      color ? '$code$text$_reset' : text;

  static final Stopwatch _watch = Stopwatch();

  /// 命令开始：一行标题 + 计时起点
  static void begin(String title) {
    _watch
      ..reset()
      ..start();
    stdout.writeln(_paint(_bold, '=== $title ==='));
  }

  /// 命令结束：一行结果 + 耗时；失败时红色
  static void end({int code = 0}) {
    _watch.stop();
    final elapsed = (_watch.elapsedMilliseconds / 1000).toStringAsFixed(1);
    final label = code == 0 ? '完成' : '失败（退出码 $code）';
    final painted = code == 0
        ? _paint(_green, '=== $label（${elapsed}s）===')
        : _paint(_red, '=== $label（${elapsed}s）===');
    stdout.writeln(painted);
  }

  static void step(String message) =>
      stdout.writeln(_paint(_bold, '=== $message ==='));

  static void ok(String message) =>
      stdout.writeln('${_paint(_green, '[INFO]')} $message');

  static void info(String message) =>
      stdout.writeln('${_paint(_green, '[INFO]')} $message');

  static void warn(String message) =>
      stderr.writeln('${_paint(_yellow, '[WARN]')} $message');

  static void error(String message) =>
      stderr.writeln('${_paint(_red, '[ERROR]')} $message');

  /// 只在 verbose 下显示
  static void detail(String message) {
    if (verbose) {
      stdout.writeln('${_paint(_green, '[INFO]')} $message');
    }
  }

  /// 结尾的「细节在哪」提示（有日志文件时用）
  static void detailHint(String path) {
    if (!verbose) {
      stdout.writeln('${_paint(_green, '[INFO]')} 细节: $path（-d 可实时显示）');
    }
  }
}
