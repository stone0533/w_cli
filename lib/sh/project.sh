#!/bin/bash

# ======================================================
# project.sh - Flutter 项目管理脚本
# Version: 1.0.0
# Last Updated: 2026-03-23
# Author: Stone
# Description: 更新 Flutter 项目的依赖和配置
# Features:
#   - 检查 Flutter 安装状态
#   - 升级 pub 依赖
#   - 升级 Gradle 版本
# ======================================================

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
  printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

log_success() {
  printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_error() {
  printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# 检查执行权限
if [ ! -x "$0" ]; then
  log_error "Script does not have execution permission."
  log_warn "Please run: chmod +x $0"
  exit 1
fi

# 显示帮助信息
show_help() {
  echo "使用方法: ./project.sh [选项]"
  echo "选项:"
  echo "  --update      # 更新 Flutter 项目依赖和配置"
  echo "  --help        # 显示帮助信息"
  echo "  --version     # 显示脚本版本信息"
  echo ""
  echo "示例:"
  echo "  ./project.sh --update  # 更新项目依赖和配置"
  exit 0
}

# 显示版本信息
show_version() {
  echo "project.sh version: 1.0.0"
  echo "Last updated: 2026-03-23"
  echo "Description: Flutter 项目管理脚本"
  echo "Features:"
  echo "  - 检查 Flutter 安装状态"
  echo "  - 升级 pub 依赖"
  echo "  - 升级 Gradle 版本"
  exit 0
}

# 检查 Flutter 是否安装
check_flutter() {
  if ! command -v flutter &> /dev/null; then
    log_error "Flutter 未安装，请先安装 Flutter"
    return 1
  fi
  return 0
}

# 获取当前 Flutter 版本
get_flutter_version() {
  flutter --version | grep "Flutter" | awk '{print $2}'
}

# 升级 pub 依赖
update_pub() {
  log_info "正在升级 pub 依赖..."
  
  if [ -f "pubspec.yaml" ]; then
    flutter pub upgrade
    if [ $? -eq 0 ]; then
      log_success "pub 依赖升级成功"
    else
      log_error "pub 依赖升级失败"
      return 1
    fi
  else
    log_error "未找到 pubspec.yaml 文件，当前目录可能不是 Flutter 项目"
    return 1
  fi
  
  return 0
}

# 升级 Gradle 版本
update_gradle() {
  log_info "正在升级 Gradle 版本..."
  
  # 检查是否存在 android 目录
  if [ -d "android" ]; then
    # 检查 gradle-wrapper.properties 文件
    GRADLE_WRAPPER="android/gradle/wrapper/gradle-wrapper.properties"
    if [ -f "$GRADLE_WRAPPER" ]; then
      # 获取当前 Gradle 版本
      CURRENT_GRADLE_VERSION=$(grep "distributionUrl" "$GRADLE_WRAPPER" | sed 's/.*gradle-\(.*\)-all.zip/\1/')
      log_info "当前 Gradle 版本: $CURRENT_GRADLE_VERSION"
      
      # 建议使用的 Gradle 版本（根据 Flutter 版本动态调整）
      FLUTTER_VERSION=$(get_flutter_version)
      log_info "当前 Flutter 版本: $FLUTTER_VERSION"
      
      # 这里可以根据 Flutter 版本设置推荐的 Gradle 版本
      # 例如，对于 Flutter 3.38+，推荐 Gradle 8.0+
      RECOMMENDED_GRADLE_VERSION="8.0"
      
      log_info "推荐 Gradle 版本: $RECOMMENDED_GRADLE_VERSION"
      
      # 更新 gradle-wrapper.properties 文件
      sed -i '' "s/distributionUrl=.*/distributionUrl=https\:\/\/services.gradle.org\/distributions\/gradle-$RECOMMENDED_GRADLE_VERSION-all.zip/" "$GRADLE_WRAPPER"
      
      if [ $? -eq 0 ]; then
        log_success "Gradle 版本更新成功"
      else
        log_error "Gradle 版本更新失败"
        return 1
      fi
    else
      log_error "未找到 gradle-wrapper.properties 文件"
      return 1
    fi
  else
    log_warn "未找到 android 目录，跳过 Gradle 升级"
  fi
  
  return 0
}

# 主函数
main() {
  # 检查参数
  if [ $# -eq 0 ]; then
    show_help
  fi
  
  for arg in "$@"; do
    case "$arg" in
      --update)
        # 添加运行开始分隔线
        printf "${GREEN}======================================================${NC}\n"
        printf "${GREEN}Flutter 项目管理脚本运行开始${NC}\n"
        printf "${GREEN}======================================================${NC}\n"
        
        # 检查 Flutter 是否安装
        if ! check_flutter; then
          # 添加运行结束分隔线
          printf "${GREEN}======================================================${NC}\n"
          printf "${GREEN}Flutter 项目管理脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
          printf "${GREEN}======================================================${NC}\n"
          return 1
        fi
        
        # 获取并显示当前 Flutter 版本
        FLUTTER_VERSION=$(get_flutter_version)
        log_info "使用当前 Flutter 版本: $FLUTTER_VERSION"
        
        # 升级 pub 依赖
        if ! update_pub; then
          # 添加运行结束分隔线
          printf "${GREEN}======================================================${NC}\n"
          printf "${GREEN}Flutter 项目管理脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
          printf "${GREEN}======================================================${NC}\n"
          return 1
        fi
        
        # 升级 Gradle 版本
        if ! update_gradle; then
          # 添加运行结束分隔线
          printf "${GREEN}======================================================${NC}\n"
          printf "${GREEN}Flutter 项目管理脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
          printf "${GREEN}======================================================${NC}\n"
          return 1
        fi
        
        log_success "项目更新完成！"
        
        # 添加运行结束分隔线
        printf "${GREEN}======================================================${NC}\n"
        printf "${GREEN}Flutter 项目管理脚本运行结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
        printf "${GREEN}======================================================${NC}\n"
        ;;
      --help)
        show_help
        ;;
      --version)
        show_version
        ;;
      *)
        log_error "未知参数: $arg"
        show_help
        return 1
        ;;
    esac
  done
}

# 执行主函数
main "$@"
