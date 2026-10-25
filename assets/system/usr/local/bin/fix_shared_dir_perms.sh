#!/usr/bin/env bash
# fix_shared_dir_perms.sh
# Repairs permissions for /z and accepts an explicit target from a watcher.
DEFAULT_SHARED_DIR="/z"
DEFAULT_GROUP="wheel"
SHARED_DIR="${1:-$DEFAULT_SHARED_DIR}"
GROUP="${2:-$DEFAULT_GROUP}"
find "$SHARED_DIR" ! -group "$GROUP" -exec chown :"$GROUP" {} + 2>/dev/null
find "$SHARED_DIR" -type f ! -perm -g=rwx -exec chmod g+rwx {} + 2>/dev/null
find "$SHARED_DIR" -type d ! -perm -g=rwxs -exec chmod g+rwxs {} + 2>/dev/null
setfacl -d -R -m g:"$GROUP":rwx "$SHARED_DIR" 2>/dev/null
