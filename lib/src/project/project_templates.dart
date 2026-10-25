/// `ww create` 生成的工程文件模板。
///
/// 从 `lib/sh/setup.sh` 的 heredoc 逐字搬过来（ADR-0002）：以前这些文本只存在于
/// shell 里，`ww create` 改成 Dart 之后它们是唯一的 owner。
library;

const String homeControllerTemplate = r'''import 'package:get/get.dart';

class HomeController extends GetxController {
  final count = 0.obs;

  void increment() {
    count.value++;
  }
}
''';

const String homeViewTemplate = r'''import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Obx(() => Text('${controller.count}')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
''';

const String homeBindingTemplate = r'''import 'package:get/get.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
''';

const String appRoutesTemplate = r'''part of 'app_pages.dart';

abstract class AppRoutes {
  AppRoutes._();
  static const HOME = '/home';
}
''';

const String appPagesTemplate = r'''import 'package:get/get.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = AppRoutes.HOME;

  static final routes = [
    GetPage(
      name: AppRoutes.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
  ];
}
''';

/// mainTemplate
String mainTemplate({required String packageName}) =>
    '''import 'package:flutter/material.dart';
import 'package:$packageName/app/w/toolkit.dart';

import 'app/routes/app_pages.dart';

Future<void> main() async {
  final app = WApp()
    // run() 会校验 title / initialRoute / getPages 非空，title 必须在启动前设置
    ..title = 'Flutter W Example'
    ..theme = ThemeData(primarySwatch: Colors.blue);

  // 一站式启动 = await init() + run()
  // 屏幕适配（ScreenUtil）/.env/日志等能力用插件注册：
  //   app.addPlugins([...])，参考 w_tools_app 的 WAppPlugin
  await app.start(initialRoute: AppPages.INITIAL, getPages: AppPages.routes);
}
''';

/// envTemplate
String envTemplate({required String apiBaseUrl}) =>
    '''# API 基础 URL
API_BASE_URL=$apiBaseUrl

# 其他配置
DEBUG=true''';

const String toolkitTemplate = r'''// 本项目用到的 w_tools 能力清单（w_tools_cli:init 生成的兜底版本）。
//
// 业务代码统一 import 这里，不要直接 import 各个子包 ——
// 换依赖方式时只改这一个文件。
//
// 为什么不用 meta 包 w_tools：它会经 w_tools_map 拖进 google_maps_flutter 原生 SDK。
library;

export 'package:w_tools_core/w_tools_core.dart';
export 'package:w_tools_app/w_tools_app.dart';
export 'package:w_tools_form/w_tools_form.dart';
export 'package:w_tools_ui/w_tools_ui.dart';
export 'package:w_tools_api/w_tools_api.dart';
export 'package:w_tools_toast/w_tools_toast.dart';
export 'package:w_tools_qr/w_tools_qr.dart';''';

const String widgetTestTemplate = r'''import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 测试代码
  });
}
''';

const String ciTemplate = r'''name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.10.0'

    - name: Install dependencies
      run: flutter pub get

    - name: Run tests
      run: flutter test

    - name: Build app
      run: flutter build apk
''';

