# 命令说明

每个 `ww` 子命令的用法、行为与边界。实现位置与约定见 `AGENTS.md`，
架构决策见 `doc/adr/`。

- [ww api](#ww-api) —— 生成 API 层与模型（纯 Dart）
- [ww create](#ww-create) —— 从零搭工程（纯 Dart）
- [ww common](#ww-common) —— build_runner
- [ww clean](#ww-clean) —— 清理构建产物
- [ww open](#ww-open) —— 打开 IDE / 目录
- [ww project](#ww-project) —— 更新依赖与 Gradle
- [ww build](#ww-build) —— 打包 APK / AAB / IPA（**仍是 bash 脚本**）

## ww api

```bash
ww api                  # client.dart -> data_source_mixin.dart / repository.dart
ww api generate         # 同上（显式写法）
ww api init             # 初始化 lib/app/data 目录与五个骨架文件
ww api models           # w_json/*.json -> lib/app/data/models/*.dart
ww api models --force   # 忽略增量，全量重生成
ww api --force          # 覆盖 repository.dart 中检测到的手写成员
```

要点：

- 解析 `client.dart` 用 Dart 写的扫描器（不是正则），解析失败会报错带偏移量，不会写出半截文件
- `repository.dart` / `data_source_mixin.dart` 每次整份重写；文件里存在生成器不认识的方法时**拒绝覆盖**，需 `--force`
- `data_source.dart` 是「生成一次、之后手写」的骨架，只有 marker 段里的 w_tools 导入由工具维护
- `models` 的产物与旧 shell 版本逐字节一致（`test/models_test.dart` 的 golden）
- 不再需要 python3

## ww create

从零创建一个符合本工具约定结构的 Flutter 工程。

> 2026-10 起由 Dart 实现（`lib/src/project/`），`lib/sh/setup.sh` 已删除。
> 变化：Windows 可用、无需 bash；失败时只清理本次创建的目录。

### 用法

```bash
ww create project my_app     # 完整写法
ww c p my_app                # 别名 + 简写
ww create project my_app --force   # 覆盖已存在的同名目录（默认拒绝）
```

项目名必须小写字母开头，只含小写字母、数字、下划线；不合法时退出 2。

### 它做了什么

| # | 步骤 | 具体动作 |
|---|---|---|
| 1 | 环境检查 | 找 `flutter`，打印版本 |
| 2 | 目录检查 | 已存在且无 `--force` → 退出 1；有 `--force` → 先删 |
| 3 | `flutter create` | `--org com.sampras -i swift -a kotlin` |
| 4 | 依赖 | `get dio flutter_screenutil flutter_form_builder form_builder_validators json_annotation:^4.9.0`、`retrofit:4.9.0`、dev: `build_runner json_serializable retrofit_generator:^9.7.0 w_tools_cli` |
| 5 | 目录 | `assets/{fonts,images}`、`lib/app/{components,utils,services}`、`lib/app/data/{models,sources,sources/remote}`、`test`、`.github/workflows`、`w_json` |
| 6 | w_tools 分包 | `pub add w_tools_{core,app,form,ui,api,toast,qr}:^1.0.0`（不含 `w_tools_map`），dev 加 `w_tools_cli`；补 `assets` 配置 |
| 7 | 接入骨架 | `dart run w_tools_cli:init`；不可用时兜底写 `lib/app/w/toolkit.dart` |
| 8 | 工程文件 | `main.dart` / home 三件套 / `app_pages` / `app_routes` / `.env` / `widget_test` / CI / toolkit |
| 9 | API 层 | `ww api init` 的同一套模板（client / paths / data_source / mixin / repository） |
| 10 | build_runner | 统一走 `BuildRunner`（30 分钟超时） |
| 11 | 格式化 | `dart format .` |
| 12 | analysis_options | 插入 `analyzer.exclude`（排除自动生成的 routes） |
| 13 | git | `git init`、`.gitignore` 补 `w_build/`、首次提交 |
| 14 | 健康检查 | pubspec + 目录是否存在 |
| 15 | 打开项目 | `trae` → `studio` → 跳过 |

### 失败时的行为

- `flutter create` 或后续步骤失败 → 退出非零，并**删除本次创建的目录**
- 目标目录是原来就有的 → 永远不会被删（除非显式 `--force`）

### 生成文本在哪

全部在 Dart：`lib/src/project/project_templates.dart`（工程文件）+
`lib/src/api/scaffolder.dart`（API 层）。`lib/sh/` 里已经没有生成文本。

## ww common

`ww common drbb` 执行 `dart run build_runner build --delete-conflicting-outputs`。

> 2026-10 起这一条由 Dart 实现（`lib/src/tools/build_runner.dart`），`lib/sh/common.sh` 已删除。
> 变化：Windows 上也能用、统一 30 分钟超时、超时退出码 124。

### 用法

```bash
ww common drbb            # 执行 build_runner build
ww common drbb --debug    # 带调试日志（等同 -d）
ww co drbb                # ww common 的别名
```

### 与 `ww api models` 的关系

两者都会调 build_runner，用的是同一个 `BuildRunner`：

- `ww api models` 在模型落盘后跑一次
- `ww common drbb` 是手动触发（改完 `@JsonSerializable` 注解后想立刻生成）
- `ww create` 在脚手架完成、依赖安装后跑一次

三处共用：优先 `dart`、缺省退回 `flutter`、30 分钟超时、退出码透传。

### 注意

- 必须在 Flutter 项目根目录执行（`pubspec.yaml` 所在处）
- 第一次跑需要 `dart pub get` 已经完成，否则 build_runner 找不到
- 超时返回 124，失败透传 build_runner 自己的退出码

## ww clean

清理 Flutter 构建产物，然后重新 `flutter pub get`。

> 2026-10 起由 Dart 实现（`lib/src/commands/clean_command.dart`），`lib/sh/clean.sh` 已删除。
> 变化：`--lock` / `--pod` 以前会被 ww 的参数解析拒绝，现在能真正传进来；Windows 可用。

### 用法

```bash
ww clean                 # 清理所有平台的构建文件
ww clean android         # 只清 Android
ww clean ios             # 只清 iOS
ww clean --lock          # 额外删除 pubspec.lock（iOS 时还会删 Podfile.lock）
ww clean ios --pod       # 删除 ios/Pods 与 Podfile.lock，然后 pod update
ww cl --lock             # ww clean 的别名
```

### 行为

1. `--lock`：按平台删 `pubspec.lock` / `ios/Podfile.lock`
2. `--pod`：删 `ios/Pods` 与 `ios/Podfile.lock`（`--pod` + `android` 会直接报错退出 2）
3. `flutter clean`
4. `flutter pub get`
5. 需要时执行 `pod update`（最多重试 30 次，与旧脚本一致）

任何一步失败退出码为 1；参数错误为 2。

## ww open

打开 Flutter 项目的不同部分。

> 2026-10 起由 Dart 实现（`lib/src/commands/open_command.dart`），`lib/sh/open.sh` 已删除。
> 变化：支持 help 里早就写着的短别名（`i` / `a` / `b` / `r`）；打开失败返回非零（旧脚本永远退 0）。

### 用法

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

## ww project

更新 Flutter 项目的依赖与 Gradle wrapper。

> 2026-10 起由 Dart 实现（`lib/src/commands/project_command.dart`），`lib/sh/project.sh` 已删除。

### 用法

```bash
ww project --update      # flutter pub upgrade + 把 Gradle wrapper 指到 8.0
ww p --update            # 别名
ww project --help
```

### 行为

1. 检查 `flutter` 是否可用（不可用退出 1）
2. 打印当前 Flutter 版本
3. 当前目录必须有 `pubspec.yaml`，然后执行 `flutter pub upgrade`
4. 若存在 `android/gradle/wrapper/gradle-wrapper.properties`，把 `distributionUrl`
   改写为 `gradle-8.0-all.zip`（与旧脚本相同的固定版本）
5. 没有 `android` 目录时只告警，不算失败

未知参数退出 2。

## ww build

### 1. 脚本概述

`build.sh` 是一个用于 Flutter 应用的多平台打包脚本，支持 Android APK、AAB 和 iOS IPA 打包，提供生产模式和 UAT 模式，以及详细的日志和错误处理。

#### 版本信息
- **版本**: 随 w_cli 包版本（`ww --version`）
- **作者**: Stone

### 2. 功能特点

- **多平台支持**: 支持 Android APK、AAB 和 iOS IPA 打包
- **模式选择**: 支持生产模式和 UAT 模式
- **并行构建**: 支持同时构建多个平台，提高构建速度
- **构建通知**: 构建完成后发送系统通知
- **详细日志**: 提供详细的构建过程日志和错误处理
- **应用商店要求检查**: 确保构建产物符合应用商店要求
- **构建目录管理**: 自动创建和管理构建输出目录

### 3. 安装和设置

#### 前提条件
- Flutter 环境已安装
- Android 开发环境（用于 Android 构建）
- Xcode（用于 iOS 构建，仅 macOS）

#### 安装步骤
1. 将 `build.sh` 与共享库 `lib.sh` 一起复制到项目的 `lib/sh` 目录中（脚本会 source 同目录下的 `lib.sh`，少了它无法运行）
2. 赋予脚本执行权限：
   ```bash
   chmod +x lib/sh/lib.sh lib/sh/build.sh
   ```

### 4. 目录结构

执行脚本后，会在项目根目录创建 `w_build` 目录用于存放构建产物：

```
项目根目录/
└── w_build/        # 构建产物输出目录
    ├── app_uat_2026_0321_100000.apk    # UAT 模式 APK
    ├── app_live_1.0.0.apk              # 生产模式 APK
    ├── app_uat_2026_0321_100000.aab    # UAT 模式 AAB
    ├── app_live_1.0.0.aab              # 生产模式 AAB
    └── app_uat_2026_0321_100000.ipa    # UAT 模式 IPA
```

### 5. 命令行参数

| 参数 | 描述 |
|------|------|
| `apk` | 构建 Android APK |
| `aab` | 构建 Android AAB |
| `ios` | 构建 iOS IPA |
| `--uat` | 以 UAT 模式构建，添加时间戳 |
| `--clean` | 构建前清空构建目录 |
| `--open` | 构建后打开输出目录 |
| `--debug` | 启用调试模式，显示详细日志 |
| `--version` | 显示脚本版本信息 |
| `--help` | 显示帮助信息 |
| `--name=<name>` | 指定输出文件名中的应用名称 |
| `--export-options=<file>` | 指定 iOS 导出配置文件路径 |

### 6. 环境变量

| 环境变量 | 描述 | 默认值 |
|----------|------|--------|
| `OUTPUT_DIR` | 构建产物输出目录 | `w_build` |
| `DEBUG_MODE` | 是否启用调试模式 | `false` |
| `PARALLEL_BUILD` | 是否启用并行构建（Android 内部串行，只有 iOS 与 Android 之间并行） | `false` |
| `MIN_BUILD_SIZE` | 产物最小字节数，低于它视为构建失败 | `10240` |
| `ENABLE_NOTIFICATIONS` | 是否启用构建通知 | `true` |

### 7. 使用示例

#### 7.1 构建 APK（生产模式）

**功能**: 构建 Android APK，使用生产模式（版本号）

**命令**: 
```bash
ww build apk
```

**执行流程**:
1. 检查构建环境
2. 创建输出目录
3. 执行 `flutter build apk --release`
4. 复制构建产物到输出目录
5. 显示构建结果

#### 7.2 构建 AAB（生产模式）

**功能**: 构建 Android AAB，使用生产模式（版本号）

**命令**: 
```bash
ww build aab
```

#### 7.3 构建 iOS IPA（生产模式）

**功能**: 构建 iOS IPA，使用生产模式（版本号）

**命令**: 
```bash
ww build ios
```

#### 7.4 构建多个平台（UAT 模式）

**功能**: 同时构建 APK、AAB 和 iOS IPA，使用 UAT 模式（时间戳）

**命令**: 
```bash
ww build apk aab ios --uat
```

#### 7.5 构建 APK（UAT 模式，清理并打开输出目录）

**功能**: 构建 Android APK，使用 UAT 模式，构建前清理目录，构建后打开输出目录

**命令**: 
```bash
ww build apk --uat --clean --open
```

#### 7.6 使用并行构建

**功能**: 启用并行构建，同时构建多个平台，提高构建速度

**命令**: 
```bash
PARALLEL_BUILD=true ww build apk aab
```

#### 7.7 指定应用名称

**功能**: 通过 `-name` 参数指定输出文件名中的应用名称

**命令**: 
```bash
ww build apk --name=myapp
```

**输出文件名**:
- 生产模式: `myapp_live_1.0.0.apk`
- UAT 模式: `myapp_uat_2026_0525_100000.apk`

#### 7.8 iOS 构建指定导出配置

**功能**: 通过 `-export-options` 参数指定自定义的 iOS 导出配置文件

**命令**: 
```bash
ww build ios --export-options=uat.plist
```

**说明**:
- 默认会在 `w_build/` 目录下查找 `ios.plist` 文件
- 支持指定多个配置文件，如 `uat.plist`、`dev.plist` 等



### 8. 构建模式

#### 8.1 生产模式（默认）
- 使用 `pubspec.yaml` 中的版本号
- 生成的文件名格式：`app_live_<version>.apk`
- 适用于发布到应用商店的版本

#### 8.2 UAT 模式（--uat）
- 使用当前时间戳作为版本标识
- 生成的文件名格式：`app_uat_<timestamp>.apk`
- 适用于测试和内部发布的版本

### 9. 常见问题和解决方案

| 问题 | 解决方案 |
|------|----------|
| Flutter 未安装 | 安装 Flutter 并添加到 PATH |
| Android 构建失败 | 检查 Android SDK 安装和配置 |
| iOS 构建失败 | 检查 Xcode 安装和配置，确保已安装必要的证书 |
| 构建目录权限不足 | 确保当前用户有写入构建目录的权限 |
| 磁盘空间不足 | 确保有足够的磁盘空间用于构建 |

### 10. 高级用法

#### 10.1 自定义输出目录

**功能**: 自定义构建产物输出目录

**命令**: 
```bash
OUTPUT_DIR=my_build ww build apk
```

#### 10.2 禁用构建通知

**功能**: 禁用构建完成后的系统通知

**命令**: 
```bash
ENABLE_NOTIFICATIONS=false ww build apk
```

#### 10.3 启用调试模式

**功能**: 启用调试模式，显示详细的构建过程

**命令**: 
```bash
DEBUG_MODE=true ww build apk
```

### 11. 输出示例

#### 构建 APK 输出

```
======================================================
Flutter 应用打包脚本运行开始
======================================================
[INFO] 打包模式: PROD (Versioned)
[INFO] 打包版本: 1.0.0
[INFO] 构建平台: apk
[INFO] 检查构建环境...
[INFO] aapt 已找到: /path/to/aapt
[INFO] 环境检查完成
[WARN] 创建输出目录: w_build
[INFO] === Building APK ===
[INFO] 执行: flutter build apk --release
[INFO] 构建耗时: 60s
[INFO] APK 构建成功: /path/to/project/w_build/app_live_1.0.0.apk (20MB)
[INFO] === 打包完成！ ===
======================================================
Flutter 应用打包脚本运行结束
======================================================
```

#### 构建多个平台输出

```
======================================================
Flutter 应用打包脚本运行开始
======================================================
[INFO] 打包模式: UAT
[INFO] 打包时间戳: 2026_0321_100000
[INFO] 构建平台: apk aab ios
[INFO] 检查构建环境...
[INFO] 环境检查完成
[WARN] 创建输出目录: w_build
[INFO] === Building APK ===
[INFO] 执行: flutter build apk --release
[INFO] 构建耗时: 60s
[INFO] APK 构建成功: /path/to/project/w_build/app_uat_2026_0321_100000.apk (20MB)
[INFO] === Building AAB ===
[INFO] 执行: flutter build appbundle --release
[INFO] 构建耗时: 70s
[INFO] AAB 构建成功: /path/to/project/w_build/app_uat_2026_0321_100000.aab (18MB)
[INFO] === 构建 iOS ===
[INFO] 执行: flutter build ios --release --no-codesign
[INFO] 构建耗时: 90s
[INFO] iOS 构建成功: /path/to/project/w_build/app_uat_2026_0321_100000.ipa (25MB)
[INFO] === 打包完成！ ===
======================================================
Flutter 应用打包脚本运行结束
======================================================
```

### 12. 总结

`build.sh` 脚本是一个功能强大的 Flutter 应用打包工具，支持多平台构建、多种构建模式和详细的日志输出。通过使用此脚本，开发者可以：

- 快速构建 Flutter 应用的不同平台版本
- 灵活切换生产模式和 UAT 模式
- 提高构建效率，特别是使用并行构建功能
- 获得详细的构建过程和结果信息
- 确保构建产物符合应用商店要求

通过遵循本使用说明，开发者可以充分利用 `build.sh` 脚本的功能，为 Flutter 项目构建高质量的应用包。
### 参数写法（2026-10 起）

- `--name=<name>` / `--export-options=<file>`：等号写法，旧的单横线冒号写法
  （`-name:xxx`）已移除，使用时会直接报错并提示新写法
- 同一个平台写多次会被去重，只构建一次
