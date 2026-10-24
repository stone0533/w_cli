/// JSON → Dart 模型类的渲染（纯函数）。
///
/// 从 `api.sh` 里的 python 渲染器逐条搬过来（`api.sh` 已于 ADR-0002 Phase 3b 删除），输出必须与其逐字节一致：
/// `test/fixtures/models/raw/` 是闸门。规则：
///
/// - 每个字段都加 `@JsonKey(name: '...')` 保留原始键名
/// - 对象 → 嵌套类（类名 = 父类名 + 字段名首字母大写）；命中独立类则直接引用
/// - 数组 → 按首元素推断；对象取独立类或生成 `List<Child>`，空数组/嵌套数组 → `List<dynamic>`
/// - 字段名按 Dart 标识符规则转换，冲突时追加 `_`
library;

const Set<String> _reserved = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
  'implements', 'import', 'library', 'mixin', 'part', 'typedef', 'abstract',
  'covariant', 'deferred', 'dynamic', 'export', 'extension', 'external',
  'factory', 'get', 'set', 'operator', 'static', 'async', 'await', 'yield',
  'sync', 'required', 'late',
};

/// `w_json.config` 里声明的独立类：类名 + 该 JSON 节点的键集合（排序后比较）
class StandaloneClass {
  const StandaloneClass(this.name, this.keys);

  final String name;
  final List<String> keys;

  bool matches(Map<String, dynamic> node) {
    final sorted = node.keys.toList()..sort();
    if (sorted.length != keys.length) {
      return false;
    }
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i] != keys[i]) {
        return false;
      }
    }
    return true;
  }
}

/// JSON 键 → 合法 Dart 字段名（原始键名由 `@JsonKey` 保留）
String dartFieldName(String raw) {
  var name = raw.replaceAll('-', '_');
  name = name.replaceAll(RegExp(r'[^0-9A-Za-z_]'), '_');
  name = name.replaceAllMapped(
    RegExp(r'_([A-Za-z])'),
    (match) => match.group(1)!.toUpperCase(),
  );
  if (name.isNotEmpty) {
    name = name[0].toLowerCase() + name.substring(1);
  }
  if (name.isNotEmpty && RegExp(r'^[0-9]').hasMatch(name)) {
    name = 'f_$name';
  }
  if (_reserved.contains(name)) {
    name = '${name}_';
  }
  return name;
}

/// 渲染一个类及其所有嵌套类；返回类块列表（父类在前，深度优先）。
List<String> renderModelClasses(
  String className,
  Object? data,
  List<StandaloneClass> standalones,
) {
  Object? root = data;
  if (root is List) {
    root = root.isEmpty ? null : root.first;
  }
  if (root is! Map<String, dynamic>) {
    root = <String, dynamic>{};
  }
  return _render(className, root, standalones);
}

List<String> _render(
  String name,
  Map<String, dynamic> obj,
  List<StandaloneClass> standalones,
) {
  final fields = <_Field>[];
  final nested = <MapEntry<String, Map<String, dynamic>>>[];
  final used = <String>{};

  for (final entry in obj.entries) {
    var fieldName = dartFieldName(entry.key);
    while (used.contains(fieldName)) {
      fieldName = '${fieldName}_';
    }
    used.add(fieldName);

    final value = entry.value;
    late final String type;

    if (value is Map<String, dynamic>) {
      final matched = _matchStandalone(value, standalones);
      if (matched != null) {
        type = matched;
      } else {
        final child = name + _cap(fieldName);
        type = child;
        nested.add(MapEntry(child, value));
      }
    } else if (value is List) {
      final first = value.isEmpty ? null : value.first;
      if (first is Map<String, dynamic>) {
        final matched = _matchStandalone(first, standalones);
        if (matched != null) {
          type = 'List<$matched>';
        } else {
          final child = name + _cap(fieldName);
          type = 'List<$child>';
          nested.add(MapEntry(child, first));
        }
      } else if (first == null || first is List) {
        type = 'List<dynamic>';
      } else {
        type = 'List<${_scalarType(first)}>';
      }
    } else {
      type = _scalarType(value);
    }

    fields.add(_Field(entry.key, type, fieldName));
  }

  final lines = <String>['@JsonSerializable()', 'class $name extends Object {'];
  if (fields.isNotEmpty) {
    lines.add('');
  }
  for (final field in fields) {
    lines.add("  @JsonKey(name: '${_escape(field.key)}')");
    lines.add('  ${field.type}? ${field.name};');
  }
  final params = fields.map((field) => 'this.${field.name}').join(', ');
  lines.add('  $name($params);');
  lines.add('');
  lines.add(
    '  factory $name.fromJson(Map<String, dynamic> srcJson) => _\$${name}FromJson(srcJson);',
  );
  lines.add('  Map<String, dynamic> toJson() => _\$${name}ToJson(this);');
  lines.add('}');

  final blocks = <String>[lines.join('\n')];
  for (final child in nested) {
    blocks.addAll(_render(child.key, child.value, standalones));
  }
  return blocks;
}

class _Field {
  const _Field(this.key, this.type, this.name);

  final String key;
  final String type;
  final String name;
}

String? _matchStandalone(
  Map<String, dynamic> obj,
  List<StandaloneClass> standalones,
) {
  for (final candidate in standalones) {
    if (candidate.matches(obj)) {
      return candidate.name;
    }
  }
  return null;
}

String _cap(String name) {
  if (name.isEmpty) {
    return name;
  }
  return name[0].toUpperCase() + name.substring(1);
}

String _scalarType(Object? value) {
  if (value is bool) {
    return 'bool';
  }
  if (value is int) {
    return 'int';
  }
  if (value is double) {
    return 'double';
  }
  return 'String';
}

String _escape(String text) {
  return text.replaceAll('\\', r'\\').replaceAll("'", r"\'");
}
