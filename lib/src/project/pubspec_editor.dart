/// pubspec.yaml 的小编辑：补 `flutter.assets` 配置。
///
/// 单独抽出来是为了能单测——**第 56 行的 `flutter:` 是依赖，不是配置段**：
///
/// ```yaml
/// dependencies:
///   flutter:            # ← 这里
///     sdk: flutter
///
/// flutter:              # ← 真正的配置段（列 0）
///   uses-material-design: true
/// ```
///
/// 只认**列 0** 的 `flutter:`；按 trim 后比较会把 assets 塞进 dependencies，
/// 直接写出非法 pubspec（`A dependency specification must be a string or a mapping`）。
library;

const List<String> assetsItems = ['- .env', '- assets/', '- assets/images/'];

/// 返回补好 assets 的 pubspec 文本。
String ensureAssets(String pubspec) {
  final lines = pubspec.split('\n');

  // 已经是正确的结构（存在于 flutter: 段下的 assets:）→ 补齐缺项
  final flutterIndex = lines.indexWhere((line) => line == 'flutter:');
  if (flutterIndex < 0) {
    final trimmed = pubspec.endsWith('\n')
        ? pubspec.substring(0, pubspec.length - 1)
        : pubspec;
    return '$trimmed\n\nflutter:\n  assets:\n'
        '${assetsItems.map((item) => '    $item').join('\n')}\n';
  }

  // 找 flutter 段的结束（下一个列 0 的非空行）
  var sectionEnd = lines.length;
  for (var i = flutterIndex + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.isNotEmpty && !line.startsWith(' ')) {
      sectionEnd = i;
      break;
    }
  }

  // 段内是否已有 assets:
  var assetsIndex = -1;
  for (var i = flutterIndex + 1; i < sectionEnd; i++) {
    if (RegExp(r'^\s+assets:\s*$').hasMatch(lines[i])) {
      assetsIndex = i;
      break;
    }
  }

  final buffer = <String>[];

  if (assetsIndex < 0) {
    // 没有 assets：插到 flutter 段末尾（去掉段尾空行，保持格式干净）
    var insertAt = sectionEnd;
    while (insertAt > flutterIndex + 1 && lines[insertAt - 1].trim().isEmpty) {
      insertAt--;
    }
    buffer
      ..addAll(lines.sublist(0, insertAt))
      ..add('  assets:')
      ..addAll(assetsItems.map((item) => '    $item'))
      ..addAll(lines.sublist(insertAt));
    return buffer.join('\n');
  }

  // 已有 assets：保留位置，重写条目（去重 + 补齐缺项）
  var assetsEnd = assetsIndex + 1;
  while (assetsEnd < sectionEnd &&
      RegExp(r'^\s+-\s').hasMatch(lines[assetsEnd])) {
    assetsEnd++;
  }

  buffer
    ..addAll(lines.sublist(0, assetsIndex))
    ..add('  assets:')
    ..addAll(assetsItems.map((item) => '    $item'))
    ..addAll(lines.sublist(assetsEnd));
  return buffer.join('\n');
}
