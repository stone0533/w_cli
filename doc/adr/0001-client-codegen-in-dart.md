# ADR-0001：client.dart 的解析与代码生成迁到 Dart

- 状态：已接受（2026-10-24）
- 相关：#4 #5 #7 #8 #9 #11（`api.sh` 的一批修复）

## 背景

`lib/sh/api.sh` 承担两件事：

1. **解析 `client.dart` → 生成 `data_source_mixin.dart` / `repository.dart`**
2. 解析 `w_json/*.json` → 生成 `lib/app/data/models/*.dart`

第 2 件本质是「JSON → 文本」，用 python 生成是合适的，经过本轮修复（一次调用、数据走 stdin/argv）已经稳定。

第 1 件本质是**解析一种结构化的编程语言**，却是用 shell 正则做的：`grep -o 'Future<[^>]*>'`、`awk '{print $2}'`、按「行尾是不是 `}`」判断类结束。这一批 bug 全出自这里：

- 嵌套泛型被截断，一个 `Future<Map<String, dynamic>>` 就能生成非法 Dart（#4）
- BRE 里 `+` 是字面量，`@Path/@Body/@Query` 的名字全部落到 fallback（#5）
- 只能识别固定写法，遇到 `@Headers({...})`、多行签名、`}` 结尾的注释就静默丢方法

这些都是「正则凑出来的编译器」的固有失败模式：**静默丢信息，不报错**。继续打补丁只能让正则更长。

## 决策

把 **client.dart 的解析与 mixin/repository 的生成**迁到 Dart，落在 `lib/src/api/`：

- `client_parser.dart`：`client.dart` 源码 → `List<ApiMethod>`（纯函数，无 I/O）
- `client_renderer.dart`：模型 → 两个目标文件的文本（纯函数）
- `api_generator.dart`：读文件、跳过手写方法、原子写、返回退出码

`ww api` 的默认模式改走 Dart；`--init` 与 `--models` 仍由 `api.sh` 负责（那是 JSON 那一半，本轮不动）。

**不引入 `package:analyzer`**：一个手写的词法扫描器（正确跳过字符串/注释、按 `<>`/`()` 配对）已经能覆盖 `@RestApi` 接口的写法，且不给这个 CLI 增加一个重量级依赖。真需要 AST 时再升级，替换点就是这个模块。

## 后果

- 解析失败会**报错**，而不是生成半截文件（现在还有 `dart format` 校验兜底）。
- 解析与生成可以用普通 Dart 单测覆盖，不再依赖「起子进程 + stub」。
- 迁移期会短暂存在两套实现：`api.sh` 的 client 解析路径保留但不再被 `ww api` 调用，等 Dart 路径发一个版本后删除。
- 增量检查（mtime 比较）不再需要：Dart 路径生成两个文件是毫秒级，直接重写更简单，也避免「改了 data_source.dart 但 mixin 没重算」的陈旧问题。
- Windows 上不再需要把 `.sh` 交给 `powershell.exe`（迁移完成、删除 shell 路径后）。

## 分阶段

1. **本阶段**：解析 + 渲染 + 写入，接入 `ww api`；golden 测试对着现有 shell 产物比对。
2. 下一阶段：删除 `api.sh` 的 client 解析路径与 `parse_client`/`generate_*_datasource`/`generate_repository`/`update_files`，同步更新 `doc/api_sh_usage.md`。
3. 可选：`--models` 的 JSON 生成也迁到 Dart，`api.sh` 只留 `--init` 的模板初始化。

## 后续（2026-10-25）

本 ADR 列出的三个阶段都已完成，`lib/sh/api.sh` 已删除：

1. ~~删除 client 解析路径~~ —— 已完成（#15）
2. ~~`--models` 的 JSON 生成迁 Dart~~ —— 已完成（PR #27，见 ADR-0002 Phase 3）
3. `doc/api_sh_usage.md` 已并入 [`../commands.md`](../commands.md)

现在生成文本的归属与修改约定见 [ADR-0002](0002-generation-ownership.md)。
