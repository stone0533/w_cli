/// 项目名校验。
///
/// 以前 `validateProjectName` / `isValidProjectName` / `isValidVersion` 三个函数
/// 挤在 `lib/w_cli.dart` 里，后两个没有调用方（只有测试在测）。
/// 现在只留一个入口：打印原因 + 返回布尔。
library;

final RegExp _startsWithLower = RegExp(r'^[a-z]');
final RegExp _allowedChars = RegExp(r'^[a-z0-9_]+$');

/// 项目名必须小写字母开头、只含小写字母/数字/下划线。
bool validateProjectName(String projectName) {
  if (projectName.isEmpty) {
    print('❌ Error: Project name is required');
    print('   Usage: ww create project name');
    return false;
  }
  if (!_startsWithLower.hasMatch(projectName)) {
    print('❌ Error: Project name must start with a lowercase letter');
    return false;
  }
  if (!_allowedChars.hasMatch(projectName)) {
    print(
      '❌ Error: Project name can only contain lowercase letters, numbers, and underscores',
    );
    return false;
  }
  return true;
}
