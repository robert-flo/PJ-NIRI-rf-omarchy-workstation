#!/usr/bin/env bash
# z-perms_watcher.sh
SHARED_DIR="/z"
FIX_SCRIPT="/usr/local/bin/fix_shared_dir_perms.sh"
GROUP="wheel"
"$FIX_SCRIPT" "$SHARED_DIR" "$GROUP"
while true; do
  inotifywait -r -e create,modify,move,attrib --exclude ".git" "$SHARED_DIR" 2>/dev/null || true
  sleep 0.1
  "$FIX_SCRIPT" "$SHARED_DIR" "$GROUP"
done
