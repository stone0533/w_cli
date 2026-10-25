# ADR-0002：生成文本的 owner 只有 Dart 一侧

- 状态：已接受（2026-10-25 完成全部阶段）
- 相关：ADR-0001（client 解析与生成迁到 Dart）、#14 #15 #21 #23 #26 #27 #33 #34

## 背景

「生成出来的代码长什么样」**当时**由三处决定，它们互不调用：`lib/sh/api.sh`、
`lib/src/api/`（Dart）与 `lib/sh/setup.sh`。下表是决策当时的状态：

| 产物 | 当时 `api.sh` | 当时 Dart 侧 | 当时 `setup.sh` |
| --- | --- | --- | --- |
| `client.dart` / `paths.dart` | — | `init` 模板 | `ww create` 模板 |
| `data_source.dart` | 骨架 + marker 维护 | — | 模板 |
| `data_source_mixin.dart` | 模板 | 整份重写 | 模板 |
| `repository.dart` | 模板 | 整份重写 | 模板 |
| `models/*.dart` | python 渲染 | — | 无 |
| w_tools 导入 URI | `resolve_w_tools_import` | `resolveWtoolsImport` | 写死 meta 包 |
| 驼峰转蛇形 | `snake_name` | `snakeCase` | — |
| 头部注释 | `generate_header_comment` | `renderHeader` | — |


三类重复，风险不同：

1. **文本模板重复**：`init` 写出的 `repository.dart` / `data_source_mixin.dart` 骨架，会在第一次 `ww api` 时被整份覆盖。shell 那份模板的真实寿命只有「init 之后到第一次 generate 之前」。
2. **判定规则重复**：w_tools 导入 URI 的解析、驼峰转蛇形，两边各有一份实现且**都在被使用**——`api.sh` 维护 `data_source.dart` 的 marker，Dart 重写 `repository.dart`。两份规则漂移一次，就是 `repository.dart` 回退成写死 `package:w_tools/w.dart`、项目 29 个 error 的那次事故。
3. **写策略不一致**：`data_source.dart` 存在即跳过、mixin/repository 每次重写、models 走 mtime 增量。谁赢取决于执行顺序，无法从单点判断。

## 决策

1. **所有「生成文本」由 Dart 产出**（`lib/src/api/`、`lib/src/models/`、`lib/src/project/`）；shell 只保留 `build.sh` 的打包编排。
2. `ww api init` 与 `ww create` 全流程都由 Dart 实现，`api.sh` / `setup.sh` 已删除。
3. `data_source.dart` 的 marker 维护逻辑一并搬到 Dart（`syncWtoolsImport`）。
4. 任何生成器在写盘前必须做**手写内容检测**：文件里存在生成器不认识的成员时拒绝覆盖，除非 `--force`（`repository.dart` / `data_source_mixin.dart` 已实现，见 `lib/src/api/generated_file_guard.dart`）。
5. 保留一条硬约束：**生成器必须能在「已存在且被手写改过」的文件上安全运行**——跳过、拒绝或局部同步，三选一，绝不能静默整份覆盖。

## 后果

好的方面：

- 模板、判定规则、头部注释各只剩一份，`grep` 一次即可确认改全了。
- 模板可以被 golden 测试覆盖（`test/shell/fixtures/scaffold/` 已就位），迁移时用字节一致做闸门。
- `init` 不再依赖 bash，Windows 上也能用。
- 生成逻辑可单测，不再依赖「起子进程 + stub」。

代价与风险：

- 迁移期必须保证产物**字节一致**，否则业务仓库会出现大量无意义 diff。
- `data_source.dart` 的「存在即跳过 + marker 同步」要重写一遍（约 80 行 Python/awk 逻辑翻成 Dart）。
- shell 测试减少、Dart 测试增加，测试基线要重建一次。
- ~~`models` 仍依赖 python3~~ → Phase 3 已迁移，仓库不再需要 python3。

## 备选方案

- **反向收敛（全归 shell）**：放弃已有的解析器，回到正则。ADR-0001 明确否决过，不重复讨论。
- **只统一判定规则（C 方案）**：让 shell 调 `ww` 的隐藏子命令算 URI。能消掉最危险的一类漂移（约 50 行），但模板仍是两份，`init` 产物与 `generate` 产物继续各写各的。作为 Phase 1 不通过时的降级方案。
- **维持现状**：继续依赖 `AGENTS.md` 里「两边都要 grep」的纪律。它防不住「改完一侧再跑另一侧被覆盖」这类顺序问题。

## 迁移

| 阶段 | 内容 | 验收 | 状态 |
| --- | --- | --- | --- |
| 阶段 | 内容 | 验收 | 状态 |
| --- | --- | --- | --- |
| Phase 0 | 给 `init` 的五个产物加 golden | `test/scaffold_test.dart` 全绿 | **已完成** |
| Phase 0.5 | 覆盖前检测手写成员 | 手写方法后 `ww api` 拒绝并退出 1，`--force` 才覆盖 | **已完成** |
| Phase 1 | `ww api init` 改 Dart，`api.sh init` 移除并指路 | 五件产物与 golden 字节一致 | **已完成** |
| Phase 2 | 删掉 shell 的模板与 `resolve_w_tools_import` / `snake_name` | `grep -rn "package:w_tools/w.dart" lib/sh/` 为空 | **已完成** |
| Phase 2b | `ww create` 的生成文本交给 Dart（`ProjectScaffolder`） | 产出与迁移前逐字节一致（包名除外） | **已完成** |
| Phase 3 | `models` 迁 Dart（`lib/src/models/`） | 七个 fixture 与 shell 产物逐字节一致 | **已完成** |
| Phase 3b | 删除 `lib/sh/api.sh`、`lib/sh/setup.sh`、`common.sh`、`clean.sh`、`open.sh`、`project.sh` | `lib/sh/` 只剩 `build.sh` + `lib.sh` | **已完成** |

每阶段独立提交，回滚 = revert 单个阶段。

## 验收清单（当前）

```bash
ls lib/sh/                          # build.sh  lib.sh —— 只有打包还留在 shell
grep -rn "package:w_tools/w.dart" lib/   # 只应命中 project_imports.dart 与 setup 模板里的 fallback
grep -rn "Auto-generated file" lib/      # 三个生成器各一处
grep -rn "python3" lib/                  # 应只剩历史注释
```

业务侧验证（在任一真实项目）：

```bash
ww api models --force   # 尾部出现「生成自检通过：无重复 import / 无重复 class」
ww api                  # 产物可编译
flutter analyze         # 无新增 error
```
