import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

/// 资源文件访问工具类
class Resources {
  /// 缓存脚本路径
  static final Map<String, String> _scriptPathCache = {};

  /// 读取资源文件内容
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
            final wCliDirs = source.listSync(followLinks: false)
                .where((e) => e is Directory && e.path.contains('w_cli-'));
            for (var wCliDir in wCliDirs) {
              final tempPath = path.join(wCliDir.path, resourcePath);
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
  static Future<String> extractResourceToTempFile(String resourcePath, String fileName) async {
    // 检查缓存
    if (_scriptPathCache.containsKey(fileName)) {
      return _scriptPathCache[fileName]!;
    }

    final data = await readResource(resourcePath);
    final tempDir = await Directory.systemTemp.createTemp('w_cli_');
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(data);
    
    // 设置执行权限（非Windows系统）
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', tempFile.path]);
    }
    
    // 缓存结果
    _scriptPathCache[fileName] = tempFile.path;
    return tempFile.path;
  }

  /// 清理所有临时文件
  static void cleanupTempFiles() {
    // 遍历缓存中的临时文件路径并删除
    for (final path in _scriptPathCache.values) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync(recursive: true);
        }
      } catch (e) {
        print('Warning: Failed to clean up temp file: $e');
      }
    }
    _scriptPathCache.clear();
  }

  /// 获取缓存的脚本路径
  static Map<String, String> get scriptPathCache => _scriptPathCache;
}
