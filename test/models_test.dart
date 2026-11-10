import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/models/model_renderer.dart';
import 'package:w_cli/src/models/models_generator.dart';

/// `ww api models` 的产物必须与迁移前 `api.sh models` 逐字节一致。
/// golden 取自 shell 版本（raw = 未经 dart format 的渲染结果）。
void main() {
  Directory? project;

  DirectoryFixture newProject() {
    final dir = Directory.systemTemp.createTempSync('w_cli_models');
    project = dir;
    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: demo
dependencies:
  json_annotation: ^4.9.0
dev_dependencies:
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
''');
    return DirectoryFixture(dir.path);
  }

  tearDown(() {
    final dir = project;
    if (dir != null && dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

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

  File modelFile(DirectoryFixture fixture, String name) =>
      File('${fixture.root}/lib/app/data/models/$name.dart');

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

  group('同类名多份样例合并', () {
    test('列表样例多出的字段进入共享类，列表仍复用独立类', () async {
      final fixture = newProject();
      fixture.addJsonText(
        'orderDetail.json',
        '{"data": {"order": {"id": 1, "total": 9.5}}}',
      );
      fixture.addJsonText(
        'orderList.json',
        '{"data": {"list": [{"id": 1, "total": 9.5, "extra": "x"}]}}',
      );
      fixture.addConfig(
        '# Order\norderDetail.json data.order\norderList.json data.list\n',
      );

      expect(await generate(fixture), 0);

      // 详情样例 + 列表样例合成同一份 Order：新键按出现顺序追加
      final order = generated(fixture, 'order');
      expect(order, contains('class Order extends Object'));
      expect(order, contains("@JsonKey(name: 'extra')"));
      expect(order, contains('String? extra;'));

      // 两边都命中同一个独立类，不再各自造嵌套类
      expect(generated(fixture, 'order_detail'), contains('Order? order;'));
      final list = generated(fixture, 'order_list');
      expect(list, contains('List<Order>? list;'));
      expect(list, contains("import './order.dart';"));
      expect(list, isNot(contains('OrderListResultDataList')));
    });

    test('样例完全一致时产物与单份逐字节相同', () async {
      final fixture = newProject();
      fixture.addJsonText(
        'a.json',
        '{"data": {"customer": {"cid": 7, "name": "n"}}}',
      );
      fixture.addJsonText(
        'b.json',
        '{"data": {"customer": {"cid": 7, "name": "n"}}}',
      );
      fixture.addConfig(
        '# Customer\na.json data.customer\nb.json data.customer\n',
      );

      expect(await generate(fixture), 0);
      expect(
        generated(fixture, 'customer').trimRight(),
        expected('standalone/expected', 'customer').trimRight(),
      );
    });

    test('样例字段类型冲突时退出 1，不写产物', () async {
      final fixture = newProject();
      fixture.addJsonText('a.json', '{"data": {"item": {"id": 1}}}');
      fixture.addJsonText('b.json', '{"data": {"list": [{"id": "1"}]}}');
      fixture.addConfig('# Item\na.json data.item\nb.json data.list\n');

      expect(await generate(fixture), 1);
      expect(modelFile(fixture, 'item').existsSync(), isFalse);
      expect(modelFile(fixture, 'b').existsSync(), isFalse);
    });

    test('样例是空数组时报错', () async {
      final fixture = newProject();
      fixture.addJsonText('items.json', '{"data": {"list": []}}');
      fixture.addConfig('# Item\nitems.json data.list\n');

      expect(await generate(fixture), 1);
    });

    test('配置行指向不存在的节点时报错', () async {
      final fixture = newProject();
      fixture.addJsonText('item.json', '{"data": {"item": {"id": 1}}}');
      fixture.addConfig('# Item\nitem.json data.missing\n');

      expect(await generate(fixture), 1);
    });

    test('多份样例里只有一份比产物新时也会重新生成独立类', () async {
      final fixture = newProject();
      fixture.addJsonText('a.json', '{"data": {"item": {"id": 1}}}');
      fixture.addJsonText(
        'b.json',
        '{"data": {"item": {"id": 1, "note": "n"}}}',
      );
      fixture.addConfig('# Item\na.json data.item\nb.json data.item\n');

      expect(await generate(fixture), 0);
      expect(generated(fixture, 'item'), contains("@JsonKey(name: 'note')"));

      // 把产物时间拨回，只让第二份样例保持“更新”
      final item = modelFile(fixture, 'item');
      final old = DateTime.now().subtract(const Duration(minutes: 5));
      item.setLastModifiedSync(old);
      File('${fixture.root}/w_json/a.json').setLastModifiedSync(old);
      File('${fixture.root}/w_json/b.json').setLastModifiedSync(DateTime.now());

      expect(await generate(fixture, force: false), 0);
      expect(generated(fixture, 'item'), contains("@JsonKey(name: 'note')"));
    });
  });

  group('独立类诊断', () {
    test('对象比样例多出字段时给出近似未命中诊断', () {
      final messages = <String>[];
      final blocks = renderModelClasses(
        'Demo',
        {
          'data': {
            'item': {'a': 1, 'b': 2, 'c': 3, 'd': 4},
          },
        },
        [
          StandaloneClass('Item', [
            ['a', 'b', 'c'],
          ]),
        ],
        sourceName: 'demo.json',
        onDiagnostic: messages.add,
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('Item'));
      expect(messages.single, contains('多 d'));
      expect(messages.single, contains('demo.json'));
      expect(blocks.join('\n'), contains('class DemoDataItem'));
    });

    test('对象只是样例的子集时不报（避免误伤不相干结构）', () {
      final messages = <String>[];
      renderModelClasses(
        'Demo',
        {
          'data': {
            'item': {'a': 1},
          },
        },
        [
          StandaloneClass('Item', [
            ['a', 'b', 'c'],
          ]),
        ],
        sourceName: 'demo.json',
        onDiagnostic: messages.add,
      );

      expect(messages, isEmpty);
    });

    test('形状毫不相干时不误报', () {
      final messages = <String>[];
      renderModelClasses(
        'Demo',
        {
          'data': {
            'item': {'a': 1},
          },
        },
        [
          StandaloneClass('Item', [
            ['x', 'y'],
          ]),
        ],
        onDiagnostic: messages.add,
      );

      expect(messages, isEmpty);
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

  void addJsonText(String name, String content) {
    Directory('$root/w_json').createSync(recursive: true);
    File('$root/w_json/$name').writeAsStringSync(content);
  }

  void addConfig(String content) {
    Directory('$root/w_json').createSync(recursive: true);
    File('$root/w_json/w_json.config').writeAsStringSync(content);
  }
}
