#!/bin/sh

set -eu

session_target="hyprland-session.target"
signature="${HYPRLAND_INSTANCE_SIGNATURE:?HYPRLAND_INSTANCE_SIGNATURE is not set}"
runtime_dir="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
socket_dir="$runtime_dir/hypr/$signature"
lock_file="$runtime_dir/hyprland-systemd-session.lock"
started=0

exec 9>"$lock_file"
flock -n 9 || exit 0

cleanup() {
    if [ "$started" -eq 1 ]; then
        systemctl --user stop "$session_target"
    fi
}
trap cleanup EXIT HUP INT TERM

# Hyprland runs exec-once before its IPC socket is guaranteed to exist.
# Wait for the compositor to become ready before starting graphical services.
attempt=0
while [ ! -S "$socket_dir/.socket.sock" ]; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 100 ] || exit 1
    sleep 0.1
done

# Clear a target left behind by an unclean compositor exit before importing
# this session's Wayland environment.
systemctl --user stop "$session_target" 2>/dev/null || true
systemctl --user import-environment \
    DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE \
    XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR
dbus-update-activation-environment --systemd \
    DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE \
    XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR
systemctl --user start "$session_target"
started=1
systemctl --user start \
    quickshell.service \
    quickshell-ctrl.service \
    awww-daemon.service \
    hypridle.service \
    battery-warning.service \
    udiskie.service \
    wave-check.service

while [ -S "$socket_dir/.socket.sock" ]; do
    sleep 2
done
