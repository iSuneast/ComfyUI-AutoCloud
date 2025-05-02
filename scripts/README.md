# ComfyUI Scripts

## start.sh

The `start.sh` script provides automated startup, monitoring, and auto-restart functionality for ComfyUI.

### Important Parameters

- `--listen`: Enables ComfyUI to listen on all network interfaces (0.0.0.0) instead of just localhost, allowing remote connections to access the UI and API.

- `--disable-metadata`: Prevents ComfyUI from embedding metadata in generated images, which can improve performance and reduce file sizes.

- `--disable-smart-memory`: This flag is enabled by default to prevent Out-of-Memory (OOM) errors when using the ComfyUI API. While the ComfyUI web interface works normally without this flag, API calls may experience OOM issues due to differences in memory management between web interface usage and API usage.

### Why it's needed

When using the ComfyUI API programmatically:
- The web interface efficiently reuses VRAM when running workflows
- API calls may not properly release VRAM between calls without this flag
- This can lead to OOM errors after several API calls even when the same workflow runs fine in the web UI

### Usage

```bash
# Start ComfyUI with monitoring
./start.sh

# Run in background
nohup ./start.sh > /dev/null 2>&1 &

# View logs
tail -f logs/comfyui_current.log
```

Reference: [ComfyUI Issue #5951](https://github.com/comfyanonymous/ComfyUI/issues/5951)
