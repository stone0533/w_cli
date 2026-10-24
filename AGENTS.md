## Agent skills

### Issue tracker

Issues live as GitHub issues in `stone0533/w_cli`, driven by the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles map to same-named labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

single-context — one `GLOSSARY.md` at the repo root, architecture decisions in `docs/adr/`. See `docs/agents/domain.md`.

### 生成器改动约定（api.sh）

`lib/sh/api.sh` 生成的模型文件会直接进业务仓库，**生成物脏了就是 bug**。改动生成逻辑时：

1. **改完必须跑一次全量生成**（在任一使用本工具的项目里）：
   `lib/sh/api.sh --models --full`，确认尾部出现 `生成自检通过：无重复 import / 无重复 class`
2. 自检（`verify_generated_models`）只认「重复 import / 重复 class」这两类**结构性**错误；
   语义错误（类型推导错）靠 `flutter analyze` 与 build_runner 暴露
3. 涉及「同一份数据被多个循环消费」的改动，**每个循环都要自己去重** ——
   曾经 `collect_standalone_imports` 没去重而生成阶段去了重，导致 7 个模型文件重复 import
4. 自检必须在**所有模型都写完之后**跑；写在中间会把磁盘上的旧文件误报出来
