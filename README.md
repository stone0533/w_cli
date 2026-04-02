# w_cli

A comprehensive command-line tool for Flutter projects, providing API code generation, app building, and project management utilities.
一款全面的 Flutter 项目命令行工具，提供 API 代码生成、应用构建和项目管理功能。

## Features / 特性

- **API Code Generation / API 代码生成**: Automatically generate API-related code from `client.dart` / 自动从 `client.dart` 生成 API 相关代码
- **Flutter App Building / Flutter 应用构建**: Build Flutter apps for Android (APK/AAB) and iOS (IPA) / 为 Android (APK/AAB) 和 iOS (IPA) 构建 Flutter 应用
- **Project Creation / 项目创建**: Create Flutter projects with custom structure / 使用自定义结构创建 Flutter 项目
- **Project Opening / 项目打开**: Open Flutter project in IDEs and file managers / 在 IDE 和文件管理器中打开 Flutter 项目
- **Project Management / 项目管理**: Update Flutter project dependencies and configuration / 更新 Flutter 项目依赖和配置
- **Project Cleaning / 项目清理**: Clean Flutter project build files and update dependencies / 清理 Flutter 项目构建文件并更新依赖
- **Build Runner Execution / 构建运行器执行**: Run `build_runner` with a simple command / 使用简单命令运行 `build_runner`
- **Command Aliases / 命令别名**: Short aliases for all commands for faster usage / 为所有命令提供短别名以加快使用
- **Default Behaviors / 默认行为**: Intelligent defaults for common commands / 为常用命令提供智能默认值
- **Cross-Platform / 跨平台**: Works on macOS, Linux, and Windows / 支持 macOS、Linux 和 Windows

## Installation / 安装

### Global Installation / 全局安装

```bash
dart pub global activate w_cli
```

## Usage / 使用方法

### Basic Commands / 基本命令

```bash
# Show help / 显示帮助
ww --help

# Show version / 显示版本
ww --version

# Create a new Flutter project / 创建新的 Flutter 项目
ww create project my_app

# Using aliases / 使用别名
ww c p my_app

# Project creation automatically adds w_build directory to .gitignore / 项目创建会自动将 w_build 目录添加到 .gitignore

# Generate API code / 生成 API 代码
ww api

# Build Flutter app / 构建 Flutter 应用
ww build apk
ww build aab
ww build ios

# Update w_cli to latest version / 将 w_cli 更新到最新版本
ww update

# Update Flutter project dependencies and configuration / 更新 Flutter 项目依赖和配置
ww project --update

# Open Flutter project / 打开 Flutter 项目
ww open ios
ww open android
ww open build
ww open root

# Clean Flutter project / 清理 Flutter 项目
ww clean
ww clean android
ww clean ios
```

### Command Aliases / 命令别名

```bash
# Main commands / 主命令
ww create   → ww c
ww api      → ww a
ww update   → ww u
ww build    → ww b
ww project  → ww p
ww open     → ww o
ww clean    → ww cl

# Subcommands / 子命令
ww create project → ww create p
ww open ios       → ww open i
ww open android   → ww open a
ww open build     → ww open b
ww open root      → ww open r
```

### Default Behaviors / 默认行为

```bash
# Default to project creation / 默认为项目创建
ww create     → ww create project
```

### Examples with Aliases / 使用别名的示例

```bash
# Create a project using aliases / 使用别名创建项目
ww c p my_app

# Generate API code using aliases / 使用别名生成 API 代码
ww a

# Build using aliases / 使用别名构建
ww b apk --uat

# Open using aliases / 使用别名打开
ww o i  # Open iOS project / 打开 iOS 项目
ww o r  # Open root directory / 打开根目录

# Update project using alias / 使用别名更新项目
ww p --update  # Update Flutter project dependencies and configuration / 更新 Flutter 项目依赖和配置

# Clean project using alias / 使用别名清理项目
ww cl          # Clean all platforms / 清理所有平台
ww cl ios      # Clean iOS platform / 清理 iOS 平台
```

### API Code Generation / API 代码生成

```bash
# Generate API code / 生成 API 代码
ww api

# Generate with debug mode / 使用调试模式生成
ww api --debug

# Initialize API directory structure / 初始化 API 目录结构
ww api --init

# Generate model files from JSON / 从 JSON 生成模型文件
ww api --models

# Using aliases / 使用别名
ww a            # Generate API code / 生成 API 代码
ww a --init     # Initialize API directory structure / 初始化 API 目录结构
ww a --models   # Generate model files from JSON / 从 JSON 生成模型文件
```

### Flutter App Building / Flutter 应用构建

```bash
# Build APK in production mode / 在生产模式下构建 APK
ww build apk

# Build AAB in production mode / 在生产模式下构建 AAB
ww build aab

# Build iOS in production mode / 在生产模式下构建 iOS
ww build ios

# Build in UAT mode / 在 UAT 模式下构建
ww build apk --uat

# Clear build directory and build / 清空构建目录并构建
ww build apk --clean

# Open output directory after build / 构建后打开输出目录
ww build apk --open

# Build multiple platforms / 构建多个平台
ww build apk aab

# Build all platforms in UAT mode with clean and open / 在 UAT 模式下构建所有平台并清理和打开
ww build apk aab ios --uat --clean --open

# Using short aliases / 使用短别名
ww b apk -u -o          # Build APK in UAT mode and open output directory / 在 UAT 模式下构建 APK 并打开输出目录
ww b apk aab -c -o      # Build APK and AAB with clean and open output directory / 构建 APK 和 AAB 并清理和打开输出目录
```



### Project Opening / 项目打开

```bash
# Open iOS project in Xcode / 在 Xcode 中打开 iOS 项目
ww open ios

# Open Android project in Android Studio / 在 Android Studio 中打开 Android 项目
ww open android

# Open build directory in file manager / 在文件管理器中打开构建目录
ww open build

# Open root directory in file manager / 在文件管理器中打开根目录
ww open root
```

### Build Runner Execution / 构建运行器执行

```bash
# Run build_runner build with delete-conflicting-outputs / 运行 build_runner build 并删除冲突输出
ww common drbb

# Run with debug mode / 使用调试模式运行
ww common drbb --debug

# Using full path (if needed) / 使用完整路径（如果需要）
./lib/sh/common.sh drbb
```

### Project Management / 项目管理

```bash
# Update Flutter project dependencies and configuration / 更新 Flutter 项目依赖和配置
ww project --update

# Using alias / 使用别名
ww p --update
```

### Project Cleaning / 项目清理

```bash
# Clean all platforms / 清理所有平台
ww clean

# Clean specific platform / 清理特定平台
ww clean android    # Clean Android build files / 清理 Android 构建文件
ww clean ios        # Clean iOS build files / 清理 iOS 构建文件

# Clean with lock files / 清理并清理锁文件
ww clean --lock     # Clean build files and lock files / 清理构建文件和锁文件

# Clean iOS with Pods / 清理 iOS 并重新安装 Pods
ww clean ios --pod  # Clean iOS build files and reinstall Pods / 清理 iOS 构建文件并重新安装 Pods

# Using aliases / 使用别名
ww cl              # Clean all platforms / 清理所有平台
ww cl ios          # Clean iOS platform / 清理 iOS 平台
ww cl --lock       # Clean with lock files / 清理并清理锁文件
```

## Contributing / 贡献

Contributions are welcome! Please feel free to submit a Pull Request.
欢迎贡献！请随时提交拉取请求。

## License / 许可证

MIT