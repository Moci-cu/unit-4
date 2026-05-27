#!/bin/bash
# lock.sh — Quickshell NieR lockscreen

# Check if already running
pgrep -f "lockscreen.qml" >/dev/null 2>&1 && exit 0

# Launch Quickshell lockscreen
QT_MEDIA_BACKEND=ffmpeg /usr/sbin/qs -p "$HOME/.config/quickshell/widgets/lockscreen.qml" &

# Give it a moment to spawn
sleep 0.2
