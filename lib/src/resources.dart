import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'cli/output.dart';
import 'version.dart';

/// 资源文件访问工具类
class Resources {
  /// 缓存脚本路径
  static final Map<String, String> _scriptPathCache = {};

  /// 所有脚本共用的临时目录：脚本之间会 source 同一个 lib.sh，
  /// 所以必须落在同一个目录里，不能一个脚本一个临时目录
  static Directory? _tempRoot;

  /// 任何脚本执行前都必须就位的共享库
  static const List<String> _sharedScripts = ['lib.sh'];

  static Future<Directory> _ensureTempRoot() async {
    final existing = _tempRoot;
    if (existing != null) {
      return existing;
    }
    final created = await Directory.systemTemp.createTemp('w_cli_');
    _tempRoot = created;
    return created;
  }

  /// 读取资源文件内容
  ///
  /// 查找顺序（[WW_SCRIPT_DIR] 存在时只查它，便于开发脚本时绕开缓存）：
  /// 1. `<WW_SCRIPT_DIR>/lib/sh/<脚本>`
  /// 2. `<当前工作目录>/lib/sh/<脚本>`
  /// 3. `<Platform.script 所在目录>/../lib/sh/<脚本>`
  /// 4. `~/.pub-cache/hosted/*/w_cli-<当前版本>/lib/sh/<脚本>`（全局安装场景）
  ///
  /// 第 4 条会**静默**用缓存里的脚本，这正是「删了脚本本地测试还绿」的原因，
  /// 所以命中缓存时打一条 debug 提示，并在找不到时把搜过的路径全列出来。
  static Future<Uint8List> readResource(String resourcePath) async {
    final searched = <String>[];

    Uint8List? tryFile(String candidate) {
      searched.add(candidate);
      final file = File(candidate);
      return file.existsSync() ? file.readAsBytesSync() : null;
    }

    final overrideDir = Platform.environment['WW_SCRIPT_DIR'];

    // 1. 显式覆盖（开发 build.sh 时用）
    if (overrideDir != null && overrideDir.isNotEmpty) {
      final fromOverride = tryFile(path.join(overrideDir, resourcePath));
      if (fromOverride != null) {
        return fromOverride;
      }
      throw FileSystemException(
        'WW_SCRIPT_DIR 下找不到资源: $resourcePath\n搜索过:\n'
        '${searched.map((p) => '  - $p').join('\n')}',
      );
    }

    // 2. 当前工作目录
    final fromCwd = tryFile(path.join(Directory.current.path, resourcePath));
    if (fromCwd != null) {
      return fromCwd;
    }

    // 3. 脚本所在目录（处理符号链接）
    var scriptPath = Platform.script;
    final scriptFile = File(scriptPath.toFilePath());
    if (scriptFile.existsSync()) {
      final resolvedPath = await scriptFile.resolveSymbolicLinks();
      if (resolvedPath != scriptFile.path) {
        scriptPath = Uri.file(resolvedPath);
      }
    }
    final scriptDir = path.dirname(scriptPath.toFilePath());
    final fromScript = tryFile(path.join(scriptDir, '..', resourcePath));
    if (fromScript != null) {
      return fromScript;
    }

    // 4. pub-cache（只找当前版本）
    String? homeDir;
    if (Platform.isMacOS || Platform.isLinux) {
      homeDir = Platform.environment['HOME'];
    } else if (Platform.isWindows) {
      homeDir = Platform.environment['USERPROFILE'];
    }

    if (homeDir != null) {
      final hostedDir = Directory(path.join(homeDir, '.pub-cache', 'hosted'));
      if (hostedDir.existsSync()) {
        for (final source in hostedDir.listSync(followLinks: false)) {
          if (source is! Directory) {
            continue;
          }
          for (final dir in source.listSync(followLinks: false)) {
            if (dir is! Directory || !dir.path.endsWith('w_cli-$version')) {
              continue;
            }
            final fromCache = tryFile(path.join(dir.path, resourcePath));
            if (fromCache != null) {
              Cli.detail('资源来自 pub-cache（工作区里没有）: $resourcePath');
              return fromCache;
            }
          }
        }
      }
    }

    throw FileSystemException(
      'Resource file not found: $resourcePath\n搜索过:\n'
      '${searched.map((p) => '  - $p').join('\n')}',
    );
  }

  /// 将资源文件复制到临时文件并返回路径
  /// [resourcePath] - 资源文件路径
  /// [fileName] - 临时文件名称
  /// 返回临时文件的路径
  static Future<String> extractResourceToTempFile(
    String resourcePath,
    String fileName,
  ) async {
    // 检查缓存
    if (_scriptPathCache.containsKey(fileName)) {
      return _scriptPathCache[fileName]!;
    }

    final root = await _ensureTempRoot();

    // 先把共享库放进同一个目录，脚本才能 source 到它
    for (final shared in _sharedScripts) {
      if (shared == fileName) {
        continue;
      }
      final sharedPath = path.join(root.path, shared);
      final sharedFile = File(sharedPath);
      if (!sharedFile.existsSync()) {
        final sharedData = await readResource('lib/sh/$shared');
        await sharedFile.writeAsBytes(sharedData);
      }
    }

    final data = await readResource(resourcePath);
    final tempFile = File(path.join(root.path, fileName));
    await tempFile.writeAsBytes(data);
    // 不设可执行位：脚本一律通过 `bash <script>` 调用（直接执行要慢两个数量级），
    // 省掉两次 chmod 子进程

    // 缓存结果
    _scriptPathCache[fileName] = tempFile.path;
    return tempFile.path;
  }

  /// 清理所有临时文件
  static void cleanupTempFiles() {
    // 共享目录整棵删掉：目录里的脚本与共享库互相关联，不能逐个删
    final root = _tempRoot;
    _tempRoot = null;
    _scriptPathCache.clear();

    if (root == null) {
      return;
    }
    try {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    } catch (e) {
      Cli.warn('清理临时文件失败: $e');
    }
  }

  /// 获取缓存的脚本路径
  static Map<String, String> get scriptPathCache => _scriptPathCache;
}
