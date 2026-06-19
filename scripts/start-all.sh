#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
BACKEND_DIR="$PROJECT_ROOT/backend"
CHECK_SCRIPT="$SCRIPT_DIR/check-env.sh"

SKIP_CHECK=false
BACKGROUND=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-check)
            SKIP_CHECK=true
            shift
            ;;
        --bg|--background)
            BACKGROUND=true
            shift
            ;;
        -h|--help)
            echo "用法: ./scripts/start-all.sh [选项]"
            echo ""
            echo "选项:"
            echo "  --no-check       跳过环境检查直接启动"
            echo "  --bg, --background  后台启动"
            echo "  -h, --help       显示帮助信息"
            echo ""
            echo "说明:"
            echo "  同时启动前后端服务。默认前台运行，Ctrl+C 可同时停止。"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看用法"
            exit 1
            ;;
    esac
done

if [ "$SKIP_CHECK" = false ]; then
    echo "🔍 启动前环境检查..."
    if ! bash "$CHECK_SCRIPT" all; then
        echo ""
        echo "❌ 环境检查未通过，启动中止。"
        echo "💡 如需跳过检查，可使用: ./scripts/start-all.sh --no-check"
        exit 1
    fi
    echo "✅ 环境检查通过，正在启动服务..."
    echo ""
fi

BACKEND_PID=""
FRONTEND_PID=""

cleanup() {
    echo ""
    echo "🛑 正在停止服务..."

    if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "  停止后端服务 (PID: $BACKEND_PID)..."
        kill "$BACKEND_PID" 2>/dev/null || true
        wait "$BACKEND_PID" 2>/dev/null || true
    fi

    if [ -n "$FRONTEND_PID" ] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
        echo "  停止前端服务 (PID: $FRONTEND_PID)..."
        kill "$FRONTEND_PID" 2>/dev/null || true
        wait "$FRONTEND_PID" 2>/dev/null || true
    fi

    echo "✅ 所有服务已停止"
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "🚀 启动后端服务..."
cd "$BACKEND_DIR"
if [ "$BACKGROUND" = true ]; then
    nohup mvn spring-boot:run > /tmp/opcua-backend.log 2>&1 &
    BACKEND_PID=$!
else
    mvn spring-boot:run &
    BACKEND_PID=$!
fi
echo "  后端 PID: $BACKEND_PID"

echo ""
echo "🚀 启动前端服务..."
cd "$FRONTEND_DIR"
if [ "$BACKGROUND" = true ]; then
    nohup npm run dev > /tmp/opcua-frontend.log 2>&1 &
    FRONTEND_PID=$!
else
    npm run dev &
    FRONTEND_PID=$!
fi
echo "  前端 PID: $FRONTEND_PID"

echo ""
echo "========================================"
echo "  服务启动中..."
echo "  前端: http://localhost:5184"
echo "  后端: http://localhost:8002"
echo "========================================"

if [ "$BACKGROUND" = true ]; then
    echo ""
    echo "📝 日志文件:"
    echo "  前端: /tmp/opcua-frontend.log"
    echo "  后端: /tmp/opcua-backend.log"
    echo ""
    echo "💡 停止服务: kill $BACKEND_PID $FRONTEND_PID"
    exit 0
fi

echo ""
echo "按 Ctrl+C 停止所有服务"
echo ""

wait
