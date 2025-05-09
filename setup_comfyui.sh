#!/bin/bash

# Stop execution on error
set -e

# Function to run the installation process
run_installation() {
    echo "Starting ComfyUI installation..."

    # Set installation directory to Home directory
    INSTALL_DIR="$HOME"
    cd $INSTALL_DIR

    # Check if ComfyUI directory already exists
    if [ -d "ComfyUI" ]; then
        echo "ComfyUI already exists. Updating..."
        cd ComfyUI
        git pull
    else
        # Clone ComfyUI repository
        echo "Cloning ComfyUI repository..."
        git clone https://github.com/comfyanonymous/ComfyUI.git
        cd ComfyUI
    fi

    # Create and activate virtual environment
    echo "Setting up Python virtual environment..."
    python3 -m venv venv
    . ./venv/bin/activate

    # Install ComfyUI dependencies
    echo "Installing ComfyUI dependencies..."
    pip install -r requirements.txt

    echo "ComfyUI installation completed!"
    echo "To run ComfyUI, navigate to $INSTALL_DIR/ComfyUI, activate the virtual environment, and run:"
    echo ". ./venv/bin/activate && python main.py --listen 0.0.0.0 --port 8188"
    echo "Access address: http://[YOUR_SERVER_IP]:8188"
}

# Run the installation directly (not in background)
run_installation 