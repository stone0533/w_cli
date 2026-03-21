import 'dart:io';

void main() {
  // 读取 pubspec.yaml 文件
  final pubspecFile = File('pubspec.yaml');
  final content = pubspecFile.readAsStringSync();

  // 提取版本号
  final match = RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(content);
  final version = match?.group(1) ?? 'unknown';

  // 生成版本文件
  final versionFile = File('lib/src/version.dart');
  versionFile.createSync(recursive: true);
  versionFile.writeAsStringSync('''
// 自动生成的版本文件，请勿手动修改
const String version = '$version';
''');

  print('Generated version file with version: $version');
}
