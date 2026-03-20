#!/bin/bash

# ======================================================
# api.sh - API 代码生成脚本
# Version: 1.0.0
# Last Updated: 2026-03-20
# Author: Stone
# Description: 根据 client.dart 动态生成 data_source_mixin.dart 和 repository.dart
# ======================================================

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置选项
DEBUG=false

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

# 解析命令行参数
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d|--debug)
        DEBUG=true
        shift
        ;;
      *)
        log_error "未知参数: $1"
        echo "使用方法: $0 [选项]"
        echo "选项:"
        echo "  -d, --debug    启用调试模式"
        exit 1
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

# 解析参数
parse_params() {
  local params_part="$1"
  local params=()
  
  # 提取所有参数注解
  local param_annotations=$(echo "$params_part" | grep -o "@[A-Za-z]*\([^)]*\)")
  
  for annotation in $param_annotations; do
    if [[ "$annotation" == *"@Path"* ]]; then
      # 提取 @Path 参数名
      if [[ "$annotation" == *"@Path('"* ]]; then
        local param_name=$(echo "$annotation" | grep -o "'[^']*'" | cut -d"'" -f2)
        params+=("$param_name")
      elif [[ "$annotation" == *"@Path("* ]]; then
        local param_name=$(echo "$annotation" | grep -o "@Path([^)]*)" | cut -d'(' -f2 | cut -d')' -f1 | awk '{print $2}')
        params+=("$param_name")
      fi
    elif [[ "$annotation" == *"@Body"* ]]; then
      # 提取 @Body 参数名
      local param_name=$(echo "$params_part" | grep -o "@Body([^)]*)\s*\w+\s+\w+" | grep -o "\w+" | tail -1)
      if [[ -z "$param_name" ]]; then
        # 如果没有找到参数名，使用 body 作为默认值
        param_name="body"
      fi
      params+=($param_name)
    elif [[ "$annotation" == *"@Query"* ]]; then
      # 提取 @Query 参数名
      if [[ "$annotation" == *"@Query('"* ]]; then
        local param_name=$(echo "$annotation" | grep -o "'[^']*'" | cut -d"'" -f2)
        params+=($param_name)
      elif [[ "$annotation" == *"@Query("* ]]; then
        local param_name=$(echo "$annotation" | grep -o "@Query([^)]*)" | cut -d'(' -f2 | cut -d')' -f1 | awk '{print $2}')
        params+=($param_name)
      fi
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
  local params_str=$(IFS=,; echo "${params[*]}")
  echo "$params_str"
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
  echo "${snake_case}_result.dart"
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
    echo "  );"
  fi
  
  echo ""
}

# 解析 client.dart 提取 API 方法
parse_client() {
  local api_methods=()
  local in_class=false
  local current_comment=""
  local current_http_method=""
  
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
    
    # 收集注释
    if [[ "$line" == *"// "* ]]; then
      current_comment=$(echo "$line" | sed 's/.*\/\/ *//')
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
    
    # 匹配方法定义: Future<Type> methodName(@Path() Type param);
    if [[ "$line" == *"Future<"* ]]; then
      # 提取返回类型
      local return_type=$(echo "$line" | grep -o 'Future<[^>]*>' | cut -d'<' -f2 | cut -d'>' -f1)
      
      if [[ -z "$return_type" ]]; then
        continue
      fi
      
      # 提取方法名
      local method_name=$(echo "$line" | awk '{print $2}' | cut -d'(' -f1)
      
      if [[ -z "$method_name" ]]; then
        continue
      fi
      
      # 提取参数部分
      local params_part=$(echo "$line" | cut -d'(' -f2- | rev | cut -d')' -f2- | rev)
      
      # 解析参数
      local params=$(parse_params "$params_part")
      
      # 存储方法信息
      api_methods+=("$method_name|$return_type|$params|$current_comment|$current_http_method")
      
      # 重置
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
    IFS='|' read -r method_name return_type params comment http_method <<< "$method_info"
    
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
      log_warn "模型文件不存在: $model_path"
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

# 生成 app_remote_data_source_mixin.dart
generate_remote_datasource() {
  local api_methods=($@)
  
  # 提取已存在的方法
  local existing_methods=$(extract_existing_methods)
  # 确保调试信息输出到终端，而不是文件
  log_debug "提取到的已存在方法: $existing_methods" >&2
  
  # 生成动态模型导入
  extract_imports "../../models/" "${api_methods[@]}"
  
  cat << 'EOF'
import '../client.dart';

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
    IFS='|' read -r method_name return_type params comment http_method <<< "$method_info"
    
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
  
  cat << 'EOF'
import 'package:flutter_w/w.dart';

import 'remote/data_source.dart';
import 'remote/data_source_mixin.dart';

EOF
  
  # 生成动态模型导入
  extract_imports "../models/" "${api_methods[@]}"
  
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
    IFS='|' read -r method_name return_type params comment http_method <<< "$method_info"
    
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
  if command -v dart &> /dev/null; then
    dart format "$REMOTE_DS_FILE" "$REPOSITORY_FILE"
    log_info "代码格式化完成"
  elif command -v flutter &> /dev/null; then
    flutter format "$REMOTE_DS_FILE" "$REPOSITORY_FILE"
    log_info "代码格式化完成"
  else
    log_warn "Dart 和 Flutter 命令都不可用，跳过代码格式化"
  fi
  
  log_info "已更新: $REMOTE_DS_FILE"
  log_info "已更新: $REPOSITORY_FILE"
}

# 主函数
main() {
  # 解析命令行参数
  parse_args "$@"
  
  # 添加运行开始分隔线
  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}API 代码生成脚本运行开始${NC}\n"
  printf "${GREEN}======================================================${NC}\n"
  
  log_info "开始 API 代码生成..."
  
  # 检查文件
  if ! check_files; then
    log_error "文件检查失败"
    exit 1
  fi
  
  # 直接解析 API 方法
  api_methods_str=$(parse_client)
  
  local api_methods=($api_methods_str)
  
  if [[ ${#api_methods[@]} -eq 0 ]]; then
    log_error "未解析到任何 API 方法"
    exit 1
  fi
  
  log_info "解析到 ${#api_methods[@]} 个 API 方法:"
  for method_info in "${api_methods[@]}"; do
    IFS='|' read -r method_name return_type params comment http_method <<< "$method_info"
    if [ -n "$http_method" ]; then
      log_info "  - $http_method $method_name -> $return_type"
    else
      log_info "  - $method_name -> $return_type"
    fi
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

# 执行主函数
main "$@"
