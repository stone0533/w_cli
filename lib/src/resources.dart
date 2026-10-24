import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
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
  /// [resourcePath] - 资源文件路径
  /// 返回资源文件的字节数据
  static Future<Uint8List> readResource(String resourcePath) async {
    // 尝试从当前工作目录读取
    final cwdPath = path.join(Directory.current.path, resourcePath);
    final cwdFile = File(cwdPath);
    if (cwdFile.existsSync()) {
      return cwdFile.readAsBytes();
    }

    // 尝试从脚本所在目录读取（处理符号链接）
    var scriptPath = Platform.script;
    // 解析符号链接
    final scriptFile = File(scriptPath.toFilePath());
    if (scriptFile.existsSync()) {
      final resolvedPath = await scriptFile.resolveSymbolicLinks();
      if (resolvedPath != scriptFile.path) {
        scriptPath = Uri.file(resolvedPath);
      }
    }
    final scriptDir = path.dirname(scriptPath.toFilePath());
    final relativePath = path.join(scriptDir, '..', resourcePath);
    final resourceScriptFile = File(relativePath);
    if (resourceScriptFile.existsSync()) {
      return resourceScriptFile.readAsBytes();
    }

    // 尝试从 .pub-cache 目录读取
    String? homeDir;
    if (Platform.isMacOS || Platform.isLinux) {
      homeDir = Platform.environment['HOME'];
    } else if (Platform.isWindows) {
      homeDir = Platform.environment['USERPROFILE'];
    }

    if (homeDir != null) {
      final hostedDir = Directory(path.join(homeDir, '.pub-cache', 'hosted'));
      if (hostedDir.existsSync()) {
        final hostedSources = hostedDir.listSync(followLinks: false);
        for (var source in hostedSources) {
          if (source is Directory) {
            // 获取所有 w_cli 目录
            final wCliDirs = source
                .listSync(followLinks: false)
                .where((e) => e is Directory && e.path.contains('w_cli-'))
                .toList();

            // 只查找当前版本，不尝试其他版本
            final currentVersion = version;
            final currentVersionDir = wCliDirs.firstWhere(
              (dir) => dir.path.endsWith('w_cli-$currentVersion'),
              orElse: () => Directory(''),
            );

            if (currentVersionDir.existsSync()) {
              final tempPath = path.join(currentVersionDir.path, resourcePath);
              final resourceFile = File(tempPath);
              if (resourceFile.existsSync()) {
                return resourceFile.readAsBytes();
              }
            }
          }
        }
      }
    }

    throw FileSystemException('Resource file not found: $resourcePath');
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
      print('Warning: Failed to clean up temp files: $e');
    }
  }

  /// 获取缓存的脚本路径
  static Map<String, String> get scriptPathCache => _scriptPathCache;
}
