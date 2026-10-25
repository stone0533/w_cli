import 'dart:io';

/// 文档自检：内部锚点、相对链接、已删除的命令/脚本。
///
/// 起因：
/// - `docs/commands.md` 的章节被误删，表格里的 `#ww-clean` 还留着 → 断链
/// - `doc/` 改名 `docs/` 后，相对链接没人复查
/// - README 里教用户用 `ww common drbb`（命令早删了）
///
/// 用法：
///   dart run tool/check_docs.dart              # 检查整个仓库
///   dart run tool/check_docs.dart docs README.md
///
/// GitHub 的锚点规则简化版：小写、去标点、空格换 `-`、保留中文；重复标题按 `-1` 递增。
Future<void> main(List<String> args) async {
  final roots = args.isEmpty ? ['.'] : args;
  final files = _collect(roots);

  var problems = 0;
  var links = 0;

  for (final file in files) {
    final raw = file.readAsStringSync();
    // 代码块/行内代码里的示例不算链接
    final body = _stripInlineCode(_stripCodeFences(raw));

    final anchors = _anchors(raw);
    for (final anchor in _anchorLinks(body)) {
      if (anchor.isEmpty) {
        continue;
      }
      links++;
      if (!anchors.contains(anchor)) {
        problems++;
        stdout.writeln('${file.path}: 断链 #$anchor');
      }
    }

    for (final target in _relativeLinks(body)) {
      links++;
      final resolved = FileSystemEntity.typeSync('${file.parent.path}/$target');
      if (resolved == FileSystemEntityType.notFound) {
        problems++;
        stdout.writeln('${file.path}: 相对链接指向不存在的路径 $target');
      }
    }

    // ADR 是历史记录，正文会正当引用已删除的脚本；文件里也可以显式豁免
    final exempt =
        file.path.contains('docs/adr/') ||
        file.path.endsWith('CHANGELOG.md') ||
        raw.contains('docs:allow-retired');
    if (!exempt) {
      for (final hit in _retiredMentions(raw)) {
        problems++;
        stdout.writeln('${file.path}: 出现已删除的东西「${hit.$1}」→ ${hit.$2}');
      }
    }
  }

  if (problems > 0) {
    stderr.writeln('文档检查失败：$problems 项（检查了 $links 个链接，${files.length} 个文件）');
    exit(1);
  }
  stdout.writeln('文档检查通过（$links 个链接，${files.length} 个文件）');
}

List<File> _collect(List<String> roots) {
  final files = <File>[];
  for (final root in roots) {
    final type = FileSystemEntity.typeSync(root);
    if (type == FileSystemEntityType.file) {
      files.add(File(root));
      continue;
    }
    final dir = Directory(root);
    if (!dir.existsSync()) {
      stderr.writeln('路径不存在: $root');
      exit(2);
    }
    for (final entry in dir.listSync(recursive: true, followLinks: false)) {
      if (entry is File && entry.path.endsWith('.md') && !_skip(entry.path)) {
        files.add(entry);
      }
    }
  }
  return files;
}

bool _skip(String path) {
  const ignored = ['.git', '.dart_tool', 'build/', 'w_build/', '.idea'];
  return ignored.any((pattern) => path.contains(pattern));
}

/// 已删除、且文档里不该再教人用的东西；第二个元素是应该写什么。
///
/// 豁免规则：`docs/adr/` 与 `CHANGELOG.md` 是历史记录，正文会正当引用已删除的东西；
/// 其它文件若必须提到历史，在任意一行写 `docs:allow-retired` 即可。
const _retired = [
  ('ww common', 'ww gen'),
  ('common drbb', 'ww gen'),
  ('lib/sh/api.sh', 'ww api（脚本已删除）'),
  ('lib/sh/setup.sh', 'ww create（脚本已删除）'),
  ('lib/sh/clean.sh', 'ww clean（脚本已删除）'),
  ('lib/sh/open.sh', 'ww open（脚本已删除）'),
  ('lib/sh/project.sh', 'ww deps（脚本已删除）'),
];

/// 同一行出现这些词时，说明是在讲历史/兼容，不算违规
const _historyMarkers = ['已删除', '旧名', '已废弃', 'deprecated', '已并入', '不再支持'];

Iterable<(String, String)> _retiredMentions(String markdown) sync* {
  for (final line in markdown.split('\n')) {
    if (_historyMarkers.any(line.contains)) {
      continue;
    }
    for (final entry in _retired) {
      if (line.contains(entry.$1)) {
        yield entry;
      }
    }
  }
}

/// 提取 `[text](#anchor)` 的锚点
Iterable<String> _anchorLinks(String markdown) sync* {
  for (final match in RegExp(r'\]\(#([^)\s]*)\)').allMatches(markdown)) {
    yield match.group(1)!;
  }
}

/// 提取 `[text](relative/path)` —— 排除 http(s)、mailto、纯锚点
Iterable<String> _relativeLinks(String markdown) sync* {
  for (final match in RegExp(r'\]\(([^)\s]+)\)').allMatches(markdown)) {
    var target = match.group(1)!.trim();
    const external = ['#', 'http://', 'https://', 'mailto:'];
    if (external.any(target.startsWith)) {
      continue;
    }
    target = target.split('#').first;
    if (target.isEmpty) {
      continue;
    }
    yield target;
  }
}

/// 去掉围栏代码块（``` ... ```）
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

/// 提取标题锚点（`#` 到 `######` 都可能被链接到）
Set<String> _anchors(String markdown) {
  final anchors = <String>{};
  final seen = <String, int>{};
  for (final line in markdown.split('\n')) {
    final match = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
    if (match == null) {
      continue;
    }
    final text = match
        .group(1)!
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll('`', '')
        .replaceAll('*', '')
        .trim();
    final base = _slug(text);
    final count = seen[base] ?? 0;
    seen[base] = count + 1;
    anchors.add(count == 0 ? base : '$base-$count');
  }
  return anchors;
}

String _slug(String text) {
  final lower = text.toLowerCase();
  final kept = lower.replaceAll(RegExp(r'[^\w\u4e00-\u9fff\- ]'), '');
  return kept.replaceAll(' ', '-');
}
