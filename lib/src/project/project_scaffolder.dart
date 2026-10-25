import 'dart:io';

import 'project_templates.dart';
import '../cli/output.dart';

/// `ww create` 里「写工程文件」的那一半（ADR-0002）。
///
/// 以前这些文件由 `lib/sh/setup.sh` 的 heredoc 写出，模板文本只存在于 shell 里；
/// 现在文本统一在 [project_templates]，这里只负责落盘。目录与依赖仍由 setup.sh
/// 编排（flutter create / pub add），本类只写文件。
class ProjectScaffolder {
  ProjectScaffolder({
    required this.root,
    this.apiBaseUrl = 'https://api.example.com',
  });

  final String root;
  final String apiBaseUrl;

  /// 写入全部文件，返回进程退出码（0 成功）。
  int run() {
    final packageName = _packageName();

    _write(
      'lib/app/modules/home/controllers/home_controller.dart',
      homeControllerTemplate,
    );
    _write('lib/app/modules/home/views/home_view.dart', homeViewTemplate);
    _write(
      'lib/app/modules/home/bindings/home_binding.dart',
      homeBindingTemplate,
    );
    _write('lib/app/routes/app_routes.dart', appRoutesTemplate);
    _write('lib/app/routes/app_pages.dart', appPagesTemplate);
    _write('lib/main.dart', mainTemplate(packageName: packageName));
    _write('.env', envTemplate(apiBaseUrl: apiBaseUrl));
    _write('test/widget_test.dart', widgetTestTemplate);
    _write('.github/workflows/ci.yml', ciTemplate);
    // toolkit 只在缺失时兜底：w_tools_cli:init 生成的版本更完整，别覆盖
    _writeIfMissing('lib/app/w/toolkit.dart', toolkitTemplate);
    _writeIfMissing('.ww/tasks', wwTasksTemplate);

    return 0;
  }

  /// 从 `pubspec.yaml` 读包名（main.dart 的 import 要用）
  String _packageName() {
    final pubspec = File('$root/pubspec.yaml');
    if (!pubspec.existsSync()) {
      return 'my_app';
    }
    for (final line in pubspec.readAsLinesSync()) {
      final match = RegExp(r'^name:\s*(\S+)').firstMatch(line);
      if (match != null) {
        return match.group(1)!;
      }
    }
    return 'my_app';
  }

  void _writeIfMissing(String relativePath, String content) {
    if (File('$root/$relativePath').existsSync()) {
      return;
    }
    _write(relativePath, content);
  }

  void _write(String relativePath, String content) {
    final file = File('$root/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content.endsWith('\n') ? content : '$content\n');
    Cli.detail('写入 $relativePath');
  }
}
