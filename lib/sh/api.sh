#!/bin/bash

# ======================================================
# api.sh - API 代码生成脚本
# Version: 1.0.0
# Last Updated: 2026-03-23
# Author: Stone
# Description: 根据 client.dart 动态生成 data_source_mixin.dart 和 repository.dart
# ======================================================

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置选项
DEBUG=false
INIT_MODE=false
MODELS_MODE=false

# 配置路径
CLIENT_FILE="lib/app/data/sources/client.dart"
REMOTE_DS_FILE="lib/app/data/sources/remote/data_source_mixin.dart"
REPOSITORY_FILE="lib/app/data/sources/repository.dart"
APP_REMOTE_DS_FILE="lib/app/data/sources/remote/data_source.dart"

# 转换为绝对路径
CLIENT_FILE=$(realpath "$CLIENT_FILE" 2>/dev/null || echo "$CLIENT_FILE")
REMOTE_DS_FILE=$(realpath "$REMOTE_DS_FILE" 2>/dev/null || echo "$REMOTE_DS_FILE")
REPOSITORY_FILE=$(realpath "$REPOSITORY_FILE" 2>/dev/null || echo "$REPOSITORY_FILE")
APP_REMOTE_DS_FILE=$(realpath "$APP_REMOTE_DS_FILE" 2>/dev/null || echo "$APP_REMOTE_DS_FILE")

# 辅助函数：检查命令是否可用
command_available() {
  command -v "$1" &> /dev/null
}

# 日志函数
log_info() {
  printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

log_warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_error() {
  printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

log_debug() {
  if [[ "$DEBUG" = true ]]; then
    printf "${BLUE}[DEBUG]${NC} %s\n" "$1"
  fi
}

# 显示版本信息
show_version() {
  echo "api.sh version: 1.0.0"
  echo "Last updated: 2026-03-21"
  echo "Description: 根据 client.dart 动态生成 data_source_mixin.dart 和 repository.dart"
  exit 0
}

# 显示帮助信息
show_help() {
  echo "使用方法: $0 [选项]"
  echo "选项:"
  echo "  -d, --debug    启用调试模式"
  echo "  --version      显示脚本版本信息"
  echo "  --init         初始化目录结构"
  echo "  --models       生成模型文件"
  echo "  --help         显示帮助信息"
  echo ""
  echo "示例:"
  echo "  $0              # 生成 API 代码"
  echo "  $0 --init       # 初始化目录结构"
  echo "  $0 --debug      # 启用调试模式生成代码"
  echo "  $0 --models     # 生成模型文件"
  exit 0
}

# 解析命令行参数
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d|--debug)
        DEBUG=true
        shift
        ;;
      --version)
        show_version
        ;;
      --init)
        # 标记为初始化模式
        INIT_MODE=true
        shift
        ;;
      --models)
        # 标记为模型生成模式
        MODELS_MODE=true
        shift
        ;;
      --help)
        show_help
        ;;
      *)
        log_error "未知参数: $1"
        show_help
        ;;
    esac
  done
}

# 检查文件是否存在
check_files() {
  if [[ ! -f "$CLIENT_FILE" ]]; then
    log_error "文件不存在: $CLIENT_FILE"
    return 1
  fi
  
  return 0
}

# 初始化目录结构
init_directory_structure() {
  local base_dir="lib/app/data"
  local sources_dir="$base_dir/sources"
  local remote_dir="$sources_dir/remote"
  
  # 检查并创建目录
  if [[ ! -d "$base_dir" ]]; then
    log_info "创建目录: $base_dir"
    mkdir -p "$base_dir"
  else
    log_info "目录已存在: $base_dir"
  fi
  
  if [[ ! -d "$sources_dir" ]]; then
    log_info "创建目录: $sources_dir"
    mkdir -p "$sources_dir"
  else
    log_info "目录已存在: $sources_dir"
  fi
  
  if [[ ! -d "$remote_dir" ]]; then
    log_info "创建目录: $remote_dir"
    mkdir -p "$remote_dir"
  else
    log_info "目录已存在: $remote_dir"
  fi
  
  # 检查并创建 models 目录
  local models_dir="$base_dir/models"
  if [[ ! -d "$models_dir" ]]; then
    log_info "创建目录: $models_dir"
    mkdir -p "$models_dir"
  else
    log_info "目录已存在: $models_dir"
  fi
  
  # 检查并创建 w_json 目录
  local json_dir="w_json"
  if [[ ! -d "$json_dir" ]]; then
    log_info "创建目录: $json_dir"
    mkdir -p "$json_dir"
  else
    log_info "目录已存在: $json_dir"
  fi
  
  # 检查并创建必要的文件
  if [[ ! -f "$sources_dir/client.dart" ]]; then
    log_info "创建文件: $sources_dir/client.dart"
    cat > "$sources_dir/client.dart" << 'EOF'
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

  // 这里新增需要的 API，然后执行 ww api generate 来自动生成对应的代码
}
EOF
  else
    log_info "文件已存在: $sources_dir/client.dart"
  fi
  
  if [[ ! -f "$sources_dir/paths.dart" ]]; then
    log_info "创建文件: $sources_dir/paths.dart"
    cat > "$sources_dir/paths.dart" << 'EOF'
class ApiPath {
  static const String baseUrl = 'https://api.example.com';

  // 认证相关
  static const String login = '/auth/login';
}
EOF
  else
    log_info "文件已存在: $sources_dir/paths.dart"
  fi
  
  if [[ ! -f "$remote_dir/data_source.dart" ]]; then
    log_info "创建文件: $remote_dir/data_source.dart"
    cat > "$remote_dir/data_source.dart" << 'EOF'
import 'package:w_tools/w.dart';
import '../client.dart';
import '../paths.dart';
import 'data_source_mixin.dart';

class AppRemoteDataSource extends BaseRemoteDataSource
    with AppRemoteDataSourceMixin {
  AppRemoteDataSource() {
    libRest = ApiClient(
      DioUtil.instance(
        ApiPath.baseUrl,
        interceptors: [
          WTokenInterceptor(),
          WLogInterceptor(),
          WErrorInterceptor(),
        ],
      ).dio,
    );
  }
}

EOF
  else
    log_info "文件已存在: $remote_dir/data_source.dart"
  fi
  
  # 检查并创建 data_source_mixin.dart 文件
  if [[ ! -f "$remote_dir/data_source_mixin.dart" ]]; then
    log_info "创建文件: $remote_dir/data_source_mixin.dart"
    cat > "$remote_dir/data_source_mixin.dart" << EOF
$(generate_header_comment)

import '../client.dart';

abstract class IAppRemoteDataSource {
  // 认证相关
  Future<dynamic> login(Map<String, dynamic> body);
}

mixin AppRemoteDataSourceMixin implements IAppRemoteDataSource {
  late final ApiClient libRest;

  // 认证相关
  @override
  Future<dynamic> login(Map<String, dynamic> body) {
    return libRest.login(body);
  }
}
EOF
  else
    log_info "文件已存在: $remote_dir/data_source_mixin.dart"
  fi
  
  # 检查并创建 repository.dart 文件
  if [[ ! -f "$sources_dir/repository.dart" ]]; then
    log_info "创建文件: $sources_dir/repository.dart"
    cat > "$sources_dir/repository.dart" << EOF
$(generate_header_comment)

import 'package:w_tools/w.dart';

import 'remote/data_source.dart';
import 'remote/data_source_mixin.dart';

class AppRepository extends BaseRepository<Null, AppRemoteDataSource>
    implements IAppRemoteDataSource {
  AppRepository() : super(remoteDataSource: AppRemoteDataSource());

  static AppRepository? _instance;

  static AppRepository _getInstance() {
    _instance ??= AppRepository();
    return _instance!;
  }

  static AppRepository get instance => _getInstance();

  static bool destroyInstance() {
    if (_instance == null) {
      return false;
    }
    _instance = null;
    return true;
  }

  // 认证相关
  @override
  Future<dynamic> login(Map<String, dynamic> body) {
    return remoteDataSource!.login(body);
  }
}
EOF
  else
    log_info "文件已存在: $sources_dir/repository.dart"
  fi
  
  log_info "✅ 目录结构初始化完成！"
}

# 解析参数
parse_params() {
  local params_part="$1"
  local params=()
  
  # 提取所有参数注解
  local param_annotations=$(echo "$params_part" | grep -oE "@[A-Za-z]+\([^)]*\)" || echo "")
  
  for annotation in $param_annotations; do
    if [[ "$annotation" == *"@Path"* ]]; then
      # 提取 @Path 参数名 - 从 params_part 中提取
      local param_name=$(echo "$params_part" | grep -o "@Path()[[:space:]]*[A-Za-z]+[[:space:]]+[A-Za-z]+" | grep -o "[A-Za-z]*$" | tail -1)
      if [[ -z "$param_name" ]]; then
        param_name="identifier"
      fi
      params+=($param_name)
    elif [[ "$annotation" == *"@Body"* ]]; then
      # 提取 @Body 参数名
      local param_name=$(echo "$params_part" | grep -o "@Body()[[:space:]]*[A-Za-z]+[[:space:]]+[A-Za-z]+" | grep -o "[A-Za-z]*$" | tail -1)
      if [[ -z "$param_name" ]]; then
        # 如果没有找到参数名，使用 body 作为默认值
        param_name="body"
      fi
      params+=($param_name)
    elif [[ "$annotation" == *"@Query"* ]] || [[ "$annotation" == *"@Queries"* ]]; then
      # 提取 @Query 或 @Queries 参数名
      local param_name=$(echo "$params_part" | grep -o "@[Qq]ueries()[[:space:]]*[A-Za-z]+[[:space:]]+[A-Za-z]+" | grep -o "[A-Za-z]*$" | tail -1)
      if [[ -z "$param_name" ]]; then
        param_name="queries"
      fi
      params+=($param_name)
    elif [[ "$annotation" == *"@Header"* ]]; then
      # 提取 @Header 参数名
      if [[ "$annotation" == *"@Header('"* ]]; then
        local param_name=$(echo "$annotation" | grep -o "'[^']*'" | cut -d"'" -f2)
        params+=($param_name)
      elif [[ "$annotation" == *"@Header("* ]]; then
        local param_name=$(echo "$annotation" | grep -o "@Header([^)]*)" | cut -d'(' -f2 | cut -d')' -f1 | awk '{print $2}')
        params+=($param_name)
      fi
    elif [[ "$annotation" == *"@Field"* ]]; then
      # 提取 @Field 参数名
      if [[ "$annotation" == *"@Field('"* ]]; then
        local param_name=$(echo "$annotation" | grep -o "'[^']*'" | cut -d"'" -f2)
        params+=($param_name)
      elif [[ "$annotation" == *"@Field("* ]]; then
        local param_name=$(echo "$annotation" | grep -o "@Field([^)]*)" | cut -d'(' -f2 | cut -d')' -f1 | awk '{print $2}')
        params+=($param_name)
      fi
    fi
  done
  
  # 合并参数为逗号分隔的字符串
  if [[ ${#params[@]} -eq 0 ]]; then
    echo ""
  else
    local params_str=$(IFS=,; echo "${params[*]}")
    echo "$params_str"
  fi
}

# 处理返回类型
process_return_type() {
  local return_type="$1"
  local model_type="$return_type"
  
  # 处理泛型类型
  if [[ "$return_type" == *"<"* ]]; then
    # 提取基础类型
    local base_type=$(echo "$return_type" | cut -d'<' -f1)
    # 提取泛型参数
    local generic_type=$(echo "$return_type" | cut -d'<' -f2 | cut -d'>' -f1)
    
    # 对于 List<T> 类型，使用 T 作为模型类型
    if [[ "$base_type" == "List" ]]; then
      model_type="$generic_type"
    fi
  fi
  
  echo "$model_type"
}

# 检查是否为基本类型或不需要模型的类型
is_basic_type() {
  local type="$1"
  # 基本类型列表
  local basic_types=("dynamic" "void" "bool" "int" "double" "String" "num")
  
  for basic_type in "${basic_types[@]}"; do
    if [[ "$type" == "$basic_type" ]]; then
      return 0
    fi
  done
  
  return 1
}

# 转换驼峰命名为蛇形命名
to_snake_case() {
  local camel_case="$1"
  # 移除末尾的 Result 后缀
  local base_name=$(echo "$camel_case" | sed 's/Result$//')
  # 转换为蛇形命名
  local snake_case=$(echo "$base_name" | awk '{for(i=1;i<=length;i++) {c=substr($0,i,1); if(c~/[A-Z]/ && i>1) printf "_" tolower(c); else printf tolower(c)}}')
  
  # 定义可能的文件名
  local result_file="${snake_case}_result.dart"
  local simple_file="${snake_case}.dart"
  local models_dir="lib/app/data/models"
  
  # 检查最常见的文件名（最快捷的匹配方式）
  if [ -f "$models_dir/$result_file" ]; then
    echo "$result_file"
    return
  fi
  
  if [ -f "$models_dir/$simple_file" ]; then
    echo "$simple_file"
    return
  fi
  
  # 如果目录不存在，直接返回默认值
  if [ ! -d "$models_dir" ]; then
    echo "$result_file"
    return
  fi
  
  # 一次性获取所有模型文件，避免重复执行 find 命令
  local all_models
  all_models=$(find "$models_dir" -name "*.dart" -type f -exec basename {} \; 2>/dev/null)
  
  # 如果 find 命令失败或没有结果，返回默认值
  if [ -z "$all_models" ]; then
    echo "$result_file"
    return
  fi
  
  # 内容匹配：查找包含指定类定义的文件（最准确的匹配方式）
  local model_file
  local class_pattern="(^|[[:space:]])class[[:space:]]+$camel_case([[:space:]]+|{|extends|implements)"
  local typedef_pattern="(^|[[:space:]])typedef[[:space:]]+$camel_case[[:space:]]*=[[:space:]]*"
  local extension_pattern="^extension[[:space:]]+$camel_case([[:space:]]+|on)"
  
  for model_file in $all_models; do
    local full_path="$models_dir/$model_file"
    # 检查文件中是否定义了所需的类，使用更精确的正则表达式
    if [ -f "$full_path" ] && grep -Eq "$class_pattern|$typedef_pattern|$extension_pattern" "$full_path" 2>/dev/null; then
      echo "$model_file"
      return
    fi
  done

  # 如果都没有找到，返回带 _result 后缀的文件名（保持向后兼容）
  echo "$result_file"
}

# 生成方法定义
generate_method_definition() {
  local method_info="$1"
  local show_override="$2"
  local return_statement="$3"
  
  IFS='|' read -r method_name return_type params comment http_method <<< "$method_info"
  
  # 跳过空的方法信息
  if [[ -z "$method_name" || -z "$return_type" ]]; then
    return
  fi
  
  if [[ -n "$comment" ]]; then
    echo "  // $comment"
  fi
  
  if [[ "$show_override" = true ]]; then
    echo "  @override"
  fi
  
  echo "  Future<$return_type> $method_name("
  
  # 处理多个参数
  if [[ -n "$params" ]]; then
    IFS=, read -ra param_array <<< "$params"
    for param in "${param_array[@]}"; do
      if [[ "$param" == "body" ]]; then
        echo "    Map<String, dynamic> $param,"
      elif [[ "$param" == "queries" ]]; then
        echo "    Map<String, dynamic> $param,"
      else
        echo "    String $param,"
      fi
    done
  fi
  
  if [[ -n "$return_statement" ]]; then
    echo "  ) {
    $return_statement
  }"
  else
    if [[ -n "$params" ]]; then
      echo "  );"
    else
      echo "  );"
    fi
  fi
  
  echo ""
}

# 解析 client.dart 提取 API 方法
parse_client() {
  local api_methods=()
  local in_class=false
  local current_comment=""
  local current_http_method=""
  local method_buffer=""
  
  if [[ ! -f "$CLIENT_FILE" ]]; then
    log_error "文件不存在: $CLIENT_FILE"
    return 1
  fi
  
  while IFS= read -r line; do
    # 检查是否进入 ApiClient 类
    if [[ "$line" == *"abstract class ApiClient"* ]]; then
      in_class=true
      continue
    fi
    
    # 检查是否退出类
    if [[ $in_class == true && "$line" == *"}" ]]; then
      in_class=false
      break
    fi
    
    if [[ $in_class == false ]]; then
      continue
    fi
    
    # 跳过工厂方法
    if [[ "$line" == *"factory ApiClient"* ]]; then
      continue
    fi
    
    # 提取 HTTP 方法注解
    if [[ "$line" == *"@GET"* ]]; then
      current_http_method="GET"
      continue
    elif [[ "$line" == *"@POST"* ]]; then
      current_http_method="POST"
      continue
    elif [[ "$line" == *"@PUT"* ]]; then
      current_http_method="PUT"
      continue
    elif [[ "$line" == *"@DELETE"* ]]; then
      current_http_method="DELETE"
      continue
    fi
    
    # 跳过注释行和空行
    if [[ "$line" =~ ^[[:space:]]*// ]] || [[ -z "$line" ]]; then
      continue
    fi
    
    # 收集方法定义行（处理跨多行的方法）
    if [[ "$line" == *"Future<"* ]]; then
      method_buffer="$line"
    elif [[ -n "$method_buffer" ]]; then
      method_buffer="$method_buffer $line"
    fi
    
    # 检查方法定义是否完成（包含分号）
    if [[ -n "$method_buffer" && "$method_buffer" == *");"* ]]; then
      # 提取返回类型
      local return_type=$(echo "$method_buffer" | grep -o 'Future<[^>]*>' | cut -d'<' -f2 | cut -d'>' -f1)
      
      if [[ -z "$return_type" ]]; then
        method_buffer=""
        continue
      fi
      
      # 提取方法名
      local method_name=$(echo "$method_buffer" | awk '{print $2}' | cut -d'(' -f1)
      
      if [[ -z "$method_name" ]]; then
        method_buffer=""
        continue
      fi
      
      # 提取参数部分（从第一个左括号到倒数第一个右括号）
      local params_part=$(echo "$method_buffer" | sed 's/.*Future<[^>]*> [^ (]* *(//' | sed 's/);.*//')
      
      # 解析参数
      local params=$(parse_params "$params_part")
      
      # 存储方法信息（不再包含HTTP方法，因为它在生成代码时不被使用）
      api_methods+=("$method_name|$return_type|$params|$current_comment")
      
      # 重置
      method_buffer=""
      current_comment=""
      current_http_method=""
    fi
  done < "$CLIENT_FILE"
  
  # 只返回 API 方法信息
  echo "${api_methods[@]}"
}

# 提取需要的模型导入
extract_imports() {
  local import_prefix="$1"
  shift
  local api_methods=($@)
  local models=""
  
  for method_info in "${api_methods[@]}"; do
    IFS='|' read -r method_name return_type params comment <<< "$method_info"
    
    # 跳过空的方法信息
    if [ -z "$method_name" ] || [ -z "$return_type" ]; then
      continue
    fi
    
    # 处理返回类型
    local model_type=$(process_return_type "$return_type")
    
    # 检查是否为基本类型，如果是则跳过
    if is_basic_type "$model_type"; then
      continue
    fi
    
    # 生成对应的模型文件路径
    local model_file=$(to_snake_case "$model_type")
    local model_path="lib/app/data/models/$model_file"
    
    # 检查文件是否存在
    if [ -f "$model_path" ]; then
      # 避免重复添加
      if [[ "$models" != *"$model_file"* ]]; then
        models+="$model_file "
      fi
    else
      # 只在终端输出警告，不写入文件
      log_warn "模型文件不存在: $model_path" >&2
    fi
  done
  
  # 生成导入语句
  for model in $models; do
    echo "import '$import_prefix$model';"
  done
}

# 提取 AppRemoteDataSource 中已存在的方法
extract_existing_methods() {
  local existing_methods=""
  
  if [ -f "$APP_REMOTE_DS_FILE" ]; then
    # 提取所有方法名，处理跨多行的情况
    local content=$(cat "$APP_REMOTE_DS_FILE")
    # 提取方法名并转换为空格分隔的字符串
    local methods=$(echo "$content" | grep -o "Future<[^>]*>\s*\w*" | grep -o "\w*$" | grep -v "^$" | tr '\n' ' ' | sed 's/\s\+$//')
    existing_methods="$methods"
  fi
  
  echo "$existing_methods"
}

# 生成自动生成文件的注释头部
generate_header_comment() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  cat << EOF
// **************************************************************************
// Auto-generated file. Do not edit manually.
// **************************************************************************
// This file was generated by api.sh on $timestamp
// Changes will be overwritten the next time the script runs.
// **************************************************************************

EOF
}

# 生成 app_remote_data_source_mixin.dart
generate_remote_datasource() {
  local api_methods=($@)
  
  # 提取已存在的方法
  local existing_methods=$(extract_existing_methods)
  # 确保调试信息输出到终端，而不是文件
  log_debug "提取到的已存在方法: $existing_methods" >&2
  
  # 生成注释头部
  local header_comment=$(generate_header_comment)
  
  # 生成动态模型导入
  local model_imports=$(extract_imports "../../models/" "${api_methods[@]}")
  
  # 输出文件内容
  echo "$header_comment"
  cat << 'EOF'
import '../client.dart';

EOF
  echo "$model_imports"
  cat << 'EOF'
abstract class IAppRemoteDataSource {
EOF
  
  for method_info in "${api_methods[@]}"; do
    generate_method_definition "$method_info" false ""
  done
  
  cat << 'EOF'
}

mixin AppRemoteDataSourceMixin implements IAppRemoteDataSource {
  late final ApiClient libRest;

EOF
  
  for method_info in "${api_methods[@]}"; do
    IFS='|' read -r method_name return_type params comment <<< "$method_info"
    
    # 跳过空的方法信息
    if [[ -z "$method_name" || -z "$return_type" ]]; then
      continue
    fi
    
    # 检查方法是否已在 AppRemoteDataSource 中存在
    if echo " $existing_methods " | grep -q " $method_name "; then
      # 确保调试信息输出到终端，而不是文件
      log_debug "方法 $method_name 已在 AppRemoteDataSource 中存在，跳过生成" >&2
      continue
    fi
    
    generate_method_definition "$method_info" true "return libRest.$method_name($params);"
  done
  
  cat << 'EOF'
}
EOF
}

# 生成 app_repository.dart
generate_repository() {
  local api_methods=($@)
  
  # 生成注释头部
  local header_comment=$(generate_header_comment)
  
  # 生成动态模型导入
  local model_imports=$(extract_imports "../models/" "${api_methods[@]}")
  
  # 输出文件内容
  echo "$header_comment"
  cat << 'EOF'
import 'package:w_tools/w.dart';

import 'remote/data_source.dart';
import 'remote/data_source_mixin.dart';

EOF
  echo "$model_imports"
  cat << 'EOF'

class AppRepository extends BaseRepository<Null, AppRemoteDataSource>
    implements IAppRemoteDataSource {
  AppRepository() : super(remoteDataSource: AppRemoteDataSource());

  static AppRepository? _instance;

  static AppRepository _getInstance() {
    _instance ??= AppRepository();
    return _instance!;
  }

  static AppRepository get instance => _getInstance();

  static bool destroyInstance() {
    if (_instance == null) {
      return false;
    }
    _instance = null;
    return true;
  }

EOF
  
  for method_info in "${api_methods[@]}"; do
    IFS='|' read -r method_name return_type params comment <<< "$method_info"
    
    # 跳过空的方法信息
    if [[ -z "$method_name" || -z "$return_type" ]]; then
      continue
    fi
    
    generate_method_definition "$method_info" true "return remoteDataSource!.$method_name($params);"
  done
  
  cat << 'EOF'
}
EOF
}

# 更新文件
update_files() {
  local api_methods=($@)
  
  # 生成并写入新内容
  generate_remote_datasource "${api_methods[@]}" > "$REMOTE_DS_FILE"
  generate_repository "${api_methods[@]}" > "$REPOSITORY_FILE"
  
  # 格式化生成的代码
  log_info "开始格式化代码..."
  if command_available dart; then
    dart format "$REMOTE_DS_FILE" "$REPOSITORY_FILE"
    log_info "代码格式化完成"
  elif command_available flutter; then
    flutter format "$REMOTE_DS_FILE" "$REPOSITORY_FILE"
    log_info "代码格式化完成"
  else
    log_warn "Dart 和 Flutter 命令都不可用，跳过代码格式化"
  fi
  
  log_info "已更新: $REMOTE_DS_FILE"
  log_info "已更新: $REPOSITORY_FILE"
}

# 检查并添加必要的依赖项
check_and_add_dependencies() {
  local pubspec_file="pubspec.yaml"
  
  if [[ ! -f "$pubspec_file" ]]; then
    log_error "文件不存在: $pubspec_file"
    return 1
  fi
  
  if ! command_available flutter; then
    log_error "Flutter 命令不可用，无法添加依赖项"
    return 1
  fi
  
  local updated=false
  
  # 检查并添加 dependencies 部分的依赖
  if ! grep -q "retrofit:" "$pubspec_file"; then
    log_info "添加 retrofit 依赖..."
    flutter pub add retrofit
    updated=true
  fi
  
  # 检查并添加 dev_dependencies 部分的依赖
  local dev_deps=(
    "build_runner"
    "json_serializable"
    "retrofit_generator"
  )
  
  for dep in "${dev_deps[@]}"; do
    if ! grep -q "$dep:" "$pubspec_file"; then
      log_info "添加 $dep 依赖..."
      flutter pub add --dev $dep
      updated=true
    fi
  done
  
  if [[ "$updated" = true ]]; then
    log_info "依赖项添加完成"
  else
    log_info "所有必要的依赖项已存在"
  fi
}

# 执行 build_runner build
run_build_runner() {
  log_info "执行 build_runner build..."
  if command_available dart; then
    dart pub run build_runner build --delete-conflicting-outputs
    log_info "build_runner build 执行完成"
  elif command_available flutter; then
    flutter pub run build_runner build --delete-conflicting-outputs
    log_info "build_runner build 执行完成"
  else
    log_warn "Dart 和 Flutter 命令都不可用，跳过 build_runner build"
  fi
}

# 生成模型文件
generate_models() {
  local pubspec_file="pubspec.yaml"
  local json_dir="w_json"
  local models_dir="lib/app/data/models"
  
  # 检查 pubspec.yaml 文件
  if [[ ! -f "$pubspec_file" ]]; then
    log_error "文件不存在: $pubspec_file"
    return 1
  fi
  
  # 检查 json_serializable 依赖
  if ! grep -q "json_serializable:" "$pubspec_file"; then
    log_info "添加 json_serializable 依赖..."
    if command_available flutter; then
      flutter pub add --dev json_serializable
    elif command_available dart; then
      dart pub add --dev json_serializable
    else
      log_error "Dart 和 Flutter 命令都不可用，无法添加依赖项"
      return 1
    fi
  else
    log_info "json_serializable 依赖已存在"
  fi
  
  # 检查 build_runner 依赖
  if ! grep -q "build_runner:" "$pubspec_file"; then
    log_info "添加 build_runner 依赖..."
    if command_available flutter; then
      flutter pub add --dev build_runner
    elif command_available dart; then
      dart pub add --dev build_runner
    else
      log_error "Dart 和 Flutter 命令都不可用，无法添加依赖项"
      return 1
    fi
  else
    log_info "build_runner 依赖已存在"
  fi
  
  # 检查 w_json 目录
  if [[ ! -d "$json_dir" ]]; then
    log_info "创建目录: $json_dir"
    mkdir -p "$json_dir"
  else
    log_info "目录已存在: $json_dir"
  fi
  
  # 检查 models 目录
  if [[ ! -d "$models_dir" ]]; then
    log_info "创建目录: $models_dir"
    mkdir -p "$models_dir"
  fi
  
  # 读取 json 文件
  local json_files=($json_dir/*.json)
  if [[ ${#json_files[@]} -eq 0 ]]; then
    log_error "未找到 json 文件: $json_dir"
    return 1
  fi
  
  log_info "找到 ${#json_files[@]} 个 json 文件:"
  for json_file in "${json_files[@]}"; do
    log_info "  - $(basename "$json_file")"
  done
  
  # 类型推断函数
  infer_type() {
    local value="$1"
    local field="$2"
    local class_name="$3"
    
    # 移除首尾空格
    value=$(echo "$value" | tr -d ' ')
    
    if [[ "$value" == "null" || "$value" == "None" ]]; then
      echo "String"
    elif [[ "$value" == "true" || "$value" == "false" || "$value" == "True" || "$value" == "False" ]]; then
      echo "bool"
    elif [[ "$value" =~ ^[0-9]+$ ]]; then
      echo "int"
    elif [[ "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then
      echo "double"
    elif [[ "$value" == "["* ]]; then
      echo "List"
    else
      # 对于字符串，Python 输出不带引号，所以我们假设非数字、非布尔、非 null 的值都是字符串
      echo "String"
    fi
  }

  # 生成字段声明函数
  generate_field_declaration() {
    local field="$1"
    local field_type="$2"
    local camel_field="$3"
    
    local declaration=""
    declaration+="  @JsonKey(name: '$field')\n"
    if [[ "$field_type" == *"?" ]]; then
      declaration+="  $field_type $camel_field;\n"
    else
      declaration+="  $field_type? $camel_field;\n"
    fi
    echo -e "$declaration"
  }

  # 生成模型类函数
  generate_model_class() {
    local json_content="$1"
    local class_name="$2"
    local file_path="$3"
    
    # 使用Python提取所有第一层字段
    local all_fields=$(echo "$json_content" | python3 -c "import json, sys; print(' '.join(json.load(sys.stdin).keys()))" 2>/dev/null || echo "")
    
    local field_declarations=""
    local constructor_params=""
    local nested_classes=""
    
    # 处理所有字段
    for field in $all_fields; do
      # 转换字段名（下划线转驼峰）
      local camel_field=$(echo "$field" | sed -E 's/(_)([a-z])/\U\2/g')
      
      # 提取字段值
      local value=$(echo "$json_content" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('$field'))" 2>/dev/null || echo "")
      
      # 处理嵌套对象
      if [[ "$value" == "{"* ]]; then
        # 生成嵌套类名
        local nested_class_name="${class_name}$(echo "$camel_field" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        local field_type="$nested_class_name"
        
        # 提取嵌套对象内容
        local nested_content=$(echo "$json_content" | python3 -c "import json, sys; data=json.load(sys.stdin); print(json.dumps(data.get('$field')))" 2>/dev/null || echo "{}")
        
        # 生成嵌套类
        nested_classes+="\n"$(generate_model_class "$nested_content" "$nested_class_name" "$file_path")
        
        # 生成字段声明（添加 @JsonKey 注解和空安全）
        field_declarations+="\n"$(generate_field_declaration "$field" "$field_type" "$camel_field")
        
        # 生成构造函数参数
        constructor_params+="this.$camel_field, "
      # 处理数组类型
      elif [[ "$value" == "["* ]]; then
        # 检查数组元素类型
        local array_content=$(echo "$json_content" | python3 -c "import json, sys; data=json.load(sys.stdin); arr=data.get('$field', []); print(json.dumps(arr[0]) if arr else '[]')" 2>/dev/null || echo "[]")
        
        if [[ "$array_content" == "{"* ]]; then
          # 数组元素是对象，生成嵌套类
          local nested_class_name="${class_name}$(echo "$camel_field" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
          field_type="List<$nested_class_name>"
          
          # 生成嵌套类
          nested_classes+="\n"$(generate_model_class "$array_content" "$nested_class_name" "$file_path")
        elif [[ "$array_content" == '"'* ]]; then
          # 数组元素是字符串
          field_type="List<String>"
        elif [[ "$array_content" =~ ^[0-9]+$ ]]; then
          # 数组元素是整数
          field_type="List<int>"
        elif [[ "$array_content" =~ ^[0-9]+\.[0-9]+$ ]]; then
          # 数组元素是浮点数
          field_type="List<double>"
        elif [[ "$array_content" == "true" || "$array_content" == "false" ]]; then
          # 数组元素是布尔值
          field_type="List<bool>"
        else
          # 其他类型数组
          field_type="List<dynamic>"
        fi
        
        # 生成字段声明（添加 @JsonKey 注解和空安全）
        field_declarations+="\n"$(generate_field_declaration "$field" "$field_type" "$camel_field")
        
        # 生成构造函数参数
        constructor_params+="this.$camel_field, "
      # 处理基本类型
      else
        # 推断类型
        local field_type=$(infer_type "$value" "$field" "$class_name")
        
        # 生成字段声明（添加 @JsonKey 注解和空安全）
        field_declarations+="\n"$(generate_field_declaration "$field" "$field_type" "$camel_field")
        
        # 生成构造函数参数
        constructor_params+="this.$camel_field, "
      fi
    done
    
    # 移除最后一个逗号和空格
    constructor_params=$(echo "$constructor_params" | sed 's/, $//')
    
    # 生成构造函数
    local constructor="$class_name($constructor_params);"
    
    # 生成类内容
    local class_content=""
    class_content+="@JsonSerializable()\n"
    class_content+="class $class_name extends Object {\n"
    class_content+="$field_declarations"
    
    if [[ -n "$all_fields" ]]; then
      class_content+="\n"
    fi
    
    class_content+="  $constructor\n"
    class_content+="\n"
    class_content+="  factory $class_name.fromJson(Map<String, dynamic> srcJson) => _\$${class_name}FromJson(srcJson);\n"
    class_content+="  Map<String, dynamic> toJson() => _\$${class_name}ToJson(this);\n"
    class_content+="}\n"
    
    # 返回类内容和嵌套类
    echo -e "$class_content$nested_classes"
  }

  # 转换 json 文件为 dart 文件
  log_info "开始转换 json 文件为 dart 文件..."
  for json_file in "${json_files[@]}"; do
    local json_name=$(basename "$json_file" .json)
    local dart_file="$models_dir/${json_name}.dart"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local class_name=$(echo "$json_name" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
    
    # 读取 json 文件内容并提取字段
    local json_content=$(cat "$json_file")
    
    # 生成主模型类
    local main_class_name="${class_name}Result"
    local file_content=""
    file_content+="$(generate_header_comment)"
    file_content+="\n"
    file_content+="import 'package:json_annotation/json_annotation.dart';\n"
    file_content+="\n"
    file_content+="part '${json_name}.g.dart';\n"
    file_content+="\n"
    
    # 使用 generate_model_class 函数生成主类和嵌套类
    local model_content=$(generate_model_class "$json_content" "$main_class_name" "$dart_file")
    file_content+="$model_content"
    
    # 生成 dart 文件
    log_info "生成文件: $dart_file"
    printf "$file_content" > "$dart_file"

  done
  
  # 执行 build_runner build
  run_build_runner
  
  # 格式化模型目录
  log_info "格式化模型目录..."
  if command_available dart; then
    dart format lib/app/data/models/
    log_info "模型目录格式化完成"
  else
    log_warn "Dart 命令不可用，跳过格式化"
  fi
  
  log_info "✅ 模型文件生成完成！"
}

# 主函数
main() {
  # 解析命令行参数
  parse_args "$@"
  
  # 添加运行开始分隔线
  printf "${GREEN}======================================================${NC}\n"

  # 处理模型生成模式
  if [[ "$MODELS_MODE" = true ]]; then
    printf "${GREEN}模型文件生成开始${NC}\n"
    printf "${GREEN}======================================================${NC}\n"
    
    generate_models
    
    # 添加运行结束分隔线
    printf "${GREEN}======================================================${NC}\n"
    printf "${GREEN}模型文件生成结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
    printf "${GREEN}======================================================${NC}\n"
    exit 0
  fi

  # 处理初始化模式
  if [[ "$INIT_MODE" = true ]]; then
    printf "${GREEN}API 目录结构初始化开始${NC}\n"
    printf "${GREEN}======================================================${NC}\n"
    
    log_info "检查并添加必要的依赖项..."
    check_and_add_dependencies
    
    log_info "开始初始化目录结构..."
    init_directory_structure
    
    # # 执行 build_runner build
    # run_build_runner
    
    # 添加运行结束分隔线
    printf "${GREEN}======================================================${NC}\n"
    printf "${GREEN}API 目录结构初始化结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
    printf "${GREEN}======================================================${NC}\n"
    exit 0
  fi
  
  # API 代码生成逻辑
  printf "${GREEN}API 代码生成脚本运行开始${NC}\n"
  printf "${GREEN}======================================================${NC}\n"
  
  log_info "开始 API 代码生成..."
  
  # 检查文件
  if ! check_files; then
    log_error "文件检查失败"
    exit 1
  fi

  # # 检查并添加 retrofit_generator 依赖
  # local pubspec_file="pubspec.yaml"
  # if [[ ! -f "$pubspec_file" ]]; then
  #   log_error "文件不存在: $pubspec_file"
  # else
  #   if ! grep -q "retrofit_generator:" "$pubspec_file"; then
  #     log_info "添加 retrofit_generator 依赖..."
  #     if command_available flutter; then
  #       flutter pub add --dev retrofit_generator
  #     elif command_available dart; then
  #       dart pub add --dev retrofit_generator
  #     else
  #       log_warn "Dart 和 Flutter 命令都不可用，无法添加 retrofit_generator 依赖"
  #     fi
  #   else
  #     log_info "retrofit_generator 依赖已存在"
  #   fi
  # fi

  # # 执行：dart pub run build_runner build
  # log_info "执行 build_runner..."
  # if command_available dart; then
  #   dart pub run build_runner build --delete-conflicting-outputs
  #   log_info "build_runner 执行完成"
  # elif command_available flutter; then
  #   flutter packages pub run build_runner build --delete-conflicting-outputs
  #   log_info "build_runner 执行完成"
  # else
  #   log_warn "Dart 或 Flutter 命令均不可用，跳过 build_runner"
  # fi
  
  # 直接解析 API 方法
  api_methods_str=$(parse_client)
  
  local api_methods=($api_methods_str)
  
  if [[ ${#api_methods[@]} -eq 0 ]]; then
    log_error "未解析到任何 API 方法"
    exit 1
  fi
  
  log_info "解析到 ${#api_methods[@]} 个 API 方法:"
  for method_info in "${api_methods[@]}"; do
    IFS='|' read -r method_name return_type params comment <<< "$method_info"
    log_info "  - $method_name -> $return_type"
  done
  
  # 更新文件
  log_info ""
  log_info "开始更新文件..."
  
  update_files "${api_methods[@]}"
  
  log_info ""
  log_info "✅ API 代码生成完成！"
  
  # 添加运行结束分隔线
  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}API 代码生成脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
  printf "${GREEN}======================================================${NC}\n"
}

# 调用主函数
main "$@"