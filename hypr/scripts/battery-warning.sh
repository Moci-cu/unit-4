#!/bin/bash
# Battery and TLP profile monitor, event-driven while idle.

set -u

BAT="${BAT_PATH:-/sys/class/power_supply/BAT0}"
AC="${AC_PATH:-/sys/class/power_supply/AC}"
WARN_LEVEL=20
CRITICAL_LEVEL=10
ICON_DIR="$HOME/Downloads"
PROFILE_HELPER="${PROFILE_HELPER:-$HOME/.config/hypr/scripts/power-profile.sh}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
EVENT_FIFO="$RUNTIME_DIR/dots-battery-events.$$"

notified_warned=0
notified_crited=0
prev_online=$(cat "$AC/online" 2>/dev/null || printf '0')

read_power_value() {
    local path="$1"
    local fallback="$2"
    local value

    if IFS= read -r value < "$path" 2>/dev/null; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}

check_level() {
    [ ! -f "$BAT/capacity" ] && return
    local cap status
    cap=$(read_power_value "$BAT/capacity" "100")
    status=$(read_power_value "$BAT/status" "Unknown")
    if [ "$status" = "Charging" ] || [ "$cap" -gt "$WARN_LEVEL" ]; then
        notified_warned=0
        notified_crited=0
        return
    fi
    if [ "$cap" -le "$CRITICAL_LEVEL" ] && [ "$notified_crited" -eq 0 ]; then
        notify-send -u critical "CRITICAL" "Battery ${cap}% — Plug in now" -i "$ICON_DIR/low-battery-warning.png"
        notified_crited=1
    elif [ "$cap" -le "$WARN_LEVEL" ] && [ "$notified_warned" -eq 0 ]; then
        notify-send -u normal "LOW BATTERY" "Battery ${cap}%" -i "$ICON_DIR/low-battery-warning.png"
        notified_warned=1
    fi
}

check_plug_state() {
    local online
    online=$(read_power_value "$AC/online" "0")
    if [ "$online" = "1" ] && [ "$prev_online" != "1" ]; then
        notify-send -u normal "PLUGGED IN" "Charging started" -i "$ICON_DIR/plugged.png"
        notified_warned=0
        notified_crited=0
    elif [ "$online" = "0" ] && [ "$prev_online" != "0" ]; then
        notify-send -u normal "UNPLUGGED" "Running on battery" -i "$ICON_DIR/unplugged.png"
    fi
    prev_online="$online"
}

handle_power_event() {
    check_plug_state
    check_level
    "$PROFILE_HELPER" reconcile battery >/dev/null 2>&1 || true
}

handle_profile_event() {
    "$PROFILE_HELPER" reconcile profile >/dev/null 2>&1 || true
}

if [ "${1:-}" = "--check-once" ]; then
    handle_power_event
    exit
fi

cleanup() {
    trap - EXIT INT TERM
    jobs -pr | xargs -r kill 2>/dev/null || true
    rm -f "$EVENT_FIFO"
}
trap cleanup EXIT INT TERM

rm -f "$EVENT_FIFO"
mkfifo "$EVENT_FIFO"
exec 3<> "$EVENT_FIFO"

(
    pending=0
    udevadm monitor --property --subsystem-match=power_supply 2>/dev/null |
        while IFS= read -r line; do
            if [ -z "$line" ]; then
                if [ "$pending" -eq 1 ]; then
                    printf 'power\n' > "$EVENT_FIFO"
                    pending=0
                fi
            elif [[ "$line" == POWER_SUPPLY_CAPACITY=* \
                || "$line" == POWER_SUPPLY_STATUS=* \
                || "$line" == POWER_SUPPLY_ONLINE=* ]]; then
                pending=1
            fi
        done
) &

(
    gdbus monitor --system \
        --dest org.freedesktop.UPower.PowerProfiles \
        --object-path /org/freedesktop/UPower/PowerProfiles 2>/dev/null |
        while IFS= read -r line; do
            [[ "$line" == *ActiveProfile* ]] && printf 'profile\n' > "$EVENT_FIFO"
        done
) &

check_level
"$PROFILE_HELPER" reconcile battery >/dev/null 2>&1 || true

while IFS= read -r event <&3; do
    case "$event" in
        power) handle_power_event ;;
        profile) handle_profile_event ;;
    esac
done
