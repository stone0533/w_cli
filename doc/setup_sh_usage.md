# setup.sh - Flutter 项目初始化脚本使用说明

## 1. 脚本概述

`setup.sh` 是一个用于 Flutter 项目的初始化脚本，用于自动完成 Flutter 项目的初始化、依赖安装和核心文件创建，简化项目的搭建过程。

### 版本信息
- **版本**: 1.0.0
- **最后更新**: 2026-04-02
- **作者**: Stone

## 2. 功能特点

- **自动检测操作系统**: 支持 macOS、Linux 和 Windows 系统
- **Flutter 环境检查**: 检查 Flutter 安装状态和版本
- **完整目录结构**: 创建完整的项目目录结构
- **依赖管理**: 安装必要的依赖包
- **核心文件创建**: 创建核心数据层文件和配置文件
- **代码生成**: 生成 Retrofit 代码和序列化代码
- **Git 初始化**: 初始化 Git 仓库并配置 .gitignore
- **CI/CD 配置**: 创建 GitHub Actions 配置文件
- **项目健康检查**: 检查项目文件和目录结构

## 3. 安装和设置

### 前提条件
- Flutter 环境已安装
- Git 已安装（用于初始化 Git 仓库）
- Python 3（用于生成模型文件）

### 安装步骤
1. 将 `setup.sh` 脚本复制到项目的 `lib/sh` 目录中
2. 赋予脚本执行权限：
   ```bash
   chmod +x lib/sh/setup.sh
   ```

## 4. 目录结构

执行脚本后，会创建以下目录结构：

```
项目名称/
├── assets/             # 资源目录
│   ├── fonts/          # 字体资源
│   └── images/         # 图片资源
├── lib/                # 源代码目录
│   ├── app/            # 应用代码
│   │   ├── components/ # 组件
│   │   ├── utils/      # 工具类
│   │   ├── services/   # 服务
│   │   ├── data/       # 数据层
│   │   │   ├── models/     # 数据模型
│   │   │   └── sources/    # 数据源
│   │   │       ├── remote/  # 远程数据源
│   │   ├── modules/     # 功能模块
│   │   └── routes/      # 路由配置
├── test/               # 测试目录
├── .github/workflows/  # CI/CD 配置
├── w_json/             # JSON 文件目录（用于生成模型）
├── .env                # 环境配置文件
├── pubspec.yaml        # 项目依赖配置
└── .gitignore          # Git 忽略文件
```

## 5. 命令行参数

| 参数 | 描述 |
|------|------|
| `[project_name]` | 可选，指定项目名称 |
| `--help` | 显示帮助信息 |
| `--version` | 显示脚本版本信息 |

## 6. 使用示例

### 6.1 基本使用

**功能**: 使用默认项目名称初始化 Flutter 项目

**命令**: 
```bash
./setup.sh
```

**执行流程**:
1. 检查执行权限
2. 检测操作系统
3. 检查 Flutter 安装状态
4. 询问项目名称（使用默认名称）
5. 检查项目目录
6. 创建 Flutter 项目
7. 安装依赖包
8. 创建目录结构
9. 配置项目依赖
10. 创建核心文件
11. 生成代码
12. 格式化代码
13. 初始化测试
14. 初始化 Git 仓库
15. 创建 CI/CD 配置
16. 执行项目健康检查
17. 打开项目

### 6.2 自定义项目名称

**功能**: 使用指定的项目名称初始化 Flutter 项目

**命令**: 
```bash
./setup.sh my_app
```

## 7. 配置说明

### 7.1 核心配置

| 配置项 | 描述 | 默认值 |
|--------|------|--------|
| `DEFAULT_PROJECT_NAME` | 默认项目名称 | `my_flutter_app` |
| `DEFAULT_API_BASE_URL` | 默认 API 基础 URL | `https://api.example.com` |
| `DEFAULT_W_TOOLS_PATH` | w_tools 本地路径 | `/Users/lei0533/flutter/github_w_tools` |

### 7.2 环境配置文件

脚本会创建 `.env` 文件，包含以下配置：

```
# API 基础 URL
API_BASE_URL=https://api.example.com

# 其他配置
DEBUG=true
```

## 8. 常见问题和解决方案

| 问题 | 解决方案 |
|------|----------|
| Flutter 未安装 | 安装 Flutter 并添加到 PATH |
| Git 未安装 | 安装 Git 并添加到 PATH |
| 权限不足 | 确保当前用户有写入目录的权限 |
| 依赖安装失败 | 检查网络连接，确保 pub 服务器可访问 |
| 代码生成失败 | 检查依赖配置，确保 retrofit 相关依赖已正确安装 |
| 项目名称无效 | 项目名称只能包含小写字母、数字和下划线 |

## 9. 输出示例

### 初始化项目输出

```
=== 开始初始化项目 ===
[INFO] 检测到操作系统: macos
[INFO] 检查 Flutter 是否已安装...
[INFO] Flutter 已安装
[INFO] Flutter 版本: 3.10.0
[INFO] 检查权限...
[INFO] 权限检查通过
请输入项目名称: my_app
[INFO] 检查项目目录...
[INFO] 删除已存在的项目目录: my_app
[INFO] 项目目录检查通过
[INFO] 使用 flutter create 创建项目...
[INFO] 项目创建完成
[INFO] 安装项目依赖包...
[INFO] 依赖包安装完成
[INFO] 创建目录结构...
[INFO] 目录结构创建完成
[INFO] 配置项目依赖...
[INFO] 项目依赖配置完成
[INFO] 创建核心文件...
[INFO] 核心文件创建完成
[INFO] 生成代码...
[INFO] 代码生成完成
[INFO] 格式化代码...
[INFO] 代码格式化完成
[INFO] 初始化测试...
[INFO] 测试文件初始化完成
[INFO] 初始化 Git 仓库...
[INFO] Git 仓库初始化完成
[INFO] 创建 CI/CD 配置...
[INFO] CI/CD 配置创建完成
[INFO] 执行项目健康检查...
[INFO] ✓ pubspec.yaml 存在
[INFO] ✓ lib/app/data/sources/paths.dart 存在
[INFO] ✓ lib/app/data/sources/client.dart 存在
[INFO] ✓ lib/app/data/sources/remote/data_source.dart 存在
[INFO] ✓ lib/app/data/sources/repository.dart 存在
[INFO] ✓ assets/fonts 目录存在
[INFO] ✓ assets/images 目录存在
[INFO] ✓ lib/app/components 目录存在
[INFO] ✓ lib/app/utils 目录存在
[INFO] ✓ lib/app/services 目录存在
[INFO] ✓ lib/app/data/models 目录存在
[INFO] ✓ lib/app/data/sources 目录存在
[INFO] ✓ lib/app/data/sources/remote 目录存在
[INFO] ✓ test 目录存在
[INFO] 项目健康检查完成
=== 项目初始化完成 ===
项目已成功初始化，包含以下内容：
1. 使用 flutter create 创建了 Flutter 项目
2. 安装了必要的依赖包
3. 创建了完整的目录结构
4. 添加了 w_tools 本地依赖
5. 创建了核心数据层文件
6. 生成了 Retrofit 代码
7. 格式化了代码
8. 初始化了测试文件
9. 初始化了 Git 仓库
10. 创建了 CI/CD 配置
11. 执行了项目健康检查

接下来需要：
1. 根据实际需求修改 API 路径和接口
2. 实现具体的业务逻辑
3. 编写测试用例
4. 配置 CI/CD 流程
5. 部署项目
```

## 10. 总结

`setup.sh` 脚本是一个功能强大的 Flutter 项目初始化工具，通过自动化的方式完成项目的搭建和配置。使用此脚本可以：

- 快速创建 Flutter 项目，避免手动搭建的繁琐过程
- 确保项目目录结构的一致性和规范性
- 自动安装必要的依赖包，减少手动配置的错误
- 生成核心数据层文件，为 API 开发做好准备
- 初始化 Git 仓库和 CI/CD 配置，为团队协作和持续集成做好准备

通过遵循本使用说明，开发者可以充分利用 `setup.sh` 脚本的功能，快速搭建高质量的 Flutter 项目。