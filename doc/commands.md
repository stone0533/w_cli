# 命令说明

每个 `ww` 子命令的用法、行为与边界。实现位置与修改约定见 `AGENTS.md`，架构决策见 [`adr/`](adr/)。

| 命令 | 实现 | 一句话 |
| --- | --- | --- |
| [`ww api`](#ww-api) | Dart | `client.dart` → API 层；`w_json` → 模型 |
| [`ww create`](#ww-create) | Dart | 从零搭一个符合约定的工程 |
| [`ww common`](#ww-common) | Dart | 跑 build_runner |
| [`ww clean`](#ww-clean) | Dart | 清构建产物 / 锁文件 / Pods |
| [`ww open`](#ww-open) | Dart | 打开 IDE 或目录 |
| [`ww deps`](#ww-deps) | Dart | 升级依赖与 Gradle |
| `ww gen` | Dart | 跑 build_runner（30 分钟超时） |
| [`ww fmt`](#内置短命令-fmt--get--pod--analyze) / `get` / `pod` / `analyze` | Dart | 常用长命令的短写法 |
| [`ww run`](#ww-run) | Dart | 执行 `.ww/tasks` 里的自定义任务 |
| `ww doctor` | Dart | 检查环境（flutter / dart / pod / 工程文件） |
| [`ww build`](#ww-build) | **bash** | 打包 APK / AAB / IPA |

> 除 `build` 外全部是纯 Dart，Windows 可直接用；`build` 需要 bash（Git Bash / WSL）。

## ww api

```bash
ww api                  # client.dart -> data_source_mixin.dart / repository.dart
ww api generate         # 同上（显式写法）
ww api init             # 初始化 lib/app/data 与五个骨架文件
ww api models           # w_json/*.json -> lib/app/data/models/*.dart
ww api models --force   # 忽略增量，全量重生成
ww api --force          # 覆盖 repository.dart 里检测到的手写成员
```

输出约定（全项目一致）：

```console
$ ww api models
=== ww api models · demo 1.0.0+1 ===
[INFO] 生成 7 个模型文件 → lib/app/data/models
=== 完成（16:15:06）===
```

- 开始横幅带**工程名与版本**（参照 build 的「构建 apk aab 1.0.0+1 (UAT …)」）
- 结束横幅是**完成时刻**；耗时在 `-d` 下以 `[INFO] 耗时 0.8s` 出现

- 每个命令有**开始 / 结束**横幅（结束行带耗时；失败时红色并带退出码）
- 前缀固定 `[INFO]` / `[WARN]` / `[ERROR]`；`INFO` 绿、`WARN` 黄、`ERROR` 红
- 颜色只在终端下输出；`NO_COLOR=1` 关闭，`CLICOLOR_FORCE=1` 强制开（CI 想看颜色时）
- 默认只留关键行；明细用 `-d` / `--debug` 打开
- 子进程输出默认落盘：build → `w_build/build.log`，build_runner → `w_build/build-runner.log`

要点：

- **只在 Flutter 工程里运行**：`init` / `generate` 要求当前目录有 `pubspec.yaml` 的 `flutter:` 段
  或 `lib/main.dart`，否则拒绝，避免在仓库根长出 `lib/app/`
- `client.dart` 用 Dart 写的扫描器解析（不是正则）：解析失败直接报错并给偏移量，不会写出半截文件
- `repository.dart` / `data_source_mixin.dart` 每次整份重写；文件里有生成器不认识的方法时**拒绝覆盖**，需 `--force`
- `data_source.dart` 是「生成一次、之后手写」的骨架，只有 marker 段里的 w_tools 导入由工具维护
- `models` 与旧 shell 版本逐字节一致（`test/models_test.dart` 的 golden），不需要 python3
- 已删除的旧写法（`--init` / `--models` / `--full`）会报错并给出新写法

## ww create

```bash
ww create my_app                  # 推荐写法
ww create project my_app          # 旧写法，仍然可用
ww c my_app                       # 别名
ww create my_app --force          # 覆盖同名目录（默认拒绝）
```

项目名必须小写字母开头、只含小写字母/数字/下划线，否则退出 2。

**不在已有工程里创建**：当前目录已有 `pubspec.yaml` 时直接拒绝（错误提示会告诉你去父目录），
除非显式加 `--force`——否则会在工程里套出一个子工程。

### 它做了什么

| # | 步骤 | 动作 |
| --- | --- | --- |
| 1 | 环境 | 找 `flutter` |
| 2 | 目录 | 已存在且无 `--force` → 退出 1 |
| 3 | `flutter create` | `--org com.sampras -a kotlin` |
| 4 | 依赖 | `get dio flutter_screenutil flutter_form_builder form_builder_validators json_annotation:^4.9.0`、`retrofit:4.9.0`、dev：`build_runner json_serializable retrofit_generator:^9.7.0 w_tools_cli` |
| 5 | 目录 | `assets/{fonts,images}`、`lib/app/{components,utils,services}`、`lib/app/data/{models,sources,sources/remote}`、`test`、`.github/workflows`、`w_json` |
| 6 | w_tools 分包 | `w_tools_{core,app,form,ui,api,toast,qr}:^1.0.0`（不含 `w_tools_map`）；补 `flutter.assets` |
| 7 | 接入骨架 | `dart run w_tools_cli:init`；不可用时兜底写 `lib/app/w/toolkit.dart` |
| 8 | 工程文件 | `main.dart` / home 三件套 / `app_pages` / `app_routes` / `.env` / `widget_test` / CI |
| 9 | API 层 | 与 `ww api init` 同一套模板 |
| 10 | build_runner | `BuildRunner`（30 分钟超时） |
| 11 | 格式化 | `dart format .` + 在 `analysis_options.yaml` 插入 `analyzer.exclude` |
| 12 | git | `git init`、`.gitignore` 补 `w_build/`、首次提交 |
| 13 | 健康检查 | pubspec + 目录存在性 |
| 14 | 打开 | `trae` → `studio` → macOS 的 `Android Studio.app` → 跳过 |

### 失败时的行为

- 任何一步失败：退出非零，并**删除本次创建的目录**
- 目标目录原本就存在：永远不删（除非显式 `--force`）

## ww deps

```bash
ww deps upgrade          # flutter pub upgrade + Gradle wrapper 指到 8.0
```

旧写法 `ww project --update` 仍可用。

1. 检查 `flutter`（不可用退出 1）
2. 打印当前 Flutter 版本
3. 需要 `pubspec.yaml`，执行 `flutter pub upgrade`
4. 有 `android/gradle/wrapper/gradle-wrapper.properties` 时，把 `distributionUrl` 改写为 `gradle-8.0-all.zip`
5. 没有 `android` 目录只告警，不算失败

## ww build

`lib/sh/build.sh` 是仓库里唯一保留的脚本：它串的是 `flutter build` / `xcodebuild` / `pod`，用 bash 编排更直接。

```bash
ww build apk                 # 生产模式 APK
ww build apk aab ios         # 多平台（顺序执行；重复平台会去重）
ww build apk --uat           # UAT 模式，文件名带时间戳
ww build apk --fresh         # 构建前清理旧的工具产物
ww build apk --name=MyApp    # 自定义产物文件名中的应用名
ww build ios --export-options=uat.plist
ww build apk -d              # 调试日志
```

命令行入口是 `ww build`；`bash lib/sh/build.sh ...` 等价（参数一致，脚本自己也能校验）。

### 参数

| 参数 | 说明 |
| --- | --- |
| `apk` / `aab` / `ios` | 目标平台，可给多个 |
| `--uat` | UAT 模式（文件名用时间戳） |
| `--fresh` | 构建前清理 `OUTPUT_DIR` 里本工具的旧产物（保留 `ios.plist` 等用户文件）；旧名 `--clean` 仍可用 |
| `--open` | 构建完打开输出目录 |
| `--name=<name>` | 产物文件名中的应用名，默认取当前目录名 |
| `--export-options=<file>` | iOS 导出配置，纯文件名时在 `OUTPUT_DIR` 里找 |
| `--debug` / `-d` | 调试日志 |
| `--version` / `--help` | 版本 / 帮助 |

### 环境变量

| 变量 | 说明 | 默认 |
| --- | --- | --- |
| `OUTPUT_DIR` | 产物目录 | `w_build` |
| `DEBUG_MODE` | 调试日志 | `false` |
| `PARALLEL_BUILD` | 并行构建（Android 内部串行，只有 iOS 与 Android 之间并行） | `false` |
| `ENABLE_NOTIFICATIONS` | 构建完成发系统通知 | `true` |
| `MIN_BUILD_SIZE` | 产物最小字节数，低于它视为失败 | `10240` |

### 产物

```
w_build/
├── <app>_live_<version>.apk      # 生产模式
├── <app>_uat_<时间戳>.apk        # UAT 模式
├── <app>_live_<version>.aab
├── <app>_live_<version>.ipa
├── <app>_live_<version>.dSYMs.zip # iOS 符号文件（App Store / Crashlytics 用）
├── ios.plist                     # iOS 导出配置（首次构建生成模板）
└── build.log                     # 每次构建追加的日志
```

- 版本号取自 `pubspec.yaml` 的 `version:`，`+` 会替换成 `-`（`1.2.3+4` → `1.2.3-4`）
- 每个构建步骤超时 30 分钟，超时退出 124
- 任一平台失败，整体退出 1；已成功的平台产物保留

### 日志

默认只留关键行（约 10 行），xcodebuild / gradle 的逐行输出写进 `w_build/build.log`：

```console
=== 构建 ios 1.0.0 (PROD) ===
[INFO] 未找到签名配置，按自动签名构建: team=ABC123DEF4 bundle=hk.app method=development
[INFO] Archive（xcodebuild）...
[INFO] 导出 IPA...
[INFO] dSYM: w_build/app_live_1.0.0.dSYMs.zip (41M)
[INFO] iOS 构建成功: w_build/app_live_1.0.0.ipa (37M)
[INFO]   签名 automatic · method development · team ABC123DEF4 · bundle hk.app · 用时 77s
=== 完成（14:42:57）===
[INFO] 构建细节: w_build/build.log（-d 可实时显示）
```

- `-d` / `--debug`：实时输出全部内容（排障用）
- 失败时自动打印子进程末尾 20 行 + 完整日志路径

### iOS 签名

**默认零配置**：只要 `ios/Runner.xcodeproj` 里有 `DEVELOPMENT_TEAM`，`ww build ios`
会直接按自动签名构建（`automatic` + `development`），不需要任何配置文件。

需要更多控制时，优先级从高到低：

| 优先级 | 位置 | 用途 |
| --- | --- | --- |
| 1 | `--method= --team= --bundle-id= --cert= --profile= --automatic --manual` | 临时切换，不写文件 |
| 2 | `w_build/ios.plist` | 个人覆盖（`w_build/` 已被 gitignore） |
| 3 | `ios/ExportOptions.plist` | 团队共用，可提交到仓库 |
| 4 | 自动探测 `DEVELOPMENT_TEAM` | 零配置，自动签名 |

手动签名（`--manual`）且没给 `--cert`/`--profile` 时，会**自动探测本机**：

- 证书：`security find-identity -v -p codesigning`，只认 `Apple Distribution` / `Apple Development`
- Profile：`~/Library/MobileDevice/Provisioning Profiles/*.mobileprovision`，按 bundle id 过滤

**唯一匹配才自动采用**；多个候选会列出来，要求用 `--cert=` / `--profile=` 指定。
非 macOS 或探测不到时，退回「请填写」的提示。

```bash
ww build ios --show-config                          # 只看用了哪套签名，不构建
ww build ios                                        # 本地/测试，无需配置
ww build ios --method=ad-hoc                        # 换分发方式
ww build ios --method=app-store --team=ABC123DEF4 \
             --bundle-id=com.x.y --cert="Apple Distribution: X (ID)" --profile="Profile 名"
```

### 生成一份可提交的配置

```bash
ww ios setup --dry-run     # 先看会写成什么
ww ios setup               # 写入 ios/ExportOptions.plist（已存在则拒绝，--force 覆盖）
```

值优先取命令行，其次自动探测：

```bash
ww ios setup --method=app-store --manual      # 用本机探测到的证书与 profile
ww ios setup --method=ad-hoc --team=ABC123DEF4
```

配置文件格式就是 Xcode 的 ExportOptions.plist：

```xml
<key>method</key><string>app-store</string>          <!-- app-store / ad-hoc / enterprise / development -->
<key>teamID</key><string>YOUR_TEAM_ID</string>       <!-- 10 位 -->
<key>signingStyle</key><string>manual</string>       <!-- manual / automatic -->
<key>signingCertificate</key><string>Apple Distribution: 公司名 (证书 ID)</string>
<key>provisioningProfiles</key><dict>…</dict>
```

- `manual` 时证书与 profile 必填；留 `YOUR_` 占位符会被拦下
- 证书名里的空格是正常的，会原样传给 `xcodebuild -codeSignIdentity`

### 常见问题

| 现象 | 原因 |
| --- | --- |
| 退出 1 +「目标目录已存在」 | 没加 `--force`，或项目名拼错 |
| 退出 124 | 构建超时（30 分钟） |
| 「构建产物不完整」 | 产物小于 `MIN_BUILD_SIZE` |
| iOS 提示「ios.plist 文件配置不正确」 | 缺 `method` / `teamID`，或仍有 `YOUR_` 占位符 |
| 手动签名签名失败 | `signingCertificate` 与钥匙串里的证书名不完全一致 |
