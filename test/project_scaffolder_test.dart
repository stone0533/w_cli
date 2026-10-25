import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/project/project_scaffolder.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('w_cli_proj_scaffold');
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('写工程文件并生成默认 .ww/tasks', () {
    expect(ProjectScaffolder(root: project.path).run(), 0);

    final tasks = File('${project.path}/.ww/tasks');
    expect(tasks.existsSync(), isTrue, reason: 'ww run 的默认快捷键');
    expect(tasks.readAsStringSync(), contains('gen = '));
    expect(tasks.readAsStringSync(), contains('fmt = '));

    expect(File('${project.path}/lib/main.dart').existsSync(), isTrue);
    expect(File('${project.path}/test/widget_test.dart').existsSync(), isTrue);
  });

  test('.ww/tasks 已存在时不覆盖', () {
    Directory('${project.path}/.ww').createSync(recursive: true);
    File('${project.path}/.ww/tasks').writeAsStringSync('mine = echo hi\n');

    expect(ProjectScaffolder(root: project.path).run(), 0);
    expect(
      File('${project.path}/.ww/tasks').readAsStringSync(),
      'mine = echo hi\n',
    );
  });
}
