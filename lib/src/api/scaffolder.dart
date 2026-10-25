import 'dart:io';

import '../cli/output.dart';
import 'project_imports.dart';

/// `ww api init` 的 Dart 实现（ADR-0002 Phase 1）。
///
/// 取代 `api.sh init`：五个骨架文件的文本只在这里有一份，与 `api.sh`
/// 原先的产物逐字节一致（`test/shell/fixtures/scaffold/` 是闸门）。
class ApiScaffolder {
  ApiScaffolder({this.root = '.', this.baseUrl = 'https://api.example.com'});

  final String root;
  final String baseUrl;

  /// 返回进程退出码：0 成功，1 失败。
  int run() {
    _ensureDirectories();

    // root 为 '.' 时不要输出 './lib/...'：日志和用户手敲的路径保持一致
    final base = root == '.' ? '' : '$root/';
    final sources = '${base}lib/app/data/sources';
    final remote = '$sources/remote';
    final uri = resolveWtoolsImport(projectRoot: root);

    _ensureDependencies();

    _writeIfMissing('$sources/client.dart', clientTemplate);
    _writeIfMissing('$sources/paths.dart', pathsTemplate(baseUrl));
    _writeIfMissing('$remote/data_source_mixin.dart', dataSourceMixinTemplate);
    _writeIfMissing('$sources/repository.dart', repositoryTemplate(uri));
    _syncDataSource(File('$remote/data_source.dart'), uri);

    return 0;
  }

  void _ensureDirectories() {
    final base = root == '.' ? '' : '$root/';
    for (final dir in [
      '${base}lib/app/data',
      '${base}lib/app/data/sources',
      '${base}lib/app/data/sources/remote',
      '${base}lib/app/data/models',
      '${base}w_json',
    ]) {
      final directory = Directory(dir);
      if (directory.existsSync()) {
        Cli.detail('目录已存在: $dir');
      } else {
        Cli.detail('创建目录: $dir');
        directory.createSync(recursive: true);
      }
    }
  }

  /// 缺依赖就补上（等价于 `api.sh` 原来的 check_and_add_dependencies）。
  /// 没有 flutter 时只告警：骨架本身仍然有用，别把 init 卡死。
  void _ensureDependencies() {
    final base = root == '.' ? '' : '$root/';
    final pubspec = File('${base}pubspec.yaml');
    if (!pubspec.existsSync()) {
      Cli.error('文件不存在: ${pubspec.path}');
      return;
    }

    final content = pubspec.readAsStringSync();
    final missing = <String>[
      if (!content.contains('retrofit:')) 'retrofit',
      if (!content.contains('build_runner:')) 'build_runner',
      if (!content.contains('json_serializable:')) 'json_serializable',
      if (!content.contains('retrofit_generator:')) 'retrofit_generator',
    ];
    if (missing.isEmpty) {
      Cli.detail('所有必要的依赖项已存在');
      return;
    }

    for (final dep in missing) {
      final isDev = dep != 'retrofit';
      Cli.detail('添加 $dep 依赖...');
      final result = Process.runSync(
        'flutter',
        ['pub', 'add', if (isDev) '--dev', dep],
        workingDirectory: root,
        runInShell: true,
      );
      if (result.exitCode != 0) {
        Cli.error(
          '添加 $dep 失败，请手动执行: flutter pub add ${isDev ? '--dev ' : ''}$dep',
        );
      }
    }
  }

  void _writeIfMissing(String path, String content) {
    final file = File(path);
    if (file.existsSync()) {
      Cli.detail('文件已存在: $path');
      return;
    }
    Cli.detail('创建文件: $path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  /// `data_source.dart` 是「生成一次、之后手写」的骨架：
  /// 新文件写完整内容；老文件只同步 marker 段，没有 marker 就一个字都不改。
  void _syncDataSource(File file, String uri) {
    if (!file.existsSync()) {
      Cli.detail('创建文件: ${file.path}');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(dataSourceTemplate(uri));
      return;
    }

    final existing = file.readAsStringSync();
    final synced = syncWtoolsImport(existing, uri);

    if (synced == null) {
      Cli.detail('  ↳ 未接管导入行（无 marker，视为手写文件）: ${file.path}');
      return;
    }
    if (synced != existing) {
      Cli.detail('同步 w_tools 导入: ${file.path}');
      file.writeAsStringSync(synced);
    }
  }
}

/// marker 起始行（文件里带一句中文说明，匹配时只认这个前缀）
const String wToolsImportBegin = '// <<<GENERATED w_tools import';

/// marker 结束行
const String wToolsImportEnd = '// GENERATED>>>';

/// marker 段（工具维护的那两行 + 导入）
String wToolsImportBlock(String uri) {
  return '$wToolsImportBegin（工具只维护下一行导入；本文件其余部分手写，不会被覆盖）\n'
      "import '$uri';\n"
      '$wToolsImportEnd';
}

/// 把 marker 段替换成当前项目的导入；没有 marker 时返回 null（= 手写文件，别动）。
String? syncWtoolsImport(String content, String uri) {
  final beginIndex = content.indexOf(wToolsImportBegin);
  if (beginIndex < 0) {
    return null;
  }
  final endIndex = content.indexOf(wToolsImportEnd, beginIndex);
  if (endIndex < 0) {
    return null;
  }

  final head = content.substring(0, beginIndex);
  final tail = content.substring(endIndex + wToolsImportEnd.length);
  return head + wToolsImportBlock(uri) + tail;
}

/// `data_source.dart`：marker 段 + 手写骨架
String dataSourceTemplate(String uri) {
  return '${wToolsImportBlock(uri)}$dataSourceTail';
}

/// `repository.dart`：注释头 + w_tools 导入 + 骨架
String repositoryTemplate(String uri) {
  return "${repositoryPrefix}import '$uri';\n$repositoryTail";
}

const String dataSourceTail =
    '\n'
    r'''
import '../client.dart';
import '../paths.dart';
import 'data_source_mixin.dart';

class AppRemoteDataSource extends BaseRemoteDataSource
    with AppRemoteDataSourceMixin {
  AppRemoteDataSource() {
    libRest = ApiClient(
      DioRegistry.forBaseUrl(
        ApiPath.baseUrl,
        interceptors: [
          WTokenInterceptor(),
          WLogInterceptor(),
        ],
      ).dio,
    );
  }
}

''';
const String repositoryPrefix =
    r'''// 由 api.sh 首次创建；之后的内容由 ww api 依据 client.dart 整份重写。
// 直接在这里加方法会让 ww api 拒绝覆盖（它会提示用手写扩展或 --force）。
''';
const String repositoryTail =
    '\n'
    r'''
import 'remote/data_source.dart';
import 'remote/data_source_mixin.dart';

class AppRepository extends BaseRepository<Null, AppRemoteDataSource>
    implements IAppRemoteDataSource {
  AppRepository() : super(remoteDataSource: AppRemoteDataSource());

  static AppRepository? _instance;

  static AppRepository _getInstance() {
    _instance ??= AppRepository();
    return _instance!;
  }

  static AppRepository get instance => _getInstance();

  static bool destroyInstance() {
    if (_instance == null) {
      return false;
    }
    _instance = null;
    return true;
  }

  // 认证相关
  @override
  Future<dynamic> login(Map<String, dynamic> body) {
    return remoteDataSource!.login(body);
  }
}
''';
const String clientTemplate = r'''import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';
import 'paths.dart';

part 'client.g.dart';

@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  // 认证相关
  @POST(ApiPath.login)
  Future<dynamic> login(@Body() Map<String, dynamic> data);

  // 这里新增需要的 API，然后执行 ww api generate 来自动生成对应的代码
}
''';
String pathsTemplate(String baseUrl) =>
    '''class ApiPath {
  static const String baseUrl = '$baseUrl';

  // 认证相关
  static const String login = '/auth/login';
}
''';
const String dataSourceMixinTemplate =
    r'''// **************************************************************************
// Auto-generated file. Do not edit manually.
// **************************************************************************
import '../client.dart';

abstract class IAppRemoteDataSource {
  // 认证相关
  Future<dynamic> login(Map<String, dynamic> body);
}

mixin AppRemoteDataSourceMixin implements IAppRemoteDataSource {
  late final ApiClient libRest;

  // 认证相关
  @override
  Future<dynamic> login(Map<String, dynamic> body) {
    return libRest.login(body);
  }
}
''';
