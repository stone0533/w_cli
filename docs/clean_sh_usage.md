# clean.sh - Flutter 应用清理脚本使用说明

## 1. 脚本概述

`clean.sh` 是一个用于 Flutter 应用的清理脚本，用于清理构建文件并执行 `flutter pub get`，确保项目环境的干净和依赖的更新。

### 版本信息
- **版本**: 1.0.0
- **最后更新**: 2026-03-21
- **作者**: Stone

## 2. 功能特点

- **多平台支持**: 支持清理 Android、iOS 和所有平台的构建文件
- **锁文件清理**: 支持清理 `pubspec.lock` 和 `Podfile.lock` 文件
- **iOS Pods 清理**: 支持清理 iOS Pods 目录
- **依赖更新**: 自动执行 `flutter pub get` 更新依赖
- **跨平台兼容**: 支持 macOS、Linux 和 Windows 系统
- **详细日志**: 提供详细的清理过程日志和错误处理

## 3. 安装和设置

### 前提条件
- Flutter 环境已安装
- iOS 构建需要安装 CocoaPods（仅 macOS）

### 安装步骤
1. 将 `clean.sh` 脚本复制到项目的 `lib/sh` 目录中
2. 赋予脚本执行权限：
   ```bash
   chmod +x lib/sh/clean.sh
   ```

## 4. 目录结构

脚本会清理以下目录和文件：

```
项目根目录/
├── build/             # Flutter 构建目录（会被清理）
├── ios/Pods/          # iOS Pods 目录（可选清理）
├── pubspec.lock       # Dart 依赖锁文件（可选清理）
└── ios/Podfile.lock   # iOS 依赖锁文件（可选清理）
```

## 5. 命令行参数

| 参数 | 描述 |
|------|------|
| `android` | 清理 Android 构建文件 |
| `ios` | 清理 iOS 构建文件 |
| `all` | 清理所有平台构建文件（默认） |
| `--help` | 显示帮助信息 |
| `--version` | 显示脚本版本信息 |
| `--lock` | 清理锁文件（pubspec.lock 或 Podfile.lock） |
| `--pod` | 清理 iOS Pods（仅适用于 iOS 平台） |

## 6. 配置选项

| 配置项 | 描述 | 默认值 |
|--------|------|--------|
| `MAX_RETRIES` | Pod update 最大重试次数 | 30 |

## 7. 使用示例

### 7.1 清理所有平台构建文件

**功能**: 清理所有平台的构建文件并更新依赖

**命令**: 
```bash
./clean.sh all
```

**执行流程**:
1. 检查构建环境
2. 执行 `flutter clean` 清理构建文件
3. 执行 `flutter pub get` 更新依赖
4. 显示清理结果

### 7.2 清理 Android 构建文件

**功能**: 只清理 Android 平台的构建文件并更新依赖

**命令**: 
```bash
./clean.sh android
```

### 7.3 清理 iOS 构建文件

**功能**: 只清理 iOS 平台的构建文件并更新依赖

**命令**: 
```bash
./clean.sh ios
```

### 7.4 清理锁文件

**功能**: 清理依赖锁文件并更新依赖

**命令**: 
```bash
./clean.sh --lock
```

### 7.5 清理 iOS Pods

**功能**: 清理 iOS Pods 目录、Podfile.lock 文件并更新依赖

**命令**: 
```bash
./clean.sh ios --pod
```

### 7.6 组合使用

**功能**: 清理所有平台的构建文件、锁文件，并更新依赖

**命令**: 
```bash
./clean.sh all --lock
```

## 8. 常见问题和解决方案

| 问题 | 解决方案 |
|------|----------|
| Flutter 未安装 | 安装 Flutter 并添加到 PATH |
| CocoaPods 未安装 | 安装 CocoaPods（`gem install cocoapods`） |
| 权限不足 | 确保当前用户有删除文件和目录的权限 |
| pod update 失败 | 脚本会自动重试，最多重试 30 次 |
| 依赖更新失败 | 检查网络连接和 `pubspec.yaml` 文件的正确性 |

## 9. 高级用法

### 9.1 自定义重试次数

**功能**: 自定义 Pod update 的最大重试次数

**命令**: 
```bash
MAX_RETRIES=50 ./clean.sh ios --pod
```

## 10. 输出示例

### 清理所有平台输出

```
======================================================
Flutter 应用清理脚本运行开始
======================================================
[INFO] 检查构建环境...
[INFO] 操作系统: macos
[INFO] 执行 flutter clean 命令...
[INFO] flutter clean 执行成功
[INFO] 执行 flutter pub get...
[INFO] flutter pub get 执行成功
[INFO] 执行 pod update...
[INFO] pod update 执行成功
[INFO] ✅ 清理完成！
======================================================
Flutter 应用清理脚本运行结束 2026-03-21 10:00:00
======================================================
```

### 清理 iOS Pods 输出

```
======================================================
Flutter 应用清理脚本运行开始
======================================================
[INFO] 检查构建环境...
[INFO] 操作系统: macos
[INFO] 删除 Pods 目录...
[INFO] Pods 目录删除成功
[INFO] 删除 Podfile.lock 文件...
[INFO] Podfile.lock 文件删除成功
[INFO] 执行 flutter clean 命令...
[INFO] flutter clean 执行成功
[INFO] 执行 flutter pub get...
[INFO] flutter pub get 执行成功
[INFO] 执行 pod update...
[INFO] pod update 执行成功
[INFO] ✅ 清理完成！
======================================================
Flutter 应用清理脚本运行结束 2026-03-21 10:00:00
======================================================
```

## 11. 总结

`clean.sh` 脚本是一个实用的 Flutter 应用清理工具，通过清理构建文件和更新依赖，确保项目环境的干净和一致性。使用此脚本可以：

- 快速清理构建文件，解决构建过程中的各种问题
- 确保依赖的一致性，避免依赖冲突
- 清理 iOS Pods，解决 iOS 构建中的依赖问题
- 跨平台使用，适用于不同的开发环境

通过遵循本使用说明，开发者可以充分利用 `clean.sh` 脚本的功能，保持 Flutter 项目的整洁和稳定。