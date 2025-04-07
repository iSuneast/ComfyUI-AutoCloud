#!/bin/bash

# Stop execution on error
set -e

# Set log file
LOG_FILE="/tmp/comfyui_setup.log"

# Function to run the installation process
run_installation() {
    echo "Starting ComfyUI service installation..." | tee -a $LOG_FILE

    # Set installation directory to Home directory
    INSTALL_DIR="$HOME"
    cd $INSTALL_DIR

    # Clone ComfyUI repository
    echo "Cloning ComfyUI repository..." | tee -a $LOG_FILE
    git clone https://github.com/comfyanonymous/ComfyUI.git >> $LOG_FILE 2>&1
    cd ComfyUI

    # Create and activate virtual environment
    echo "Setting up Python virtual environment..." | tee -a $LOG_FILE
    python3 -m venv venv >> $LOG_FILE 2>&1
    source venv/bin/activate

    # Install ComfyUI dependencies
    echo "Installing ComfyUI dependencies..." | tee -a $LOG_FILE
    pip install -r requirements.txt >> $LOG_FILE 2>&1

    # Configure ComfyUI as a system service
    echo "Configuring ComfyUI as a system service..." | tee -a $LOG_FILE
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
EOL" >> $LOG_FILE 2>&1

    # Enable and start service
    echo "Enabling and starting ComfyUI service..." | tee -a $LOG_FILE
    sudo systemctl daemon-reload >> $LOG_FILE 2>&1
    sudo systemctl enable comfyui >> $LOG_FILE 2>&1
    sudo systemctl start comfyui >> $LOG_FILE 2>&1

    echo "ComfyUI installation completed, service is running!" | tee -a $LOG_FILE
    echo "Access address: http://[YOUR_SERVER_IP]:8188" | tee -a $LOG_FILE
    echo "To check service status, run: sudo systemctl status comfyui" | tee -a $LOG_FILE
}

# Run the installation in the background
run_installation &

# Display the log in real-time
echo "ComfyUI installation is running in the background. Displaying logs in real-time:"
echo "Log file location: $LOG_FILE"
tail -f $LOG_FILE 