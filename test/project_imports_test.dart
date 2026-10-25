import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:w_cli/src/api/project_imports.dart';

Directory makeProject({
  String? name,
  bool barrel = true,
  Map<String, String>? extra,
}) {
  final root = Directory.systemTemp.createTempSync('wcli_import_');
  File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(
    'name: ${name ?? 'demo_app'}\nenvironment:\n  sdk: ^3.8.0\n',
  );
  if (barrel) {
    final f = File(p.join(root.path, 'lib/app/w/toolkit.dart'));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync("export 'package:w_tools_ui/w_tools_ui.dart';\n");
  }
  extra?.forEach((rel, content) {
    final f = File(p.join(root.path, rel));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  });
  return root;
}

void main() {
  group('resolveWtoolsImport', () {
    test('有聚合入口 → 用项目自己的入口', () {
      final root = makeProject(name: 'ureward_member_app');
      expect(
        resolveWtoolsImport(projectRoot: root.path),
        'package:ureward_member_app/app/w/toolkit.dart',
      );
    });

    test('没有聚合入口 → 回退 meta 包（老项目）', () {
      final root = makeProject(barrel: false);
      expect(
        resolveWtoolsImport(projectRoot: root.path),
        'package:w_tools/w.dart',
      );
    });

    test('有入口但读不到包名 → 回退 meta 包', () {
      final root = makeProject(
        extra: {'pubspec.yaml': 'environment:\n  sdk: ^3.8.0\n'},
      );
      expect(
        resolveWtoolsImport(projectRoot: root.path),
        'package:w_tools/w.dart',
      );
    });

    test('readPackageName 只认行首 name:', () {
      final root = makeProject(
        extra: {'pubspec.yaml': 'description: x\nname: my_app\n  name: nope\n'},
      );
      expect(readPackageName(root.path), 'my_app');
    });
  });
}
