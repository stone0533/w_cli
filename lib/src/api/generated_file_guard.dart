/// 覆盖前的手写成员检测。
///
/// `repository.dart` / `data_source_mixin.dart` 每次由生成器整份重写，
/// 但用户很自然会在里面加业务方法（repository 本来就是写查询的地方）。
/// 直接覆盖等于静默删代码，所以在写之前比对：
///
/// - 文件里已有的成员（[declaredMemberNames]）
/// - 生成器准备写的成员
///
/// 差集非空就拒绝写入，除非显式 `--force`。
library;

/// 从类体里抽取成员名。
///
/// 只看**恰好两个空格缩进**的类级声明——4 个以上是方法体内部，不算成员；
/// 同时跳过注释、注解行与构造函数（`AppRepository()` 没有类型前缀，不参与比对）。
Set<String> declaredMemberNames(String source) {
  final names = <String>{};
  var inBlockComment = false;

  for (final rawLine in source.split('\n')) {
    var line = rawLine;

    if (inBlockComment) {
      final end = line.indexOf('*/');
      if (end < 0) {
        continue;
      }
      line = line.substring(end + 2);
      inBlockComment = false;
    }

    final blockStart = line.indexOf('/*');
    if (blockStart >= 0) {
      final end = line.indexOf('*/', blockStart + 2);
      if (end >= 0) {
        line = line.substring(0, blockStart) + line.substring(end + 2);
      } else {
        line = line.substring(0, blockStart);
        inBlockComment = true;
      }
    }

    final commentStart = line.indexOf('//');
    if (commentStart >= 0) {
      line = line.substring(0, commentStart);
    }

    // 类体成员固定两空格缩进；三空格以上属于方法体
    if (!line.startsWith('  ') || line.startsWith('   ')) {
      continue;
    }

    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('}') || trimmed.startsWith('@')) {
      continue;
    }

    final match = _memberPattern.firstMatch(trimmed);
    if (match != null) {
      names.add(match.group(1)!);
    }
  }

  return names;
}

/// 生成器不认识的成员 = 手写内容。
Set<String> handwrittenMembers({
  required String existingContent,
  required String generatedContent,
}) {
  return declaredMemberNames(existingContent)
      .difference(declaredMemberNames(generatedContent));
}

final _memberPattern = RegExp(
  r'^(?:static\s+)?(?:final\s+|const\s+|late\s+)?'
  r'[A-Za-z_][\w<>?,\s.\[\]]*?\s+'
  r'([A-Za-z_]\w*)\s*[\(=;]',
);
