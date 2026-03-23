# open.sh - Flutter 项目打开脚本使用说明

## 1. 脚本概述

`open.sh` 是一个用于 Flutter 项目的打开脚本，用于打开 Flutter 项目的不同部分，如 iOS 项目、Android 项目、构建目录和根目录。

### 版本信息
- **版本**: 1.0.0
- **最后更新**: 2026-03-21
- **作者**: Stone

## 2. 功能特点

- **多平台支持**: 支持打开 iOS 项目、Android 项目、构建目录和根目录
- **跨平台兼容**: 支持 macOS 和 Linux 系统
- **智能检测**: 自动检测操作系统并使用相应的打开方式
- **详细日志**: 提供详细的执行过程日志和错误处理

## 3. 安装和设置

### 前提条件
- Flutter 项目已创建
- 相应的 IDE 已安装（Xcode 用于 iOS，Android Studio 用于 Android）

### 安装步骤
1. 将 `open.sh` 脚本复制到项目的 `lib/sh` 目录中
2. 赋予脚本执行权限：
   ```bash
   chmod +x lib/sh/open.sh
   ```

## 4. 目录结构

脚本会打开以下目录和文件：

```
项目根目录/
├── ios/Runner.xcworkspace    # iOS 项目（用 Xcode 打开）
├── android/                  # Android 项目（用 Android Studio 打开）
├── w_build/                  # 构建目录（用 Finder/文件管理器打开）
└── 项目根目录                # 项目根目录（用 Finder/文件管理器打开）
```

## 5. 命令行参数

| 参数 | 描述 |
|------|------|
| `ios` | 用 Xcode 打开 iOS 项目 |
| `android` | 用 Android Studio 打开 Android 项目 |
| `build` | 用 Finder/文件管理器打开构建目录 |
| `root` | 用 Finder/文件管理器打开根目录 |
| `--help` | 显示帮助信息 |
| `--version` | 显示脚本版本信息 |

## 6. 使用示例

### 6.1 打开 iOS 项目

**功能**: 用 Xcode 打开 iOS 项目

**命令**: 
```bash
./open.sh ios
```

**执行流程**:
1. 检查 iOS 项目 workspace 文件是否存在
2. 检查当前操作系统是否为 macOS
3. 使用 Xcode 打开 iOS 项目
4. 显示打开结果

### 6.2 打开 Android 项目

**功能**: 用 Android Studio 打开 Android 项目

**命令**: 
```bash
./open.sh android
```

**执行流程**:
1. 检查 Android 项目目录是否存在
2. 检查当前操作系统
3. 根据操作系统使用相应的方式打开 Android Studio
4. 显示打开结果

### 6.3 打开构建目录

**功能**: 用 Finder/文件管理器打开构建目录

**命令**: 
```bash
./open.sh build
```

**执行流程**:
1. 检查构建目录是否存在
2. 根据操作系统使用相应的方式打开文件管理器
3. 显示打开结果

### 6.4 打开根目录

**功能**: 用 Finder/文件管理器打开根目录

**命令**: 
```bash
./open.sh root
```

**执行流程**:
1. 检查根目录是否存在
2. 根据操作系统使用相应的方式打开文件管理器
3. 显示打开结果

## 7. 常见问题和解决方案

| 问题 | 解决方案 |
|------|----------|
| iOS 项目文件不存在 | 确保 Flutter 项目已创建，且 iOS 目录存在 |
| Android 项目目录不存在 | 确保 Flutter 项目已创建，且 Android 目录存在 |
| 构建目录不存在 | 先执行构建命令创建构建目录 |
| Xcode 未安装 | 安装 Xcode（仅 macOS） |
| Android Studio 未安装 | 安装 Android Studio |
| 操作系统不支持 | 脚本仅支持 macOS 和 Linux 系统 |

## 8. 输出示例

### 打开 iOS 项目输出

```
[INFO] 用 Xcode 打开 iOS 项目...
[INFO] iOS 项目已成功打开
```

### 打开 Android 项目输出

```
[INFO] 用 Android Studio 打开 Android 项目...
[INFO] Android 项目已成功打开
```

### 打开构建目录输出

```
[INFO] 用 Finder 打开构建目录...
[INFO] 构建目录已成功打开
```

### 打开根目录输出

```
[INFO] 用 Finder 打开根目录...
[INFO] 根目录已成功打开
```

## 9. 总结

`open.sh` 脚本是一个便捷的 Flutter 项目打开工具，通过提供简单的命令，快速打开项目的不同部分。使用此脚本可以：

- 快速打开 iOS 项目，进行 iOS 相关的开发和调试
- 快速打开 Android 项目，进行 Android 相关的开发和调试
- 快速打开构建目录，查看构建产物
- 快速打开项目根目录，进行项目整体管理

通过遵循本使用说明，开发者可以充分利用 `open.sh` 脚本的功能，提高 Flutter 项目的开发效率。