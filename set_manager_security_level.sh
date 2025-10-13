#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/ComfyUI/user/default/ComfyUI-Manager/config.ini"
TARGET_VALUE="strong"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config.ini not found at $CONFIG_FILE" >&2
  exit 1
fi

backup="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONFIG_FILE" "$backup"
echo "Backup created at $backup"

tmp="$(mktemp)"
awk -v target="$TARGET_VALUE" '
BEGIN { found=0 }
{
  if ($0 ~ /^[[:space:]]*[#;]/) { print; next }
  if ($0 ~ /^[[:space:]]*security_level[[:space:]]*=/) {
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)
    print indent "security_level = " target
    found=1
    next
  }
  print
}
END {
  if (found == 0) {
    print ""
    print "# Added by set_manager_security_level.sh"
    print "security_level = " target
  }
}
' "$CONFIG_FILE" > "$tmp"

mv "$tmp" "$CONFIG_FILE"
echo "Updated security_level to $TARGET_VALUE in $CONFIG_FILE"




