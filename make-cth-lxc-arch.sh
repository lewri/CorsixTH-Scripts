#!/bin/bash
CONTAINER_NAME="corsixth-appimage-build"

# Safely stop and destroy existing container (if applicable)
if [ -d "/var/lib/lxc/$CONTAINER_NAME" ]; then
  # Check if container is running
  if lxc-info -n "$CONTAINER_NAME" | grep -q RUNNING; then
    echo "➜ Stopping running container..."
    lxc-stop -n "$CONTAINER_NAME" || true
  fi
  echo "➜ Destroying existing container..."
  lxc-destroy -n "$CONTAINER_NAME" || true
fi

# Create fresh container
# jammy for 22.04, noble for 24.04, resolute for 26.04, stonking for 26.10
echo "➜ Creating new container..."
lxc-create -n "$CONTAINER_NAME" -t download -- \
  --dist ubuntu \
  --release stonking \
  --arch amd64

# Add FUSE configuration
echo "➜ Configuring FUSE access..."
cat >> "/var/lib/lxc/$CONTAINER_NAME/config" << EOT
# Allow FUSE device (Updated for cgroup v2)
lxc.cgroup2.devices.allow = c 10:229 rwm
lxc.mount.entry = /dev/fuse dev/fuse none bind,optional,create=file
EOT

# Inject build script
echo "➜ Injecting build script..."
SCRIPT_PATH="/var/lib/lxc/$CONTAINER_NAME/rootfs/corsixth-appimage-sdl3.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/corsixth-appimage-sdl3.sh" ]; then
  cp "$SCRIPT_DIR/corsixth-appimage-sdl3.sh" "$SCRIPT_PATH"
else
  wget -q https://raw.githubusercontent.com/lewri/CorsixTH-Scripts/refs/heads/main/corsixth-appimage-sdl3.sh -O "$SCRIPT_PATH"
fi
chmod +x "$SCRIPT_PATH"

# Start container and attach
echo "➜ Starting container..."
lxc-start -n "$CONTAINER_NAME"

echo "➜ Attaching to container..."
echo "   Run the build script with: ./corsixth-appimage-sdl3.sh"
lxc-attach -n "$CONTAINER_NAME"

# Determine user 1000 home and destination directory
TARGET_USER="$(getent passwd 1000 | cut -d: -f1)"
TARGET_HOME="$(getent passwd 1000 | cut -d: -f6)"
TARGET_DIR="${TARGET_HOME}/Desktop"
if [ ! -d "$TARGET_DIR" ]; then
  TARGET_DIR="$TARGET_HOME"
fi

if [ -n "$TARGET_DIR" ] && [ -d "$TARGET_DIR" ]; then
  echo "➜ Copying AppImage to $TARGET_DIR..."
  cp "/var/lib/lxc/$CONTAINER_NAME/rootfs/CorsixTH/build/CorsixTH"*.AppImage "$TARGET_DIR/" 2>/dev/null || true
  if [ -n "$TARGET_USER" ]; then
    chown "$TARGET_USER:" "$TARGET_DIR/CorsixTH"*.AppImage 2>/dev/null || true
  fi
fi

# Safely stop and destroy existing container (if applicable)
if [ -d "/var/lib/lxc/$CONTAINER_NAME" ]; then
  # Check if container is running
  if lxc-info -n "$CONTAINER_NAME" | grep -q RUNNING; then
    echo "➜ Stopping running container..."
    lxc-stop -n "$CONTAINER_NAME" || true
  fi
  echo "➜ Destroying existing container..."
  lxc-destroy -n "$CONTAINER_NAME" || true
fi
