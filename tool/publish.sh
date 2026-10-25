#!/usr/bin/env bash
#
# 发布到 pub.dev 的封装。
#
# 为什么需要它：
#   本机常把 PUB_HOSTED_URL 设成只读镜像（pub.flutter-io.cn），直接 `dart pub publish`
#   会往镜像发。这里显式指定目标，并先跑一遍发布前检查。
#
# 用法：
#   bash tool/publish.sh              # 检查 + 发布
#   bash tool/publish.sh --dry-run    # 只检查 + dry-run
#   PUBLISH_HOSTED_URL=https://example.com bash tool/publish.sh   # 换目标（会警告）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

publish_host="${PUBLISH_HOSTED_URL:-https://pub.dev}"

usage() {
  sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

if ! command -v dart > /dev/null 2>&1; then
  echo "找不到 dart" >&2
  exit 2
fi

echo "== 发布目标: $publish_host"
if [ "$publish_host" != "https://pub.dev" ]; then
  echo "!! 警告：目标不是 pub.dev（是通过 PUBLISH_HOSTED_URL 指定的）" >&2
fi

echo "== 发布前检查"
dart run tool/release_check.dart --strict

echo "== 文档检查"
dart run tool/check_docs.dart

echo "== 发布"
# 不继承本机的 PUB_HOSTED_URL / FLUTTER_STORAGE_BASE_URL（通常是只读镜像）
exec env -u FLUTTER_STORAGE_BASE_URL \
  PUB_HOSTED_URL="$publish_host" \
  dart pub publish "$@"
