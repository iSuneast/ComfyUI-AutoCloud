#!/bin/bash

# ============================================================================
# RunPod Model Warmup Script
# RunPod 模型预热脚本
#
# 功能: 将高频使用的模型从慢速 Volume 存储复制到本地 NVMe SSD
#       以实现秒级模型加载和切换速度
#
# 原理:
#   1. 源路径 (慢): /workspace (RunPod Volume，网络存储)
#   2. 目标路径 (快): /root/fast_cache (Pod 本地 NVMe SSD)
#   3. Linux Page Cache: 复制后文件会被缓存到 RAM，加载速度可达内存级别
#
# 使用方法:
#   ./warmup.sh [配置文件]
#   ./warmup.sh                          # 使用默认配置
#   ./warmup.sh my_models.conf           # 使用自定义配置
#   ./warmup.sh /path/to/config.conf     # 使用完整路径配置
#
# 环境变量:
#   COMFYUI_PATH  - ComfyUI 安装路径 (默认: /workspace/ComfyUI)
#   CACHE_PATH    - 本地缓存路径 (默认: /root/fast_cache)
#   CONFIG_DIR    - 配置文件目录 (默认: 脚本所在目录)
# ============================================================================

set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 获取项目根目录 (脚本在 runpod 子目录下)
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# 获取项目同级目录
PROJECT_PARENT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"

# === 自动检测 ComfyUI 路径 ===
auto_detect_comfyui() {
    # 如果已设置环境变量且目录存在，直接返回
    if [ -n "$COMFYUI_PATH" ] && [ -d "$COMFYUI_PATH" ]; then
        return
    fi
    
    # 检测顺序：
    # 1. 默认 RunPod 路径: /workspace/ComfyUI
    # 2. 项目同级目录: ../ComfyUI (相对于项目根目录)
    
    local default_path="/workspace/ComfyUI"
    local sibling_path="$PROJECT_PARENT_DIR/ComfyUI"
    
    if [ -d "$default_path" ]; then
        COMFYUI_PATH="$default_path"
    elif [ -d "$sibling_path" ]; then
        COMFYUI_PATH="$sibling_path"
    else
        # 保持默认值，后续会在 check_environment 中报错
        COMFYUI_PATH="${COMFYUI_PATH:-/workspace/ComfyUI}"
    fi
}

# 执行自动检测
auto_detect_comfyui

# === 配置区域 ===
# 可通过环境变量覆盖
COMFYUI_PATH="${COMFYUI_PATH:-/workspace/ComfyUI}"
MODELS_SRC="${COMFYUI_PATH}/models"
CACHE_PATH="${CACHE_PATH:-/root/fast_cache}"
CONFIG_DIR="${CONFIG_DIR:-$SCRIPT_DIR}"
DEFAULT_CONFIG="warmup_models.conf"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 统计变量
TOTAL_FILES=0
COPIED_FILES=0
SKIPPED_FILES=0
FAILED_FILES=0
TOTAL_SIZE=0

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

# === 格式化文件大小 ===
format_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1073741824}")GB"
    elif [ $size -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1048576}")MB"
    elif [ $size -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1024}")KB"
    else
        echo "${size}B"
    fi
}

# === 获取文件大小 ===
get_file_size() {
    local file=$1
    if [ -f "$file" ]; then
        stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# === 检查运行环境 ===
check_environment() {
    log_header "检查运行环境"
    
    # 检查是否在 RunPod 环境
    if [ ! -d "/workspace" ]; then
        log_warning "未检测到 /workspace 目录，可能不是 RunPod 环境"
        log_info "继续执行，但请确保路径配置正确"
    fi
    
    # 检查 ComfyUI 路径
    if [ ! -d "$COMFYUI_PATH" ]; then
        log_error "ComfyUI 目录不存在: $COMFYUI_PATH"
        log_info "已尝试以下路径:"
        log_info "  - /workspace/ComfyUI (RunPod 默认路径)"
        log_info "  - $PROJECT_PARENT_DIR/ComfyUI (项目同级目录)"
        log_info "请设置 COMFYUI_PATH 环境变量指向正确路径"
        exit 1
    fi
    
    # 检查 models 目录
    if [ ! -d "$MODELS_SRC" ]; then
        log_error "Models 目录不存在: $MODELS_SRC"
        exit 1
    fi
    
    log_success "ComfyUI 路径: $COMFYUI_PATH"
    log_success "Models 源路径: $MODELS_SRC"
    log_success "缓存目标路径: $CACHE_PATH"
    
    # 显示磁盘空间信息
    log_info "磁盘空间信息:"
    if [ -d "/workspace" ]; then
        echo "  Volume (/workspace): $(df -h /workspace 2>/dev/null | tail -1 | awk '{print $4}') 可用"
    fi
    if [ -d "/root" ]; then
        echo "  Local NVMe (/root): $(df -h /root 2>/dev/null | tail -1 | awk '{print $4}') 可用"
    fi
}

# === 设置 extra_model_paths.yaml ===
setup_extra_model_paths() {
    log_header "配置 ComfyUI 额外模型路径"
    
    local yaml_file="$COMFYUI_PATH/extra_model_paths.yaml"
    local template_file="$CONFIG_DIR/extra_model_paths.yaml.template"
    
    # 每次都从模板更新，确保配置始终是最新的
    # 创建或更新配置文件
    if [ -f "$template_file" ]; then
        cp "$template_file" "$yaml_file"
        log_success "已从模板更新 extra_model_paths.yaml"
    else
        # 生成默认配置
        cat > "$yaml_file" << 'EOF'
# RunPod Local NVMe Cache Configuration
# Auto-generated by warmup.sh
runpod_local_nvme:
    base_path: /root/fast_cache
    checkpoints: checkpoints
    loras: loras
    vae: vae
    controlnet: controlnet
    upscale_models: upscale_models
    embeddings: embeddings
    clip: clip
    unet: unet
    diffusion_models: diffusion_models
    clip_vision: clip_vision
    style_models: style_models
    gligen: gligen
    hypernetworks: hypernetworks
    photomaker: photomaker
    instantid: instantid
    ipadapter: ipadapter
    insightface: insightface
    facerestore_models: facerestore_models
    ultralytics: ultralytics
    ultralytics_bbox: ultralytics/bbox
    ultralytics_segm: ultralytics/segm
    sams: sams
    onnx: onnx
    mmdets: mmdets
    mmdets_bbox: mmdets/bbox
    mmdets_segm: mmdets/segm
EOF
        log_success "已生成默认 extra_model_paths.yaml"
    fi
    
    # 替换缓存路径变量 (如果使用自定义路径)
    if [ "$CACHE_PATH" != "/root/fast_cache" ]; then
        sed -i "s|/root/fast_cache|$CACHE_PATH|g" "$yaml_file"
        log_info "已更新缓存路径为: $CACHE_PATH"
    fi
}

# === 生成备份文件路径 ===
# 将 xxx.safetensors 转换为 xxx.bak.safetensors
get_backup_path() {
    local file_path=$1
    local dir=$(dirname "$file_path")
    local filename=$(basename "$file_path")
    local extension="${filename##*.}"
    local basename="${filename%.*}"
    
    # 生成备份文件名: xxx.bak.safetensors
    echo "${dir}/${basename}.bak.${extension}"
}

# === 恢复备份文件 ===
# 如果源文件是断开的符号链接，尝试从备份恢复
restore_from_backup() {
    local src=$1
    local backup=$(get_backup_path "$src")
    
    # 检查源文件是否是断开的符号链接
    if [ -L "$src" ] && [ ! -e "$src" ]; then
        log_warning "检测到断开的符号链接: $src"
        
        # 删除断开的符号链接
        rm -f "$src"
        
        # 尝试从备份恢复
        if [ -f "$backup" ]; then
            log_info "从备份恢复: $backup"
            mv "$backup" "$src"
            return 0
        else
            log_error "备份文件不存在: $backup"
            return 1
        fi
    fi
    
    return 0
}

# === 创建符号链接 ===
# 将源文件替换为指向缓存的符号链接
create_symlink() {
    local src=$1
    local dest=$2
    local backup=$(get_backup_path "$src")
    
    # 如果源文件已经是指向正确目标的符号链接，跳过
    if [ -L "$src" ]; then
        local current_target=$(readlink "$src")
        if [ "$current_target" = "$dest" ]; then
            log_info "符号链接已存在且正确: $src -> $dest"
            return 0
        else
            # 符号链接指向错误目标，删除重建
            log_warning "符号链接目标不正确，重新创建"
            rm -f "$src"
        fi
    fi
    
    # 如果是普通文件，创建备份
    if [ -f "$src" ] && [ ! -L "$src" ]; then
        # 如果备份已存在，先删除旧备份
        if [ -f "$backup" ]; then
            log_info "删除旧备份: $backup"
            rm -f "$backup"
        fi
        
        log_info "创建备份: $backup"
        mv "$src" "$backup"
    fi
    
    # 创建符号链接
    ln -s "$dest" "$src"
    log_success "创建符号链接: $src -> $dest"
    
    return 0
}

# === 复制单个文件 ===
copy_file() {
    local relative_path=$1
    local src="$MODELS_SRC/$relative_path"
    local dest="$CACHE_PATH/$relative_path"
    local dest_dir=$(dirname "$dest")
    local backup=$(get_backup_path "$src")
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    # 步骤 1: 检查并恢复断开的符号链接
    if ! restore_from_backup "$src"; then
        log_error "无法恢复文件: $relative_path"
        FAILED_FILES=$((FAILED_FILES + 1))
        return 1
    fi
    
    # 步骤 2: 确定实际的源文件（可能是原文件或备份文件）
    local actual_src="$src"
    if [ -L "$src" ]; then
        # 如果是符号链接，检查备份文件是否存在
        if [ -f "$backup" ]; then
            actual_src="$backup"
        fi
    fi
    
    # 检查源文件是否存在
    if [ ! -f "$actual_src" ]; then
        log_warning "源文件不存在: $relative_path"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return 1
    fi
    
    # 获取文件大小
    local file_size=$(get_file_size "$actual_src")
    local size_str=$(format_size $file_size)
    
    # 步骤 3: 检查缓存文件是否已存在且相同
    if [ -f "$dest" ]; then
        local dest_size=$(get_file_size "$dest")
        if [ "$file_size" -eq "$dest_size" ]; then
            # 缓存已存在，确保符号链接正确
            if [ ! -L "$src" ]; then
                create_symlink "$src" "$dest"
            fi
            log_info "跳过已缓存: $relative_path ($size_str)"
            SKIPPED_FILES=$((SKIPPED_FILES + 1))
            return 0
        fi
    fi
    
    # 创建目标目录
    mkdir -p "$dest_dir"
    
    # 步骤 4: 复制文件到缓存
    log_info "正在复制: $relative_path ($size_str)..."
    
    local start_time=$(date +%s.%N)
    
    if cp "$actual_src" "$dest" 2>/dev/null; then
        local end_time=$(date +%s.%N)
        local duration=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
        local speed=$(awk "BEGIN {printf \"%.2f\", $file_size / $duration / 1048576}" 2>/dev/null || echo "N/A")
        
        log_success "复制完成: $relative_path (${duration}s, ${speed}MB/s)"
        COPIED_FILES=$((COPIED_FILES + 1))
        TOTAL_SIZE=$((TOTAL_SIZE + file_size))
        
        # 步骤 5: 创建符号链接
        create_symlink "$src" "$dest"
        
        return 0
    else
        log_error "复制失败: $relative_path"
        FAILED_FILES=$((FAILED_FILES + 1))
        return 1
    fi
}

# === 处理通配符模式 ===
expand_pattern() {
    local pattern=$1
    local dir=$(dirname "$pattern")
    local file_pattern=$(basename "$pattern")
    local src_dir="$MODELS_SRC/$dir"
    
    if [ ! -d "$src_dir" ]; then
        return
    fi
    
    # 使用 find 进行模式匹配
    find "$src_dir" -maxdepth 1 -name "$file_pattern" -type f 2>/dev/null | while read -r file; do
        local relative=$(echo "$file" | sed "s|$MODELS_SRC/||")
        echo "$relative"
    done
}

# === 解析配置文件 ===
parse_config() {
    local config_file=$1
    local files=()
    
    while IFS= read -r line || [ -n "$line" ]; do
        # 去除首尾空格
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # 跳过空行和注释
        if [ -z "$line" ] || [[ "$line" == \#* ]]; then
            continue
        fi
        
        # 检查是否包含通配符
        if [[ "$line" == *"*"* ]]; then
            # 展开通配符
            while IFS= read -r expanded; do
                if [ -n "$expanded" ]; then
                    echo "$expanded"
                fi
            done < <(expand_pattern "$line")
        else
            echo "$line"
        fi
    done < "$config_file"
}

# === 执行预热 ===
do_warmup() {
    local config_file=$1
    
    log_header "开始模型预热"
    log_info "配置文件: $config_file"
    
    # 重置统计
    TOTAL_FILES=0
    COPIED_FILES=0
    SKIPPED_FILES=0
    FAILED_FILES=0
    TOTAL_SIZE=0
    
    # 创建缓存根目录
    mkdir -p "$CACHE_PATH"
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 解析并处理每个文件
    while IFS= read -r file_path; do
        if [ -n "$file_path" ]; then
            copy_file "$file_path"
        fi
    done < <(parse_config "$config_file")
    
    # 计算总时间
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    # 显示统计信息
    log_header "预热完成统计"
    echo ""
    echo "  总文件数:   $TOTAL_FILES"
    echo "  已复制:     $COPIED_FILES"
    echo "  已跳过:     $SKIPPED_FILES"
    echo "  失败:       $FAILED_FILES"
    echo "  总大小:     $(format_size $TOTAL_SIZE)"
    echo "  耗时:       ${total_time}s"
    if [ $total_time -gt 0 ] && [ $TOTAL_SIZE -gt 0 ]; then
        local avg_speed=$(awk "BEGIN {printf \"%.2f\", $TOTAL_SIZE / $total_time / 1048576}" 2>/dev/null || echo "N/A")
        echo "  平均速度:   ${avg_speed}MB/s"
    fi
    echo ""
    
    # 显示缓存目录内容
    log_info "缓存目录内容:"
    if [ -d "$CACHE_PATH" ]; then
        find "$CACHE_PATH" -type f -exec ls -lh {} \; 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    fi
}

# === 清理缓存 ===
clean_cache() {
    log_header "清理本地缓存"
    
    if [ -d "$CACHE_PATH" ]; then
        local cache_size=$(du -sh "$CACHE_PATH" 2>/dev/null | cut -f1)
        log_info "当前缓存大小: $cache_size"
        
        rm -rf "$CACHE_PATH"
        mkdir -p "$CACHE_PATH"
        
        log_success "缓存已清理"
    else
        log_info "缓存目录不存在，无需清理"
    fi
}

# === 恢复所有备份文件 ===
# 将所有 .bak.safetensors 文件恢复为原始文件，删除符号链接
restore_backups() {
    log_header "恢复备份文件"
    
    local restored=0
    local symlinks_removed=0
    local errors=0
    
    # 查找所有 .bak. 备份文件
    log_info "扫描备份文件: $MODELS_SRC"
    
    while IFS= read -r backup_file; do
        if [ -z "$backup_file" ]; then
            continue
        fi
        
        # 计算原始文件路径: xxx.bak.safetensors -> xxx.safetensors
        local dir=$(dirname "$backup_file")
        local filename=$(basename "$backup_file")
        # 移除 .bak 部分
        local original_name=$(echo "$filename" | sed 's/\.bak\./\./')
        local original_file="${dir}/${original_name}"
        
        log_info "处理: $backup_file"
        
        # 删除符号链接（如果存在）
        if [ -L "$original_file" ]; then
            log_info "删除符号链接: $original_file"
            rm -f "$original_file"
            symlinks_removed=$((symlinks_removed + 1))
        elif [ -f "$original_file" ]; then
            log_warning "原始文件已存在且不是符号链接: $original_file"
            log_warning "跳过恢复，保留现有文件"
            continue
        fi
        
        # 恢复备份文件
        if mv "$backup_file" "$original_file" 2>/dev/null; then
            log_success "已恢复: $original_file"
            restored=$((restored + 1))
        else
            log_error "恢复失败: $backup_file"
            errors=$((errors + 1))
        fi
        
    done < <(find "$MODELS_SRC" -name "*.bak.*" -type f 2>/dev/null)
    
    # 显示统计
    log_header "恢复完成统计"
    echo ""
    echo "  已恢复文件:     $restored"
    echo "  已删除符号链接: $symlinks_removed"
    echo "  失败:           $errors"
    echo ""
    
    if [ $restored -eq 0 ] && [ $symlinks_removed -eq 0 ]; then
        log_info "没有找到需要恢复的备份文件"
    fi
}

# === 显示帮助 ===
show_help() {
    cat << EOF
RunPod Model Warmup Script - 模型预热脚本

用法:
    $0 [选项] [配置文件]

选项:
    -h, --help          显示此帮助信息
    -c, --clean         清理本地缓存
    -s, --status        显示缓存状态
    -l, --list          列出配置文件中的模型
    -r, --restore       恢复所有备份文件，删除符号链接
    --setup-only        仅配置 extra_model_paths.yaml，不复制文件

配置文件:
    如果不指定，默认使用 $CONFIG_DIR/$DEFAULT_CONFIG
    可以指定配置文件名 (从 runpod 目录) 或完整路径

环境变量:
    COMFYUI_PATH    ComfyUI 安装路径 (默认: /workspace/ComfyUI)
    CACHE_PATH      本地缓存路径 (默认: /root/fast_cache)
    CONFIG_DIR      配置文件目录 (默认: $SCRIPT_DIR)

预热机制说明:
    1. 模型文件被复制到本地 NVMe 高速缓存 ($CACHE_PATH)
    2. 原文件被重命名为 .bak.xxx (如 model.bak.safetensors)
    3. 创建符号链接指向缓存文件，ComfyUI 通过符号链接读取高速缓存
    4. Pod 重启后缓存丢失，再次运行预热脚本会自动恢复备份并重新预热

示例:
    $0                              # 使用默认配置预热
    $0 my_models.conf               # 使用自定义配置
    $0 --clean                      # 清理缓存
    $0 --status                     # 查看缓存状态
    $0 --restore                    # 恢复所有备份，删除符号链接
    CACHE_PATH=/tmp/cache $0        # 使用自定义缓存路径

EOF
}

# === 显示缓存状态 ===
show_status() {
    log_header "缓存状态"
    
    # 缓存目录状态
    if [ -d "$CACHE_PATH" ]; then
        local cache_size=$(du -sh "$CACHE_PATH" 2>/dev/null | cut -f1)
        local file_count=$(find "$CACHE_PATH" -type f 2>/dev/null | wc -l)
        
        echo "  缓存路径: $CACHE_PATH"
        echo "  总大小:   $cache_size"
        echo "  文件数:   $file_count"
        echo ""
        
        if [ $file_count -gt 0 ]; then
            log_info "缓存文件列表:"
            find "$CACHE_PATH" -type f -exec ls -lh {} \; 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
        fi
    else
        log_info "缓存目录不存在: $CACHE_PATH"
    fi
    
    # 符号链接和备份状态
    echo ""
    log_info "符号链接和备份状态:"
    if [ -d "$MODELS_SRC" ]; then
        local symlink_count=$(find "$MODELS_SRC" -type l 2>/dev/null | wc -l)
        local backup_count=$(find "$MODELS_SRC" -name "*.bak.*" -type f 2>/dev/null | wc -l)
        local broken_links=0
        
        # 统计断开的符号链接
        while IFS= read -r link; do
            if [ ! -e "$link" ]; then
                broken_links=$((broken_links + 1))
            fi
        done < <(find "$MODELS_SRC" -type l 2>/dev/null)
        
        echo "  符号链接数:     $symlink_count"
        echo "  断开的链接:     $broken_links"
        echo "  备份文件数:     $backup_count"
        
        if [ $broken_links -gt 0 ]; then
            echo ""
            log_warning "检测到 $broken_links 个断开的符号链接 (缓存可能已丢失)"
            log_info "运行预热脚本将自动恢复并重新缓存"
        fi
    fi
    
    # 显示磁盘空间
    echo ""
    log_info "磁盘空间:"
    if [ -d "/root" ]; then
        df -h /root 2>/dev/null | tail -1 | awk '{print "  Local (/root): " $3 " used, " $4 " free (" $5 " used)"}'
    fi
    if [ -d "/workspace" ]; then
        df -h /workspace 2>/dev/null | tail -1 | awk '{print "  Volume (/workspace): " $3 " used, " $4 " free (" $5 " used)"}'
    fi
}

# === 列出配置的模型 ===
list_models() {
    local config_file=$1
    
    log_header "配置的模型列表"
    log_info "配置文件: $config_file"
    echo ""
    echo "  图例: ✓=存在 🔗=已缓存(符号链接) 📦=有备份 ✗=不存在"
    echo ""
    
    local count=0
    local cached=0
    local backed_up=0
    
    while IFS= read -r file_path; do
        if [ -n "$file_path" ]; then
            local src="$MODELS_SRC/$file_path"
            local dest="$CACHE_PATH/$file_path"
            local backup=$(get_backup_path "$src")
            local status=""
            local size_str=""
            
            # 检查状态
            if [ -L "$src" ]; then
                # 是符号链接
                if [ -f "$dest" ]; then
                    local size=$(format_size $(get_file_size "$dest"))
                    status="🔗"
                    size_str="$size, 已缓存"
                    cached=$((cached + 1))
                else
                    status="⚠️"
                    size_str="符号链接断开"
                fi
                if [ -f "$backup" ]; then
                    status="${status}📦"
                    backed_up=$((backed_up + 1))
                fi
            elif [ -f "$src" ]; then
                local size=$(format_size $(get_file_size "$src"))
                status="✓"
                size_str="$size"
                # 检查是否有缓存
                if [ -f "$dest" ]; then
                    status="${status}🔗"
                    size_str="$size_str, 已缓存"
                    cached=$((cached + 1))
                fi
            else
                status="✗"
                size_str="不存在"
            fi
            
            echo "  [$status] $file_path ($size_str)"
            count=$((count + 1))
        fi
    done < <(parse_config "$config_file")
    
    echo ""
    log_info "统计: 共 $count 个模型, $cached 个已缓存, $backed_up 个有备份"
}

# === 主函数 ===
main() {
    local config_file=""
    local action="warmup"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                action="clean"
                shift
                ;;
            -s|--status)
                action="status"
                shift
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -r|--restore)
                action="restore"
                shift
                ;;
            --setup-only)
                action="setup"
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                config_file=$1
                shift
                ;;
        esac
    done
    
    # 确定配置文件路径
    if [ -z "$config_file" ]; then
        config_file="$CONFIG_DIR/$DEFAULT_CONFIG"
    elif [ ! -f "$config_file" ]; then
        # 尝试从 runpod 目录查找
        if [ -f "$CONFIG_DIR/$config_file" ]; then
            config_file="$CONFIG_DIR/$config_file"
        else
            log_error "配置文件不存在: $config_file"
            exit 1
        fi
    fi
    
    # 执行操作
    case $action in
        warmup)
            check_environment
            setup_extra_model_paths
            do_warmup "$config_file"
            ;;
        clean)
            clean_cache
            ;;
        status)
            show_status
            ;;
        list)
            check_environment
            list_models "$config_file"
            ;;
        restore)
            check_environment
            restore_backups
            ;;
        setup)
            check_environment
            setup_extra_model_paths
            log_success "配置完成，extra_model_paths.yaml 已就绪"
            ;;
    esac
}

# 运行主函数
main "$@"

