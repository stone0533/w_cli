# 测试布局

两套测试，各自负责不同的东西：

```
test/
├── *_test.dart            # Dart 单测：解析器、渲染器、命令、golden 对拍
├── fixtures/              # Dart 测试用的 golden
│   ├── api/               #   mixin / repository 的逐字节产物
│   └── models/            #   JSON -> 模型 的逐字节产物
│       ├── *.json         #     输入
│       ├── raw/           #     未经 dart format 的渲染结果（版本无关，用它比对）
│       ├── expected/      #     已格式化的结果（人工核对用）
│       └── standalone/    #     w_json.config 独立类场景
└── shell/                 # shell 测试：只剩 build.sh + lib.sh
    ├── run.sh             #   直接 bash 跑，失败即非零退出
    ├── fixtures/          #   shell 侧固定输入与产物
    └── stubs/             #   flutter 等命令的桩
```

## 文档锚点检查

`tool/check_doc_anchors.dart` 校验 Markdown 里的 `[x](#anchor)` 是否能对上标题。
CI 里跑；`docs/commands.md` 的章节被误删过、链接却还在，肉眼看不出。

```bash
dart run tool/check_doc_anchors.dart          # 检查整个仓库
dart run tool/check_doc_anchors.dart doc      # 只检查某个目录
```

## 怎么跑

```bash
dart test                # Dart：解析、渲染、命令行为
bash test/shell/run.sh   # shell：退出码契约、source、超时、build.sh 端到端
```

## 加测试时的选择

| 要测什么 | 放哪 |
| --- | --- |
| 解析 / 渲染 / 生成的文本 | `test/*_test.dart` + `test/fixtures/`（与 shell 旧产物对拍） |
| `ww` 子命令的参数、退出码、文件副作用 | `test/shell/run.sh`（用 stub 造外部命令） |
| `build.sh` 的纯函数与打包流程 | `test/shell/run.sh`（stub `flutter`） |

## 约定

- **golden 是逐字节契约**：改了渲染器又不想改业务仓库产物，测试必须仍然绿
- shell 测试不要往仓库根写文件（`setup_error.log` 这类曾经踩过）
- 测试里的脚本清单从 `lib/sh/` 动态取，不要硬编码文件名——删脚本时它要能自己跟上
