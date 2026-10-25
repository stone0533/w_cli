# ww common 使用说明

`ww common drbb` 执行 `dart run build_runner build --delete-conflicting-outputs`。

> 2026-10 起这一条由 Dart 实现（`lib/src/tools/build_runner.dart`），`lib/sh/common.sh` 已删除。
> 变化：Windows 上也能用、统一 30 分钟超时、超时退出码 124。

## 用法

```bash
ww common drbb            # 执行 build_runner build
ww common drbb --debug    # 带调试日志（等同 -d）
ww co drbb                # ww common 的别名
```

## 与 `ww api models` 的关系

两者都会调 build_runner，用的是同一个 `BuildRunner`：

- `ww api models` 在模型落盘后跑一次
- `ww common drbb` 是手动触发（改完 `@JsonSerializable` 注解后想立刻生成）
- `ww create` 在脚手架完成、依赖安装后跑一次

三处共用：优先 `dart`、缺省退回 `flutter`、30 分钟超时、退出码透传。

## 注意

- 必须在 Flutter 项目根目录执行（`pubspec.yaml` 所在处）
- 第一次跑需要 `dart pub get` 已经完成，否则 build_runner 找不到
- 超时返回 124，失败透传 build_runner 自己的退出码
