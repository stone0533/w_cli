import 'package:test/test.dart';
import 'package:w_cli/src/api/generated_file_guard.dart';

const _generated = '''
class AppRepository {
  AppRepository() : super(remoteDataSource: AppRemoteDataSource());

  static AppRepository? _instance;

  static AppRepository _getInstance() {
    _instance ??= AppRepository();
    return _instance!;
  }

  static AppRepository get instance => _getInstance();

  static bool destroyInstance() {
    return true;
  }

  @override
  Future<List<UserResult>> getUsers(int page) {
    return remoteDataSource!.getUsers(page);
  }
}
''';

void main() {
  group('declaredMemberNames', () {
    test('抽到类级成员，忽略构造函数', () {
      expect(
        declaredMemberNames(_generated),
        {'_instance', '_getInstance', 'instance', 'destroyInstance', 'getUsers'},
      );
    });

    test('方法体内部的声明不算成员', () {
      const source = '''
class A {
  void run() {
    final temp = 1;
    print(temp);
  }
}
''';
      expect(declaredMemberNames(source), {'run'});
    });

    test('注释掉的成员不算', () {
      const source = '''
class A {
  // Future<int> commented();
  /* Future<int> blocked(); */
  Future<int> real();
}
''';
      expect(declaredMemberNames(source), {'real'});
    });
  });

  group('handwrittenMembers', () {
    test('没有手写内容时为空', () {
      expect(
        handwrittenMembers(
          existingContent: _generated,
          generatedContent: _generated,
        ),
        isEmpty,
      );
    });

    test('手写方法会被识别出来', () {
      final existing = _generated.replaceFirst(
        '  static bool destroyInstance() {',
        '  Future<int> orderCount() async => 0;\n\n  static bool destroyInstance() {',
      );

      expect(
        handwrittenMembers(
          existingContent: existing,
          generatedContent: _generated,
        ),
        {'orderCount'},
      );
    });

    test('删除生成的方法不算手写（生成器会补回来）', () {
      final existing = _generated.replaceFirst(
        '  static bool destroyInstance() {\n    return true;\n  }\n',
        '',
      );

      expect(
        handwrittenMembers(
          existingContent: existing,
          generatedContent: _generated,
        ),
        isEmpty,
      );
    });
  });
}
