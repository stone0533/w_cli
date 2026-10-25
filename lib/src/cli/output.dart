import 'dart:io';

/// 统一的终端输出。
///
/// 约定（与 `lib/sh/build.sh` 一致）：
/// - 阶段用 [step]，结果用 [ok]，过程用 [info]，排障细节用 [detail]
/// - [detail] 只在 `-d` / `--verbose` 下显示
/// - 前缀固定 `[INFO]` / `[WARN]` / `[ERROR]`，不用 emoji（成败由退出码与末行说明）
class Cli {
  Cli._();

  /// `-d` / `--verbose` 打开后显示 detail
  static bool verbose = false;

  static void step(String message) => stdout.writeln('=== $message ===');

  static void ok(String message) => stdout.writeln('[INFO] $message');

  static void info(String message) => stdout.writeln('[INFO] $message');

  static void warn(String message) => stderr.writeln('[WARN] $message');

  static void error(String message) => stderr.writeln('[ERROR] $message');

  /// 只在 verbose 下显示
  static void detail(String message) {
    if (verbose) {
      stdout.writeln('[INFO] $message');
    }
  }

  /// 结尾的「细节在哪」提示（有日志文件时用）
  static void detailHint(String path) {
    if (!verbose) {
      stdout.writeln('[INFO] 细节: $path（-d 可实时显示）');
    }
  }
}
