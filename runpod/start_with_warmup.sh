#!/bin/bash

# ============================================================================
# RunPod ComfyUI Startup Script with Model Warmup
# RunPod ComfyUI 启动脚本 (带模型预热功能)
#
# 功能:
#   1. 执行模型预热 - 将高频模型复制到本地 NVMe SSD
#   2. 配置 ComfyUI 额外模型路径
#   3. 启动 ComfyUI 服务并监控
#
# 使用方法:
#   ./start_with_warmup.sh [选项]
#
# 在 RunPod Template 中配置:
#   Docker Command: bash /workspace/ComfyUI-AutoCloud/runpod/start_with_warmup.sh
#
# 环境变量:
#   COMFYUI_PATH      - ComfyUI 安装路径 (默认: /workspace/ComfyUI)
#   CACHE_PATH        - 本地缓存路径 (默认: /root/fast_cache)
#   WARMUP_CONFIG     - 预热配置文件 (默认: warmup_models.conf)
#   SKIP_WARMUP       - 设为 1 跳过预热 (默认: 0)
#   COMFYUI_ARGS      - 额外的 ComfyUI 启动参数
# ============================================================================

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === 配置 ===
export COMFYUI_PATH="${COMFYUI_PATH:-/workspace/ComfyUI}"
export CACHE_PATH="${CACHE_PATH:-/root/fast_cache}"
export CONFIG_DIR="${CONFIG_DIR:-$SCRIPT_DIR}"

WARMUP_CONFIG="${WARMUP_CONFIG:-warmup_models.conf}"
SKIP_WARMUP="${SKIP_WARMUP:-0}"

# ComfyUI 启动参数
# --listen: 允许外部访问 (RunPod 必须)
# --highvram: 尽量常驻显存，减少模型交换
# --disable-metadata: 禁用元数据写入
# --disable-smart-memory: 禁用智能内存管理
DEFAULT_COMFYUI_ARGS="--listen --disable-metadata"
COMFYUI_ARGS="${COMFYUI_ARGS:-$DEFAULT_COMFYUI_ARGS}"

# 监控配置
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="comfyui_${TIMESTAMP}.log"
CURRENT_LOG_SYMLINK="comfyui_current.log"
MAX_RESTARTS=5
RESTART_DELAY=10
MAX_LOGS=10
HEALTH_CHECK_INTERVAL=600  # 健康检查间隔 (秒)
MAX_RESPONSE_TIME=30       # 最大响应时间 (秒)
COMFYUI_PORT=8188          # ComfyUI 默认端口
WARMUP_TIMEOUT=600         # 预热超时时间 (秒，10分钟)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# === 日志函数 ===
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_header() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================================${NC}"
}

# === 终止其他运行中的脚本 ===
kill_running_scripts() {
    log_info "检查其他运行中的启动脚本..."
    
    # 查找并终止其他 start_with_warmup.sh 进程
    for pid in $(pgrep -f "start_with_warmup.sh" 2>/dev/null | grep -v $$ || true); do
        log_warning "终止已存在的启动脚本进程: $pid"
        kill -15 $pid 2>/dev/null || kill -9 $pid 2>/dev/null || true
    done
    
    sleep 2
}

# === 清理现有进程 ===
cleanup_processes() {
    log_info "清理现有 ComfyUI 进程..."
    
    # 检查端口是否被占用
    if command -v lsof >/dev/null 2>&1 && lsof -i :$COMFYUI_PORT > /dev/null 2>&1; then
        log_warning "端口 $COMFYUI_PORT 被占用，正在释放..."
        
        PIDS=$(lsof -t -i :$COMFYUI_PORT 2>/dev/null || true)
        
        for pid in $PIDS; do
            if [ -n "$pid" ]; then
                log_info "终止占用端口的进程: $pid"
                kill -15 $pid 2>/dev/null || true
                sleep 2
                
                if kill -0 $pid 2>/dev/null; then
                    kill -9 $pid 2>/dev/null || true
                fi
            fi
        done
        
        sleep 2
    fi
    
    # 清理可能残留的 ComfyUI 进程
    pkill -f "python.*main.py" 2>/dev/null || true
    sleep 2
    
    log_success "进程清理完成"
}

# === 执行模型预热 ===
do_warmup() {
    if [ "$SKIP_WARMUP" = "1" ]; then
        log_warning "跳过模型预热 (SKIP_WARMUP=1)"
        return 0
    fi
    
    log_header "执行模型预热"
    
    local warmup_script="$SCRIPT_DIR/warmup.sh"
    
    if [ ! -f "$warmup_script" ]; then
        log_error "预热脚本不存在: $warmup_script"
        log_warning "跳过预热，继续启动 ComfyUI"
        return 0
    fi
    
    # 检查配置文件
    local config_path="$CONFIG_DIR/$WARMUP_CONFIG"
    if [ ! -f "$config_path" ]; then
        log_warning "预热配置文件不存在: $config_path"
        log_info "使用默认配置或跳过预热"
    fi
    
    # 执行预热脚本 (带超时)
    log_info "开始预热，超时时间: ${WARMUP_TIMEOUT}s"
    
    if timeout $WARMUP_TIMEOUT bash "$warmup_script" "$WARMUP_CONFIG"; then
        log_success "模型预热完成"
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "预热超时 (${WARMUP_TIMEOUT}s)"
        else
            log_error "预热脚本执行失败 (exit code: $exit_code)"
        fi
        log_warning "继续启动 ComfyUI..."
    fi
}

# === 检测 GPU 并设置参数 ===
detect_gpu_and_set_args() {
    log_info "检测 GPU 配置..."
    
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1)
        if [ -n "$gpu_info" ]; then
            log_success "检测到 GPU: $gpu_info"
            
            # 获取显存大小 (MB)
            local vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
            
            if [ -n "$vram" ]; then
                if [ "$vram" -ge 24000 ]; then
                    log_info "高显存 GPU (${vram}MB)，启用 --highvram"
                    COMFYUI_ARGS="$COMFYUI_ARGS --highvram"
                elif [ "$vram" -ge 12000 ]; then
                    log_info "中等显存 GPU (${vram}MB)，使用默认设置"
                else
                    log_info "低显存 GPU (${vram}MB)，启用 --lowvram"
                    COMFYUI_ARGS="$COMFYUI_ARGS --lowvram"
                fi
            fi
        fi
    else
        log_warning "未检测到 nvidia-smi，可能没有 GPU 或驱动未安装"
    fi
}

# === 启动 ComfyUI ===
start_comfyui() {
    log_header "启动 ComfyUI"
    
    cd "$COMFYUI_PATH"
    
    # 创建日志目录
    mkdir -p logs
    
    # 激活虚拟环境 (如果存在)
    if [ -d "venv" ]; then
        log_info "激活虚拟环境..."
        if command -v source >/dev/null 2>&1; then
            source venv/bin/activate
        else
            . venv/bin/activate
        fi
    fi
    
    log_info "启动参数: $COMFYUI_ARGS"
    log_info "日志文件: logs/$LOG_FILE"
    
    # 启动 ComfyUI
    python main.py $COMFYUI_ARGS >> logs/$LOG_FILE 2>&1
    return $?
}

# === 健康检查 ===
check_health() {
    if timeout $MAX_RESPONSE_TIME curl -s "http://127.0.0.1:$COMFYUI_PORT/system_stats" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# === 等待服务就绪 ===
wait_for_ready() {
    local max_wait=180  # 最多等待 3 分钟
    local waited=0
    local interval=5
    
    log_info "等待 ComfyUI 服务就绪 (最多 ${max_wait}s)..."
    
    while [ $waited -lt $max_wait ]; do
        if check_health; then
            log_success "ComfyUI 服务已就绪 (等待 ${waited}s)"
            return 0
        fi
        sleep $interval
        waited=$((waited + interval))
        echo -n "."
    done
    
    echo ""
    log_warning "ComfyUI 服务在 ${max_wait}s 内未就绪，继续监控..."
    return 1
}

# === 监控并自动重启 ===
monitor_and_restart() {
    local restart_count=0
    
    while [ $restart_count -lt $MAX_RESTARTS ]; do
        cleanup_processes
        
        # 启动 ComfyUI (后台运行)
        start_comfyui &
        local pid=$!
        
        log_info "ComfyUI 已启动，PID: $pid"
        
        # 等待服务就绪
        sleep 30
        wait_for_ready
        
        # 监控进程
        while kill -0 $pid 2>/dev/null; do
            sleep $HEALTH_CHECK_INTERVAL
            
            if ! check_health; then
                log_error "ComfyUI 服务无响应，准备重启..."
                kill -15 $pid 2>/dev/null || true
                sleep 2
                kill -9 $pid 2>/dev/null || true
                break
            fi
            
            log_info "健康检查通过"
        done
        
        # 进程已退出
        log_warning "ComfyUI 进程已退出"
        
        restart_count=$((restart_count + 1))
        
        if [ $restart_count -lt $MAX_RESTARTS ]; then
            log_info "第 $restart_count 次重启，等待 ${RESTART_DELAY}s..."
            sleep $RESTART_DELAY
        else
            log_error "已达到最大重启次数 ($MAX_RESTARTS)，退出"
        fi
    done
}

# === 管理日志文件 ===
manage_logs() {
    cd "$COMFYUI_PATH/logs" 2>/dev/null || return
    
    # 创建当前日志的软链接
    if [ -L "$CURRENT_LOG_SYMLINK" ]; then
        rm "$CURRENT_LOG_SYMLINK"
    fi
    ln -s "$LOG_FILE" "$CURRENT_LOG_SYMLINK"
    
    # 保留最近的日志文件
    ls -t comfyui_*.log 2>/dev/null | tail -n +$((MAX_LOGS + 1)) | xargs rm -f 2>/dev/null || true
    
    cd - > /dev/null
}

# === 显示帮助 ===
show_help() {
    cat << EOF
RunPod ComfyUI 启动脚本 (带模型预热)

用法:
    $0 [选项]

选项:
    -h, --help              显示此帮助信息
    --skip-warmup           跳过模型预热
    --warmup-only           仅执行预热，不启动 ComfyUI
    --highvram              强制使用 --highvram 参数
    --lowvram               强制使用 --lowvram 参数

环境变量:
    COMFYUI_PATH            ComfyUI 安装路径 (默认: /workspace/ComfyUI)
    CACHE_PATH              本地缓存路径 (默认: /root/fast_cache)
    WARMUP_CONFIG           预热配置文件名 (默认: warmup_models.conf)
    SKIP_WARMUP             设为 1 跳过预热
    COMFYUI_ARGS            额外的 ComfyUI 启动参数

RunPod Template 配置示例:
    Docker Command: bash /workspace/ComfyUI-AutoCloud/runpod/start_with_warmup.sh
    
    或者使用环境变量:
    Environment Variables:
        WARMUP_CONFIG=my_models.conf
        COMFYUI_ARGS=--listen --highvram

EOF
}

# === 主函数 ===
main() {
    local warmup_only=0
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --skip-warmup)
                SKIP_WARMUP=1
                shift
                ;;
            --warmup-only)
                warmup_only=1
                shift
                ;;
            --highvram)
                COMFYUI_ARGS="$COMFYUI_ARGS --highvram"
                shift
                ;;
            --lowvram)
                COMFYUI_ARGS="$COMFYUI_ARGS --lowvram"
                shift
                ;;
            *)
                log_warning "未知参数: $1"
                shift
                ;;
        esac
    done
    
    log_header "RunPod ComfyUI 启动脚本"
    log_info "ComfyUI 路径: $COMFYUI_PATH"
    log_info "缓存路径: $CACHE_PATH"
    log_info "预热配置: $WARMUP_CONFIG"
    
    # 检查 ComfyUI 路径
    if [ ! -d "$COMFYUI_PATH" ]; then
        log_error "ComfyUI 目录不存在: $COMFYUI_PATH"
        exit 1
    fi
    
    # 终止其他脚本
    kill_running_scripts
    
    # 检测 GPU
    detect_gpu_and_set_args
    
    # 执行预热
    do_warmup
    
    if [ $warmup_only -eq 1 ]; then
        log_success "预热完成，退出 (--warmup-only)"
        exit 0
    fi
    
    # 切换到 ComfyUI 目录
    cd "$COMFYUI_PATH"
    
    # 管理日志
    mkdir -p logs
    manage_logs
    
    # 启动并监控
    monitor_and_restart
}

# 运行主函数
main "$@"

