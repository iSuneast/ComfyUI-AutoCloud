#!/bin/bash

# Quick start script for ComfyUI HTTP File Server
# This script provides easy access to start the HTTP server for ComfyUI files

echo "🚀 ComfyUI HTTP File Server - Quick Start"
echo "============================================="

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTTP_SERVER_SCRIPT="$SCRIPT_DIR/scripts/http_server.sh"

# Check if the http_server.sh script exists
if [ ! -f "$HTTP_SERVER_SCRIPT" ]; then
    echo "Error: HTTP server script not found at $HTTP_SERVER_SCRIPT"
    exit 1
fi

# Check if user provided any arguments
if [ $# -eq 0 ]; then
    echo "Starting HTTP server with default settings..."
    echo "Default: http://localhost:8080"
    echo ""
    echo "💡 Tip: You can also use custom options:"
    echo "   $0 -p 9000           # Custom port"
    echo "   $0 -h 127.0.0.1      # Localhost only"
    echo "   $0 --help            # Show all options"
    echo ""
    
    # Start with default settings
    exec "$HTTP_SERVER_SCRIPT"
else
    # Pass all arguments to the http_server.sh script
    exec "$HTTP_SERVER_SCRIPT" "$@"
fi 