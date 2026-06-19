#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
BACKEND_DIR="$PROJECT_ROOT/backend"

FRONTEND_PORT=5184
BACKEND_PORT=8002

MODE="all"

PASS="✅"
FAIL="❌"
WARN="⚠️"
INFO="ℹ️"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        frontend-only|frontend)
            MODE="frontend"
            shift
            ;;
        backend-only|backend)
            MODE="backend"
            shift
            ;;
        all)
            MODE="all"
            shift
            ;;
        --help|-h)
            echo "用法: ./scripts/check-env.sh [模式]"
            echo ""
            echo "模式:"
            echo "  all          检查全部 (默认)"
            echo "  frontend     仅检查前端相关"
            echo "  backend      仅检查后端相关"
            echo "  -h, --help   显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看用法"
            exit 1
            ;;
    esac
done

print_header() {
    echo ""
    echo "========================================"
    echo "  $1"
    echo "========================================"
}

check_pass() {
    echo "  $PASS $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

check_fail() {
    echo "  $FAIL $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_warn() {
    echo "  $WARN $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

check_port() {
    local port=$1
    local name=$2
    if command -v lsof >/dev/null 2>&1; then
        if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
            local pid
            pid=$(lsof -Pi :"$port" -sTCP:LISTEN -t | head -1)
            check_fail "端口 $port ($name) 已被占用 (PID: $pid)"
            return 1
        else
            check_pass "端口 $port ($name) 可用"
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -an 2>/dev/null | grep -E "[.:]${port}[[:space:]]+.*LISTEN" >/dev/null 2>&1; then
            check_fail "端口 $port ($name) 已被占用"
            return 1
        else
            check_pass "端口 $port ($name) 可用"
            return 0
        fi
    else
        check_warn "无法检查端口 $port ($name)（未找到 lsof 或 netstat）"
        return 0
    fi
}

check_command() {
    local cmd=$1
    local name=$2
    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version=$($cmd --version 2>/dev/null | head -1)
        check_pass "$name 已安装: $version"
        return 0
    else
        check_fail "$name 未安装，请先安装 $cmd"
        return 1
    fi
}

check_frontend_tools() {
    print_header "前端工具检查"
    check_command "node" "Node.js"
    check_command "npm" "npm"
}

check_backend_tools() {
    print_header "后端工具检查"
    check_command "java" "Java"
    check_command "mvn" "Maven"
}

check_frontend_ports() {
    print_header "前端端口检查"
    check_port "$FRONTEND_PORT" "前端 Vite 服务"
}

check_backend_ports() {
    print_header "后端端口检查"
    check_port "$BACKEND_PORT" "后端 Spring Boot"
}

check_frontend_deps() {
    print_header "前端依赖检查"

    if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
        check_fail "node_modules 不存在，请先运行 'cd frontend && npm install'"
        return 1
    fi

    local dep_count
    dep_count=$(find "$FRONTEND_DIR/node_modules" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    check_pass "node_modules 存在（约 $dep_count 个包）"
    return 0
}

check_backend_deps() {
    print_header "后端依赖检查"

    if [ ! -f "$BACKEND_DIR/pom.xml" ]; then
        check_fail "pom.xml 不存在"
        return 1
    fi
    check_pass "pom.xml 存在"

    local m2_repo="$HOME/.m2/repository"
    if [ -d "$m2_repo" ]; then
        check_pass "Maven 本地仓库存在"
    else
        check_warn "Maven 本地仓库不存在，首次启动将下载依赖（可能需要较长时间）"
    fi

    if [ -d "$BACKEND_DIR/target" ]; then
        check_pass "编译输出目录 target 存在"
    else
        check_warn "编译输出目录不存在，首次启动将自动编译"
    fi

    return 0
}

print_summary() {
    print_header "检查结果汇总"
    echo "  通过: $PASS_COUNT"
    echo "  失败: $FAIL_COUNT"
    echo "  警告: $WARN_COUNT"
    echo ""

    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo "$FAIL 环境检查未通过，请修复上述问题后再启动。"
        echo ""
        return 1
    elif [ "$WARN_COUNT" -gt 0 ]; then
        echo "$WARN 环境检查有警告，可以启动但可能需要额外时间。"
        echo ""
        return 0
    else
        echo "$PASS 环境检查全部通过！"
        echo ""
        return 0
    fi
}

run_frontend_checks() {
    print_header "前端环境检查"
    check_frontend_tools
    check_frontend_ports
    check_frontend_deps
}

run_backend_checks() {
    print_header "后端环境检查"
    check_backend_tools
    check_backend_ports
    check_backend_deps
}

run_all_checks() {
    print_header "环境检查 - OPC-UA 工业监控系统"
    check_frontend_tools
    check_backend_tools
    check_frontend_ports
    check_backend_ports
    check_frontend_deps
    check_backend_deps
}

case "$MODE" in
    frontend)
        run_frontend_checks
        ;;
    backend)
        run_backend_checks
        ;;
    all)
        run_all_checks
        ;;
esac

print_summary
exit $?
