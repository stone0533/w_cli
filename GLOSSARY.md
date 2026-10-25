# 术语表

仓库里反复出现的词，按「一句话解释 + 出处」写。改动这些概念时先读这里。

## 生成相关

| 术语 | 含义 |
| --- | --- |
| **生成文本** | 由工具写出的代码：`client.dart`、`paths.dart`、`data_source.dart`、`data_source_mixin.dart`、`repository.dart`、`models/*.dart`、`main.dart` 等。owner 只有 Dart 一侧（[ADR-0002](docs/adr/0002-generation-ownership.md)） |
| **marker 段** | `data_source.dart` 里 `// <<<GENERATED w_tools import …` 到 `// GENERATED>>>` 之间的区域。只有这一段由工具维护，其余手写 |
| **增量（mtime）** | `models` 的默认策略：JSON 比产物新才重新生成；`--force` 忽略增量全量重写 |
| **覆盖保护** | 整份重写的文件（`repository.dart` / `data_source_mixin.dart`）在发现「生成器不认识的方法」时**拒绝覆盖**，需 `--force`（[generated_file_guard.dart](lib/src/api/generated_file_guard.dart)） |
| **自检** | `models` 全部写完后校验「无重复 import / 无重复 class」；只认结构性错误，语义错误靠 `flutter analyze` |
| **golden** | `test/fixtures/` 与 `test/shell/fixtures/` 里的逐字节产物，用来钉住「生成结果不漂移」 |

## 工程与签名

| 术语 | 含义 |
| --- | --- |
| **w_tools 导入判定** | 决定生成文件里写 `package:<pubspec.name>/app/w/toolkit.dart` 还是回退 `package:w_tools/w.dart`；只有一份实现：[resolveWtoolsImport](lib/src/api/project_imports.dart) |
| **零配置签名** | `ww build ios` 在没有 plist 时，从 `ios/Runner.xcodeproj` 读 `DEVELOPMENT_TEAM`，按 `automatic + development` 直接出包 |
| **签名配置来源** | 优先级：命令行 > `w_build/ios.plist`（个人）> `ios/ExportOptions.plist`（团队可提交）> 零配置。`ww build ios --show-config` 会报出来源 |
| **profile / certificate** | iOS 签名两要素：Provisioning Profile（按 bundle id 匹配）与证书全名（`security find-identity` 里的字符串，含空格） |

## 命令与输出

| 术语 | 含义 |
| --- | --- |
| **内置动词** | `lib/src/commands/task_commands.dart` 里的短命令：`fmt` / `get` / `add` / `pod` / `analyze` / `fix` / `test` / `l10n` / `outdated` / `gen` / `watch` |
| **capture 模式** | 子进程输出落盘 `w_build/<cmd>.log`、终端只留摘要；`-d` 时改为实时透传（[capture.dart](lib/src/cli/capture.dart)） |
| **横幅** | `=== ww <命令> … ===`（开始）与 `=== 完成（时刻）===`（结束），绿色，由 `Cli.begin/end` 统一打 |
| **详述开关** | `-d` / `--debug`，全局可用；控制 `Cli.detail` 是否输出 |
| **`.ww/tasks`** | 项目内的自定义快捷键文件，`ww run <名字>` 执行；一行一条 `名字 = 命令` |

## 仓库约定

| 术语 | 含义 |
| --- | --- |
| **`lib/sh/`** | 只剩 `build.sh`（打包编排）与 `lib.sh`（共享库）；**不写任何生成文本** |
| **工作区卫生** | `test/shell/run.sh` 结束前对比 `git status`，且断言 `w_build/` `w_json/` `lib/app/` 不存在 |
| **锚点检查** | `tool/check_docs.dart`：校验 Markdown 里的 `#anchor` 是否都有对应标题 |
