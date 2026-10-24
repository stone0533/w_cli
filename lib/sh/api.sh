#!/bin/bash

# ======================================================
# api.sh - API 代码生成脚本
# Version: 1.0.1
# Last Updated: 2026-05-09
# Author: Stone
# Description: 根据 client.dart 动态生成 data_source_mixin.dart 和 repository.dart
# ======================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# 全局变量：存储配置文件中引用的 JSON 文件名（用于增量检查）
CONFIG_REFERENCED_JSON_FILES=""

# 全局变量：独立类规格（类名 / JSON 文件 / 节点路径），传给 python 渲染器做结构匹配
STANDALONE_SPEC_LINES=()

# 待落盘的模型文件（临时路径 / 目标路径成对）。生成阶段只写临时文件，
# 全部写完再一次性 format 校验、一次性 mv：N 个模型只起 1 次 dart 进程。
PENDING_MODEL_TEMPS=()
PENDING_MODEL_TARGETS=()

# 配置选项（DEBUG 由 lib.sh 提供）
SUBCOMMAND=""          # init | models（空 = 没给子命令）
FORCE=false            # 配合 models：忽略增量检查
INCREMENTAL_MODE=true  # 默认启用增量模式

# 显示版本信息
show_version() {
  ww::show_version "根据 client.dart 动态生成 data_source_mixin.dart 和 repository.dart"
}

# 显示帮助信息
show_help() {
  echo "使用方法: $0 <init|models> [选项]"
  echo ""
  echo "子命令:"
  echo "  init           初始化 lib/app/data 目录与模板文件"
  echo "  models         从 w_json/*.json 生成模型文件（默认增量模式）"
  echo ""
  echo "选项:"
  echo "  --force        配合 models：忽略增量检查，全量重新生成"
  echo "  -d, --debug    启用调试模式"
  echo "  --version      显示脚本版本信息"
  echo "  --help         显示帮助信息"
  echo ""
  echo "说明:"
  echo "  client.dart 的代码生成（ww api generate）是纯 Dart 实现，见 docs/adr/0001"
  echo "  本脚本只负责 init 与 models 这两个需要操作文件系统的子命令。"
  echo ""
  echo "示例:"
  echo "  $0 init                 # 初始化目录结构"
  echo "  $0 models               # 生成模型文件（增量模式）"
  echo "  $0 models --force       # 强制全量重新生成模型"
}

# 解析命令行参数：子命令只有 init / models，修饰符只有 --force 与 --debug
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--debug)
        DEBUG=true
        shift
        ;;
      --version)
        show_version
        exit 0
        ;;
      --help)
        show_help
        exit 0
        ;;
      --force)
        FORCE=true
        shift
        ;;
      init|models)
        if [[ -n "$SUBCOMMAND" ]]; then
          log_error "子命令只能给一个，收到: $SUBCOMMAND 和 $1"
          show_help >&2
          exit 2
        fi
        SUBCOMMAND="$1"
        shift
        ;;
      --init|--models|--full)
        log_error "$1 已改成子命令，请改用：$(_legacy_hint "$1")"
        exit 2
        ;;
      generate|g)
        # 这一半已经是纯 Dart 实现（lib/src/api/），api.sh 里没有对应代码
        log_error "generate 由 ww api 直接实现（Dart），api.sh 只有 init 与 models"
        log_info "请改用：ww api generate"
        exit 2
        ;;
      *)
        log_error "未知参数: $1"
        show_help >&2
        exit 2
        ;;
    esac
  done

  if [[ "$FORCE" = true && "$SUBCOMMAND" != "models" ]]; then
    log_error "--force 只能配合 models 使用"
    show_help >&2
    exit 2
  fi
}

# 旧参数 -> 新写法的一行指路
_legacy_hint() {
  case "$1" in
    --init) printf '%s' "api.sh init" ;;
    --models) printf '%s' "api.sh models" ;;
    --full) printf '%s' "api.sh models --force" ;;
    *) printf '%s' "api.sh --help" ;;
  esac
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

# 生成自动生成文件的注释头部
# 生成文件的头部注释。
#
# 只保留「自动生成、勿手改」的警示，**不写时间戳**：
# 时间戳会让每次生成都改动所有文件（git 全是噪音 diff，看不出真正的业务改动）。
generate_header_comment() {
  cat << 'EOF'
// **************************************************************************
// Auto-generated file. Do not edit manually.
// **************************************************************************
EOF
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
      flutter pub add --dev "$dep"
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
    dart run build_runner build --delete-conflicting-outputs
    log_info "build_runner build 执行完成"
  elif command_available flutter; then
    flutter run build_runner build --delete-conflicting-outputs
    log_info "build_runner build 执行完成"
  else
    log_warn "Dart 和 Flutter 命令都不可用，跳过 build_runner build"
  fi
}

# 解析配置文件：只收集独立类（类名 / JSON 文件 / 节点路径），不在这里生成。
# 全部收集完再统一生成，配置行的先后顺序因此不再影响结构匹配。
parse_config_file() {
  local config_file="$1"
  local json_dir="$2"

  if [[ ! -f "$config_file" ]]; then
    log_info "配置文件不存在: $config_file，跳过自定义类生成"
    return 0
  fi

  log_info "读取配置文件: $config_file"

  local current_class=""
  local line=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
      continue
    fi

    # 类名注释行（# Merchant）
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
      current_class=$(echo "$line" | sed 's/^[[:space:]]*#[[:space:]]*//')
      continue
    fi

    # 配置行：json 文件名 + 节点路径
    if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
      local json_file="${BASH_REMATCH[1]}"
      local node_path="${BASH_REMATCH[2]}"

      if [[ -z "$current_class" ]]; then
        log_warn "跳过配置行，缺少类名: $line"
        continue
      fi

      local full_json_path="$json_dir/$json_file"
      if [[ ! -f "$full_json_path" ]]; then
        log_warn "JSON 文件不存在: $full_json_path"
        continue
      fi

      log_debug "  - $current_class: $json_file -> $node_path"

      STANDALONE_SPEC_LINES+=("${current_class}	${full_json_path}	${node_path}")

      if [[ -z "${CONFIG_REFERENCED_JSON_FILES:-}" || ! " $CONFIG_REFERENCED_JSON_FILES " =~ " $json_file " ]]; then
        CONFIG_REFERENCED_JSON_FILES="$CONFIG_REFERENCED_JSON_FILES $json_file"
      fi
    fi
  done < "$config_file"
}

# 一次 python 调用完成「JSON → Dart 模型类」的类型推导与渲染。
# 以前每个字段都要起一次 python3，并且把字段名拼进 python 源码——既慢，
# 又会被键里的引号/空格打崩。现在数据只走 stdin 与 argv。
MODEL_RENDERER_PY=$(cat <<'PY'
import json
import os
import re
import sys

RESERVED = {
    "assert", "break", "case", "catch", "class", "const", "continue",
    "default", "do", "else", "enum", "extends", "false", "final", "finally",
    "for", "if", "in", "is", "new", "null", "rethrow", "return", "super",
    "switch", "this", "throw", "true", "try", "var", "void", "while", "with",
    "implements", "import", "library", "mixin", "part", "typedef", "abstract",
    "covariant", "deferred", "dynamic", "export", "extension", "external",
    "factory", "get", "set", "operator", "static", "async", "await", "yield",
    "sync", "required", "late",
}


def dart_field(raw):
    """JSON 键 -> 合法 Dart 字段名（原始键名由 @JsonKey 保留）"""
    name = raw.replace("-", "_")
    name = re.sub(r"[^0-9A-Za-z_]", "_", name)
    name = re.sub(r"_([A-Za-z])", lambda m: m.group(1).upper(), name)
    if name:
        name = name[0].lower() + name[1:]
    if name and name[0].isdigit():
        name = "f_" + name
    if name in RESERVED:
        name += "_"
    return name


def cap(name):
    return name[0].upper() + name[1:] if name else name


def scalar_type(value):
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "double"
    return "String"


def escape(text):
    return text.replace("\\", "\\\\").replace("'", "\\'")


def load_standalones(spec):
    """w_json.config 里声明的独立类：类名 -> 键集合"""
    items = []
    for line in spec.splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        name, path, node = parts
        try:
            with open(path, "r", encoding="utf-8") as handle:
                data = json.load(handle)
        except Exception:
            continue
        for part in node.split("."):
            if isinstance(data, dict) and part in data:
                data = data[part]
            else:
                data = None
                break
        if isinstance(data, dict):
            items.append((name, tuple(sorted(data.keys()))))
    return items


def match_standalone(obj, standalones):
    keys = tuple(sorted(obj.keys()))
    for name, candidate in standalones:
        if candidate == keys:
            return name
    return None


def render(name, obj, standalones):
    fields = []
    nested = []
    used_names = set()

    for key, value in obj.items():
        fname = dart_field(key)
        while fname in used_names:
            fname += "_"
        used_names.add(fname)

        if isinstance(value, dict):
            matched = match_standalone(value, standalones)
            if matched:
                ftype = matched
            else:
                child = name + cap(fname)
                ftype = child
                nested.append((child, value))
        elif isinstance(value, list):
            first = value[0] if value else None
            if isinstance(first, dict):
                matched = match_standalone(first, standalones)
                if matched:
                    ftype = "List<%s>" % matched
                else:
                    child = name + cap(fname)
                    ftype = "List<%s>" % child
                    nested.append((child, first))
            elif first is None or isinstance(first, list):
                ftype = "List<dynamic>"
            else:
                ftype = "List<%s>" % scalar_type(first)
        else:
            ftype = scalar_type(value)

        fields.append((key, ftype, fname))

    lines = ["@JsonSerializable()", "class %s extends Object {" % name]
    if fields:
        lines.append("")
    for key, ftype, fname in fields:
        lines.append("  @JsonKey(name: '%s')" % escape(key))
        lines.append("  %s? %s;" % (ftype, fname))
    params = ", ".join("this.%s" % fname for _, _, fname in fields)
    lines.append("  %s(%s);" % (name, params))
    lines.append("")
    lines.append(
        "  factory %s.fromJson(Map<String, dynamic> srcJson) => _$%sFromJson(srcJson);"
        % (name, name)
    )
    lines.append("  Map<String, dynamic> toJson() => _$%sToJson(this);" % name)
    lines.append("}")

    blocks = ["\n".join(lines)]
    for child_name, child_obj in nested:
        blocks.extend(render(child_name, child_obj, standalones))
    return blocks


def main():
    class_name = sys.argv[1]
    data = json.loads(sys.stdin.read())
    if isinstance(data, list):
        data = data[0] if data else {}
    if not isinstance(data, dict):
        data = {}
    standalones = load_standalones(os.environ.get("W_STANDALONE", ""))
    sys.stdout.write("\n\n".join(render(class_name, data, standalones)) + "\n")


main()
PY
)

# 提取 JSON 节点内容（路径走 argv，不再拼进 python 源码）
extract_json_node() {
  local json_file="$1"
  local node_path="$2"

  python3 - "$json_file" "$node_path" <<'PY'
import json
import sys

path, node_path = sys.argv[1], sys.argv[2]

with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

current = data
for part in node_path.split("."):
    if isinstance(current, dict) and part in current:
        current = current[part]
    else:
        sys.exit(1)

print(json.dumps(current, ensure_ascii=False))
PY
}

# 生成模型类：整棵 JSON 交给一次 python 调用，bash 只负责取输出
generate_model_class() {
  local json_content="$1"
  local class_name="$2"
  # $3 file_path / $4 is_top_level 保留兼容，渲染已经不需要它们

  local spec=""
  if [[ ${#STANDALONE_SPEC_LINES[@]} -gt 0 ]]; then
    spec="$(printf '%s\n' "${STANDALONE_SPEC_LINES[@]}")"
  fi

  if ! printf '%s' "$json_content" | W_STANDALONE="$spec" python3 -c "$MODEL_RENDERER_PY" "$class_name"; then
    log_error "生成模型失败: $class_name"
    return 1
  fi
}

# 驼峰类名 -> 蛇形文件名
snake_name() {
  printf '%s' "$1" | awk '{for(i=1;i<=length;i++) {c=substr($0,i,1); if(c~/[A-Z]/ && i>1) printf "_" tolower(c); else printf tolower(c)}}'
}

# 扫模型内容里用到的独立类，生成 import 语句（排除自身，避免自引用）
collect_standalone_imports() {
  local self_class="$1"
  local model_content="$2"

  local imports=""
  local spec=""
  local name=""
  local path=""
  local node=""
  # 配置里同一个类名可能出现多行（同一段落下的每个 json 都沿用该类的名字），
  # 生成阶段靠 seen_standalone 去重，import 阶段也必须去重，
  # 否则会写出两条一模一样的 import（analyzer: duplicate_import）。
  local emitted=" "

  for spec in "${STANDALONE_SPEC_LINES[@]}"; do
    if [[ -z "$spec" ]]; then
      continue
    fi
    IFS=$'\t' read -r name path node <<< "$spec"

    if [[ "$name" = "$self_class" ]]; then
      continue
    fi
    case "$emitted" in
      *" $name "*) continue ;;
    esac
    if printf '%s' "$model_content" | grep -q "\b${name}\b"; then
      emitted="$emitted$name "
      imports+="import './$(snake_name "$name").dart';"$'\n'
    fi
  done

  printf '%s' "$imports"
}

# 生成后自检：重复 import / 重复 class 都是生成器的 bug，直接报错。
#
# 用 awk 而不是 flutter analyze：生成阶段只关心这两个模式，速度快、不依赖 Flutter 环境。
verify_generated_models() {
  local models_dir="$1"

  if [[ ! -d "$models_dir" ]]; then
    return 0
  fi

  # 只查同一文件内的结构性错误：重复 import、重复 class。
  # 不同文件里出现同名 class 在 Dart 里是允许的（只有同时 import 才冲突），
  # 所以每个文件开头重置一次统计。
  local bad=""
  bad="$(awk '
    FNR == 1 {
      delete seen_import
      delete seen_class
    }
    /^import /{
      if (seen_import[$0]++) print FILENAME ": 重复 import → " $0
    }
    /^class /{
      name = $2
      if (name != "" && seen_class[name]++) print FILENAME ": 重复 class → " name
    }
  ' "$models_dir"/*.dart 2>/dev/null)"

  if [[ -n "$bad" ]]; then
    log_error "生成的模型文件自检未通过："
    printf '%s\n' "$bad" >&2
    return 1
  fi

  log_info "生成自检通过：无重复 import / 无重复 class"
  return 0
}

# 生成一个模型文件。主模型和独立类走同一段装配：import 扫描、part、原子写，
# 以前两条路径各写各的，import 只长在其中一条上。
generate_model_file() {
  local class_name="$1"
  local json_content="$2"
  local dart_file="$3"
  local part_name="$4"

  local model_content=""
  model_content="$(generate_model_class "$json_content" "$class_name" "$dart_file")"

  local file_content=""
  local header=""
  header="$(generate_header_comment)"
  # 头部 + 一个空行（头部为空时不留空行，避免文件以空行开头）
  if [[ -n "$header" ]]; then
    file_content+="$header"$'\n\n'
  fi
  file_content+="import 'package:json_annotation/json_annotation.dart';\n"
  file_content+="\n"

  local standalone_imports=""
  standalone_imports="$(collect_standalone_imports "$class_name" "$model_content")"
  if [[ -n "$standalone_imports" ]]; then
    file_content+="$standalone_imports"
    file_content+="\n"
  fi

  file_content+="part '${part_name}.g.dart';\n"
  file_content+="\n"
  file_content+="$model_content"

  log_info "生成文件: $dart_file"
  local tmp_dart=""
  tmp_dart="$(mktemp "${dart_file}.XXXXXX")" || { log_error "无法创建临时文件: $dart_file"; return 1; }
  # printf 的格式串不能是文件内容：内容里的 \' 会被当成转义吃掉
  if ! printf '%s' "${file_content//\\n/$'\n'}" > "$tmp_dart"; then
    log_error "写入临时文件失败: $dart_file"
    rm -f "$tmp_dart"
    return 1
  fi
  PENDING_MODEL_TEMPS+=("$tmp_dart")
  PENDING_MODEL_TARGETS+=("$dart_file")
}

# 一次性校验并落盘：所有临时文件都合法才 mv，任何一个不合法就整批放弃，
# 不会留下"生成了一半"的目录。
flush_generated_models() {
  if [[ ${#PENDING_MODEL_TEMPS[@]} -eq 0 ]]; then
    return 0
  fi

  if command_available dart; then
    log_info "校验生成的代码..."
    if ! dart format "${PENDING_MODEL_TEMPS[@]}" > /dev/null 2>&1; then
      log_error "生成的模型不是合法 Dart，已放弃写入（原有文件未改动）"
      rm -f "${PENDING_MODEL_TEMPS[@]}"
      PENDING_MODEL_TEMPS=()
      PENDING_MODEL_TARGETS=()
      return 1
    fi
  else
    log_warn "未找到 dart，跳过生成代码的合法性校验"
  fi

  local index=0
  while [[ $index -lt ${#PENDING_MODEL_TEMPS[@]} ]]; do
    mv -- "${PENDING_MODEL_TEMPS[$index]}" "${PENDING_MODEL_TARGETS[$index]}"
    index=$((index + 1))
  done

  PENDING_MODEL_TEMPS=()
  PENDING_MODEL_TARGETS=()
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
  
  # 检查 json_annotation 依赖
  if ! grep -q "json_annotation:" "$pubspec_file"; then
    log_info "添加 json_annotation 依赖..."
    if command_available flutter; then
      flutter pub add json_annotation
    elif command_available dart; then
      dart pub add json_annotation
    else
      log_error "Dart 和 Flutter 命令都不可用，无法添加依赖项"
      return 1
    fi
  else
    log_info "json_annotation 依赖已存在"
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
  local json_files=()
  # 使用 glob 检查是否存在匹配的文件
  for file in "$json_dir"/*.json; do
    if [[ -f "$file" ]]; then
      json_files+=("$file")
    fi
  done
  
  if [[ ${#json_files[@]} -eq 0 ]]; then
    log_error "未找到 json 文件: $json_dir"
    return 1
  fi
  
  log_info "找到 ${#json_files[@]} 个 json 文件:"
  for json_file in "${json_files[@]}"; do
    log_info "  - $(basename "$json_file")"
  done
  
  # 先解析配置（只收集），再统一生成：配置行的先后顺序不再影响结构匹配
  parse_config_file "$json_dir/w_json.config" "$json_dir"

  # 生成独立类（同类名只生成一次，保持声明顺序）
  if [[ ${#STANDALONE_SPEC_LINES[@]} -gt 0 ]]; then
    log_info "生成配置文件声明的独立类..."
    local seen_standalone=" "
    local spec=""
    local standalone_class=""
    local standalone_json=""
    local standalone_node=""
    for spec in "${STANDALONE_SPEC_LINES[@]}"; do
      if [[ -z "$spec" ]]; then
        continue
      fi
      IFS=$'\t' read -r standalone_class standalone_json standalone_node <<< "$spec"

      case "$seen_standalone" in
        *" $standalone_class "*) continue ;;
      esac
      seen_standalone="$seen_standalone$standalone_class "

      local standalone_dart_name=""
      standalone_dart_name="$(snake_name "$standalone_class")"
      local standalone_dart_file="$models_dir/${standalone_dart_name}.dart"

      if [[ "$INCREMENTAL_MODE" = true && -f "$standalone_dart_file" ]]; then
        local json_mtime=$(stat -f "%m" "$standalone_json" 2>/dev/null || stat -c "%Y" "$standalone_json" 2>/dev/null)
        local config_mtime=$(stat -f "%m" "$json_dir/w_json.config" 2>/dev/null || stat -c "%Y" "$json_dir/w_json.config" 2>/dev/null)
        local dart_mtime=$(stat -f "%m" "$standalone_dart_file" 2>/dev/null || stat -c "%Y" "$standalone_dart_file" 2>/dev/null)
        if [[ "$json_mtime" -le "$dart_mtime" && "$config_mtime" -le "$dart_mtime" ]]; then
          log_info "  - ${standalone_dart_name}.dart (无需更新)"
          continue
        fi
      fi

      local standalone_content=""
      standalone_content="$(extract_json_node "$standalone_json" "$standalone_node")"
      if [[ -z "$standalone_content" ]]; then
        log_warn "无法提取节点内容: $standalone_node"
        continue
      fi

      generate_model_file "$standalone_class" "$standalone_content" "$standalone_dart_file" "$standalone_dart_name" || return 1
      log_info "  ~ ${standalone_dart_name}.dart (生成/更新)"
    done

    # 独立类先落盘：后面的增量检查要靠磁盘上的 mtime 判断主模型是否需要生成
    flush_generated_models || return 1
    # 注意：这里**不要**做重复 import 自检 —— 此时主模型还是磁盘上的旧文件，
    # 会把上一次生成的重复报出来。自检统一放在所有模型都写完之后。
  fi
  
  # 检查文件是否需要更新
  local files_to_generate=()
  local has_changes=false
  
  if [[ "$INCREMENTAL_MODE" = true ]]; then
    log_info "增量模式: 检查文件是否需要更新..."
    
    # 获取配置文件修改时间（用于检查引用的 JSON 文件）
    local config_file="$json_dir/w_json.config"
    local config_mtime=0
    if [[ -f "$config_file" ]]; then
      config_mtime=$(stat -f "%m" "$config_file" 2>/dev/null || stat -c "%Y" "$config_file" 2>/dev/null)
    fi
    
    for json_file in "${json_files[@]}"; do
      local json_name=$(basename "$json_file" .json)
      local dart_file_name=$(echo "$json_name" | awk '{for(i=1;i<=length;i++) {c=substr($0,i,1); if(c~/[A-Z]/ && i>1) printf "_" tolower(c); else printf tolower(c)}}')
      local dart_file="$models_dir/${dart_file_name}.dart"
      
      if [[ ! -f "$dart_file" ]]; then
        # 文件不存在，需要生成
        files_to_generate+=("$json_file|$dart_file|$dart_file_name|$json_name")
        has_changes=true
        log_info "  + ${json_name}.json -> ${dart_file_name}.dart (新建)"
      else
        # 获取文件修改时间
        local json_mtime=$(stat -f "%m" "$json_file" 2>/dev/null || stat -c "%Y" "$json_file" 2>/dev/null)
        local dart_mtime=$(stat -f "%m" "$dart_file" 2>/dev/null || stat -c "%Y" "$dart_file" 2>/dev/null)
        
        local need_update=false
        
        # 检查 JSON 文件是否比 Dart 文件新
        if [[ "$json_mtime" -gt "$dart_mtime" ]]; then
          need_update=true
        fi
        
        # 如果 JSON 文件在配置文件中被引用，还要检查配置文件是否比 Dart 文件新
        if [[ "$need_update" = false && -n "$CONFIG_REFERENCED_JSON_FILES" && " $CONFIG_REFERENCED_JSON_FILES " =~ " ${json_name}.json " ]]; then
          if [[ "$config_mtime" -gt "$dart_mtime" ]]; then
            need_update=true
          fi
        fi
        
        if [[ "$need_update" = true ]]; then
          # 需要更新
          files_to_generate+=("$json_file|$dart_file|$dart_file_name|$json_name")
          has_changes=true
          log_info "  ~ ${json_name}.json -> ${dart_file_name}.dart (已更新)"
        else
          log_info "  - ${json_name}.json -> ${dart_file_name}.dart (无需更新)"
        fi
      fi
    done
    
    if [[ "$has_changes" = false ]]; then
      log_info "✅ 所有模型文件都是最新的，无需重新生成"
      return 0
    fi
    
    log_info "需要更新 ${#files_to_generate[@]} 个文件"
  else
    # 全量模式：添加所有文件
    for json_file in "${json_files[@]}"; do
      local json_name=$(basename "$json_file" .json)
      local dart_file_name=$(echo "$json_name" | awk '{for(i=1;i<=length;i++) {c=substr($0,i,1); if(c~/[A-Z]/ && i>1) printf "_" tolower(c); else printf tolower(c)}}')
      local dart_file="$models_dir/${dart_file_name}.dart"
      files_to_generate+=("$json_file|$dart_file|$dart_file_name|$json_name")
    done
    has_changes=true
    log_info "全量模式: 重新生成所有 ${#files_to_generate[@]} 个文件..."
  fi
  
  # 转换 json 文件为 dart 文件（与独立类共用同一段装配）
  log_info "开始转换 json 文件为 dart 文件..."
  for item in "${files_to_generate[@]}"; do
    IFS='|' read -r json_file dart_file dart_file_name json_name <<< "$item"

    local class_name=$(echo "$json_name" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
    local json_content=$(cat "$json_file")
    local main_class_name="${class_name}Result"

    generate_model_file "$main_class_name" "$json_content" "$dart_file" "$dart_file_name" || return 1
  done

  flush_generated_models || return 1

  # 自检：重复 import 是生成器的 bug，不要让它落到仓库里
  verify_generated_models "$models_dir" || return 1

  # 执行 build_runner build
  run_build_runner

  log_info "✅ 模型文件生成完成！"
}

# 主函数
main() {
  parse_args "$@"

  if [[ -z "$SUBCOMMAND" ]]; then
    log_error "缺少子命令"
    show_help >&2
    exit 2
  fi

  if [[ "$FORCE" = true ]]; then
    INCREMENTAL_MODE=false
  fi

  printf "${GREEN}======================================================${NC}\n"

  if [[ "$SUBCOMMAND" = "models" ]]; then
    printf "${GREEN}模型文件生成开始${NC}\n"
    printf "${GREEN}======================================================${NC}\n"

    generate_models || exit 1

    printf "${GREEN}======================================================${NC}\n"
    printf "${GREEN}模型文件生成结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
    printf "${GREEN}======================================================${NC}\n"
    exit 0
  fi

  printf "${GREEN}API 目录结构初始化开始${NC}\n"
  printf "${GREEN}======================================================${NC}\n"

  log_info "检查并添加必要的依赖项..."
  check_and_add_dependencies || exit 1

  log_info "开始初始化目录结构..."
  init_directory_structure

  printf "${GREEN}======================================================${NC}\n"
  printf "${GREEN}API 目录结构初始化结束${NC} $(date '+%Y-%m-%d %H:%M:%S')\n"
  printf "${GREEN}======================================================${NC}\n"
  exit 0
}

# 调用主函数
# 只有直接执行时才跑 main，被 source 时只提供函数（方便测试）
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
