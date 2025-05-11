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