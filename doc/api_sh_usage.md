# api.sh - API 代码生成脚本使用说明

## 1. 脚本概述

`api.sh` 是一个用于 Flutter 项目的 API 代码生成脚本，根据 `client.dart` 文件动态生成 `data_source_mixin.dart` 和 `repository.dart` 文件，简化 API 层代码的编写和维护。

### 版本信息
- **版本**: 1.0.0
- **最后更新**: 2026-03-23
- **作者**: Stone

## 2. 功能特点

- **自动代码生成**: 根据 `client.dart` 中的 API 接口定义，自动生成相应的数据源和仓库代码
- **目录结构初始化**: 可自动创建完整的 API 相关目录结构和基础文件
- **模型文件生成**: 支持从 JSON 文件生成 Dart 模型类
- **依赖管理**: 自动检查和添加必要的依赖项
- **代码格式化**: 自动格式化生成的代码，确保代码风格一致
- **调试模式**: 提供调试模式，显示详细的执行过程

## 3. 安装和设置

### 前提条件
- Flutter 或 Dart 环境已安装
- 项目中已配置 `retrofit` 相关依赖

### 安装步骤
1. 将 `api.sh` 脚本复制到项目的 `lib/sh` 目录中
2. 赋予脚本执行权限：
   ```bash
   chmod +x lib/sh/api.sh
   ```

## 4. 目录结构

执行脚本后，会创建或更新以下目录结构：

```
lib/
└── app/
    └── data/
        ├── models/        # 存储数据模型
        └── sources/       # 存储数据源
            ├── remote/     # 远程数据源
            │   ├── data_source.dart           # 远程数据源实现
            │   └── data_source_mixin.dart     # 远程数据源混入类
            ├── client.dart                   # API 客户端接口
            ├── paths.dart                     # API 路径常量
            └── repository.dart                # 仓库模式实现
w_json/    # 存储 JSON 文件，用于生成模型
```

## 5. 命令行参数

| 参数 | 描述 |
|------|------|
| `-d, --debug` | 启用调试模式，显示详细的执行过程 |
| `--version` | 显示脚本版本信息 |
| `--init` | 初始化 API 目录结构和基础文件 |
| `--models` | 从 JSON 文件生成模型文件 |
| `--help` | 显示帮助信息 |

## 6. 使用示例

### 6.1 生成 API 代码

**功能**: 根据 `client.dart` 文件生成 `data_source_mixin.dart` 和 `repository.dart` 文件

**命令**: 
```bash
./api.sh
```

**执行流程**:
1. 检查 `client.dart` 文件是否存在
2. 检查并添加必要的依赖项
3. 执行 `build_runner build` 生成 Retrofit 代码
4. 解析 `client.dart` 中的 API 方法
5. 生成并更新 `data_source_mixin.dart` 和 `repository.dart` 文件
6. 格式化生成的代码

### 6.2 初始化 API 目录结构

**功能**: 创建完整的 API 相关目录结构和基础文件

**命令**: 
```bash
./api.sh --init
```

**执行流程**:
1. 检查并添加必要的依赖项（retrofit、build_runner 等）
2. 创建目录结构：`lib/app/data/sources/remote`、`lib/app/data/models` 等
3. 创建基础文件：`client.dart`、`paths.dart`、`data_source.dart` 等
4. 执行 `build_runner build` 生成初始代码

### 6.3 生成模型文件

**功能**: 从 `w_json` 目录中的 JSON 文件生成 Dart 模型类

**命令**: 
```bash
./api.sh --models
```

**执行流程**:
1. 检查并添加必要的依赖项（json_serializable、build_runner）
2. 读取 `w_json` 目录中的 JSON 文件
3. 分析 JSON 结构，生成对应的 Dart 模型类
4. 执行 `build_runner build` 生成序列化代码
5. 格式化生成的代码

### 6.4 使用调试模式

**功能**: 显示详细的执行过程，便于调试

**命令**: 
```bash
./api.sh --debug
```

## 7. 配置说明

### 7.1 核心配置文件

- **client.dart**: 定义 API 接口，使用 Retrofit 注解
- **paths.dart**: 定义 API 路径常量
- **w_json/**: 存储用于生成模型的 JSON 文件

### 7.2 API 接口定义示例

在 `client.dart` 中定义 API 接口：

```dart
import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';
import 'paths.dart';

part 'client.g.dart';

@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  // 认证相关
  @POST(ApiPath.login)
  Future<dynamic> login(@Body() Map<String, dynamic> data);

  // 其他 API 接口
  @GET(ApiPath.users)
  Future<List<User>> getUsers();
}
```

## 8. 常见问题和解决方案

| 问题 | 解决方案 |
|------|----------|
| `client.dart` 文件不存在 | 执行 `./api.sh --init` 初始化目录结构和文件 |
| 依赖项缺失 | 脚本会自动检查并添加必要的依赖项 |
| 模型文件不存在 | 确保 `w_json` 目录中有对应的 JSON 文件，或手动创建模型文件 |
| 代码生成失败 | 尝试使用 `--debug` 模式查看详细错误信息，或检查 `client.dart` 中的语法错误 |

## 9. 高级用法

### 9.1 自定义模型生成

1. 在 `w_json` 目录中创建 JSON 文件，例如 `user.json`
2. 执行 `./api.sh --models` 生成对应的模型类
3. 在 `client.dart` 中使用生成的模型类作为返回类型

### 9.2 批量生成 API 代码

当修改了多个 API 接口时，只需执行一次 `./api.sh` 命令，脚本会自动更新所有相关文件。

## 10. 输出示例

### 生成 API 代码输出

```
======================================================
API 代码生成脚本运行开始
======================================================
[INFO] 开始 API 代码生成...
[INFO] retrofit_generator 依赖已存在
[INFO] 执行 build_runner...
[INFO] build_runner 执行完成
[INFO] 解析到 2 个 API 方法:
[INFO]   - POST login -> dynamic
[INFO]   - GET getUsers -> List<User>
[INFO] 
[INFO] 开始更新文件...
[INFO] 开始格式化代码...
[INFO] 代码格式化完成
[INFO] 已更新: lib/app/data/sources/remote/data_source_mixin.dart
[INFO] 已更新: lib/app/data/sources/repository.dart
[INFO] 
[INFO] ✅ API 代码生成完成！
======================================================
API 代码生成脚本运行结束 2026-03-23 10:00:00
======================================================
```

### 初始化目录结构输出

```
======================================================
API 目录结构初始化开始
======================================================
[INFO] 检查并添加必要的依赖项...
[INFO] 开始初始化目录结构...
[INFO] 创建目录: lib/app/data
[INFO] 创建目录: lib/app/data/sources
[INFO] 创建目录: lib/app/data/sources/remote
[INFO] 创建目录: lib/app/data/models
[INFO] 创建目录: w_json
[INFO] 创建文件: lib/app/data/sources/client.dart
[INFO] 创建文件: lib/app/data/sources/paths.dart
[INFO] 创建文件: lib/app/data/sources/remote/data_source.dart
[INFO] 创建文件: lib/app/data/sources/remote/data_source_mixin.dart
[INFO] 创建文件: lib/app/data/sources/repository.dart
[INFO] ✅ 目录结构初始化完成！
[INFO] 执行 build_runner...
[INFO] build_runner 执行完成
======================================================
API 目录结构初始化结束 2026-03-23 10:00:00
======================================================
```

## 11. 总结

`api.sh` 脚本是一个强大的工具，可以显著减少 Flutter 项目中 API 层代码的编写工作量。通过自动生成数据源和仓库代码，它不仅提高了开发效率，还确保了代码的一致性和可维护性。

使用 `api.sh` 脚本，开发者可以：
- 快速初始化 API 相关目录结构
- 自动生成符合规范的 API 层代码
- 从 JSON 文件生成模型类
- 确保代码风格一致
- 减少手动编写重复代码的错误

通过遵循本使用说明，开发者可以充分利用 `api.sh` 脚本的功能，为 Flutter 项目构建高效、规范的 API 层。