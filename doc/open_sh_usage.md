# ww open 使用说明

打开 Flutter 项目的不同部分。

> 2026-10 起由 Dart 实现（`lib/src/commands/open_command.dart`），`lib/sh/open.sh` 已删除。
> 变化：支持 help 里早就写着的短别名（`i` / `a` / `b` / `r`）；打开失败返回非零（旧脚本永远退 0）。

## 用法

```bash
ww open ios        # 用 Xcode 打开 ios/Runner.xcworkspace（仅 macOS）
ww open i          # 同上
ww open android    # 用 Android Studio 打开 android/（macOS: open -a / Linux: studio.sh）
ww open build      # 用文件管理器打开 w_build/
ww open root       # 用文件管理器打开项目根目录
ww o b             # 别名
```

| 目标 | 要求 |
|---|---|
| `ios` / `i` | 存在 `ios/Runner.xcworkspace`；仅 macOS |
| `android` / `a` | 存在 `android/`；macOS 用 `open -a "Android Studio"`，Linux 用 `studio.sh` |
| `build` / `b` | 存在 `w_build/`；macOS `open` / Linux `xdg-open` |
| `root` / `r` | 项目根目录；同上 |

无参数或 `--help` 打印帮助（退出 0）；未知参数退出 2；打开失败退出非零。
