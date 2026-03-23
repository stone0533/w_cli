# build.sh - Flutter 应用打包脚本使用说明

## 1. 脚本概述

`build.sh` 是一个用于 Flutter 应用的多平台打包脚本，支持 Android APK、AAB 和 iOS IPA 打包，提供生产模式和 UAT 模式，以及详细的日志和错误处理。

### 版本信息
- **版本**: 1.0.1
- **最后更新**: 2026-03-21
- **作者**: Stone

## 2. 功能特点

- **多平台支持**: 支持 Android APK、AAB 和 iOS IPA 打包
- **模式选择**: 支持生产模式和 UAT 模式
- **并行构建**: 支持同时构建多个平台，提高构建速度
- **构建通知**: 构建完成后发送系统通知
- **详细日志**: 提供详细的构建过程日志和错误处理
- **应用商店要求检查**: 确保构建产物符合应用商店要求
- **构建目录管理**: 自动创建和管理构建输出目录

## 3. 安装和设置

### 前提条件
- Flutter 环境已安装
- Android 开发环境（用于 Android 构建）
- Xcode（用于 iOS 构建，仅 macOS）

### 安装步骤
1. 将 `build.sh` 脚本复制到项目的 `lib/sh` 目录中
2. 赋予脚本执行权限：
   ```bash
   chmod +x lib/sh/build.sh
   ```

## 4. 目录结构

执行脚本后，会在项目根目录创建 `w_build` 目录用于存放构建产物：

```
项目根目录/
└── w_build/        # 构建产物输出目录
    ├── app_uat_2026_0321_100000.apk    # UAT 模式 APK
    ├── app_live_1.0.0.apk              # 生产模式 APK
    ├── app_uat_2026_0321_100000.aab    # UAT 模式 AAB
    ├── app_live_1.0.0.aab              # 生产模式 AAB
    └── app_uat_2026_0321_100000.ipa    # UAT 模式 IPA
```

## 5. 命令行参数

| 参数 | 描述 |
|------|------|
| `apk` | 构建 Android APK |
| `aab` | 构建 Android AAB |
| `ios` | 构建 iOS IPA |
| `--uat` | 以 UAT 模式构建，添加时间戳 |
| `--clean` | 构建前清空构建目录 |
| `--open` | 构建后打开输出目录 |
| `--version` | 显示脚本版本信息 |
| `--help` | 显示帮助信息 |
| `-name:<app_name>` | 指定应用名称（用于生成的文件名） |

## 6. 环境变量

| 环境变量 | 描述 | 默认值 |
|----------|------|--------|
| `OUTPUT_DIR` | 构建产物输出目录 | `w_build` |
| `DEBUG_MODE` | 是否启用调试模式 | `false` |
| `PARALLEL_BUILD` | 是否启用并行构建 | `false` |
| `ENABLE_NOTIFICATIONS` | 是否启用构建通知 | `true` |

## 7. 使用示例

### 7.1 构建 APK（生产模式）

**功能**: 构建 Android APK，使用生产模式（版本号）

**命令**: 
```bash
./build.sh apk
```

**执行流程**:
1. 检查构建环境
2. 创建输出目录
3. 执行 `flutter build apk --release`
4. 复制构建产物到输出目录
5. 显示构建结果

### 7.2 构建 AAB（生产模式）

**功能**: 构建 Android AAB，使用生产模式（版本号）

**命令**: 
```bash
./build.sh aab
```

### 7.3 构建 iOS IPA（生产模式）

**功能**: 构建 iOS IPA，使用生产模式（版本号）

**命令**: 
```bash
./build.sh ios
```

### 7.4 构建多个平台（UAT 模式）

**功能**: 同时构建 APK、AAB 和 iOS IPA，使用 UAT 模式（时间戳）

**命令**: 
```bash
./build.sh apk aab ios --uat
```

### 7.5 构建 APK（UAT 模式，清理并打开输出目录）

**功能**: 构建 Android APK，使用 UAT 模式，构建前清理目录，构建后打开输出目录

**命令**: 
```bash
./build.sh apk --uat --clean --open
```

### 7.6 使用并行构建

**功能**: 启用并行构建，同时构建多个平台，提高构建速度

**命令**: 
```bash
PARALLEL_BUILD=true ./build.sh apk aab
```

### 7.7 指定应用名称

**功能**: 指定应用名称，用于生成的文件名

**命令**: 
```bash
./build.sh apk --name:my_app
```

## 8. 构建模式

### 8.1 生产模式（默认）
- 使用 `pubspec.yaml` 中的版本号
- 生成的文件名格式：`app_live_<version>.apk`
- 适用于发布到应用商店的版本

### 8.2 UAT 模式（--uat）
- 使用当前时间戳作为版本标识
- 生成的文件名格式：`app_uat_<timestamp>.apk`
- 适用于测试和内部发布的版本

## 9. 常见问题和解决方案

| 问题 | 解决方案 |
|------|----------|
| Flutter 未安装 | 安装 Flutter 并添加到 PATH |
| Android 构建失败 | 检查 Android SDK 安装和配置 |
| iOS 构建失败 | 检查 Xcode 安装和配置，确保已安装必要的证书 |
| 构建目录权限不足 | 确保当前用户有写入构建目录的权限 |
| 磁盘空间不足 | 确保有足够的磁盘空间用于构建 |

## 10. 高级用法

### 10.1 自定义输出目录

**功能**: 自定义构建产物输出目录

**命令**: 
```bash
OUTPUT_DIR=my_build ./build.sh apk
```

### 10.2 禁用构建通知

**功能**: 禁用构建完成后的系统通知

**命令**: 
```bash
ENABLE_NOTIFICATIONS=false ./build.sh apk
```

### 10.3 启用调试模式

**功能**: 启用调试模式，显示详细的构建过程

**命令**: 
```bash
DEBUG_MODE=true ./build.sh apk
```

## 11. 输出示例

### 构建 APK 输出

```
======================================================
Flutter 应用打包脚本运行开始
======================================================
[INFO] 打包模式: PROD (Versioned)
[INFO] 打包版本: 1.0.0
[INFO] 构建平台: apk
[INFO] 检查构建环境...
[INFO] aapt 已找到: /path/to/aapt
[INFO] 环境检查完成
[WARN] 创建输出目录: w_build
[INFO] === Building APK ===
[INFO] 执行: flutter build apk --release
[INFO] 构建耗时: 60s
[INFO] APK 构建成功: /path/to/project/w_build/app_live_1.0.0.apk (20MB)
[INFO] === 打包完成！ ===
======================================================
Flutter 应用打包脚本运行结束 2026-03-21 10:00:00
======================================================
```

### 构建多个平台输出

```
======================================================
Flutter 应用打包脚本运行开始
======================================================
[INFO] 打包模式: UAT
[INFO] 打包时间戳: 2026_0321_100000
[INFO] 构建平台: apk aab ios
[INFO] 检查构建环境...
[INFO] 环境检查完成
[WARN] 创建输出目录: w_build
[INFO] === Building APK ===
[INFO] 执行: flutter build apk --release
[INFO] 构建耗时: 60s
[INFO] APK 构建成功: /path/to/project/w_build/app_uat_2026_0321_100000.apk (20MB)
[INFO] === Building AAB ===
[INFO] 执行: flutter build appbundle --release
[INFO] 构建耗时: 70s
[INFO] AAB 构建成功: /path/to/project/w_build/app_uat_2026_0321_100000.aab (18MB)
[INFO] === 构建 iOS ===
[INFO] 执行: flutter build ios --release --no-codesign
[INFO] 构建耗时: 90s
[INFO] iOS 构建成功: /path/to/project/w_build/app_uat_2026_0321_100000.ipa (25MB)
[INFO] === 打包完成！ ===
======================================================
Flutter 应用打包脚本运行结束 2026-03-21 10:00:00
======================================================
```

## 12. 总结

`build.sh` 脚本是一个功能强大的 Flutter 应用打包工具，支持多平台构建、多种构建模式和详细的日志输出。通过使用此脚本，开发者可以：

- 快速构建 Flutter 应用的不同平台版本
- 灵活切换生产模式和 UAT 模式
- 提高构建效率，特别是使用并行构建功能
- 获得详细的构建过程和结果信息
- 确保构建产物符合应用商店要求

通过遵循本使用说明，开发者可以充分利用 `build.sh` 脚本的功能，为 Flutter 项目构建高质量的应用包。