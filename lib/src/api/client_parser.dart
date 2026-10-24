/// 解析 `client.dart`（retrofit 风格的抽象类），得到方法签名。
///
/// 为什么要用 Dart 写：这套解析以前是 shell 正则，`Future<Map<String, dynamic>>`
/// 会被截断，注解参数名全部落到 fallback，而且失败是静默的。这里用一个最小的
/// 词法扫描器替代正则，遇到看不懂的写法就报错，而不是生成半截文件。
library;

/// 方法参数：类型来自 client.dart 原文。
class ApiParam {
  const ApiParam({required this.name, required this.type});

  final String name;
  final String type;

  @override
  String toString() => '$type $name';
}

/// 一个 API 方法。
class ApiMethod {
  const ApiMethod({
    required this.name,
    required this.returnType,
    required this.params,
    this.clientId,
  });

  final String name;

  /// `Future<...>` 里的类型，可能带嵌套泛型（`Map<String, dynamic>`）。
  final String returnType;
  final List<ApiParam> params;

  /// `@ApiClientId('xxx')` 声明的自定义客户端实例名。
  final String? clientId;

  @override
  String toString() => 'Future<$returnType> $name(${params.join(', ')})';
}

/// 解析失败：告诉调用方是哪一行、为什么，而不是静默返回空列表。
class ApiParseException implements Exception {
  ApiParseException(this.message, {this.offset});

  final String message;
  final int? offset;

  @override
  String toString() =>
      offset == null ? 'ApiParseException: $message' : 'ApiParseException: $message (offset $offset)';
}

const String _clientClass = 'abstract class ApiClient';

/// 从 `client.dart` 源码里取出 `ApiClient` 的方法列表。
///
/// 只认识 retrofit 接口类里会出现的写法：`Future<T> name(params);`，
/// 参数可带注解、可选类型、可跨行。遇到无法解析的结构抛 [ApiParseException]。
List<ApiMethod> parseApiClient(String source) {
  final body = _classBody(_stripComments(source));
  final methods = <ApiMethod>[];

  var pendingClientId = '';

  var i = 0;
  while (i < body.length) {
    // 自定义客户端实例：@ApiClientId('libRest2')
    if (body.startsWith('@ApiClientId', i)) {
      final open = body.indexOf('(', i);
      if (open < 0) {
        throw ApiParseException('@ApiClientId 缺少参数', offset: i);
      }
      final close = _matchParen(body, open);
      pendingClientId = _unquote(body.substring(open + 1, close).trim());
      i = close + 1;
      continue;
    }

    if (body.startsWith('Future<', i)) {
      final parsed = _parseMethod(body, i);
      methods.add(ApiMethod(
        name: parsed.method.name,
        returnType: parsed.method.returnType,
        params: parsed.method.params,
        clientId: pendingClientId.isEmpty ? null : pendingClientId,
      ));
      pendingClientId = '';
      i = parsed.nextIndex;
      continue;
    }

    i++;
  }

  return methods;
}

class _ParsedMethod {
  _ParsedMethod(this.method, this.nextIndex);

  final ApiMethod method;
  final int nextIndex;
}

_ParsedMethod _parseMethod(String body, int start) {
  final angleStart = start + 'Future'.length;
  final angleEnd = _matchAngle(body, angleStart);
  final returnType = body.substring(angleStart + 1, angleEnd).trim();
  if (returnType.isEmpty) {
    throw ApiParseException('Future<> 里没有类型', offset: start);
  }

  var i = angleEnd + 1;
  while (i < body.length && _isSpace(body[i])) {
    i++;
  }

  final nameStart = i;
  while (i < body.length && _isIdentifierChar(body[i])) {
    i++;
  }
  if (i == nameStart) {
    throw ApiParseException('Future<$returnType> 后面没有方法名', offset: nameStart);
  }
  final name = body.substring(nameStart, i);

  while (i < body.length && _isSpace(body[i])) {
    i++;
  }
  if (i >= body.length || body[i] != '(') {
    throw ApiParseException('方法 $name 缺少参数列表', offset: i);
  }

  final paramsClose = _matchParen(body, i);
  final paramsSource = body.substring(i + 1, paramsClose);
  final params = _parseParams(paramsSource);

  var next = paramsClose + 1;
  while (next < body.length && body[next] != ';') {
    next++;
  }
  if (next >= body.length) {
    throw ApiParseException('方法 $name 缺少结尾分号', offset: paramsClose);
  }

  return _ParsedMethod(
    ApiMethod(name: name, returnType: returnType, params: params),
    next + 1,
  );
}

List<ApiParam> _parseParams(String source) {
  final params = <ApiParam>[];
  final used = <String>{};

  for (final raw in splitTopLevel(source)) {
    final parsed = _parseParam(raw);
    if (parsed == null) {
      continue;
    }

    // 同名参数（两个 @Query 曾经都叫 queries）会让生成的 Dart 非法
    var name = parsed.$1;
    var suffix = 2;
    while (used.contains(name)) {
      name = '${parsed.$1}$suffix';
      suffix++;
    }
    used.add(name);
    params.add(ApiParam(name: name, type: parsed.$2));
  }

  return params;
}

/// 返回 (名字, 类型)；空声明返回 null。
(String, String)? _parseParam(String raw) {
  var text = raw;

  // 去掉注解：@Path()、@Query('page')、@Body()
  text = text.replaceAll(RegExp(r'@[A-Za-z_]+(\s*\([^)]*\))?'), ' ');
  // 去掉默认值
  final equals = text.indexOf('=');
  if (equals >= 0) {
    text = text.substring(0, equals);
  }
  // 命名参数的花括号与修饰符
  text = text.replaceAll('{', ' ').replaceAll('}', ' ');
  text = text.trim();
  text = text.replaceFirst(RegExp(r'^(required|covariant|final|const)\s+'), '');
  text = text.trim();

  if (text.isEmpty) {
    return null;
  }

  final parts = text.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return (parts.first, 'dynamic');
  }

  // 类型里可能带空格：Map<String, dynamic> data
  final type = parts.sublist(0, parts.length - 1).join(' ');
  final name = parts.last;
  return (name, type);
}

/// 按顶层逗号切分，忽略 `<> () {} []` 里的逗号。
List<String> splitTopLevel(String source) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];

    if (char == '"' || char == "'") {
      final end = _skipString(source, i);
      buffer.write(source.substring(i, end + 1));
      i = end;
      continue;
    }

    if (char == '<' || char == '(' || char == '{' || char == '[') {
      depth++;
    } else if (char == '>' || char == ')' || char == '}' || char == ']') {
      depth--;
    }

    if (char == ',' && depth == 0) {
      parts.add(buffer.toString());
      buffer.clear();
      continue;
    }

    buffer.write(char);
  }

  if (buffer.toString().trim().isNotEmpty) {
    parts.add(buffer.toString());
  }

  return parts;
}

/// 取出 `abstract class ApiClient { ... }` 的类体。
String _classBody(String source) {
  final classAt = source.indexOf(_clientClass);
  if (classAt < 0) {
    throw ApiParseException('没有找到 `$_clientClass`');
  }

  final open = source.indexOf('{', classAt);
  if (open < 0) {
    throw ApiParseException('`$_clientClass` 后面没有 `{`', offset: classAt);
  }

  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '"' || char == "'") {
      i = _skipString(source, i);
      continue;
    }
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(open + 1, i);
      }
    }
  }

  throw ApiParseException('`$_clientClass` 的括号没有闭合', offset: open);
}

/// 去掉 `//` 与 `/* */` 注释，字符串里的内容原样保留。
String _stripComments(String source) {
  final buffer = StringBuffer();

  for (var i = 0; i < source.length; i++) {
    final char = source[i];

    if (char == '"' || char == "'") {
      final end = _skipString(source, i);
      buffer.write(source.substring(i, end + 1));
      i = end;
      continue;
    }

    if (char == '/' && i + 1 < source.length) {
      if (source[i + 1] == '/') {
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        buffer.write('\n');
        continue;
      }
      if (source[i + 1] == '*') {
        final end = source.indexOf('*/', i + 2);
        i = end < 0 ? source.length : end + 1;
        continue;
      }
    }

    buffer.write(char);
  }

  return buffer.toString();
}

/// 返回字符串字面量结束引号的下标。
int _skipString(String source, int start) {
  final quote = source[start];
  var i = start + 1;
  while (i < source.length) {
    if (source[i] == r'\') {
      i += 2;
      continue;
    }
    if (source[i] == quote) {
      return i;
    }
    i++;
  }
  throw ApiParseException('字符串没有闭合', offset: start);
}

/// `<` 的配对 `>` 下标。
int _matchAngle(String source, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '<') {
      depth++;
    } else if (char == '>') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }
  throw ApiParseException('泛型没有闭合', offset: openIndex);
}

/// `(` 的配对 `)` 下标，跳过字符串与嵌套括号。
int _matchParen(String source, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '"' || char == "'") {
      i = _skipString(source, i);
      continue;
    }
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }
  throw ApiParseException('括号没有闭合', offset: openIndex);
}

String _unquote(String text) {
  var value = text.trim();
  if (value.length >= 2 && (value.startsWith("'") || value.startsWith('"'))) {
    value = value.substring(1, value.length - 1);
  }
  return value;
}

bool _isSpace(String char) => char == ' ' || char == '\t' || char == '\n' || char == '\r';

bool _isIdentifierChar(String char) => RegExp(r'[A-Za-z0-9_$]').hasMatch(char);

/// 从任意 Dart 源码里取出 `Future<...> name` 的方法名，用于识别手写层已实现的方法。
Set<String> extractFutureMethodNames(String source) {
  final names = <String>{};
  final text = _stripComments(source);

  var i = 0;
  while (i < text.length) {
    if (!text.startsWith('Future<', i)) {
      i++;
      continue;
    }
    try {
      final angleEnd = _matchAngle(text, i + 'Future'.length);
      var cursor = angleEnd + 1;
      while (cursor < text.length && _isSpace(text[cursor])) {
        cursor++;
      }
      final start = cursor;
      while (cursor < text.length && _isIdentifierChar(text[cursor])) {
        cursor++;
      }
      if (cursor > start) {
        names.add(text.substring(start, cursor));
      }
      i = cursor;
    } on ApiParseException {
      i++;
    }
  }

  return names;
}
