#!/bin/bash
if ! pgrep -f 'ControlCenter.qml' > /dev/null; then
    systemctl --user start quickshell-ctrl
    # Retry IPC up to 2s (200ms interval)
    for i in $(seq 1 10); do
        sleep 0.2
        PID=$(pgrep -f 'ControlCenter.qml' | head -1)
        [ -n "$PID" ] && qs ipc --pid "$PID" call ctrl "${1:-toggle}" && exit 0
    done
    exit 1
fi
PID=$(pgrep -f 'ControlCenter.qml' | head -1)
[ -n "$PID" ] && qs ipc --pid "$PID" call ctrl "${1:-toggle}"
