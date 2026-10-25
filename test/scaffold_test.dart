import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/api/scaffolder.dart';

/// `ww api init` 的产物必须与迁移前 `api.sh init` 逐字节一致——
/// golden 取自 shell 版本，是 ADR-0002 Phase 1 的闸门。
void main() {
  late Directory project;
  late String root;

  setUp(() {
    project = Directory.systemTemp.createTempSync('w_cli_scaffold');
    root = project.path;
    Directory('$root/lib/app/w').createSync(recursive: true);
    File('$root/lib/app/w/toolkit.dart').writeAsStringSync('// barrel\n');
    File('$root/pubspec.yaml').writeAsStringSync('''
name: demo
dependencies:
  retrofit: ^4.0.0
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
  retrofit_generator: ^8.0.0
''');
  });

  tearDown(() => project.deleteSync(recursive: true));

  String read(String relative) => File('$root/$relative').readAsStringSync();

  const expectedFiles = {
    'client.dart': 'lib/app/data/sources/client.dart',
    'paths.dart': 'lib/app/data/sources/paths.dart',
    'data_source.dart': 'lib/app/data/sources/remote/data_source.dart',
    'data_source_mixin.dart':
        'lib/app/data/sources/remote/data_source_mixin.dart',
    'repository.dart': 'lib/app/data/sources/repository.dart',
  };

  group('产物与 golden 一致', () {
    for (final entry in expectedFiles.entries) {
      test(entry.key, () {
        expect(ApiScaffolder(root: root).run(), 0);
        expect(
          read(entry.value),
          File(
            'test/shell/fixtures/scaffold/${entry.key}.expected',
          ).readAsStringSync(),
        );
      });
    }
  });

  test('重复运行不改变任何文件', () {
    expect(ApiScaffolder(root: root).run(), 0);
    final first = {for (final path in expectedFiles.values) path: read(path)};

    expect(ApiScaffolder(root: root).run(), 0);
    for (final entry in first.entries) {
      expect(read(entry.key), entry.value, reason: entry.key);
    }
  });

  test('已存在的文件不会被覆盖', () {
    expect(ApiScaffolder(root: root).run(), 0);
    File(
      '$root/lib/app/data/sources/paths.dart',
    ).writeAsStringSync('class ApiPath {}\n');

    expect(ApiScaffolder(root: root).run(), 0);
    expect(read('lib/app/data/sources/paths.dart'), 'class ApiPath {}\n');
  });

  test('data_source.dart 有 marker 时同步成当前项目的导入', () {
    expect(ApiScaffolder(root: root).run(), 0);

    final path = '$root/lib/app/data/sources/remote/data_source.dart';
    final stale = read('lib/app/data/sources/remote/data_source.dart')
        .replaceFirst(
          "import 'package:demo/app/w/toolkit.dart';",
          "import 'package:w_tools/w.dart';",
        );
    File(path).writeAsStringSync('$stale\nclass HandWritten {}\n');

    expect(ApiScaffolder(root: root).run(), 0);
    final synced = read('lib/app/data/sources/remote/data_source.dart');
    expect(synced, contains("import 'package:demo/app/w/toolkit.dart';"));
    expect(synced, contains('class HandWritten {}'));
  });

  test('没有 marker 的 data_source.dart 一个字节都不改', () {
    final path = '$root/lib/app/data/sources/remote/data_source.dart';
    Directory('$root/lib/app/data/sources/remote').createSync(recursive: true);
    const handwritten =
        "import 'package:w_tools/w.dart';\n\nclass OnlyMine {}\n";
    File(path).writeAsStringSync(handwritten);

    expect(ApiScaffolder(root: root).run(), 0);
    expect(File(path).readAsStringSync(), handwritten);
  });

  test('没有聚合入口时回退到 meta 包（与 Dart 生成器同一套规则）', () {
    File('$root/lib/app/w/toolkit.dart').deleteSync();

    expect(ApiScaffolder(root: root).run(), 0);
    expect(
      read('lib/app/data/sources/remote/data_source.dart'),
      contains("import 'package:w_tools/w.dart';"),
    );
    expect(
      read('lib/app/data/sources/repository.dart'),
      contains("import 'package:w_tools/w.dart';"),
    );
  });
}
