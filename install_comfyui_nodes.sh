#!/bin/bash

# Stop script execution when an error occurs
set -e

echo "Starting installation of ComfyUI custom nodes..."

# Set ComfyUI installation directory
COMFYUI_DIR="$HOME/ComfyUI"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"

# Check if ComfyUI directory exists
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "Error: ComfyUI directory does not exist ($COMFYUI_DIR)"
    echo "Please install ComfyUI first"
    exit 1
fi

# Create custom_nodes directory (if it doesn't exist)
mkdir -p "$CUSTOM_NODES_DIR"
cd "$CUSTOM_NODES_DIR"

# Activate virtual environment
. "$COMFYUI_DIR/venv/bin/activate"

# Function to install or update a custom node
install_or_update_node() {
    local node_dir="$1"
    local repo_url="$2"
    
    echo "Installing/Updating $node_dir..."
    if [ -d "$CUSTOM_NODES_DIR/$node_dir" ]; then
        echo "$node_dir already exists, updating..."
        cd "$CUSTOM_NODES_DIR/$node_dir"
        git pull
        cd "$CUSTOM_NODES_DIR"
    else
        git clone "$repo_url"
    fi
    
    # Install dependencies if requirements.txt exists
    if [ -f "$CUSTOM_NODES_DIR/$node_dir/requirements.txt" ]; then
        echo "Installing dependencies for $node_dir..."
        pip install -r "$CUSTOM_NODES_DIR/$node_dir/requirements.txt"
    fi
}

# Install or update custom nodes
install_or_update_node "ComfyUI-Manager" "https://github.com/ltdrdata/ComfyUI-Manager"
install_or_update_node "comfyui-workspace-manager" "https://github.com/11cafe/comfyui-workspace-manager"
install_or_update_node "ComfyUI-WebhookNotifier" "https://github.com/iSuneast/ComfyUI-WebhookNotifier.git"
install_or_update_node "ComfyUI-Crystools" "https://github.com/crystian/ComfyUI-Crystools.git"

echo "ComfyUI custom nodes installation completed!"
echo "Please visit ComfyUI in your browser to confirm successful installation" 