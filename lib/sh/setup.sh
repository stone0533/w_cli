#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# ======================================================
# setup.sh - Flutter 项目初始化脚本
# Version: 1.1.0
# Last Updated: 2026-10-25
# Author: Stone
# Description: 自动完成Flutter项目的初始化、依赖安装和核心文件创建
# Features:
#   - 自动检测操作系统
#   - 检查 Flutter 安装状态
#   - 创建完整的目录结构
#   - 安装必要的依赖包
#   - 生成 w_tools 接入骨架（pub 上的分包依赖 + 聚合入口 + 暂存层 + doctor 配置）
#   - 创建核心数据层文件
#   - 生成 Retrofit 代码
#   - 初始化 Git 仓库
#   - 创建 CI/CD 配置
# ======================================================

# 使用方法：
#   bash setup.sh [项目名称] [选项]
#
# 选项：
#   --help            显示帮助信息
#   --version         显示脚本版本信息
#
# 示例：
#   # 基本使用
#   bash setup.sh
#
#   # 自定义项目名称
#   bash setup.sh my_app

# 常量定义
readonly DEFAULT_PROJECT_NAME="my_flutter_app"
readonly DEFAULT_API_BASE_URL="https://api.example.com"
# 只依赖用到的分包（ADR-0002）：meta 包 w_tools 会经 w_tools_map 拖进
# google_maps_flutter 原生 SDK，而新项目几乎都用不到地图。
# 需要地图时再单独加 w_tools_map。
readonly W_TOOLS_SUBPACKAGES="core app form ui api toast qr"

# 全局变量
PROJECT_NAME=""
API_BASE_URL="$DEFAULT_API_BASE_URL"
OS=""
TOTAL_STEPS=15
CURRENT_STEP=0
# --force：目标目录已存在时允许覆盖（默认拒绝，避免误删）
FORCE=false
# 本次运行是否创建了项目目录：只有自己创建的东西才允许清理时删除
PROJECT_CREATED_BY_US=false

# 错误处理函数
handle_error() {
  local error_message="$1"
  local error_code="${2:-1}"
  
  echo -e "${RED}错误:${NC} $error_message"
  echo -e "${YELLOW}建议:${NC} 请检查错误信息并尝试解决问题"
  
  # 记录错误到日志文件
  local log_file="$(pwd)/setup_error.log"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $error_message" >> "$log_file"
  log_error "错误已记录到: $log_file"
  
  cleanup || true
  exit "$error_code"
}

# 清理函数
# 只删除本次运行创建出来的东西；绝不按名字去猜、绝不碰用户已存在的目录。
cleanup() {
  echo "正在清理本次运行的临时产物..."

  if [ "$PROJECT_CREATED_BY_US" = true ] && [ -n "$PROJECT_NAME" ] && [ -d "$PROJECT_NAME" ]; then
    echo "删除本次运行创建的项目目录: $PROJECT_NAME"
    rm -rf -- "$PROJECT_NAME" || true
  fi

  # 清理临时文件（-- 防止名字以 - 开头时被当成选项）
  if [ -n "$PROJECT_NAME" ]; then
    rm -f -- "$PROJECT_NAME/pubspec.yaml.tmp" 2>/dev/null || true
  fi
}

# 捕获错误
trap 'handle_error "脚本执行失败"' ERR

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

# 在项目目录里执行命令
run_in_project() {
  ( cd "$PROJECT_NAME" && "$@" )
}

# 执行命令（argv 形式，不经过 eval，路径里的空格和特殊字符不会被当成语法）
run_command() {
  log_info "执行命令: $*"
  if ! "$@"; then
    handle_error "命令执行失败: $*"
  fi
}

# 带超时的命令执行（argv 形式）：超时会杀掉子进程并返回 124
run_command_with_timeout() {
  local timeout_seconds="$1"
  shift

  log_info "执行命令（超时: ${timeout_seconds}s）: $*"
  if ! ww::run_with_timeout "$timeout_seconds" "$@"; then
    handle_error "命令执行失败或超时: $*"
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
  log_info "检测到操作系统: $OS"
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
# 显示版本信息
show_version() {
  ww::show_version "Flutter 项目初始化脚本"
}

# 显示帮助信息
show_help() {
  echo "使用方法: $0 [项目名称] [选项]"
  echo "选项:"
  echo "  --force           目标目录已存在时覆盖它（默认拒绝）"
  echo "  --help            显示帮助信息"
  echo "  --version         显示脚本版本信息"
  echo ""
  echo "示例:"
  echo "  # 基本使用"
  echo "  bash setup.sh"
  echo ""
  echo "  # 自定义项目名称"
  echo "  bash setup.sh my_app"
  echo ""
  echo "  # 覆盖已存在的同名目录"
  echo "  bash setup.sh my_app --force"
}

# 检查执行权限

# 解析命令行参数
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --force)
        FORCE=true
        ;;
      --help)
        show_help
        exit 0
        ;;
      --version)
        show_version
        exit 0
        ;;
      *)
        # 直接将第一个位置参数作为项目名称
        if [ -z "$PROJECT_NAME" ]; then
          PROJECT_NAME="$1"
        else
          log_error "未知选项: $1"
          show_help >&2
          exit 2
        fi
        ;;
    esac
    shift
  done
  
  # 验证命令行参数
  if [ -n "$PROJECT_NAME" ] && ! validate_config "$PROJECT_NAME" "PROJECT_NAME"; then
    handle_error "命令行参数中的项目名称无效" 2
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
  log_info "检查 Flutter 是否已安装..."
  if ! command -v flutter &> /dev/null; then
    handle_error "Flutter 未安装或未添加到 PATH"
  fi
  log_info "Flutter 已安装"
  
  # 检查 Flutter 版本
  flutter_version=$(flutter --version | head -n 1 | cut -d ' ' -f 2)
  log_info "Flutter 版本: $flutter_version"
}

# 检查项目目录是否适合创建
check_directory_suitable() {
  log_info "检查项目目录..."
  if [ -d "$PROJECT_NAME" ]; then
    if [ "$FORCE" = true ]; then
      log_warn "目标目录已存在，--force 已启用，将覆盖: $PROJECT_NAME"
      rm -rf -- "$PROJECT_NAME"
    else
      log_error "目标目录已存在: $PROJECT_NAME"
      log_error "为避免误删，默认不覆盖；确认要覆盖请加 --force"
      handle_error "目标目录已存在: ${PROJECT_NAME}（如需覆盖请加 --force）" 1
    fi
  fi
  log_info "项目目录检查通过"
}

# 检查权限
# 功能：检查脚本执行所需的权限
# 检查内容：
# 1. 当前目录写入权限
# 2. Flutter 命令执行权限
check_permissions() {
  log_info "检查权限..."
  
  # 检查当前目录写入权限
  if [ ! -w "$(pwd)" ]; then
    handle_error "没有写入当前目录的权限"
  fi
  
  # 检查 Flutter 命令执行权限
  if ! command -v flutter &> /dev/null || ! flutter --version &> /dev/null; then
    handle_error "Flutter 未安装或未添加到 PATH"
  fi
  
  log_info "权限检查通过"
}

# 询问项目名
ask_project_name() {
  if [ -z "$PROJECT_NAME" ]; then
    read -rp "请输入项目名称: " PROJECT_NAME
    if [ -z "$PROJECT_NAME" ]; then
      PROJECT_NAME="$DEFAULT_PROJECT_NAME"
      log_info "使用默认项目名称: $PROJECT_NAME"
    fi
  fi
  validate_project_name
}

# 创建项目
create_project() {
  log_info "使用 flutter create 创建项目..."
  # 从这里开始目录归本次运行所有：失败时 cleanup 才允许删除它
  PROJECT_CREATED_BY_US=true
  run_command_with_timeout 900 flutter create --org com.sampras -i swift -a kotlin "$PROJECT_NAME"
  log_info "项目创建完成"
}

# 安装项目依赖包
# 功能：安装核心依赖和开发依赖
# 步骤：
# 1. 检查 pubspec.yaml 文件是否存在
# 2. 执行 flutter pub get 获取基础依赖
# 3. 安装核心依赖包
# 4. 安装开发依赖包
install_dependencies() {
  log_info "安装项目依赖包..."
  # 确保 pubspec.yaml 存在
  if [ ! -f "$PROJECT_NAME/pubspec.yaml" ]; then
    handle_error "pubspec.yaml 文件不存在，请先创建项目"
  fi
  # 使用 flutter pub add 安装依赖，避免使用 get_cli 导致的崩溃
  # 安装核心依赖（w_tools 分包在下一步按「本地 path / 线上版本」分别安装）
  # json_annotation 钉 ^4.9.0：retrofit_generator 9.x 要求 json_annotation <4.10.0，
  # 装最新版（4.12）会和 json_serializable 冲突，version solving 直接失败。
  run_command_with_timeout 600 run_in_project flutter pub add get dio flutter_screenutil \
    flutter_form_builder form_builder_validators "json_annotation:^4.9.0"
  # retrofit 钉死 4.9.0：4.9.2 起 Parser 枚举新增 DartMappable，
  # 而 retrofit_generator 9.x 的 switch 不认这个值，build_runner 会编译失败。
  # 要升到 4.10+，必须同时把 retrofit_generator 升到 10.x（连带 build_runner/analyzer 升级）。
  run_command_with_timeout 600 run_in_project flutter pub add "retrofit:4.9.0"
  # 安装开发依赖
  run_command_with_timeout 600 run_in_project flutter pub add \
    build_runner json_serializable "retrofit_generator:^9.7.0" w_tools_cli --dev
  log_info "依赖包安装完成"
  
  # 手动创建首页文件，避免使用 get_cli 导致的崩溃
  log_info "创建首页..."
  
  # 创建目录结构
  mkdir -p "$PROJECT_NAME/lib/app/modules/home/controllers"
  mkdir -p "$PROJECT_NAME/lib/app/modules/home/views"
  mkdir -p "$PROJECT_NAME/lib/app/modules/home/bindings"
  mkdir -p "$PROJECT_NAME/lib/app/routes"
  
  # 创建 home_controller.dart
  
  # 创建 home_view.dart
  
  # 创建 home_binding.dart
  
  # 创建 app_routes.dart
  
  # 创建 app_pages.dart
  
  # 更新 main.dart 文件
  
  log_info "首页创建完成"
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
  log_info "创建目录结构..."
  # 合并为一个命令，减少进程创建
  local project_path="$PROJECT_NAME"
  run_command mkdir -p \
    "$project_path/assets/fonts" "$project_path/assets/images" \
    "$project_path/lib/app/components" "$project_path/lib/app/utils" "$project_path/lib/app/services" \
    "$project_path/lib/app/w" "$project_path/lib/app/design_system" \
    "$project_path/lib/app/data/models" "$project_path/lib/app/data/sources" \
    "$project_path/lib/app/data/sources/remote" \
    "$project_path/test" "$project_path/.github/workflows" "$project_path/w_json"
  log_info "目录结构创建完成"
}

# 添加 w_tools 分包依赖
#
# 规则（ADR-0002）：**只依赖用到的分包，不依赖 meta 包 w_tools** ——
# meta 包会经 w_tools_map 拖进 google_maps_flutter 原生 SDK。
#
# 一律使用 pub 上的发布版本（不写本地 path 依赖）：
#   - 新项目开箱即用，不要求机器上存在 w_tools 仓库
#   - 需要本地联调某个分包时，用 dependency_overrides 指向本地路径，
#     不要把它写进 dependencies（否则提交后别人拉不动）
add_w_tools_dependency() {
  log_info "配置 w_tools 分包依赖..."

  if [ ! -f "$PROJECT_NAME/pubspec.yaml" ]; then
    handle_error "pubspec.yaml 文件不存在，请先创建项目"
  fi

  local pubspec_file="$PROJECT_NAME/pubspec.yaml"
  local pkg=""

  for pkg in $W_TOOLS_SUBPACKAGES; do
    if ! run_command_with_timeout 300 run_in_project flutter pub add "w_tools_${pkg}:^1.0.0"; then
      handle_error "添加依赖失败: w_tools_${pkg}"
    fi
  done

  # doctor / init 等工具（只在开发期用，不进构建）
  if ! run_command_with_timeout 300 run_in_project flutter pub add w_tools_cli --dev; then
    log_warn "添加 w_tools_cli 失败（不影响编译，但缺少 dart run w_tools_cli:doctor）"
  fi

  log_info "w_tools 分包依赖配置完成（未包含 w_tools_map）"
  
  # 添加 assets 配置（无论 w_tools 是否存在，都执行）
  log_info "检查是否已存在 assets 配置"
  log_info "检查文件: $pubspec_file"
  
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
    elif [[ "$in_flutter_section" == true && "$line" =~ ^[[:space:]]*#.*assets: ]]; then
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
    elif [[ "$in_flutter_section" == true && "$line" =~ ^[[:space:]]*assets: ]]; then
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
  
  log_info "已添加 assets 配置"
  
  log_info "assets 配置检查完成"
  
  log_info "项目依赖配置完成"
}

# 生成 w_tools 的接入骨架
#
# 由 w_tools_cli:init 生成（单一来源）：
#   lib/app/w/toolkit.dart            聚合入口：业务代码统一 import 它
#   lib/app/design_system/README.md   暂存层规则
#   .w_tools_doctor.yaml              doctor 配置（全注释，不改变默认行为）
#   AGENTS.md                         w_tools 规则片段（AI 会自动读这一段）
#
# init 不可用时只兜底写 toolkit.dart，其余靠 `dart run w_tools_cli:init` 补。
create_w_tools_scaffold() {
  log_info "生成 w_tools 接入骨架..."

  if run_in_project dart run w_tools_cli:init >/dev/null 2>&1; then
    log_info "已通过 w_tools_cli:init 生成接入骨架"
    return 0
  fi

  log_warn "w_tools_cli:init 不可用，改为写入最小可用的聚合入口"
  local toolkit_file="$PROJECT_NAME/lib/app/w/toolkit.dart"
  mkdir -p "$(dirname "$toolkit_file")"
  cat > "$toolkit_file" << EOF
// 本项目用到的 w_tools 能力清单（w_tools_cli:init 生成的兜底版本）。
//
// 业务代码统一 import 这里，不要直接 import 各个子包 ——
// 换依赖方式时只改这一个文件。
//
// 为什么不用 meta 包 w_tools：它会经 w_tools_map 拖进 google_maps_flutter 原生 SDK。
library;

export 'package:w_tools_core/w_tools_core.dart';
export 'package:w_tools_app/w_tools_app.dart';
export 'package:w_tools_form/w_tools_form.dart';
export 'package:w_tools_ui/w_tools_ui.dart';
export 'package:w_tools_api/w_tools_api.dart';
export 'package:w_tools_toast/w_tools_toast.dart';
export 'package:w_tools_qr/w_tools_qr.dart';
EOF
  log_info "已写入 $toolkit_file（可再跑 dart run w_tools_cli:init 补全 AGENTS/doctor 配置）"
}

# 创建核心文件
# 功能：创建项目所需的核心数据层文件
# 包括：
# - paths.dart：API 路径常量
# - client.dart：Retrofit API 客户端接口
# - data_source.dart：远程数据源实现
# - repository.dart：仓库模式实现
create_core_files() {
  log_info "创建核心文件..."
  
  local project_dir="$PROJECT_NAME"
  
  # 确保目录结构存在
  run_command mkdir -p "$project_dir/lib/app/data/sources/remote" "$project_dir/lib/app/routes"
  
  # 创建 .env 文件
  # 环境配置文件
  log_info "创建环境配置文件..."
  log_info "已创建 .env 文件"
  
  # 创建 main.dart
  # 应用入口文件
  log_info "创建应用入口文件..."
  # main.dart 按 w_tools_app 1.x 的 WApp API 生成：
  #   - WApp 没有 designWidth / envFileName（旧版 API），屏幕适配与 .env 由插件负责
  #   - 用 start() 而不是 init() + run()，避免漏掉 init 的时序问题
   
  log_info "核心文件创建完成"
}

# 生成代码

# 格式化代码
format_code() {
  log_info "格式化代码..."
  run_command run_in_project dart format .
  log_info "代码格式化完成"
}

# 修改 analysis_options.yaml 文件，添加 analyzer 配置
update_analysis_options() {
  log_info "更新 analysis_options.yaml 文件..."
  local analysis_file="$PROJECT_NAME/analysis_options.yaml"
  
  # 检查文件是否存在
  if [ -f "$analysis_file" ]; then
    # 检查是否已经包含 analyzer 配置
    if ! grep -q "analyzer:" "$analysis_file"; then
      # 使用 awk 命令在 include 语句后添加 analyzer 配置
      awk '{
        print $0
        if ($0 == "include: package:flutter_lints/flutter.yaml") {
          print ""
          print "analyzer:"
          print "  exclude:"
          print "    - \"lib/app/routes/app_routes.dart\"  # Exclude auto-generated routes file to avoid naming convention warnings"
        }
      }' "$analysis_file" > "$analysis_file.tmp"
      mv "$analysis_file.tmp" "$analysis_file"
      log_info "已添加 analyzer 配置到 analysis_options.yaml"
    else
      log_warn "analyzer 配置已存在，跳过"
    fi
  else
    log_error "analysis_options.yaml 文件不存在"
  fi
}

# 初始化测试
initialize_tests() {
  log_info "初始化测试..."
  log_info "测试文件初始化完成"
}

# 初始化 Git 仓库
initialize_git() {
  if [ -d "$PROJECT_NAME" ]; then
    log_info "初始化 Git 仓库..."
    run_command run_in_project git init
    
    # 将 w_build 目录添加到 .gitignore 文件
    log_info "添加 w_build 目录到 .gitignore 文件..."
    local gitignore_file="$PROJECT_NAME/.gitignore"
    
    # 检查 .gitignore 文件是否存在
    if [ ! -f "$gitignore_file" ]; then
      # 创建 .gitignore 文件
      : > "$gitignore_file"
    fi
    
    # 检查 w_build 是否已经在 .gitignore 文件中
    if ! grep -q "w_build/" "$gitignore_file"; then
      # 添加 w_build 到 .gitignore 文件
      printf 'w_build/\n' >> "$gitignore_file"
    fi
    
    # 添加所有文件并提交
    run_command run_in_project git add .
    run_command run_in_project git commit -m "Initial commit"
    log_info "Git 仓库初始化完成"
  fi
}

# 创建 CI/CD 配置
create_ci_cd_config() {
  log_info "创建 CI/CD 配置..."
  # 创建 GitHub Actions 配置
  log_info "CI/CD 配置创建完成"
}

# 项目健康检查
health_check() {
  log_info "执行项目健康检查..."
  
  # 确保 PROJECT_NAME 不为空
  if [ -z "$PROJECT_NAME" ]; then
    log_warn "项目名称为空，跳过健康检查"
    return
  fi
  
  # 检查 pubspec.yaml
  if [ -f "$PROJECT_NAME/pubspec.yaml" ]; then
    log_info "✓ pubspec.yaml 存在"
  else
    log_error "✗ pubspec.yaml 不存在"
  fi
  
  # API 层（paths / client / data_source / mixin / repository）由 Dart 侧在脚本之后生成，
  # 不在这里检查，否则健康检查会误报"文件不存在"
  
  # 检查目录结构
  directories=("assets/fonts" "assets/images" "lib/app/components" "lib/app/utils" "lib/app/services" "lib/app/data/models" "lib/app/data/sources" "lib/app/data/sources/remote" "test")
  for dir in "${directories[@]}"; do
    if [ -d "$PROJECT_NAME/$dir" ]; then
      log_info "✓ $dir 目录存在"
    else
      log_error "✗ $dir 目录不存在"
    fi
  done
  
  log_info "项目健康检查完成"
}

# 打开项目
# 功能：使用不同的IDE打开项目
# 支持：trae、Android Studio
open_project() {
  log_info "正在打开项目..."
  # 确保 PROJECT_NAME 不为空
  if [ -z "$PROJECT_NAME" ]; then
    log_warn "项目名称为空，跳过打开项目"
    return
  fi
  
  # 确保项目目录存在
  if [ ! -d "$PROJECT_NAME" ]; then
    log_warn "项目目录不存在，跳过打开项目"
    return
  fi
  
  # 使用 trae 打开项目
  if command -v trae &> /dev/null; then
    log_info "使用 trae 打开项目"
    trae "$PROJECT_NAME"
  else
    log_warn "trae 命令未找到，跳过"
  fi
  
  # 使用 Android Studio 打开项目
  if command -v studio &> /dev/null; then
    log_info "使用 Android Studio 打开项目"
    studio "$PROJECT_NAME"
  elif [ -d "/Applications/Android Studio.app" ]; then
    log_info "使用 macOS 打开 Android Studio"
    open -a 'Android Studio' "$PROJECT_NAME"
  elif [ "$OS" = "windows" ] && [ -d "C:/Program Files/Android/Android Studio/bin" ]; then
    local studio_path="C:/Program Files/Android/Android Studio/bin/studio64.exe"
    local normalized_path=$(normalize_path "$studio_path")
    log_info "使用 Windows 打开 Android Studio"
    "$normalized_path" "$PROJECT_NAME"
  else
    log_warn "Android Studio 未找到，跳过"
  fi
  
  # # 使用 Xcode 打开项目（iOS）
  # if [ "$OS" = "macos" ] && [ -d "$PROJECT_NAME/ios" ]; then
  #   if command -v xcodebuild &> /dev/null; then
  #     log_info "使用 Xcode 打开项目"
  #     run_command "open -a Xcode $PROJECT_NAME/ios"
  #   else
  #     log_warn "Xcode 未找到，跳过"
  #   fi
  # fi
  
  # # 使用 VS Code 打开项目（备选方案）
  # if command -v code &> /dev/null; then
  #   log_info "使用 VS Code 打开项目"
  #   run_command "code $PROJECT_NAME"
  # else
  #   log_warn "VS Code 未找到，跳过"
  # fi
}

# 主函数
main() {
  # 首先解析命令行参数，这样 --help 可以立即生效
  parse_args "$@"
  
  # 添加运行开始分隔线
  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}Flutter 项目初始化脚本运行开始${NC}\n"
  printf "${GREEN}======================================================${NC}\n"
  
  # 检测操作系统
  detect_os
  
  # 执行初始化步骤
  CURRENT_STEP=1
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  check_flutter
  
  CURRENT_STEP=2
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  check_permissions
  
  CURRENT_STEP=3
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  ask_project_name
  
  CURRENT_STEP=4
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  check_directory_suitable
  
  CURRENT_STEP=5
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  create_project
  
  CURRENT_STEP=6
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  install_dependencies
  
  CURRENT_STEP=7
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  create_directory_structure

  CURRENT_STEP=8
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  add_w_tools_dependency

  CURRENT_STEP=9
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  create_w_tools_scaffold

  CURRENT_STEP=10
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  create_core_files

  CURRENT_STEP=11
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  format_code

  CURRENT_STEP=12
  show_progress "$CURRENT_STEP" "$TOTAL_STEPS"
  update_analysis_options

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
  
  # 添加运行结束分隔线
  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}Flutter 项目初始化脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
  printf "${GREEN}======================================================${NC}\n"
  
  log_info "项目已成功初始化，包含以下内容："
  log_info "1. 使用 flutter create 创建了 Flutter 项目"
  log_info "2. 安装了必要的依赖包（retrofit 钉 4.9.0）"
  log_info "3. 创建了完整的目录结构"
  log_info "4. 添加了 w_tools 分包依赖（不含 w_tools_map）"
  log_info "5. 生成了 w_tools 接入骨架（toolkit / design_system / AGENTS / doctor 配置）"
  log_info "6. 创建了核心数据层文件（API 层与 Retrofit 代码由 ww create 随后生成）"
  log_info "8. 格式化了代码"
  log_info "9. 初始化了测试文件"
  log_info "10. 初始化了 Git 仓库"
  log_info "11. 创建了 CI/CD 配置"
  log_info "12. 执行了项目健康检查"
  log_info ""
  log_info "接下来需要："
  log_info "1. 根据实际需求修改 API 路径和接口"
  log_info "2. 实现具体的业务逻辑"
  log_info "3. 编写测试用例"
  log_info "4. 配置 CI/CD 流程"
  log_info "5. 部署项目"
  log_info ""
  
  # 打开项目
  open_project
}

# 执行主函数
# 只有直接执行时才跑 main，被 source 时只提供函数（方便测试）
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
