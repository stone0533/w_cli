/// JSON → Dart 模型类的渲染（纯函数）。
///
/// 从 `api.sh` 里的 python 渲染器逐条搬过来（`api.sh` 已于 ADR-0002 Phase 3b 删除），输出必须与其逐字节一致：
/// `test/fixtures/models/raw/` 是闸门。规则：
///
/// - 每个字段都加 `@JsonKey(name: '...')` 保留原始键名
/// - 对象 → 嵌套类（类名 = 父类名 + 字段名首字母大写）；命中独立类则直接引用
/// - 数组 → 按首元素推断；对象取独立类或生成 `List<Child>`，空数组/嵌套数组 → `List<dynamic>`
/// - 命中独立类按"任一配置样例的键集合"判定；只差几个键时给一条诊断，不静默换类型
/// - 字段名按 Dart 标识符规则转换，冲突时追加 `_`
library;

const Set<String> _reserved = {
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'implements',
  'import',
  'library',
  'mixin',
  'part',
  'typedef',
  'abstract',
  'covariant',
  'deferred',
  'dynamic',
  'export',
  'extension',
  'external',
  'factory',
  'get',
  'set',
  'operator',
  'static',
  'async',
  'await',
  'yield',
  'sync',
  'required',
  'late',
};

/// `w_json.config` 里声明的独立类：类名 + 每一份样例的键集合（排序后比较）。
///
/// 同一个类名可以挂多份样例（`xxxDetails.json` 与 `xxxList.json` 这种）：
/// 命中**任意一份**即视为该类型。类的形状由 `ModelsGenerator` 把各份样例
/// 合并后给出，所以列表样例多出来的字段会进入共享类，而不是让列表这边
/// 静默退化成嵌套类。
class StandaloneClass {
  const StandaloneClass(this.name, this.signatures);

  final String name;

  /// 每份样例各自的键集合（已排序）。只留下一份的话，另一边只要多/少一个
  /// 字段就匹配不上，产物会悄无声息地换类型——这正是要避免的。
  final List<List<String>> signatures;

  bool matches(Map<String, dynamic> node) {
    final sorted = node.keys.toList()..sort();
    return signatures.any((candidate) => _sameKeys(candidate, sorted));
  }
}

bool _sameKeys(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
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
///
/// [sourceName] 只用于诊断文案（例如 `couponList.json`）；[onDiagnostic]
/// 在"某个对象差点命中独立类但差几个键"时被调用。
List<String> renderModelClasses(
  String className,
  Object? data,
  List<StandaloneClass> standalones, {
  String? sourceName,
  void Function(String message)? onDiagnostic,
}) {
  Object? root = data;
  if (root is List) {
    root = root.isEmpty ? null : root.first;
  }
  if (root is! Map<String, dynamic>) {
    root = <String, dynamic>{};
  }
  return _render(className, root, standalones, sourceName, onDiagnostic);
}

List<String> _render(
  String name,
  Map<String, dynamic> obj,
  List<StandaloneClass> standalones,
  String? sourceName,
  void Function(String message)? onDiagnostic,
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
        _reportNearMiss(
          value,
          standalones,
          generatedClass: child,
          sourceName: sourceName,
          where: '字段 $fieldName',
          onDiagnostic: onDiagnostic,
        );
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
          _reportNearMiss(
            first,
            standalones,
            generatedClass: child,
            sourceName: sourceName,
            where: '字段 $fieldName 的元素',
            onDiagnostic: onDiagnostic,
          );
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
    blocks.addAll(
      _render(child.key, child.value, standalones, sourceName, onDiagnostic),
    );
  }
  return blocks;
}

/// 与某个独立类的形状只差几个键时报一条诊断。
///
/// 只在「一边是另一边的真子集/真超集」时提示，避免把真正的新结构也喊出来；
/// 这是"样例漂移导致静默换类型"唯一能被看见的出口。
void _reportNearMiss(
  Map<String, dynamic> node,
  List<StandaloneClass> standalones, {
  required String generatedClass,
  required String? sourceName,
  required String where,
  required void Function(String message)? onDiagnostic,
}) {
  if (onDiagnostic == null) {
    return;
  }
  final near = _nearMiss(node, standalones);
  if (near == null) {
    return;
  }
  final diff = <String>[
    if (near.extra.isNotEmpty) '多 ${near.extra.join(', ')}',
    if (near.missing.isNotEmpty) '少 ${near.missing.join(', ')}',
  ].join('；');
  final origin = sourceName == null ? '' : '$sourceName ';
  onDiagnostic(
    '$origin$where 与独立类 ${near.target.name} 的形状不一致'
    '（$diff），已生成嵌套类 $generatedClass。'
    '若它应复用 ${near.target.name}，请把这些键补进 w_json.config 里 '
    '${near.target.name} 的任一配置样例，或把该文件也挂到 ${near.target.name} 下。',
  );
}

/// 找"最接近但没命中"的独立类。
///
/// 只认「对象比某份样例**多**几个键」这一种关系：这正是"给样例加字段忘了同步"
/// 的形态。反过来（对象比样例少）绝大多数是本来就不相干的另一个结构，
/// 报出来只会淹没真正的信号——`memberMerchantList` 的 `merchantInfo` 就是例子。
({StandaloneClass target, List<String> extra, List<String> missing})? _nearMiss(
  Map<String, dynamic> node,
  List<StandaloneClass> standalones,
) {
  final keys = node.keys.toSet();
  ({StandaloneClass target, List<String> extra, List<String> missing})? best;
  var bestScore = 1 << 30;

  for (final candidate in standalones) {
    for (final signature in candidate.signatures) {
      final signatureSet = signature.toSet();
      final extra = keys.difference(signatureSet).toList()..sort();
      final missing = signatureSet.difference(keys).toList()..sort();
      if (extra.isEmpty || missing.isNotEmpty) {
        continue; // 已命中，或不是"只多不少"的情况
      }
      final score = extra.length + missing.length;
      if (score < bestScore) {
        bestScore = score;
        best = (target: candidate, extra: extra, missing: missing);
      }
    }
  }
  return best;
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
