#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/ComfyUI/user/default/ComfyUI-Manager/config.ini"
TARGET_VALUE="strong"
MODE="set"

usage() {
  echo "Usage: $0 [--restore] [--value <level>|--set <level>|-v <level>|<level>]"
  echo "  No args: set security_level to 'strong'"
  echo "  --restore: clear security_level value (set to empty)"
  echo "  --value|--set|-v <level> or positional <level>: set specific level"
}

# Parse arguments
if [[ $# -gt 0 ]]; then
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --restore)
      MODE="restore"
      shift
      ;;
    --value|--set|-v)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: missing value for --value" >&2
        usage
        exit 1
      fi
      TARGET_VALUE="$1"
      shift
      ;;
    *)
      TARGET_VALUE="$1"
      shift
      ;;
  esac
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config.ini not found at $CONFIG_FILE" >&2
  exit 1
fi

if [[ "$MODE" == "restore" ]]; then
  tmp="$(mktemp)"
  awk -v target="" '
BEGIN { found=0 }
{
  if ($0 ~ /^[[:space:]]*[#;]/) { print; next }
  if ($0 ~ /^[[:space:]]*security_level[[:space:]]*=/) {
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)
    # no trailing value when target is empty
    print indent "security_level =" (length(target) ? " " target : "")
    found=1
    next
  }
  print
}
END {
  if (found == 0) {
    print ""
    print "# Added by set_manager_security_level.sh"
    if (length(target)) {
      print "security_level = " target
    } else {
      print "security_level ="
    }
  }
}
' "$CONFIG_FILE" > "$tmp"
  mv "$tmp" "$CONFIG_FILE"
  echo "Cleared security_level in $CONFIG_FILE"
  exit 0
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
    print indent "security_level =" (length(target) ? " " target : "")
    found=1
    next
  }
  print
}
END {
  if (found == 0) {
    print ""
    print "# Added by set_manager_security_level.sh"
    if (length(target)) {
      print "security_level = " target
    } else {
      print "security_level ="
    }
  }
}
' "$CONFIG_FILE" > "$tmp"

mv "$tmp" "$CONFIG_FILE"
echo "Updated security_level to $TARGET_VALUE in $CONFIG_FILE"




