#!/usr/bin/env bash
# fix_shared_dir_perms.sh
# Repairs permissions for /z-drive and accepts an explicit target from a watcher.
DEFAULT_SHARED_DIR="/z-drive"
DEFAULT_GROUP="wheel"
SHARED_DIR="${1:-$DEFAULT_SHARED_DIR}"
GROUP="${2:-$DEFAULT_GROUP}"

# Use -xdev and prune cloud mount to avoid traversing FUSE / network filesystems
find "$SHARED_DIR" -xdev -path "$SHARED_DIR/cloud" -prune -o ! -group "$GROUP" -exec chown :"$GROUP" {} + 2>/dev/null || true
find "$SHARED_DIR" -xdev -path "$SHARED_DIR/cloud" -prune -o -type f ! -perm -g=rwx -exec chmod g+rwx {} + 2>/dev/null || true
find "$SHARED_DIR" -xdev -path "$SHARED_DIR/cloud" -prune -o -type d ! -perm -g=rwxs -exec chmod g+rwxs {} + 2>/dev/null || true
find "$SHARED_DIR" -xdev -path "$SHARED_DIR/cloud" -prune -o -type d -exec setfacl -d -m g:"$GROUP":rwx {} + 2>/dev/null || true
exit 0
