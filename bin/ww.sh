#!/usr/bin/env sh

# 确定脚本所在目录
SCRIPT_DIR="$(dirname "$0")"

# 检查是否存在快照文件
SNAPSHOT_FILE="$SCRIPT_DIR/w_cli.jit"

if [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "Generating snapshot file..."
  # 生成快照文件
  dart compile jit-snapshot "$SCRIPT_DIR/w_cli.dart"
  echo "Snapshot file generated successfully!"
fi

# 使用快照文件执行
dart "$SNAPSHOT_FILE" "$@"