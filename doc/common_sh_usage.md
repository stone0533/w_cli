# common.sh 使用说明

## 脚本概述

`common.sh` 是一个通用脚本工具，提供了一些常用的辅助函数和命令，主要用于 Flutter 项目的开发过程中。

**脚本路径：** `/Users/lei0533/flutter/github_w_cli/lib/sh/common.sh`

**版本：** 1.0.0

**更新日期：** 2026-03-24

## 功能特点

- 提供 `drbb` 命令，执行 `dart run build_runner build --delete-conflicting-outputs`
- 支持调试模式，显示详细的执行信息
- 自动检测并使用可用的命令（优先使用 dart，其次使用 flutter）
- 统一的日志输出格式，使用彩色信息增强可读性
- 支持 `--help` 和 `--version` 参数

## 命令说明

### drbb

执行 `dart run build_runner build --delete-conflicting-outputs` 命令，用于生成和更新项目中的代码。

**参数：**
- `-d, --debug`：启用调试模式，显示详细的执行信息

**功能：**
1. 检查 Dart 或 Flutter 命令是否可用
2. 执行 build_runner build 命令
3. 显示执行结果和时间戳

## 使用示例

### 基本使用

```bash
# 执行 build_runner build 命令
./common.sh drbb

# 启用调试模式执行
./common.sh -d drbb

# 启用调试模式执行（使用长选项）
./common.sh --debug drbb
```

### 作为 ww 命令使用

```bash
# 执行 build_runner build 命令
ww common drbb

# 启用调试模式执行
ww common -d drbb

# 使用别名
ww co drbb  # 执行 build_runner build 命令
ww co -d drbb  # 启用调试模式执行
```

## 错误处理

- 如果 Dart 和 Flutter 命令都不可用，脚本会显示错误信息并退出
- 如果 build_runner build 命令执行失败，脚本会显示错误信息并返回失败状态

## 日志输出

脚本使用彩色日志输出，不同级别的信息使用不同颜色：
- 绿色：信息（INFO）
- 黄色：警告（WARN）
- 红色：错误（ERROR）
- 蓝色：调试信息（DEBUG，仅在调试模式下显示）

## 执行权限

确保脚本具有执行权限：

```bash
chmod +x /Users/lei0533/flutter/github_w_cli/lib/sh/common.sh
```