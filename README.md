# ComfyUI Node Installer

这个仓库包含用于安装和更新 ComfyUI 自定义节点的脚本。

## 文件说明

- `install_comfyui_nodes.sh`: 主安装脚本
- `config/`: 配置文件目录
  - `basic_nodes.conf`: 基础节点配置文件
  - `advanced_nodes.conf`: 高级节点配置文件

## 使用方法

### 安装基础节点

```bash
./install_comfyui_nodes.sh
```

或者

```bash
./install_comfyui_nodes.sh basic_nodes.conf
```

### 安装高级节点

```bash
./install_comfyui_nodes.sh advanced_nodes.conf
```

### 安装自定义节点列表

你可以创建自己的配置文件：

1. 在 `config/` 目录中创建一个新的配置文件，如 `config/my_nodes.conf`
2. 运行脚本并指定配置文件名：
   ```bash
   ./install_comfyui_nodes.sh my_nodes.conf
   ```

3. 也可以使用完整路径：
   ```bash
   ./install_comfyui_nodes.sh /path/to/your/custom_config.conf
   ```

## 配置文件格式

配置文件的格式很简单，每行一个 Git 仓库 URL。例如：

```
https://github.com/ltdrdata/ComfyUI-Manager
https://github.com/11cafe/comfyui-workspace-manager
# 这是一个注释行，会被忽略
https://github.com/iSuneast/ComfyUI-WebhookNotifier.git
```

可以使用 `#` 添加注释行，空行会被忽略。

## HTTP 文件服务器

本项目还提供了一个HTTP文件服务器，可以通过浏览器访问ComfyUI文件夹中的所有文件。

### 快速启动

```bash
./start_http_server.sh
```

默认设置下，服务器会在 `http://localhost:8080` 启动，提供对 `~/ComfyUI` 目录的访问。

### 自定义选项

```bash
# 使用自定义端口
./start_http_server.sh -p 9000

# 只允许本地访问
./start_http_server.sh -h 127.0.0.1

# 使用自定义ComfyUI目录
./start_http_server.sh -d /path/to/your/comfyui

# 查看所有选项
./start_http_server.sh --help
```

### 直接使用HTTP服务器脚本

你也可以直接使用完整的HTTP服务器脚本：

```bash
./scripts/http_server.sh [选项]
```

### 功能特点

- 🌐 通过浏览器访问ComfyUI文件夹
- 📁 支持文件和目录浏览
- ⚙️ 可配置端口和主机地址
- 🔒 包含安全提示和端口检查
- 📱 响应式界面，支持移动设备
- 🐍 使用Python内置HTTP服务器（无需额外依赖）

### 安全提示

- 仅在安全的网络环境中使用
- 不使用时请及时停止服务器（Ctrl+C）
- 如需公网访问，请配置适当的防火墙规则

## RunPod 模型预热

针对 RunPod 生产环境的模型预热功能，通过将高频使用的模型从慢速 Volume 存储复制到本地 NVMe SSD，实现秒级模型加载。

详细文档请查看 [runpod/README.md](runpod/README.md)

### 快速开始

```bash
# 在 RunPod Template 中配置启动命令
bash /workspace/ComfyUI-AutoCloud/runpod/start_with_warmup.sh
```