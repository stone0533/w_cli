import 'dart:io';

/// 检查 Markdown 里的内部锚点链接是否都有对应标题。
///
/// 起因：`docs/commands.md` 的章节被误删后，表格里的 `#ww-clean` 之类的链接
/// 还留着——肉眼很难发现，CI 也没管。这个脚本在 CI 里跑，断链直接红。
///
/// 用法：
///   dart run tool/check_doc_anchors.dart            # 检查仓库里所有 .md
///   dart run tool/check_doc_anchors.dart doc README.md
///
/// GitHub 的锚点规则简化版：小写、去掉标点、空格换 `-`，保留字母（含中文）与数字。
Future<void> main(List<String> args) async {
  final roots = args.isEmpty ? ['.'] : args;
  final files = <File>[];
  for (final root in roots) {
    final entity = FileSystemEntity.typeSync(root);
    if (entity == FileSystemEntityType.file) {
      files.add(File(root));
      continue;
    }
    final dir = Directory(root);
    if (!dir.existsSync()) {
      stderr.writeln('路径不存在: $root');
      exit(2);
    }
    for (final entry in dir.listSync(recursive: true, followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.md')) {
        continue;
      }
      if (_skip(entry.path)) {
        continue;
      }
      files.add(entry);
    }
  }

  var broken = 0;
  var checked = 0;
  for (final file in files) {
    final content = file.readAsStringSync();
    final anchors = _anchors(content);
    // 代码块/行内代码里的 `](#x)` 是示例，不算链接
    final links = _internalLinks(_stripInlineCode(_stripCodeFences(content)));

    for (final link in links) {
      // `#` 后面是空的（纯占位）直接忽略
      if (link.isEmpty) {
        continue;
      }
      checked++;
      if (!anchors.contains(link)) {
        broken++;
        stdout.writeln('${file.path}: 断链 #$link');
      }
    }
  }

  if (broken > 0) {
    stderr.writeln('共 $broken 个断链 / 检查了 $checked 个内部链接');
    exit(1);
  }
  stdout.writeln('锚点检查通过（$checked 个内部链接，${files.length} 个文件）');
}

/// 去掉围栏代码块（``` ... ```），避免把示例里的 `](#x)` 当链接
String _stripCodeFences(String markdown) {
  final buffer = StringBuffer();
  var inFence = false;
  for (final line in markdown.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (!inFence) {
      buffer.writeln(line);
    }
  }
  return buffer.toString();
}

/// 去掉行内代码（`...`）
String _stripInlineCode(String markdown) =>
    markdown.replaceAll(RegExp(r'`[^`\n]*`'), '');

bool _skip(String path) {
  const ignored = ['.git', '.dart_tool', 'build/', 'w_build/', '.idea'];
  return ignored.any((pattern) => path.contains(pattern));
}

/// 提取标题锚点（`#` 到 `######` 都可能被链接到）
Set<String> _anchors(String markdown) {
  final anchors = <String>{};
  final seen = <String, int>{};
  for (final line in markdown.split('\n')) {
    final match = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
    if (match == null) {
      continue;
    }
    // 去掉标题里嵌的 markdown 语法（链接、行内代码、粗体）
    final text = match
        .group(1)!
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll('`', '')
        .replaceAll('*', '')
        .trim();
    final base = _slug(text);
    final count = seen[base] ?? 0;
    seen[base] = count + 1;
    // GitHub 对重复标题追加 -1 / -2
    anchors.add(count == 0 ? base : '$base-$count');
  }
  return anchors;
}

String _slug(String text) {
  final lower = text.toLowerCase();
  final kept = lower.replaceAll(RegExp(r'[^\w\u4e00-\u9fff\- ]'), '');
  return kept.replaceAll(' ', '-');
}

/// 提取 `[text](#anchor)` 形式的内部链接
Iterable<String> _internalLinks(String markdown) sync* {
  final pattern = RegExp(r'\]\(#([^)\s]*)\)');
  for (final match in pattern.allMatches(markdown)) {
    yield match.group(1)!;
  }
}
