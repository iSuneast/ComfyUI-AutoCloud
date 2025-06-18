#!/bin/bash

# HTTP File Server for ComfyUI Directory
# This script starts an HTTP server to access ComfyUI folder via web browser

set -e

# Default configuration
DEFAULT_PORT=8888
DEFAULT_HOST="0.0.0.0"
COMFYUI_DIR="$HOME/ComfyUI"

# Function to display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT     Set server port (default: $DEFAULT_PORT)"
    echo "  -h, --host HOST     Set server host (default: $DEFAULT_HOST)"
    echo "  -d, --dir DIR       Set ComfyUI directory (default: $COMFYUI_DIR)"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                              # Start server with default settings"
    echo "  $0 -p 9000                      # Start server on port 9000"
    echo "  $0 -h 127.0.0.1 -p 8080        # Start server on localhost:8080"
    echo "  $0 -d /path/to/custom/comfyui   # Use custom ComfyUI directory"
}

# Function to check if port is available
check_port() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i :$port >/dev/null 2>&1; then
            echo "Warning: Port $port is already in use"
            return 1
        fi
    fi
    return 0
}

# Function to detect Python command
detect_python() {
    if command -v python3 >/dev/null 2>&1; then
        echo "python3"
    elif command -v python >/dev/null 2>&1; then
        echo "python"
    else
        echo "Error: Python is not installed or not in PATH"
        exit 1
    fi
}

# Parse command line arguments
PORT=$DEFAULT_PORT
HOST=$DEFAULT_HOST

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -d|--dir)
            COMFYUI_DIR="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate inputs
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "Error: Invalid port number. Port must be between 1 and 65535"
    exit 1
fi

# Check if ComfyUI directory exists
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "Error: ComfyUI directory does not exist: $COMFYUI_DIR"
    echo "Please make sure ComfyUI is installed or specify the correct directory with -d option"
    exit 1
fi

# Detect Python
PYTHON_CMD=$(detect_python)

# Check if port is available
check_port $PORT

echo "====================================="
echo "ComfyUI HTTP File Server"
echo "====================================="
echo "Directory: $COMFYUI_DIR"
echo "Server:    http://$HOST:$PORT"
echo "Python:    $PYTHON_CMD"
echo ""

# Check if we can access the directory
if [ ! -r "$COMFYUI_DIR" ]; then
    echo "Warning: Cannot read ComfyUI directory. Check permissions."
fi

echo "Starting HTTP server..."
echo "Access your ComfyUI files at: http://$HOST:$PORT"
echo "Press Ctrl+C to stop the server"
echo ""

# Change to ComfyUI directory and start server
cd "$COMFYUI_DIR"

# Remove any existing index.html that might interfere with directory listing
if [ -f "index.html" ] && [ ! -s "index.html" ]; then
    echo "Removing empty index.html to enable directory browsing..."
    rm -f "index.html"
fi

# Start the HTTP server
trap 'echo -e "\n\nShutting down HTTP server..."; exit 0' INT

if [ "$HOST" = "0.0.0.0" ]; then
    echo "Server accessible from:"
    echo "  - Local:    http://localhost:$PORT"
    echo "  - Network:  http://$(hostname -I | awk '{print $1}'):$PORT"
    echo ""
fi

echo "Directory listing will be automatically displayed."
echo "You can browse files and folders directly in your web browser."
echo ""

# Use Python's built-in HTTP server
$PYTHON_CMD -m http.server $PORT --bind $HOST 