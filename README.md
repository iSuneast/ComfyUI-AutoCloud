# ComfyUI-AutoCloud

Automatically deploy ComfyUI on Google Cloud servers.

## Setup Instructions

1. Connect to your Google Cloud server via SSH
2. Clone this repository:
   ```
   git clone https://github.com/iSuneast/ComfyUI-AutoCloud.git
   cd ComfyUI-AutoCloud
   ```
3. Make the setup script executable:
   ```
   chmod +x setup_comfyui.sh
   ```
4. Run the setup script:
   ```
   ./setup_comfyui.sh
   ```
   Note: This will install ComfyUI directly in your home directory (~/).
   
   **Important**: This script assumes that you already have the necessary system dependencies (git, python3, python3-pip, python3-venv, ffmpeg, libgl1-mesa-glx) and PyTorch installed on your system.
   
5. Once installation completes, ComfyUI will be available at:
   ```
   http://[YOUR_SERVER_IP]:8188
   ```

## Managing the ComfyUI Service

- Check service status:
  ```
  sudo systemctl status comfyui
  ```
- Stop the service:
  ```
  sudo systemctl stop comfyui
  ```
- Start the service:
  ```
  sudo systemctl start comfyui
  ```
- Restart the service:
  ```
  sudo systemctl restart comfyui
  ```
- View service logs:
  ```
  sudo journalctl -u comfyui
  ``` 