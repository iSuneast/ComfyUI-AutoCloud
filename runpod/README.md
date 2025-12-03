# RunPod 模型预热 (Model Warmup)

针对 RunPod 生产环境的模型预热功能，通过将高频使用的模型从慢速 Volume 存储复制到本地 NVMe SSD，实现秒级模型加载。

## 核心原理

| 存储类型 | 路径 | 速度 | 特点 |
|---------|------|------|------|
| Volume (网络存储) | `/workspace` | 慢 | 持久化，重启不丢失 |
| Local NVMe SSD | `/root/fast_cache` | 快 | 临时，重启后清空 |

预热脚本会在 ComfyUI 启动前，将配置的模型复制到本地高速存储，并配置 ComfyUI 优先从本地加载。

## 快速开始

**1. 配置预热模型列表**

编辑 `warmup_models.conf`，添加需要预热的模型：

```bash
# 主模型
checkpoints/flux1-dev-fp8.safetensors
checkpoints/sdxl_juggernaut_v9.safetensors

# LoRA
loras/my_style_lora.safetensors

# ControlNet
controlnet/controlnet-canny-sdxl-1.0.safetensors
```

**2. 在 RunPod Template 中配置启动命令**

```bash
bash /workspace/ComfyUI-AutoCloud/runpod/start_with_warmup.sh
```

## 脚本说明

### `warmup.sh` - 预热脚本

独立的模型预热脚本，可单独使用：

```bash
# 使用默认配置预热
./warmup.sh

# 使用自定义配置
./warmup.sh my_models.conf

# 查看缓存状态
./warmup.sh --status

# 清理缓存
./warmup.sh --clean

# 列出配置的模型
./warmup.sh --list

# 仅配置 extra_model_paths.yaml
./warmup.sh --setup-only
```

### `start_with_warmup.sh` - 带预热的启动脚本

完整的 ComfyUI 启动脚本，包含预热、自动重启和健康检查：

```bash
# 正常启动（包含预热）
./start_with_warmup.sh

# 跳过预热
./start_with_warmup.sh --skip-warmup

# 仅执行预热
./start_with_warmup.sh --warmup-only

# 高显存模式
./start_with_warmup.sh --highvram

# 低显存模式
./start_with_warmup.sh --lowvram
```

## 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `COMFYUI_PATH` | `/workspace/ComfyUI` | ComfyUI 安装路径 |
| `CACHE_PATH` | `/root/fast_cache` | 本地缓存路径 |
| `WARMUP_CONFIG` | `warmup_models.conf` | 预热配置文件名 |
| `SKIP_WARMUP` | `0` | 设为 `1` 跳过预热 |
| `COMFYUI_ARGS` | `--listen --disable-metadata` | ComfyUI 启动参数 |

## 配置文件格式

`warmup_models.conf` 格式：

```bash
# 注释以 # 开头
# 格式: <类型>/<文件名>

# 支持的类型对应 models 目录下的子文件夹
checkpoints/model.safetensors
loras/lora.safetensors
vae/vae.safetensors
controlnet/controlnet.safetensors

# 支持通配符
checkpoints/sdxl_*.safetensors
```

支持的模型类型：
- `checkpoints` - 主模型
- `loras` - LoRA 模型
- `vae` - VAE 模型
- `controlnet` - ControlNet 模型
- `upscale_models` - 放大模型
- `embeddings` - 嵌入模型
- `clip` - CLIP 模型
- `unet` - UNet 模型
- `diffusion_models` - 扩散模型
- 以及更多...

## 最佳实践

1. **只预热高频模型** - 不要复制所有模型，只复制 API 最常用的
2. **优先使用 FP8 模型** - 体积小，复制快
   - SDXL FP16 (6.5GB) → 复制需 25-40秒
   - SDXL FP8 (2.5GB) → 复制需 10-15秒
3. **合理预期启动时间** - 预热会增加 1-2 分钟启动时间，但换来运行时秒级加载
4. **利用 Linux Page Cache** - 复制后文件会被缓存到 RAM，实现内存级加载速度

## 文件结构

```
runpod/
├── README.md                       # 本文档
├── warmup_models.conf              # 预热模型配置
├── extra_model_paths.yaml.template # ComfyUI 额外路径模板
├── warmup.sh                       # 预热脚本
└── start_with_warmup.sh            # 带预热的启动脚本
```

## RunPod Template 配置示例

**Docker Command:**

```bash
bash /workspace/ComfyUI-AutoCloud/runpod/start_with_warmup.sh
```

**Environment Variables (可选):**

```
WARMUP_CONFIG=my_models.conf
COMFYUI_ARGS=--listen --highvram
SKIP_WARMUP=0
```

## 性能对比

| 指标 | 不使用预热 | 使用预热 |
|------|-----------|---------|
| 模型加载速度 | 30-60秒 | 1-3秒 |
| Pod 启动时间 | 较短 | +1-2分钟 |
| API 响应延迟 | 高 | 低 |
| 模型切换速度 | 慢 | 快 |

## 故障排除

### 预热脚本找不到模型

确保模型路径正确，路径格式为 `<类型>/<文件名>`，相对于 ComfyUI 的 `models` 目录。

```bash
# 查看配置的模型是否存在
./warmup.sh --list
```

### 缓存空间不足

检查本地磁盘空间：

```bash
./warmup.sh --status
```

清理缓存释放空间：

```bash
./warmup.sh --clean
```

### ComfyUI 没有从缓存加载模型

确保 `extra_model_paths.yaml` 已正确配置：

```bash
./warmup.sh --setup-only
cat /workspace/ComfyUI/extra_model_paths.yaml
```

