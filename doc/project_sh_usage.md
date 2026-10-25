# ww project 使用说明

更新 Flutter 项目的依赖与 Gradle wrapper。

> 2026-10 起由 Dart 实现（`lib/src/commands/project_command.dart`），`lib/sh/project.sh` 已删除。

## 用法

```bash
ww project --update      # flutter pub upgrade + 把 Gradle wrapper 指到 8.0
ww p --update            # 别名
ww project --help
```

## 行为

1. 检查 `flutter` 是否可用（不可用退出 1）
2. 打印当前 Flutter 版本
3. 当前目录必须有 `pubspec.yaml`，然后执行 `flutter pub upgrade`
4. 若存在 `android/gradle/wrapper/gradle-wrapper.properties`，把 `distributionUrl`
   改写为 `gradle-8.0-all.zip`（与旧脚本相同的固定版本）
5. 没有 `android` 目录时只告警，不算失败

未知参数退出 2。
