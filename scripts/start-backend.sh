#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
CHECK_SCRIPT="$SCRIPT_DIR/check-env.sh"

SKIP_CHECK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-check)
            SKIP_CHECK=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$SKIP_CHECK" = false ]; then
    echo "🔍 启动前环境检查..."
    if ! bash "$CHECK_SCRIPT" backend-only; then
        echo ""
        echo "❌ 环境检查未通过，启动中止。"
        echo "💡 如需跳过检查，可使用: ./scripts/start-backend.sh --no-check"
        exit 1
    fi
    echo "✅ 环境检查通过，正在启动后端..."
    echo ""
fi

cd "$BACKEND_DIR"
exec mvn spring-boot:run
