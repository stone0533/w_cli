## Unreleased

### Breaking

- `lib/sh/api.sh` 删除：`init` / `models` / `generate` 全部由 Dart 实现（ADR-0002）。
  直接调用脚本的用法改用 `ww api init` / `ww api models` / `ww api`
- `ww api` 改为子命令写法，旧的 `--init` / `--models` / `--full` 不再支持（会报错并提示新写法）：
  | 旧写法 | 新写法 |
  |---|---|
  | `ww api --init` | `ww api init` |
  | `ww api --models` | `ww api models` |
  | `ww api --models --full` | `ww api models --force` |
- 生成器自检 `verify_generated_models` 现在真的会检查重复 class（之前只查 import）

### Changed

- `lib/sh/setup.sh` 1.1.0：按当前项目结构重写脚手架
  - 依赖改为 **w_tools 分包**（`core`/`app`/`form`/`ui`/`api`/`toast`/`qr`），不再安装 meta 包
    `w_tools`（会经 `w_tools_map` 拖进 `google_maps_flutter`）。一律用 **pub 发布版本**
    `^1.0.0`，不写本地 `path` 依赖（需要联调时用 `dependency_overrides`）；
    随之移除已无用的 `W_TOOLS_PATH` 配置
  - `retrofit` 钉 `4.9.0`、`json_annotation` 钉 `^4.9.0` —— 与 `retrofit_generator` 9.x 兼容
    （4.9.2 起 `Parser` 新增 `DartMappable`，9.x 的 switch 不认，`build_runner` 会编译失败）
  - devDependencies 增加 `w_tools_cli`：新项目可直接 `dart run w_tools_cli:doctor`
  - 新增步骤：`dart run w_tools_cli:init` 生成 `lib/app/w/toolkit.dart`、
    `lib/app/design_system/`、`.w_tools_doctor.yaml`、`AGENTS.md` 片段；
    init 不可用时兜底写聚合入口
  - 目录结构补 `lib/app/w`、`lib/app/design_system`
  - `main.dart` 模板改用 w_tools_app 1.x 的 `WApp.start()`：去掉已不存在的
    `designWidth` / `envFileName`（屏幕适配与 `.env` 由插件负责）

### Fixed

- **`ww build` / `ww create` / `ww project` 无法运行**：脚本被提取成临时文件后没有可执行位，
  而三个脚本里有「检查执行权限」的守卫，直接退出。守卫已删除（`ww` 一律用 `bash` 调用），
  并加了「不可执行的副本也能跑」的回归测试
- `ww create` 生成的 API 层改用 `ApiScaffolder`（与 `ww api init` 同一份模板），
  `setup.sh` 里重复的那份模板已删除

### Removed

- 删除 `lib/w_cli.dart` 里 10 个从未被命令分发的 stub handler
  （`handleCreatePage/Screen/Controller/View/Provider`、`handleInitCommand`、
  `handleGenerateLocales/Model`、`handleInstallCommand`、`handleRemoveCommand`）：
  它们都只打印「not yet implemented」，对应命令也从未在 `bin` 注册

### Added

- `ww run [任务名]` + `.ww/tasks`：项目自定义快捷键（一行一条 `名字 = 命令`，
  可提交到仓库给团队/CI 共用）；`ww run` 列任务、`--dry-run` 只打印
- `ww create` 会生成一份默认 `.ww/tasks`（gen / fmt / get）
- 四个内置短命令：`ww fmt`（dart format .）、`ww get`（flutter pub get）、
  `ww pod`（pod install --project-directory=ios）、`ww analyze`（flutter analyze）

### Changed

- 命令改名（旧名保留一版并提示）：
  | 旧 | 新 |
  |---|---|
  | `ww update` | `ww self-update`（`su`） |
  | `ww project --update` | `ww deps upgrade` |
  | `ww common drbb` | `ww gen` |
  | `ww build --clean` | `ww build --fresh` |
- `ww clean` 无参数改为打印帮助（以前会立刻清空所有构建产物），要清理请显式写 `ww clean all`
- `ww create <name>` 不再要求写 `project`（`ww create project <name>` 仍可用）
- `ww <命令> --help` 打印该命令自己的帮助；`ww build` / `ww common` 无参数也打印帮助

### Changed

- `lib/sh/lib.sh` 精简为「只服务 build.sh」：删掉 `ww::die` / `ww::require` /
  `ww::show_version` / `ww::usage_error` / `log_success`（其余脚本迁 Dart 后无人使用）
- `ww open` 改为 Dart 实现，`lib/sh/open.sh` 删除：支持 `i`/`a`/`b`/`r` 短别名，
  打开失败返回非零（旧脚本永远退 0）
- `lib/sh/setup.sh` 删除：`ww create` 编排也迁到 Dart（`lib/src/project/`），
  Windows 可用；assets 配置的兜底路径不再依赖 `sed -i ''`（只在 macOS 有效）
- `ww create` 的生成文本全部迁到 Dart：`lib/src/project/project_templates.dart` +
  `ProjectScaffolder`（main.dart / home / routes / CI / .env / toolkit），
  `setup.sh` 只剩编排
- `ww clean` / `ww project` 改为 Dart 实现，`lib/sh/clean.sh`、`lib/sh/project.sh` 删除：
  `--lock` / `--pod` 以前会被 ww 的参数解析拒绝，现在可用；Windows 也可用
- `ww common drbb` 改为 Dart 实现（`lib/src/tools/build_runner.dart`），`lib/sh/common.sh` 删除：
  统一 30 分钟超时、超时退出码 124、Windows 可用
- `ww common drbb --debug` / `-d` 之前会被 ArgParser 拒绝，现在可用
- `ww create` 在脚手架完成后统一调用 `BuildRunner`（`setup.sh` 不再自己跑 build_runner）

### Added

- `ww api models` 不再需要 python3：JSON→Dart 渲染在 `lib/src/models/`
- `ww api` 覆盖前检测手写成员，`--force` 才覆盖
- `ww api generate`（别名 `g`）显式写法
- `ww api -d/--debug` 可以传到脚本（之前会被参数解析拒绝）

## 1.0.30

- Updated version number to 1.0.30
- Updated build.sh script to version 1.0.2 with enhanced features
- Added `-name` parameter support for custom output file naming
- Added `-export-options` parameter for iOS build configuration
- Updated documentation to include new parameters and usage examples
- Enhanced script logging and debugging capabilities

## 1.0.29

- Updated version number to 1.0.29
- Fixed Flutter version compatibility issues
- Replaced deprecated `dart pub run` and `flutter pub run` commands with `dart run`
- Enhanced script compatibility for Flutter 3.10+
- Improved cross-version compatibility for build_runner execution

## 1.0.28

- Updated version number to 1.0.28
- Enhanced api.sh with incremental model generation mode
- Added --full flag for force full regeneration of models
- Updated documentation for api.sh with new features
- Added --full parameter support in command line parser
- Updated script version information

## 1.0.26

- Updated version number to 1.0.26

## 1.0.25

- Updated version number to 1.0.25
- Comprehensive pre-publishing checklist completed

## 1.0.24

- Updated version number to 1.0.24
- Improved documentation for all scripts
- Updated common.sh script with enhanced functionality
- Updated setup.sh script with improved project initialization
- Enhanced overall code structure and consistency

## 1.0.23

- Updated version number to 1.0.23
- Added `ww clean` command for Flutter project cleaning
- Enhanced setup.sh script with improved project initialization
- Updated common.sh script with better error handling
- Improved code structure and consistency
- Updated documentation with common and clean command usage

## 1.0.22

- Updated version number to 1.0.22
- Added common.sh script with drbb function
- drbb function executes: dart run build_runner build --delete-conflicting-outputs
- Updated resources in pubspec.yaml to include common.sh
- Added clean.sh to resources

## 1.0.21

- Updated version number to 1.0.21
- Improved code structure and consistency
- Fixed command parsing and parameter handling
- Enhanced error messages and user feedback
- Updated API command handling logic
- Removed unused generate command references

## 1.0.20

- Updated version number to 1.0.20
- Renamed setup_project.sh to setup.sh for consistency
- Updated test file to use setup.sh instead of setup_project.sh
- Generated detailed usage documentation for all scripts
- Improved code formatting and consistency
- Fixed script path resolution issues

## 1.0.19

- Updated version number to 1.0.19
- Enhanced setup_project.sh to use flutter pub add instead of get install
- Improved error handling and script reliability
- Ensured no get_cli dependency is used

## 1.0.18

- Updated version number to 1.0.18
- Removed get_cli dependency to avoid network issues
- Simplified dependency installation using flutter pub add
- Improved error handling and script reliability

## 1.0.17

- Updated version number to 1.0.17
- Improved script error handling and logging
- Enhanced code structure and readability

## 1.0.16

- Updated version number to 1.0.16
- Fixed parameter name in setup_project.sh call
- Changed --project-name to --name to match script expectations
- Added command aliases for easier usage:
  - `create` → `c`
  - `generate` → `g`
  - `update` → `u`
  - `build` → `b`
  - `open` → `o`
  - `project` → `p`
  - `api` → `a`
  - `ios` → `i`
  - `android` → `a`
  - `build` → `b`
  - `root` → `r`
- Added default behaviors:
  - `ww create` → `ww create project`
  - `ww generate` → `ww generate api`
  - `ww g` → `ww g api`
- Updated help messages to include aliases and default behaviors

## 1.0.15

- Updated version number to 1.0.15
- Fixed script path resolution issue for global installation
- Added symbolic link handling for script path resolution
- Improved .pub-cache directory traversal logic
- Enhanced error messages for resource file not found errors

## 1.0.14

- Updated version number to 1.0.14
- Removed deprecated w.dart file
- Added additional tests for script path resolution
- Improved error messages with detailed suggestions
- Enhanced resource file extraction logic

## 1.0.13

- Updated version number to 1.0.13
- Fixed issue with --clean and --uat options not being recognized for build command
- Updated ArgParser configuration for build command options
- Improved command parsing and option handling

## 1.0.12

- Updated version number to 1.0.12
- Improved log output by using real-time streaming for script execution
- Added current version display after update command
- Removed unnecessary script path print statements
- Enhanced error handling for script execution

## 1.0.11

- Updated version number to 1.0.11
- Added automatic execution permission for scripts
- Fixed command format to use `ww create project name` instead of `ww create project:name`
- Improved error handling for script execution

## 1.0.10

- Updated version number to 1.0.10
- Cleaned up code by removing unused handleSetupCommand function
- Updated README.md with correct installation instructions and command format
- Ensured project structure documentation is up-to-date

## 1.0.9

- Improved getScriptPath function with enhanced path discovery
- Added support for finding script files in current working directory
- Added support for traversing parent directories to find script files
- Enhanced error messages with all attempted paths
- Improved script path resolution for different installation environments

## 1.0.8

- Improved handleUpdateCommand function with better logging and error handling
- Added detailed output for version checking and update process
- Added verification step to confirm update success
- Added reminder to restart terminal for changes to take effect
- Simplified files configuration in pubspec.yaml using glob patterns
- Changed files pattern to bin/** and lib/** to ensure all files are included
- Ensure script files are properly included in published package

## 1.0.7

- Fixed files configuration in pubspec.yaml to explicitly include all script files
- Added specific entries for lib/sh directory and individual script files
- Ensure all script files are properly included in published package

## 1.0.6

- Fixed files configuration in pubspec.yaml to include lib directory
- Ensure script files are properly included in published package
- Updated files pattern to use directory paths instead of glob patterns

## 1.0.5

- Fixed script path resolution issue for global installation
- Added direct .pub-cache path resolution for script files
- Improved error messages with all attempted paths
- Enhanced path discovery for different installation environments

## 1.0.4

- Improved handleUpdateCommand function with better error handling
- Added exit code checking for update command
- Enhanced user feedback for update success and failure cases
- Added helpful error messages and suggestions

## 1.0.3

- Fixed script path resolution issue when running from global installation
- Improved getScriptPath function to handle different installation environments
- Added multiple path resolution strategies to find script files

## 1.0.2

- Changed command name from `w` to `ww` to avoid conflict with system `w` command
- Added `executables` field to pubspec.yaml to define command name
- Updated documentation and help messages to use `ww` command

## 1.0.1

- Added `files` field to pubspec.yaml to include sh directory in published package
- Fixed path resolution for scripts when running from global installation

## 1.0.0

- Initial version.
- Added `w create project` command for project initialization
- Added `w generate api` command for API code generation
- Added `w update` command for updating the tool
- Added `w build` command for building Flutter apps
- Added support for project initialization with setup_project.sh
- Updated command structure for better organization
