#!/bin/bash

# Stop execution on error
set -e

echo "Starting ComfyUI service installation..."

# Set installation directory to Home directory
INSTALL_DIR="$HOME"
cd $INSTALL_DIR

# Clone ComfyUI repository
echo "Cloning ComfyUI repository..."
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install ComfyUI dependencies
echo "Installing ComfyUI dependencies..."
pip install -r requirements.txt

# Configure ComfyUI as a system service
echo "Configuring ComfyUI as a system service..."
sudo bash -c "cat > /etc/systemd/system/comfyui.service << EOL
[Unit]
Description=ComfyUI Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/ComfyUI
ExecStart=$INSTALL_DIR/ComfyUI/venv/bin/python main.py --listen 0.0.0.0 --port 8188
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL"

# Enable and start service
echo "Enabling and starting ComfyUI service..."
sudo systemctl daemon-reload
sudo systemctl enable comfyui
sudo systemctl start comfyui

echo "ComfyUI installation completed, service is running!"
echo "Access address: http://[YOUR_SERVER_IP]:8188"
echo "To check service status, run: sudo systemctl status comfyui" 