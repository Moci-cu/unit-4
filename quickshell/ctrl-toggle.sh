#!/bin/bash
PID=$(pgrep -f 'ControlCenter.qml' | head -1)
[ -n "$PID" ] && qs ipc --pid "$PID" call ctrl "${1:-toggle}"
