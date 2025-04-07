#!/bin/bash

# Stop execution on error
set -e

# Set log file
LOG_FILE="/tmp/comfyui_setup.log"

# Function to run the installation process
run_installation() {
    echo "Starting ComfyUI installation..." | tee -a $LOG_FILE

    # Set installation directory to Home directory
    INSTALL_DIR="$HOME"
    cd $INSTALL_DIR

    # Check if ComfyUI directory already exists
    if [ -d "ComfyUI" ]; then
        echo "ComfyUI already exists. Updating..." | tee -a $LOG_FILE
        cd ComfyUI
        git pull >> $LOG_FILE 2>&1
    else
        # Clone ComfyUI repository
        echo "Cloning ComfyUI repository..." | tee -a $LOG_FILE
        git clone https://github.com/comfyanonymous/ComfyUI.git >> $LOG_FILE 2>&1
        cd ComfyUI
    fi

    # Create and activate virtual environment
    echo "Setting up Python virtual environment..." | tee -a $LOG_FILE
    python3 -m venv venv >> $LOG_FILE 2>&1
    source venv/bin/activate

    # Install ComfyUI dependencies
    echo "Installing ComfyUI dependencies..." | tee -a $LOG_FILE
    pip install -r requirements.txt >> $LOG_FILE 2>&1

    echo "ComfyUI installation completed!" | tee -a $LOG_FILE
    echo "To run ComfyUI, navigate to $INSTALL_DIR/ComfyUI, activate the virtual environment, and run:" | tee -a $LOG_FILE
    echo "source venv/bin/activate && python main.py --listen 0.0.0.0 --port 8188" | tee -a $LOG_FILE
    echo "Access address: http://[YOUR_SERVER_IP]:8188" | tee -a $LOG_FILE
}

# Run the installation in the background
run_installation &

# Display the log in real-time
echo "ComfyUI installation is running in the background. Displaying logs in real-time:"
echo "Log file location: $LOG_FILE"
tail -f $LOG_FILE 