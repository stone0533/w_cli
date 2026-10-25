# ww create 使用说明

从零创建一个符合本工具约定结构的 Flutter 工程。

> 2026-10 起由 Dart 实现（`lib/src/project/`），`lib/sh/setup.sh` 已删除。
> 变化：Windows 可用、无需 bash；失败时只清理本次创建的目录。

## 用法

```bash
ww create project my_app     # 完整写法
ww c p my_app                # 别名 + 简写
ww create project my_app --force   # 覆盖已存在的同名目录（默认拒绝）
```

项目名必须小写字母开头，只含小写字母、数字、下划线；不合法时退出 2。

## 它做了什么

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

## 失败时的行为

- `flutter create` 或后续步骤失败 → 退出非零，并**删除本次创建的目录**
- 目标目录是原来就有的 → 永远不会被删（除非显式 `--force`）

## 生成文本在哪

全部在 Dart：`lib/src/project/project_templates.dart`（工程文件）+
`lib/src/api/scaffolder.dart`（API 层）。`lib/sh/` 里已经没有生成文本。
