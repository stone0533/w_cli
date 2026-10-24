# api.sh - API 目录初始化与模型生成

## 1. 脚本概述

`api.sh` 现在只负责一件事：`models` —— 从 `w_json/*.json` 生成 Dart 模型。目录初始化（`init`）与代码生成（`generate`）已迁到 Dart，见 ADR-0002。

> **`client.dart` -> `data_source_mixin.dart` / `repository.dart` 已迁到 Dart**，
> 请改用 `ww api`。原因与分阶段见 `docs/adr/0001-client-codegen-in-dart.md`。
> 直接运行 `api.sh`（不带参数）会报错并提示改用 `ww api`。

### 版本信息
- **版本**: 随 w_cli 包版本（`ww --version`）
- **作者**: Stone

## 2. 功能特点

- **目录结构初始化**: 可自动创建完整的 API 相关目录结构和基础文件
- **模型文件生成**: 支持从 JSON 文件生成 Dart 模型类，包括嵌套对象和数组类型
- **依赖管理**: 自动检查和添加必要的依赖项（json_serializable、build_runner 等）
- **代码格式化**: 生成后统一格式化
- **调试模式**: 提供调试模式，显示详细的执行过程
- **独立类**: 支持 `w_json/w_json.config` 声明跨文件复用的模型类
- **空安全支持**: 生成的模型完全支持 Dart 空安全
- **生成物校验**: 写盘前用 `dart format` 校验，不合法就保留原文件并报错

## 3. 安装和设置

### 前提条件
- Flutter 或 Dart 环境已安装
- 项目中已配置 `retrofit` 相关依赖

### 安装步骤
1. 将 `api.sh` 与共享库 `lib.sh` 一起复制到项目的 `lib/sh` 目录中（脚本会 source 同目录下的 `lib.sh`，少了它无法运行）
2. 赋予脚本执行权限：
   ```bash
   chmod +x lib/sh/lib.sh lib/sh/api.sh
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
| `init`（已移除，改用 `ww api init`） | 初始化 API 目录结构和基础文件 |
| `models` | 从 JSON 文件生成模型文件（默认增量模式） |
| `--force` | 配合 `models` 使用，忽略增量检查、全量重新生成 |
| `--help` | 显示帮助信息 |

## 6. 使用示例

### 6.1 生成 API 代码（已迁到 `ww api`）

这一步不再由 `api.sh` 负责：

```bash
ww api            # 解析 client.dart，生成 data_source_mixin.dart 与 repository.dart
```

- 解析与生成在 Dart 侧完成（`lib/src/api/`），解析不了会直接报错，不会生成半截文件
- 仍然会跳过 `data_source.dart` 里已经手写实现的方法
- 详见 `docs/adr/0001-client-codegen-in-dart.md`

### 6.2 初始化 API 目录结构

**功能**: 创建完整的 API 相关目录结构和基础文件

**命令**: 
```bash
ww api init
```

**执行流程**:
1. 检查并添加必要的依赖项（retrofit、build_runner 等）
2. 创建目录结构：`lib/app/data/sources/remote`、`lib/app/data/models` 等
3. 创建基础文件：`client.dart`、`paths.dart`、`data_source.dart` 等
4. 执行 `build_runner build` 生成初始代码

### 6.3 生成模型文件

**功能**: 从 `w_json` 目录中的 JSON 文件生成 Dart 模型类

**命令（增量模式，默认）**: 
```bash
./api.sh models
```

**命令（全量模式）**: 
```bash
./api.sh models --force
```

**执行流程**:
1. 检查并添加必要的依赖项（json_serializable、build_runner）
2. 读取 `w_json` 目录中的 JSON 文件
3. **增量模式**：检查文件修改时间，只更新需要更新的模型文件
4. **全量模式**：强制重新生成所有模型文件，忽略增量检查
5. 分析 JSON 结构，生成对应的 Dart 模型类
6. 执行 `build_runner build` 生成序列化代码
7. 格式化生成的代码

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
  
  // 使用自定义ApiClient实例
  @ApiClientId('libRest2')
  @GET(ApiPath.otherApi)
  Future<OtherData> getOtherData();
}
```

**自定义ApiClient实例说明：**
- 使用 `@ApiClientId('customName')` 注解可以为特定API方法指定使用不同的ApiClient实例
- 在 `data_source.dart` 中需要相应地初始化多个ApiClient实例
- 生成的代码会自动为每个自定义实例生成对应的声明和方法调用

## 8. 常见问题和解决方案

| 问题 | 解决方案 |
|------|----------|
| `client.dart` 文件不存在 | 执行 `ww api init` 初始化目录结构和文件 |
| 依赖项缺失 | 脚本会自动检查并添加必要的依赖项 |
| 模型文件不存在 | 确保 `w_json` 目录中有对应的 JSON 文件，或手动创建模型文件 |
| 代码生成失败 | 尝试使用 `--debug` 模式查看详细错误信息，或检查 `client.dart` 中的语法错误 |

## 9. 高级用法

### 9.1 自定义模型生成

1. 在 `w_json` 目录中创建 JSON 文件，例如 `user.json`
2. 执行 `./api.sh models` 生成对应的模型类
3. 在 `client.dart` 中使用生成的模型类作为返回类型

### 9.2 批量生成 API 代码

当修改了多个 API 接口时，只需执行一次 `./api.sh` 命令，脚本会自动更新所有相关文件。

## 10. 输出示例

### 生成 API 代码输出

这一步现在由 `ww api` 负责，示例输出：

```
🚀 Running API code generation
解析到 6 个 API 方法：
  - ping -> String
  - getUsers -> List<UserResult>
  ...
已更新: lib/app/data/sources/remote/data_source_mixin.dart
已更新: lib/app/data/sources/repository.dart
```

### 模型文件生成输出

```
======================================================
模型文件生成开始
======================================================
[INFO] 找到 2 个 json 文件:
[INFO]   - merchant.json
[INFO]   - user.json
[INFO]   ~ merchant.dart (生成/更新)
[INFO]   + user.json -> user.dart (新建)
[INFO] ✅ 模型文件生成完成！
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

`api.sh` 现在只管两件事：初始化 API 目录结构（`init`）与从 JSON 生成模型（`models`）。

API 层代码的生成（`client.dart` -> `data_source_mixin.dart` / `repository.dart`）已经迁到 Dart，
用 `ww api` 触发；解析与生成在同一处，解析失败会明确报错而不是写出半截文件。

日常使用：

```bash
ww api init             # 搭好目录与模板
ww api                  # 生成 data_source_mixin.dart / repository.dart
ww api models           # w_json/*.json -> lib/app/data/models/*.dart
ww api models --force   # 忽略增量，全量重生成
```