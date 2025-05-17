#!/bin/bash

# Kill any running start.sh script first
kill_running_start_scripts() {
    echo "$(date): Looking for other running start.sh processes..."
    # Find and kill any other start.sh processes
    for pid in $(pgrep -f "start.sh" | grep -v $$); do
        echo "$(date): Killing existing start.sh process with PID: $pid"
        kill -15 $pid 2>/dev/null || kill -9 $pid 2>/dev/null || true
    done
    sleep 2
}

# Set variables
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="comfyui_${TIMESTAMP}.log"
CURRENT_LOG_SYMLINK="comfyui_current.log"
MAX_RESTARTS=5
RESTART_DELAY=10
MAX_LOGS=10
HEALTH_CHECK_INTERVAL=600  # Health check interval (seconds)
MAX_RESPONSE_TIME=30      # Maximum response time (seconds)
COMFYUI_PORT=8188         # ComfyUI default port

# Create log directory
mkdir -p logs

# Function: Clean up existing processes
cleanup_processes() {
    echo "$(date): Cleaning up existing ComfyUI processes..." | tee -a logs/$LOG_FILE
    pkill -f "python main.py" || true
    sleep 2
}

# Function: Start ComfyUI
start_comfyui() {
    echo "$(date): Starting ComfyUI service..." | tee -a logs/$LOG_FILE
    if [ -d "venv" ]; then
        if command -v source >/dev/null 2>&1; then
            source venv/bin/activate
        else
            . venv/bin/activate
        fi
    else
        echo "$(date): Warning: Virtual environment not found, continuing without activation" | tee -a logs/$LOG_FILE
    fi
    python main.py --listen --disable-metadata --disable-smart-memory >> logs/$LOG_FILE 2>&1
    return $?
}

# Function: Check if ComfyUI is responding
check_comfyui_health() {
    echo "$(date): Performing health check..." | tee -a logs/$LOG_FILE
    if timeout $MAX_RESPONSE_TIME curl -s "http://127.0.0.1:$COMFYUI_PORT/system_stats" > /dev/null; then
        echo "$(date): Health check passed" | tee -a logs/$LOG_FILE
        return 0
    else
        echo "$(date): Health check failed - service not responding" | tee -a logs/$LOG_FILE
        return 1
    fi
}

# Function: Monitor and auto-restart
monitor_and_restart() {
    restart_count=0
    
    while [ $restart_count -lt $MAX_RESTARTS ]; do
        # Clean up processes and start ComfyUI
        cleanup_processes
        start_comfyui &
        pid=$!
        
        echo "$(date): ComfyUI started, PID: $pid" | tee -a logs/$LOG_FILE
        
        # Wait for process to initialize (longer initial wait)
        echo "$(date): Waiting 120 seconds for ComfyUI to fully initialize..." | tee -a logs/$LOG_FILE
        sleep 120
        
        # Check if service is up after initial wait
        if check_comfyui_health; then
            echo "$(date): ComfyUI successfully started and responding" | tee -a logs/$LOG_FILE
        else
            echo "$(date): ComfyUI still starting up, will continue monitoring..." | tee -a logs/$LOG_FILE
        fi
        
        # Monitor process health
        while kill -0 $pid 2>/dev/null; do
            # Process is running, check health
            if ! check_comfyui_health; then
                echo "$(date): ComfyUI service is unresponsive, restarting..." | tee -a logs/$LOG_FILE
                kill $pid
                sleep 2
                if kill -0 $pid 2>/dev/null; then
                    echo "$(date): Process didn't terminate gracefully, forcing kill..." | tee -a logs/$LOG_FILE
                    kill -9 $pid
                fi
                break
            fi
            
            # Sleep before next health check
            sleep $HEALTH_CHECK_INTERVAL
        done
        
        # Check if process ended naturally
        if ! kill -0 $pid 2>/dev/null; then
            echo "$(date): ComfyUI exited abnormally" | tee -a logs/$LOG_FILE
        fi
        
        # Increment restart counter
        restart_count=$((restart_count + 1))
        echo "$(date): This is restart attempt $restart_count" | tee -a logs/$LOG_FILE
        
        if [ $restart_count -lt $MAX_RESTARTS ]; then
            echo "$(date): Waiting $RESTART_DELAY seconds before restarting..." | tee -a logs/$LOG_FILE
            sleep $RESTART_DELAY
        else
            echo "$(date): Reached maximum restart attempts $MAX_RESTARTS, giving up" | tee -a logs/$LOG_FILE
        fi
    done
}

# Manage log files: Keep only the most recent logs
manage_logs() {
    cd logs
    
    # Create symlink to current log for easy access
    if [ -L "$CURRENT_LOG_SYMLINK" ]; then
        rm "$CURRENT_LOG_SYMLINK"
    fi
    ln -s "$LOG_FILE" "$CURRENT_LOG_SYMLINK"
    
    # Keep only the most recent MAX_LOGS log files
    ls -t comfyui_*.log | tail -n +$((MAX_LOGS + 1)) | xargs rm -f 2>/dev/null || true
    
    cd ..
}

# Main function
main() {
    echo "$(date): Starting ComfyUI monitoring script" | tee -a logs/$LOG_FILE
    # Kill any running start.sh scripts first
    kill_running_start_scripts
    # Clean up existing ComfyUI processes
    cleanup_processes
    manage_logs
    monitor_and_restart
}

# Run main function
main

# To run this script in the background:
# nohup ./start.sh > /dev/null 2>&1 &
# To view current logs:
# tail -f logs/comfyui_current.log
