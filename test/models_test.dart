import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/models/models_generator.dart';

/// `ww api models` 的产物必须与迁移前 `api.sh models` 逐字节一致。
/// golden 取自 shell 版本（raw = 未经 dart format 的渲染结果）。
void main() {
  late Directory project;

  DirectoryFixture newProject() {
    project = Directory.systemTemp.createTempSync('w_cli_models');
    File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: demo
dependencies:
  json_annotation: ^4.9.0
dev_dependencies:
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
''');
    return DirectoryFixture(project.path);
  }

  tearDown(() => project.deleteSync(recursive: true));

  Future<int> generate(DirectoryFixture fixture, {bool force = true}) {
    return ModelsGenerator(
      root: fixture.root,
      force: force,
      formatOutput: false,
      runBuildRunner: false,
    ).generate();
  }

  String expected(String group, String name) => File(
    'test/fixtures/models/$group/$name.dart.expected',
  ).readAsStringSync();

  String generated(DirectoryFixture fixture, String name) =>
      File('${fixture.root}/lib/app/data/models/$name.dart').readAsStringSync();

  group('与 shell 产物一致', () {
    for (final json
        in Directory('test/fixtures/models').listSync().whereType<File>().where(
          (file) => file.path.endsWith('.json'),
        )) {
      final name = json.uri.pathSegments.last.replaceFirst('.json', '');
      test(name, () async {
        final fixture = newProject();
        fixture.addJson(json);

        expect(await generate(fixture), 0);
        expect(
          generated(fixture, name).trimRight(),
          expected('raw', name).trimRight(),
        );
      });
    }
  });

  group('独立类（w_json.config）', () {
    late DirectoryFixture fixture;

    setUp(() {
      fixture = newProject();
      fixture.addJson(File('test/fixtures/models/standalone/json/shop.json'));
      File(
        'test/fixtures/models/standalone/json/w_json.config',
      ).copySync('${fixture.root}/w_json/w_json.config');
    });

    test('三个文件都与 shell 产物一致', () async {
      expect(await generate(fixture), 0);
      for (final name in ['shop', 'customer', 'order']) {
        expect(
          generated(fixture, name).trimRight(),
          expected('standalone/expected', name).trimRight(),
          reason: name,
        );
      }
    });

    test('主模型 import 了被引用的独立类', () async {
      expect(await generate(fixture), 0);
      final shop = generated(fixture, 'shop');
      expect(shop, contains("import './customer.dart';"));
      expect(shop, contains("import './order.dart';"));
    });
  });

  test('增量模式：第二次跑没有变更', () async {
    final fixture = newProject();
    fixture.addJson(File('test/fixtures/models/simple.json'));

    expect(await generate(fixture), 0);
    final first = generated(fixture, 'simple');
    expect(await generate(fixture, force: false), 0);
    expect(generated(fixture, 'simple'), first);
  });

  test('force 会重写未变更的文件', () async {
    final fixture = newProject();
    fixture.addJson(File('test/fixtures/models/simple.json'));
    expect(await generate(fixture), 0);

    final path = '${fixture.root}/lib/app/data/models/simple.dart';
    File(path).writeAsStringSync('// stale\n');
    expect(await generate(fixture, force: false), 0);
    expect(File(path).readAsStringSync(), '// stale\n');

    expect(await generate(fixture), 0);
    expect(File(path).readAsStringSync(), contains('class SimpleResult'));
  });

  test('没有 json 时报错', () async {
    final fixture = newProject();
    expect(await generate(fixture), 1);
  });
}

class DirectoryFixture {
  DirectoryFixture(this.root);

  final String root;

  void addJson(File source) {
    Directory('$root/w_json').createSync(recursive: true);
    source.copySync('$root/w_json/${source.uri.pathSegments.last}');
  }
}
