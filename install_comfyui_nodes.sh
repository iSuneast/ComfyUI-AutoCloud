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
source "$COMFYUI_DIR/venv/bin/activate"

# Install custom nodes
echo "Installing ComfyUI-Manager..."
git clone https://github.com/ltdrdata/ComfyUI-Manager

echo "Installing comfyui-workspace-manager..."
git clone https://github.com/11cafe/comfyui-workspace-manager

echo "Installing ComfyUI-WebhookNotifier..."
git clone https://github.com/iSuneast/ComfyUI-WebhookNotifier.git

echo "Installing ComfyUI-Crystools..."
git clone https://github.com/crystian/ComfyUI-Crystools.git

# Install required dependencies
echo "Installing dependencies..."
if [ -f "$CUSTOM_NODES_DIR/ComfyUI-Manager/requirements.txt" ]; then
    pip install -r "$CUSTOM_NODES_DIR/ComfyUI-Manager/requirements.txt"
fi

if [ -f "$CUSTOM_NODES_DIR/comfyui-workspace-manager/requirements.txt" ]; then
    pip install -r "$CUSTOM_NODES_DIR/comfyui-workspace-manager/requirements.txt"
fi

if [ -f "$CUSTOM_NODES_DIR/ComfyUI-WebhookNotifier/requirements.txt" ]; then
    pip install -r "$CUSTOM_NODES_DIR/ComfyUI-WebhookNotifier/requirements.txt"
fi

if [ -f "$CUSTOM_NODES_DIR/ComfyUI-Crystools/requirements.txt" ]; then
    pip install -r "$CUSTOM_NODES_DIR/ComfyUI-Crystools/requirements.txt"
fi

echo "ComfyUI custom nodes installation completed!"
echo "Please visit ComfyUI in your browser to confirm successful installation" 