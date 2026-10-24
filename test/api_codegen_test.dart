import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/api/api_generator.dart';
import 'package:w_cli/src/api/client_parser.dart';
import 'package:w_cli/src/api/client_renderer.dart';

/// 迁移的等价性闸门：Dart 侧的产物必须与 `api.sh` 原有产物逐字一致
/// （golden 取自 shell 版本，只把时间戳固定成 2026-01-01 00:00:00）。
void main() {
  final clientSource =
      File('test/shell/fixtures/client_nested.expected').readAsStringSync();
  final mixinGolden =
      File('test/fixtures/api/remote_data_source.expected').readAsStringSync();
  final repositoryGolden =
      File('test/fixtures/api/repository.expected').readAsStringSync();

  const headerTimestamp = '2026-01-01 00:00:00';

  group('parseApiClient', () {
    test('解析出全部方法', () {
      final methods = parseApiClient(clientSource);

      expect(methods.map((method) => method.name), [
        'ping',
        'getProfile',
        'getUsers',
        'getOrders',
        'deleteUser',
        'login',
      ]);
    });

    test('嵌套泛型返回类型完整保留', () {
      final methods = parseApiClient(clientSource);

      expect(methods[1].returnType, 'Map<String, dynamic>');
      expect(methods[2].returnType, 'List<UserResult>');
      expect(methods[3].returnType, 'List<OrderResult>');
    });

    test('参数保留名字与类型（多个 @Query 不重名）', () {
      final methods = parseApiClient(clientSource);
      final orders = methods.firstWhere((method) => method.name == 'getOrders');

      expect(orders.params.map((param) => param.name), ['page', 'size']);
      expect(orders.params.map((param) => param.type), ['int', 'int']);
    });

    test('注解参数与 Map 类型', () {
      final methods = parseApiClient(clientSource);

      final login = methods.firstWhere((method) => method.name == 'login');
      expect(login.params.single.name, 'data');
      expect(login.params.single.type, 'Map<String, dynamic>');

      final delete = methods.firstWhere((method) => method.name == 'deleteUser');
      expect(delete.params.single.name, 'id');
      expect(delete.params.single.type, 'String');
    });

    test('`}` 出现在注释里也不会提前结束解析', () {
      final methods = parseApiClient('''
abstract class ApiClient {
  Future<String> a();

  // 返回值形如 {data}
  Future<String> b();
}
''');

      expect(methods.map((method) => method.name), ['a', 'b']);
    });

    test('解析不了的写法直接报错，不返回半截结果', () {
      expect(
        () => parseApiClient('''
abstract class ApiClient {
  Future<String> broken()
}
'''),
        throwsA(isA<ApiParseException>()),
      );
    });

    test('没有 ApiClient 类时报错', () {
      expect(
        () => parseApiClient('class Other {}'),
        throwsA(isA<ApiParseException>()),
      );
    });
  });

  group('renderRemoteDataSource', () {
    test('与 shell 版本的产物逐字一致', () {
      final methods = parseApiClient(clientSource);
      final rendered = renderRemoteDataSource(
        header: renderHeader(headerTimestamp),
        methods: methods,
        existingMethods: const {},
        modelFiles: const ['user.dart', 'order.dart'],
      );

      expect(rendered, mixinGolden);
    });

    test('手写层已实现的方法跳过实现，但接口里保留', () {
      final methods = parseApiClient(clientSource);
      final rendered = renderRemoteDataSource(
        header: renderHeader(headerTimestamp),
        methods: methods,
        existingMethods: const {'ping'},
        modelFiles: const ['user.dart', 'order.dart'],
      );

      expect(rendered, contains('Future<String> ping();'));
      expect(rendered, isNot(contains('return libRest.ping();')));
      expect(rendered, contains('return libRest.login(data);'));
    });

    test('自定义 ApiClientId 生成独立实例并用于调用', () {
      final methods = parseApiClient('''
abstract class ApiClient {
  @ApiClientId('libRest2')
  Future<String> other();
}
''');
      final rendered = renderRemoteDataSource(
        header: renderHeader(headerTimestamp),
        methods: methods,
        existingMethods: const {},
        modelFiles: const [],
      );

      expect(rendered, contains('late final ApiClient libRest2;'));
      expect(rendered, contains('return libRest2.other();'));
    });
  });

  group('renderRepository', () {
    test('与 shell 版本的产物逐字一致', () {
      final methods = parseApiClient(clientSource);
      final rendered = renderRepository(
        header: renderHeader(headerTimestamp),
        methods: methods,
        modelFiles: const ['user.dart', 'order.dart'],
      );

      expect(rendered, repositoryGolden);
    });
  });

  group('snakeCase', () {
    test('驼峰转蛇形', () {
      expect(snakeCase('UserResult'), 'user_result');
      expect(snakeCase('Order'), 'order');
      expect(snakeCase('APIKey'), 'a_p_i_key');
    });
  });
}
