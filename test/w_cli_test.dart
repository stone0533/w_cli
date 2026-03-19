import 'package:test/test.dart';
import 'package:w_cli/w_cli.dart' as w;

void main() {
  // 测试命令处理函数
  test('handleCreateCommand with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleCreateCommand([]), prints('Error: No subcommand specified for create\nUsage: w_cli create [project]\n'));
  });

  test('handleCreateCommand with unknown subcommand', () {
    // 测试未知子命令的情况
    expect(() => w.handleCreateCommand(['unknown']), prints('Error: Unknown create subcommand: unknown\n'));
  });

  test('handleGenerateCommand with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleGenerateCommand([]), prints('Error: No subcommand specified for generate\nUsage: w_cli generate [locales|model]\n'));
  });

  test('handleGenerateCommand with unknown subcommand', () {
    // 测试未知子命令的情况
    expect(() => w.handleGenerateCommand(['unknown']), prints('Error: Unknown generate subcommand: unknown\n'));
  });

  test('handleInstallCommand with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleInstallCommand([]), prints('Error: No package specified\n'));
  });

  test('handleRemoveCommand with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleRemoveCommand([]), prints('Error: No package specified\n'));
  });

  test('handleCreatePage with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleCreatePage([]), prints('Error: No page name specified\n'));
  });

  test('handleCreateScreen with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleCreateScreen([]), prints('Error: No screen name specified\n'));
  });

  test('handleCreateController with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleCreateController([]), prints('Error: No controller name specified\n'));
  });

  test('handleCreateView with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleCreateView([]), prints('Error: No view name specified\n'));
  });

  test('handleCreateProvider with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleCreateProvider([]), prints('Error: No provider name specified\n'));
  });

  test('handleGenerateLocales with no arguments', () {
    // 测试没有参数的情况
    expect(() => w.handleGenerateLocales([]), prints('Error: No locales directory specified\n'));
  });
}

