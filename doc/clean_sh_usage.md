# ww clean 使用说明

清理 Flutter 构建产物，然后重新 `flutter pub get`。

> 2026-10 起由 Dart 实现（`lib/src/commands/clean_command.dart`），`lib/sh/clean.sh` 已删除。
> 变化：`--lock` / `--pod` 以前会被 ww 的参数解析拒绝，现在能真正传进来；Windows 可用。

## 用法

```bash
ww clean                 # 清理所有平台的构建文件
ww clean android         # 只清 Android
ww clean ios             # 只清 iOS
ww clean --lock          # 额外删除 pubspec.lock（iOS 时还会删 Podfile.lock）
ww clean ios --pod       # 删除 ios/Pods 与 Podfile.lock，然后 pod update
ww cl --lock             # ww clean 的别名
```

## 行为

1. `--lock`：按平台删 `pubspec.lock` / `ios/Podfile.lock`
2. `--pod`：删 `ios/Pods` 与 `ios/Podfile.lock`（`--pod` + `android` 会直接报错退出 2）
3. `flutter clean`
4. `flutter pub get`
5. 需要时执行 `pod update`（最多重试 30 次，与旧脚本一致）

任何一步失败退出码为 1；参数错误为 2。
