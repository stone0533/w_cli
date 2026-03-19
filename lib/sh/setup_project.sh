#!/bin/bash
set -e  # 遇到错误立即退出

# 项目初始化脚本
# 功能：自动完成Flutter项目的初始化、依赖安装和核心文件创建
# Author: Stone
# 版本：2.4.0
# 日期：2026-03-08
#
# 使用方法：
#   bash setup_project.sh [选项]
#
# 选项：
#   --help            显示帮助信息
#   --flutter-w-path  指定 flutter_w 路径
#   --api-base-url    指定 API 基础 URL
#   --yes             自动确认所有操作
#   --dry-run         模拟执行，不实际操作
#   --project-name    指定项目名称
#   --config          指定配置文件路径
#
# 示例：
#   # 基本使用
#   bash setup_project.sh
#
#   # 自动确认所有操作
#   bash setup_project.sh --yes
#
#   # 自定义项目名称
#   bash setup_project.sh --project-name my_app
#
#   # 模拟执行
#   bash setup_project.sh --dry-run
#
#   # 使用配置文件
#   bash setup_project.sh --config my_config.sh

# 常量定义
readonly DEFAULT_PROJECT_NAME="my_flutter_app"
readonly DEFAULT_API_BASE_URL="https://api.example.com"
readonly DEFAULT_FLUTTER_W_PATH="/Users/lei0533/Work/SamprasCN/Flutter/00_base/stone_flutter_w"
readonly DEFAULT_CONFIG_FILE=".setup_config"
readonly PLUGIN_DIRECTORY=".plugins"

# 彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
PROJECT_NAME=""
API_BASE_URL="$DEFAULT_API_BASE_URL"
FLUTTER_W_PATH="$DEFAULT_FLUTTER_W_PATH"
AUTO_CONFIRM=false
DRY_RUN=false
OS=""
CONFIG_FILE="$DEFAULT_CONFIG_FILE"
TOTAL_STEPS=15
CURRENT_STEP=0

# 错误处理函数
handle_error() {
  local error_message="$1"
  local error_code="${2:-1}"
  
  echo -e "${RED}错误:${NC} $error_message"
  echo -e "${YELLOW}建议:${NC} 请检查错误信息并尝试解决问题"
  
  # 记录错误到日志文件
  local script_dir="$(dirname "$(realpath "$0")")"
  local log_file="$script_dir/setup_error.log"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $error_message" >> "$log_file"
  log_message "错误已记录到: $log_file"
  
  cleanup
  exit "$error_code"
}

# 清理函数
cleanup() {
  echo "正在清理资源..."
  
  # 仅在项目目录存在且非空时删除
  if [ -d "$PROJECT_NAME" ] && [ "$(ls -A "$PROJECT_NAME" 2>/dev/null)" ]; then
    echo "删除项目目录: $PROJECT_NAME"
    rm -rf "$PROJECT_NAME"
  fi
  
  # 清理临时文件
  if [ -n "$PROJECT_NAME" ]; then
    rm -f "$PROJECT_NAME/pubspec.yaml.tmp" 2>/dev/null
  fi
  
  # 清理插件目录
  if [ -d "$PLUGIN_DIRECTORY" ]; then
    rm -rf "$PLUGIN_DIRECTORY"
  fi
}

# 捕获错误
trap 'handle_error "脚本执行失败"' ERR

# 日志记录函数
log_message() {
  echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# 显示进度
show_progress() {
  local current="$1"
  local total="$2"
  local percentage=$((current * 100 / total))
  
  # 使用 ANSI 转义序列实现进度条
  echo -ne "${BLUE}进度:${NC} [$(printf '%*s' $((percentage/2)) '' | tr ' ' '#')$(printf '%*s' $((50-percentage/2)) '' | tr ' ' ' ')] $percentage% \r"
  
  if [ "$current" -eq "$total" ]; then
    echo -ne "\n"
  fi
}

# 执行命令（支持模拟执行）
run_command() {
  if [ "$DRY_RUN" = true ]; then
    log_message "${YELLOW}模拟执行:${NC} $1"
  else
    log_message "执行命令: $1"
    if ! eval "$1"; then
      handle_error "命令执行失败: $1"
    fi
  fi
}

# 带超时的命令执行
run_command_with_timeout() {
  local command="$1"
  local timeout="${2:-300}"  # 默认5分钟超时
  
  log_message "执行命令（超时: ${timeout}s）: $command"
  
  if [ "$DRY_RUN" = true ]; then
    log_message "${YELLOW}模拟执行:${NC} $command"
    return 0
  fi
  
  # 使用 timeout 命令执行
  if command -v timeout &> /dev/null; then
    if ! timeout "$timeout" bash -c "$command"; then
      handle_error "命令执行失败或超时: $command"
    fi
  else
    # 没有 timeout 命令时的备选方案
    if ! eval "$command"; then
      handle_error "命令执行失败: $command"
    fi
  fi
}

# 检测操作系统
detect_os() {
  case "$OSTYPE" in
    darwin*) OS="macos" ;;
    linux*) OS="linux" ;;
    cygwin*) OS="windows" ;;
    msys*) OS="windows" ;;
    *) OS="unknown" ;;
  esac
  log_message "检测到操作系统: $OS"
}

# 跨平台路径处理
# 功能：将路径转换为当前操作系统的标准格式
# 参数：路径字符串
# 返回：标准化后的路径
normalize_path() {
  local path="$1"
  
  if [ "$OS" = "windows" ]; then
    # Windows 路径处理
    echo "$path" | sed 's/\//\\/g'
  else
    # Unix-like 路径处理
    echo "$path" | sed 's/\\/\//g'
  fi
}

# 跨平台命令执行
# 功能：根据操作系统执行相应的命令
# 参数：命令字符串
# 注意：在不同操作系统上可能需要不同的处理
run_cross_platform_command() {
  local command="$1"
  
  case "$OS" in
    windows)
      # Windows 特定处理
      log_message "在 Windows 上执行: $command"
      ;;
    macos|linux)
      # Unix-like 系统处理
      log_message "在 $OS 上执行: $command"
      ;;
    *)
      log_message "在未知系统上执行: $command"
      ;;
  esac
  
  run_command "$command"
}

# 加载配置文件
load_config() {
  local config_file="${1:-"$DEFAULT_CONFIG_FILE"}"
  
  if [ -f "$config_file" ]; then
    log_message "加载配置文件: $config_file"
    source "$config_file"
    
    # 验证配置值
    if [ -n "$PROJECT_NAME" ] && ! validate_config "$PROJECT_NAME" "PROJECT_NAME"; then
      handle_error "配置文件中的项目名称无效"
    fi
    
    if [ -n "$API_BASE_URL" ] && ! validate_config "$API_BASE_URL" "API_BASE_URL"; then
      handle_error "配置文件中的 API 基础 URL 无效"
    fi
    
    if [ -n "$FLUTTER_W_PATH" ] && ! validate_config "$FLUTTER_W_PATH" "FLUTTER_W_PATH"; then
      handle_error "配置文件中的 flutter_w 路径无效"
    fi
  else
    log_message "${YELLOW}配置文件不存在，使用默认配置${NC}"
  fi
}

# 加载插件
load_plugins() {
  local plugin_dir="${1:-"$PLUGIN_DIRECTORY"}"
  
  if [ -d "$plugin_dir" ]; then
    log_message "加载插件目录: $plugin_dir"
    for plugin in "$plugin_dir"/*.sh; do
      if [ -f "$plugin" ]; then
        log_message "加载插件: $(basename "$plugin")"
        source "$plugin"
      fi
    done
  else
    log_message "${YELLOW}插件目录不存在，跳过${NC}"
  fi
}

# 帮助信息
show_help() {
  echo "用法: $0 [选项]"
  echo "选项:"
  echo "  --help            显示帮助信息"
  echo "  --flutter-w-path  指定 flutter_w 路径"
  echo "  --api-base-url    指定 API 基础 URL"
  echo "  --yes             自动确认所有操作"
  echo "  --dry-run         模拟执行，不实际操作"
  echo "  --project-name    指定项目名称"
  echo "  --config          指定配置文件路径"
}

# 解析命令行参数
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help)
        show_help
        exit 0
        ;;
      --flutter-w-path)
        FLUTTER_W_PATH="$2"
        shift
        ;;
      --api-base-url)
        API_BASE_URL="$2"
        shift
        ;;
      --yes)
        AUTO_CONFIRM=true
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      --project-name)
        PROJECT_NAME="$2"
        shift
        ;;
      --config)
        CONFIG_FILE="$2"
        shift
        ;;
      *)
        echo -e "${RED}未知选项:${NC} $1"
        show_help
        exit 1
        ;;
    esac
    shift
  done
  
  # 验证命令行参数
  if [ -n "$PROJECT_NAME" ] && ! validate_config "$PROJECT_NAME" "PROJECT_NAME"; then
    handle_error "命令行参数中的项目名称无效"
  fi
  
  if [ -n "$API_BASE_URL" ] && ! validate_config "$API_BASE_URL" "API_BASE_URL"; then
    handle_error "命令行参数中的 API 基础 URL 无效"
  fi
  
  if [ -n "$FLUTTER_W_PATH" ] && ! validate_config "$FLUTTER_W_PATH" "FLUTTER_W_PATH"; then
    handle_error "命令行参数中的 flutter_w 路径无效"
  fi
  
  # 验证配置文件路径
  if [ -n "$CONFIG_FILE" ] && ! validate_input "$CONFIG_FILE" "filename"; then
    handle_error "配置文件路径无效"
  fi
}

# 验证输入
# 功能：验证不同类型的输入
# 参数：
#   input - 输入值
#   type - 输入类型（project_name, url, path, filename）
# 返回：0 表示验证通过，1 表示验证失败
validate_input() {
  local input="$1"
  local type="$2"
  
  # 检查输入是否为空
  if [ -z "$input" ]; then
    return 1
  fi
  
  case "$type" in
    "project_name")
      # 项目名称只能包含小写字母、数字和下划线
      if [[ ! "$input" =~ ^[a-z0-9_]+$ ]]; then
        return 1
      fi
      ;;
    "url")
      # 验证 URL 格式
      if [[ ! "$input" =~ ^https?:// ]]; then
        return 1
      fi
      ;;
    "path")
      # 检查路径是否存在且可访问
      if [ ! -d "$input" ]; then
        return 1
      fi
      ;;
    "filename")
      # 验证文件名（只能包含字母、数字、下划线、点和连字符）
      if [[ ! "$input" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
  
  return 0
}

# 防止路径注入
# 功能：清理路径中的危险字符
# 参数：路径字符串
# 返回：清理后的路径
sanitize_path() {
  local path="$1"
  # 移除可能的路径遍历字符
  echo "$path" | sed 's/\.\.//g'
}

# 验证配置值
# 功能：验证配置文件中的值
# 参数：
#   value - 配置值
#   key - 配置键名
# 返回：0 表示验证通过，1 表示验证失败
validate_config() {
  local value="$1"
  local key="$2"
  
  case "$key" in
    "PROJECT_NAME")
      validate_input "$value" "project_name"
      ;;
    "API_BASE_URL")
      validate_input "$value" "url"
      ;;
    "FLUTTER_W_PATH")
      validate_input "$value" "path"
      ;;
    *)
      # 其他配置项，至少确保不为空
      if [ -z "$value" ]; then
        return 1
      fi
      ;;
  esac
  
  return $?
}

# 验证项目名称
validate_project_name() {
  if ! validate_input "$PROJECT_NAME" "project_name"; then
    handle_error "项目名称只能包含小写字母、数字和下划线"
  fi
}

# 检查 flutter 命令是否存在
check_flutter() {
  log_message "检查 Flutter 是否已安装..."
  if ! command -v flutter &> /dev/null; then
    handle_error "Flutter 未安装或未添加到 PATH"
  fi
  log_message "${GREEN}Flutter 已安装${NC}"
  
  # 检查 Flutter 版本
  flutter_version=$(flutter --version | head -n 1 | cut -d ' ' -f 2)
  log_message "Flutter 版本: $flutter_version"
}

# 检查项目目录是否适合创建
check_directory_suitable() {
  log_message "检查项目目录..."
  if [ -d "$PROJECT_NAME" ]; then
    if [ "$AUTO_CONFIRM" = false ]; then
      read -p "项目目录 $PROJECT_NAME 已存在，确定要覆盖吗？(y/n): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi
      # 删除已存在的目录
      run_command "rm -rf \"$PROJECT_NAME\""
    else
      # 自动确认模式下，直接删除已存在的目录
      log_message "删除已存在的项目目录: $PROJECT_NAME"
      run_command "rm -rf \"$PROJECT_NAME\""
    fi
  fi
  log_message "${GREEN}项目目录检查通过${NC}"
}

# 检查权限
# 功能：检查脚本执行所需的权限
# 检查内容：
# 1. 当前目录写入权限
# 2. Flutter 命令执行权限
check_permissions() {
  log_message "检查权限..."
  
  # 检查当前目录写入权限
  if [ ! -w "$(pwd)" ]; then
    handle_error "没有写入当前目录的权限"
  fi
  
  # 检查 Flutter 命令执行权限
  if ! command -v flutter &> /dev/null || ! flutter --version &> /dev/null; then
    handle_error "Flutter 未安装或未添加到 PATH"
  fi
  
  # 检查 get 命令执行权限
  if ! command -v get &> /dev/null; then
    log_message "${YELLOW}get 命令未找到，将在后续步骤中安装${NC}"
  fi
  
  log_message "${GREEN}权限检查通过${NC}"
}

# 检查 get_cli 是否已安装
check_get_cli() {
  log_message "检查 get_cli 是否已安装..."
  if ! flutter pub global list | grep -q "get_cli"; then
    if [ "$AUTO_CONFIRM" = false ]; then
      read -p "get_cli 未安装，是否安装？(y/n): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        handle_error "get_cli 未安装，无法继续"
      fi
    fi
    log_message "正在安装 get_cli..."
    run_command_with_timeout "flutter pub global activate get_cli"
  else
    log_message "${GREEN}get_cli 已安装${NC}"
  fi
}

# 询问项目名
ask_project_name() {
  if [ -z "$PROJECT_NAME" ]; then
    if [ "$AUTO_CONFIRM" = false ]; then
      read -p "请输入项目名称: " PROJECT_NAME
      if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME="$DEFAULT_PROJECT_NAME"
        log_message "使用默认项目名称: $PROJECT_NAME"
      fi
    else
      PROJECT_NAME="$DEFAULT_PROJECT_NAME"
      log_message "使用默认项目名称: $PROJECT_NAME"
    fi
  fi
  validate_project_name
}

# 确认操作
confirm_operation() {
  if [ "$AUTO_CONFIRM" = false ]; then
    read -p "$1 (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  fi
}

# 使用 get_cli 创建项目
create_project() {
  log_message "使用 get_cli 创建项目..."
  run_command_with_timeout "get create project $PROJECT_NAME"
  log_message "${GREEN}项目创建完成${NC}"
}

# 安装项目依赖包
# 功能：安装核心依赖和开发依赖
# 步骤：
# 1. 检查 pubspec.yaml 文件是否存在
# 2. 执行 flutter pub get 获取基础依赖
# 3. 安装核心依赖包
# 4. 安装开发依赖包
install_dependencies() {
  log_message "安装项目依赖包..."
  # 确保 pubspec.yaml 存在
  if [ ! -f "$PROJECT_NAME/pubspec.yaml" ]; then
    handle_error "pubspec.yaml 文件不存在，请先创建项目"
  fi
  # 一次性执行所有依赖安装，减少 Flutter 启动次数
  # 先执行 flutter pub get
  run_command_with_timeout "(cd \"$PROJECT_NAME\" && flutter pub get)"
  # 安装核心依赖
  run_command_with_timeout "(cd \"$PROJECT_NAME\" && get install dio flutter_screenutil flutter_form_builder form_builder_validators retrofit)"
  # 安装开发依赖（尝试两种方式，确保兼容性）
  if ! run_command_with_timeout "(cd \"$PROJECT_NAME\" && get install build_runner json_serializable retrofit_generator analyzer --dev)"; then
    log_message "${YELLOW}使用 --dev 选项失败，尝试不带 --dev 选项${NC}"
    run_command_with_timeout "(cd \"$PROJECT_NAME\" && get install build_runner json_serializable retrofit_generator analyzer)"
  fi
  log_message "${GREEN}依赖包安装完成${NC}"
}

# 创建必要的目录结构
# 功能：创建项目所需的完整目录结构
# 包含：
# - assets/fonts 和 assets/images：存放字体和图片资源
# - lib/app/components：存放组件
# - lib/app/utils：存放工具类
# - lib/app/services：存放服务
# - lib/app/data/models：存放数据模型
# - lib/app/data/sources：存放数据源
# - lib/app/data/sources/remote：存放远程数据源
# - test：存放测试文件
# - .github/workflows：存放 CI/CD 配置
create_directory_structure() {
  log_message "创建目录结构..."
  # 合并为一个命令，减少进程创建
  local project_path="$PROJECT_NAME"
  run_command "mkdir -p \"$project_path\"/assets/{fonts,images} \"$project_path\"/lib/app/{components,utils,services} \"$project_path\"/lib/app/data/{models,sources} \"$project_path\"/lib/app/data/sources/remote \"$project_path\"/test \"$project_path\"/.github/workflows"
  log_message "${GREEN}目录结构创建完成${NC}"
}

# 修改 pubspec.yaml 添加依赖
add_flutter_w_dependency() {
  log_message "配置项目依赖..."
  # 确保 pubspec.yaml 存在
  if [ ! -f "$PROJECT_NAME/pubspec.yaml" ]; then
    handle_error "pubspec.yaml 文件不存在，请先创建项目"
  fi
  # 检查 pubspec.yaml 是否已包含必要依赖
  if ! grep -q "flutter_w" "$PROJECT_NAME/pubspec.yaml"; then
    # 找到 dependencies 部分的位置
    dependencies_line=$(grep -n "^dependencies:" "$PROJECT_NAME/pubspec.yaml" | cut -d: -f1)
    if [ -n "$dependencies_line" ]; then
      # 找到 dependencies 部分的结束位置（下一个顶级键或文件结束）
      # 使用 awk 来找到 dependencies 部分的结束并在其前插入 flutter_w 依赖
      awk -v path="$FLUTTER_W_PATH" '{
        # 检查是否是新的顶级键（以字母开头，后面跟冒号）
        if (NR > 1 && /^[a-zA-Z_]+:/ && in_dependencies) {
          # 遇到新的顶级键，在其前插入 flutter_w 依赖
          print "  flutter_w:"
          print "    path: " path
          print ""
          in_dependencies = 0
        }
        print $0
        # 标记进入 dependencies 部分
        if (/^dependencies:/) {
          in_dependencies = 1
        }
      } END {
        # 如果文件结束时仍在 dependencies 部分，在文件末尾插入
        if (in_dependencies) {
          print ""
          print "  flutter_w:"
          print "    path: " path
        }
      }' "$PROJECT_NAME/pubspec.yaml" > "$PROJECT_NAME/pubspec.yaml.tmp"
      run_command "mv \"$PROJECT_NAME/pubspec.yaml.tmp\" \"$PROJECT_NAME/pubspec.yaml\""
    else
      # 如果没有找到 dependencies 部分，在文件末尾添加
      run_command "echo \"\" >> \"$PROJECT_NAME/pubspec.yaml\""
      run_command "echo \"dependencies:\" >> \"$PROJECT_NAME/pubspec.yaml\""
      run_command "echo \"  flutter_w:\" >> \"$PROJECT_NAME/pubspec.yaml\""
      run_command "echo \"    path: $FLUTTER_W_PATH\" >> \"$PROJECT_NAME/pubspec.yaml\""
    fi
  fi
  
  # 确保 pubspec.yaml 存在
  if [ ! -f "$PROJECT_NAME/pubspec.yaml" ]; then
    log_message "${YELLOW}pubspec.yaml 文件不存在，跳过 assets 配置${NC}"
    return
  fi
  
  # 添加 assets 配置（无论 flutter_w 是否存在，都执行）
  log_message "检查是否已存在 assets 配置"
  local pubspec_file="$PROJECT_NAME/pubspec.yaml"
  log_message "检查文件: $pubspec_file"
  
  # 检查文件是否存在
  if [ ! -f "$pubspec_file" ]; then
    log_message "${YELLOW}pubspec.yaml 文件不存在，跳过 assets 配置${NC}"
    return
  fi
  
  # 更简单直接的方法：在 flutter 部分添加或替换 assets 配置
  # 创建临时文件，用于重写 pubspec.yaml
  cat > "$pubspec_file.tmp" << 'EOF'
EOF
  
  # 读取原文件，处理 assets 配置
  in_flutter_section=false
  assets_added=false
  
  while IFS= read -r line; do
    # 检查是否进入 flutter 部分
    if [[ "$line" == "flutter:" ]]; then
      in_flutter_section=true
      echo "$line" >> "$pubspec_file.tmp"
    elif [[ "$in_flutter_section == true" && "$line" =~ ^[[:space:]]*#.*assets: ]]; then
      # 找到注释掉的 assets 配置，替换为新的配置
      echo "  assets:" >> "$pubspec_file.tmp"
      echo "    - .env" >> "$pubspec_file.tmp"
      echo "    - assets/" >> "$pubspec_file.tmp"
      echo "    - assets/images/" >> "$pubspec_file.tmp"
      echo "" >> "$pubspec_file.tmp"
      assets_added=true
      # 跳过所有注释掉的 assets 相关行
      while IFS= read -r next_line && [[ "$next_line" =~ ^[[:space:]]*# ]]; do
        : # 跳过注释行
      done
      if [[ -n "$next_line" && "$next_line" != "" ]]; then
        echo "$next_line" >> "$pubspec_file.tmp"
      fi
    elif [[ "$in_flutter_section == true" && "$line" =~ ^[[:space:]]*assets: ]]; then
      # 找到已有的 assets 配置，检查并添加缺失项
      echo "$line" >> "$pubspec_file.tmp"
      assets_added=true
      # 检查并添加缺失的配置项
      has_env=false
      has_assets=false
      has_images=false
      
      while IFS= read -r next_line && [[ "$next_line" =~ ^[[:space:]]+- ]]; do
        echo "$next_line" >> "$pubspec_file.tmp"
        if [[ "$next_line" =~ -[[:space:]]*\.env ]]; then
          has_env=true
        elif [[ "$next_line" =~ -[[:space:]]*assets/ ]]; then
          has_assets=true
        elif [[ "$next_line" =~ -[[:space:]]*assets/images/ ]]; then
          has_images=true
        fi
      done
      
      # 添加缺失的配置项
      if [[ "$has_env" == false ]]; then
        echo "    - .env" >> "$pubspec_file.tmp"
      fi
      if [[ "$has_assets" == false ]]; then
        echo "    - assets/" >> "$pubspec_file.tmp"
      fi
      if [[ "$has_images" == false ]]; then
        echo "    - assets/images/" >> "$pubspec_file.tmp"
      fi
      
      if [[ -n "$next_line" && "$next_line" != "" ]]; then
        echo "$next_line" >> "$pubspec_file.tmp"
      fi
    else
      echo "$line" >> "$pubspec_file.tmp"
    fi
  done < "$pubspec_file"
  
  # 如果没有找到 assets 配置，在 flutter 部分末尾添加
  if [[ "$assets_added" == false ]]; then
    # 找到 flutter 部分的末尾
    sed -i '' '/^flutter:/a \
  assets:\
    - .env\
    - assets/\
    - assets/images/\
' "$pubspec_file.tmp"
  fi
  
  # 用临时文件替换原文件
  mv "$pubspec_file.tmp" "$pubspec_file"
  
  log_message "已添加 assets 配置"
  
  log_message "assets 配置检查完成"
  
  log_message "${GREEN}项目依赖配置完成${NC}"
}

# 创建核心文件
# 功能：创建项目所需的核心数据层文件
# 包括：
# - paths.dart：API 路径常量
# - client.dart：Retrofit API 客户端接口
# - data_source.dart：远程数据源实现
# - repository.dart：仓库模式实现
create_core_files() {
  log_message "创建核心文件..."
  
  local project_dir="$PROJECT_NAME"
  local api_url="$API_BASE_URL"
  
  # 确保目录结构存在
  run_command "mkdir -p \"$project_dir\"/lib/app/data/sources/remote \"$project_dir\"/lib/app/routes"
  
  # 创建 .env 文件
  # 环境配置文件
  log_message "创建环境配置文件..."
  cat > "$project_dir/.env" << EOF
# API 基础 URL
API_BASE_URL=$API_BASE_URL

# 其他配置
DEBUG=true
EOF
  log_message "已创建 .env 文件"
  
  # 创建 paths.dart
  # 定义 API 路径常量
  log_message "创建 API 路径文件..."
  cat > "$project_dir/lib/app/data/sources/paths.dart" << EOF
class ApiPath {
  static const String baseUrl = '$api_url';
  
  // 认证相关
  static const String login = '/auth/login';
}
EOF
  
  # 创建 client.dart
  # 使用 Retrofit 定义 API 客户端接口
  log_message "创建 API 客户端文件..."
  cat > "$project_dir/lib/app/data/sources/client.dart" << 'EOF'
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
}
EOF
  
  # 创建 data_source_mixin.dart
  # 实现远程数据源混入类，处理网络请求
  log_message "创建远程数据源混入文件..."
  cat > "$project_dir/lib/app/data/sources/remote/data_source_mixin.dart" << 'EOF'
import '../client.dart';

abstract class IAppRemoteDataSource {}

mixin AppRemoteDataSourceMixin implements IAppRemoteDataSource {
  late final ApiClient libRest;
}
EOF

  # 创建 data_source.dart
  # 实现远程数据源，处理网络请求
  log_message "创建远程数据源文件..."
  cat > "$project_dir/lib/app/data/sources/remote/data_source.dart" << 'EOF'
import 'package:flutter_w/w.dart';
import '../client.dart';
import '../paths.dart';
import 'data_source_mixin.dart';

class AppRemoteDataSource extends BaseRemoteDataSource with AppRemoteDataSourceMixin {
  AppRemoteDataSource() {
    libRest = ApiClient(
      DioUtil.instance(
        ApiPath.baseUrl,
        interceptors: [WTokenInterceptor(), WLogInterceptor(), WErrorInterceptor()],
      ).dio,
    );
  }
}
EOF
  
  # 创建 repository.dart
  # 实现仓库模式，提供数据访问接口
  log_message "创建仓库文件..."
  cat > "$project_dir/lib/app/data/sources/repository.dart" << 'EOF'
import 'package:flutter_w/w.dart';

import 'remote/data_source.dart';
import 'remote/data_source_mixin.dart';

class AppRepository extends BaseRepository<Null, AppRemoteDataSource> implements IAppRemoteDataSource {
  AppRepository() : super(remoteDataSource: AppRemoteDataSource());

  static AppRepository? _instance;

  static AppRepository _getInstance() {
    _instance ??= AppRepository();
    return _instance!;
  }

  static AppRepository get instance => _getInstance();
}
EOF
  
  # 创建 main.dart
  # 应用入口文件
  log_message "创建应用入口文件..."
  cat > "$project_dir/lib/main.dart" << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_w/w.dart';

import 'app/routes/app_pages.dart';

void main() async {
  // 创建 WApp 实例，用于管理应用的初始化和运行
  var app = WApp()
  // 设置设计稿宽度，用于屏幕适配
    ..designWidth = 375.0
  // 设置应用标题
    ..title = "Flutter W Example"
  // 设置初始路由
    ..initialRoute = AppPages.INITIAL
  // 设置路由页面列表
    ..getPages = AppPages.routes
    ..envFileName = '.env'
    ..theme = ThemeData(primarySwatch: Colors.blue);

  // 初始化应用
  // 这会执行一系列初始化任务，如设置系统UI、加载环境变量等
  await app.init();

  // 运行应用
  app.run();
}
EOF
   
  log_message "${GREEN}核心文件创建完成${NC}"
}

# 生成代码
generate_code() {
  log_message "生成代码..."
  # 再次执行 flutter pub get 确保所有依赖都已正确安装
  run_command_with_timeout "(cd \"$PROJECT_NAME\" && flutter pub get)"
  # 执行代码生成
  if ! run_command_with_timeout "(cd \"$PROJECT_NAME\" && dart pub run build_runner build)"; then
    log_message "${YELLOW}代码生成失败，尝试使用 --delete-conflicting-outputs 选项${NC}"
    run_command_with_timeout "(cd \"$PROJECT_NAME\" && dart pub run build_runner build --delete-conflicting-outputs)"
  fi
  log_message "${GREEN}代码生成完成${NC}"
}



# 格式化代码
format_code() {
  log_message "格式化代码..."
  run_command "(cd \"$PROJECT_NAME\" && dart format .)"
  log_message "${GREEN}代码格式化完成${NC}"
}

# 初始化测试
initialize_tests() {
  log_message "初始化测试..."
  cat > "$PROJECT_NAME/test/widget_test.dart" << 'EOF'
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 测试代码
  });
}
EOF
  log_message "${GREEN}测试文件初始化完成${NC}"
}

# 初始化 Git 仓库
initialize_git() {
  if [ -d "$PROJECT_NAME" ]; then
    log_message "初始化 Git 仓库..."
    run_command "(cd \"$PROJECT_NAME\" && git init && git add . && git commit -m \"Initial commit\")"
    log_message "${GREEN}Git 仓库初始化完成${NC}"
  fi
}

# 创建 CI/CD 配置
create_ci_cd_config() {
  log_message "创建 CI/CD 配置..."
  # 创建 GitHub Actions 配置
  cat > "$PROJECT_NAME/.github/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.10.0'

    - name: Install dependencies
      run: flutter pub get

    - name: Run tests
      run: flutter test

    - name: Build app
      run: flutter build apk
EOF
  log_message "${GREEN}CI/CD 配置创建完成${NC}"
}

# 项目健康检查
health_check() {
  log_message "执行项目健康检查..."
  
  # 确保 PROJECT_NAME 不为空
  if [ -z "$PROJECT_NAME" ]; then
    log_message "${YELLOW}项目名称为空，跳过健康检查${NC}"
    return
  fi
  
  # 检查 pubspec.yaml
  if [ -f "$PROJECT_NAME/pubspec.yaml" ]; then
    log_message "${GREEN}✓ pubspec.yaml 存在${NC}"
  else
    log_message "${RED}✗ pubspec.yaml 不存在${NC}"
  fi
  
  # 检查核心文件
  core_files=("lib/app/data/sources/paths.dart" "lib/app/data/sources/client.dart" "lib/app/data/sources/remote/data_source.dart" "lib/app/data/sources/repository.dart")
  for file in "${core_files[@]}"; do
    if [ -f "$PROJECT_NAME/$file" ]; then
      log_message "${GREEN}✓ $file 存在${NC}"
    else
      log_message "${RED}✗ $file 不存在${NC}"
    fi
  done
  
  # 检查目录结构
  directories=("assets/fonts" "assets/images" "lib/app/components" "lib/app/utils" "lib/app/services" "lib/app/data/models" "lib/app/data/sources" "lib/app/data/sources/remote" "test")
  for dir in "${directories[@]}"; do
    if [ -d "$PROJECT_NAME/$dir" ]; then
      log_message "${GREEN}✓ $dir 目录存在${NC}"
    else
      log_message "${RED}✗ $dir 目录不存在${NC}"
    fi
  done
  
  log_message "${GREEN}项目健康检查完成${NC}"
}

# 打开项目
# 功能：使用不同的IDE打开项目
# 支持：trae、Android Studio
open_project() {
  echo "正在打开项目..."
  # 确保 PROJECT_NAME 不为空
  if [ -z "$PROJECT_NAME" ]; then
    log_message "${YELLOW}项目名称为空，跳过打开项目${NC}"
    return
  fi
  
  # 确保项目目录存在
  if [ ! -d "$PROJECT_NAME" ]; then
    log_message "${YELLOW}项目目录不存在，跳过打开项目${NC}"
    return
  fi
  
  # 使用 trae 打开项目
  if command -v trae &> /dev/null; then
    log_message "使用 trae 打开项目"
    run_command "trae $PROJECT_NAME"
  else
    log_message "${YELLOW}trae 命令未找到，跳过${NC}"
  fi
  
  # 使用 Android Studio 打开项目
  if command -v studio &> /dev/null; then
    log_message "使用 Android Studio 打开项目"
    run_command "studio $PROJECT_NAME"
  elif [ -d "/Applications/Android Studio.app" ]; then
    log_message "使用 macOS 打开 Android Studio"
    run_command "open -a 'Android Studio' $PROJECT_NAME"
  elif [ "$OS" = "windows" ] && [ -d "C:/Program Files/Android/Android Studio/bin" ]; then
    local studio_path="C:/Program Files/Android/Android Studio/bin/studio64.exe"
    local normalized_path=$(normalize_path "$studio_path")
    log_message "使用 Windows 打开 Android Studio"
    run_command "\"$normalized_path\" \"$PROJECT_NAME\""
  else
    log_message "${YELLOW}Android Studio 未找到，跳过${NC}"
  fi
  
  # # 使用 Xcode 打开项目（iOS）
  # if [ "$OS" = "macos" ] && [ -d "$PROJECT_NAME/ios" ]; then
  #   if command -v xcodebuild &> /dev/null; then
  #     log_message "使用 Xcode 打开项目"
  #     run_command "open -a Xcode $PROJECT_NAME/ios"
  #   else
  #     log_message "${YELLOW}Xcode 未找到，跳过${NC}"
  #   fi
  # fi
  
  # # 使用 VS Code 打开项目（备选方案）
  # if command -v code &> /dev/null; then
  #   log_message "使用 VS Code 打开项目"
  #   run_command "code $PROJECT_NAME"
  # else
  #   log_message "${YELLOW}VS Code 未找到，跳过${NC}"
  # fi
}

# 脚本测试
test_script() {
  log_message "运行脚本测试..."
  
  # 测试命令行参数解析
  test_args() {
    log_message "测试命令行参数解析..."
    # 测试代码
  }
  
  # 测试错误处理
  test_error_handling() {
    log_message "测试错误处理..."
    # 测试代码
  }
  
  # 运行所有测试
  test_args
  test_error_handling
  
  log_message "${GREEN}脚本测试完成${NC}"
}

# 主函数
main() {
  # 首先解析命令行参数，这样 --help 可以立即生效
  parse_args "$@"
  
  echo -e "${GREEN}=== 开始初始化项目 ===${NC}"
  
  # 检测操作系统
  detect_os
  
  # 加载配置文件
  load_config "$CONFIG_FILE"
  
  # 加载插件
  load_plugins
  
  # 执行初始化步骤
  CURRENT_STEP=1
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  check_flutter
  
  CURRENT_STEP=2
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  check_permissions
  
  CURRENT_STEP=3
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  check_get_cli
  
  CURRENT_STEP=4
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  ask_project_name
  
  CURRENT_STEP=5
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  check_directory_suitable
  
  CURRENT_STEP=6
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  create_project
  
  CURRENT_STEP=7
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  install_dependencies
  
  CURRENT_STEP=8
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  create_directory_structure
  
  CURRENT_STEP=9
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  add_flutter_w_dependency
  
  CURRENT_STEP=10
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  create_core_files
  
  CURRENT_STEP=11
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  generate_code
  
  CURRENT_STEP=12
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  format_code
  
  CURRENT_STEP=13
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  initialize_tests
  
  CURRENT_STEP=14
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  initialize_git
  create_ci_cd_config
  
  CURRENT_STEP=15
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  health_check
  
  echo -e "${GREEN}=== 项目初始化完成 ===${NC}"
  echo "项目已成功初始化，包含以下内容："
  echo "1. 使用 get_cli 创建了 Flutter 项目"
  echo "2. 安装了必要的依赖包"
  echo "3. 创建了完整的目录结构"
  echo "4. 添加了 flutter_w 本地依赖"
  echo "5. 创建了核心数据层文件"
  echo "6. 生成了 Retrofit 代码"
  echo "7. 格式化了代码"
  echo "8. 初始化了测试文件"
  echo "9. 初始化了 Git 仓库"
  echo "10. 创建了 CI/CD 配置"
  echo "11. 执行了项目健康检查"
  echo ""
  echo "接下来需要："
  echo "1. 根据实际需求修改 API 路径和接口"
  echo "2. 实现具体的业务逻辑"
  echo "3. 编写测试用例"
  echo "4. 配置 CI/CD 流程"
  echo "5. 部署项目"
  echo ""
  
  # 打开项目
  open_project
}

# 执行主函数
main "$@"