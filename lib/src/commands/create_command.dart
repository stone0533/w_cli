import '../cli/output.dart';
import '../cli/script_runner.dart';
import '../cli/validators.dart';
import '../project/project_creator.dart';

/// 处理 create 命令
/// [arguments] - 命令参数
Future<int> handleCreateCommand(
  List<String> arguments, {
  bool force = false,
}) async {
  // 两种写法都接受：`ww create my_app` 与 `ww create project my_app`
  final rest = [...arguments];
  if (rest.isNotEmpty && (rest.first == 'project' || rest.first == 'p')) {
    rest.removeAt(0);
  }

  if (rest.isEmpty) {
    Cli.error('Project name is required');
    Cli.info('   Usage: ww create|c [project|p] <name>');
    return 2;
  }

  return await handleCreateProject(rest.first, force: force);
}

/// 处理项目创建
/// [projectName] - 项目名称
Future<int> handleCreateProject(
  String projectName, {
  bool force = false,
}) async {
  if (!validateProjectName(projectName)) {
    return 2;
  }

  Cli.info('Creating Flutter project: $projectName');
  try {
    return await ProjectCreator(name: projectName, force: force).run();
  } catch (e) {
    handleError(e, 'project creation');
    return 1;
  }
}
