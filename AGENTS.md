## Agent skills

### Issue tracker

Issues live as GitHub issues in `stone0533/w_cli`, driven by the `gh` CLI. See `doc/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles map to same-named labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `doc/agents/triage-labels.md`.

### Domain docs

single-context — one `GLOSSARY.md` at the repo root, architecture decisions in `doc/adr/`. See `doc/agents/domain.md`.

### 生成逻辑的归属（ADR-0002）

生成文本的 owner 只有 Dart 一侧；`lib/sh/api.sh` 已删除。

| 实现 | 负责 | 写文件的方式 |
| --- | --- | --- |
| `lib/src/api/scaffolder.dart` | `init`：五个骨架文件 + `data_source.dart` 的 marker 同步 | 存在即跳过（marker 段除外） |
| `lib/src/api/api_generator.dart` | `generate`：`data_source_mixin.dart` / `repository.dart` | 整份重写，**有手写成员时拒绝**（`--force` 才覆盖） |
| `lib/src/models/models_generator.dart` | `models`：`w_json/*.json` → 模型 | 增量（mtime），批量校验后落盘 |
| `lib/src/project/project_scaffolder.dart` | `ww create`：`main.dart` / home / routes / CI / .env / toolkit | 存在即跳过（toolkit 只在缺失时兜底） |
| `lib/src/project/project_creator.dart` | `ww create` 全流程编排（flutter create / pub add / git / 目录 / 健康检查） | 不写模板，只调各 scaffolder |

改模板/导入/头部这类「生成文本」时，记得 `grep -rn "要改的那段文本" lib/`——
生成文本已经全部在 Dart；`lib/sh/` 只剩 build.sh（打包）+ lib.sh（它的共享库），都不写生成文本。
判定规则只有一份：`lib/src/api/project_imports.dart` 的 `resolveWtoolsImport`。

### 生成器改动约定（models）

生成的模型文件会直接进业务仓库，**生成物脏了就是 bug**。改动生成逻辑时：

1. **改完必须跑一次全量生成**（在任一使用本工具的项目里）：
   `ww api models --force`，确认尾部出现 `生成自检通过：无重复 import / 无重复 class`
   并对拍 `test/models_test.dart`（golden 是迁移前 shell 版本的逐字节产物）
2. 自检（`ModelsGenerator._verifyGeneratedModels`）只认「重复 import / 重复 class」这两类**结构性**错误；
   语义错误（类型推导错）靠 `flutter analyze` 与 build_runner 暴露
3. 涉及「同一份数据被多个循环消费」的改动，**每个循环都要自己去重** ——
   曾经 `collect_standalone_imports` 没去重而生成阶段去了重，导致 7 个模型文件重复 import
4. 自检必须在**所有模型都写完之后**跑；写在中间会把磁盘上的旧文件误报出来

### 骨架文件的导入（marker 约定）

`data_source.dart` 是**「生成一次、之后手写」**的骨架（里面有拦截器接线、`DioRegistry` 等
本地化配置），生成器绝不能整份覆盖它。`repository.dart` / `data_source_mixin.dart` 则是由
`w_cli api` 从 `client.dart` **推导**出来的，每次整份重写。

规则：

1. **w_tools 的导入行永远放在 marker 段内**，由工具维护，其余内容手写：
   ```dart
   // <<<GENERATED w_tools import（工具只维护下一行导入；本文件其余部分手写，不会被覆盖）
   import 'package:<pubspec.name>/app/w/toolkit.dart';
   // GENERATED>>>
   ```
2. **导入 URI 不写死**：`resolveWtoolsImport` 先看 `lib/app/w/toolkit.dart` 是否存在
   （存在 → `package:<pubspec.name>/app/w/toolkit.dart`），否则回退 meta 包
   `package:w_tools/w.dart` 并告警。写死 meta 包会让已切分包的项目直接编译不过。
3. **老文件没有 marker 就跳过**（`syncWtoolsImport` 返回 null 时只提示），不要为了同步导入
   去覆盖手写内容；需要接管时由人手动补 marker。
4. marker 只用在**创建一次、之后手写**的文件上（目前只有 `data_source.dart`）。
   `repository.dart` / `data_source_mixin.dart` 由 Dart 侧每次整份重写，里面写 marker 是噪音。
