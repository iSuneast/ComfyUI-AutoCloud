#!/bin/bash

# Stop script execution when an error occurs
set -e

# Set config directory
CONFIG_DIR="$(dirname "$0")/config"

# Default config is basic nodes
CONFIG_FILE="$CONFIG_DIR/basic_nodes.conf"

# Check if a config file was specified as argument
if [ "$1" != "" ]; then
    # Check if it's a relative path without directory
    if [[ "$1" != *"/"* ]]; then
        CONFIG_FILE="$CONFIG_DIR/$1"
    else
        CONFIG_FILE="$1"
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not found: $CONFIG_FILE"
        exit 1
    fi
fi

echo "Starting installation of ComfyUI nodes from config: $(basename "$CONFIG_FILE")..."

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

# Update pip to latest version
echo "Updating pip to latest version..."
pip install --upgrade pip

# Function to install or update a custom node
install_or_update_node() {
    local repo_url="$1"
    local node_dir=$(basename "$repo_url" .git)
    
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

# Read the config file line by line and install each node
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and lines starting with #
    if [[ -z "$line" || "$line" == \#* ]]; then
        continue
    fi
    install_or_update_node "$line"
done < "$CONFIG_FILE"

echo "ComfyUI nodes installation completed!"
echo "Please restart ComfyUI to load the new nodes" 