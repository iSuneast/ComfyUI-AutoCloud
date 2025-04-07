#!/bin/bash

# Stop script execution when an error occurs
set -e

echo "Starting ComfyUI script setup..."

# Set ComfyUI installation directory
COMFYUI_DIR="$HOME/ComfyUI"
SOURCE_SCRIPT="scripts/start.sh"

# Check if ComfyUI directory exists
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "Error: ComfyUI directory does not exist ($COMFYUI_DIR)"
    echo "Please install ComfyUI first"
    exit 1
fi

# Check if source script exists
if [ ! -f "$SOURCE_SCRIPT" ]; then
    echo "Error: Source script does not exist ($SOURCE_SCRIPT)"
    exit 1
fi

# Copy the script to ComfyUI directory
echo "Copying $SOURCE_SCRIPT to $COMFYUI_DIR..."
cp "$SOURCE_SCRIPT" "$COMFYUI_DIR/"

# Make the script executable
echo "Making script executable..."
chmod +x "$COMFYUI_DIR/start.sh"

# Run the script
echo "Running start.sh..."
cd "$COMFYUI_DIR"
./start.sh

echo "Script execution completed!" 