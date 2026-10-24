## Agent skills

### Issue tracker

Issues live as GitHub issues in `stone0533/w_cli`, driven by the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles map to same-named labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

single-context — one `GLOSSARY.md` at the repo root, architecture decisions in `docs/adr/`. See `docs/agents/domain.md`.

### 生成逻辑有两套实现（改之前先确认改哪套）

「生成出来的代码长什么样」由**两处**决定，它们互不调用：

| 实现 | 负责 | 写文件的方式 |
| --- | --- | --- |
| `lib/sh/api.sh` | `init`、`models`（模型文件）、`data_source.dart` / `repository.dart` 的**首次**创建 | 存在即跳过 |
| `lib/src/api/`（Dart，`w_cli api`） | `data_source_mixin.dart`、`repository.dart` 的**内容** | 每次整份重写 |

改模板/导入/头部这类「生成文本」时，**两边都要 grep 一遍**：

```bash
grep -rn "要改的那段文本" lib/src lib/sh
```

只改一边的后果：下次跑另一个命令，改动被覆盖回去 —— 曾经出现过「改完 api.sh 再跑 `w_cli api`，
`repository.dart` 又变回写死的 `package:w_tools/w.dart`，项目 29 个 error」。
判定规则（`resolveWtoolsImport` / `resolve_w_tools_import`）两边必须保持一致。

### 生成器改动约定（api.sh）

`lib/sh/api.sh` 生成的模型文件会直接进业务仓库，**生成物脏了就是 bug**。改动生成逻辑时：

1. **改完必须跑一次全量生成**（在任一使用本工具的项目里）：
   `lib/sh/api.sh models --force`，确认尾部出现 `生成自检通过：无重复 import / 无重复 class`
   （语法已从 `--models --full` 改为子命令；旧写法会直接报错退出）
2. 自检（`verify_generated_models`）只认「重复 import / 重复 class」这两类**结构性**错误；
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
2. **导入 URI 不写死**：`resolve_w_tools_import` 先看 `lib/app/w/toolkit.dart` 是否存在
   （存在 → `package:<pubspec.name>/app/w/toolkit.dart`），否则回退 meta 包
   `package:w_tools/w.dart` 并告警。写死 meta 包会让已切分包的项目直接编译不过。
3. **老文件没有 marker 就跳过**（`sync_or_hint` 返回 3 时只提示），不要为了同步导入
   去覆盖手写内容；需要接管时由人手动补 marker。
4. marker 只用在**创建一次、之后手写**的文件上（目前只有 `data_source.dart`）。
   `repository.dart` / `data_source_mixin.dart` 由 Dart 侧每次整份重写，里面写 marker 是噪音。
