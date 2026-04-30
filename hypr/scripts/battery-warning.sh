#!/bin/bash
# Battery monitor — event-driven via udevadm (zero CPU idle)
BAT="/sys/class/power_supply/BAT0"
WARN_LEVEL=20
CRITICAL_LEVEL=10
ICON_DIR="$HOME/Downloads"
notified_warned=0
notified_crited=0
prev_online=$(cat /sys/class/power_supply/AC/online 2>/dev/null)

check_level() {
    [ ! -f "$BAT/capacity" ] && return
    local cap status
    cap=$(cat "$BAT/capacity")
    status=$(cat "$BAT/status")
    if [ "$status" = "Charging" ] || [ "$cap" -gt "$WARN_LEVEL" ]; then
        notified_warned=0; notified_crited=0; return
    fi
    if [ "$cap" -le "$CRITICAL_LEVEL" ] && [ "$notified_crited" -eq 0 ]; then
        notify-send -u critical "CRITICAL" "Battery ${cap}% — Plug in now" -i "$ICON_DIR/low-battery-warning.png"
        notified_crited=1
    elif [ "$cap" -le "$WARN_LEVEL" ] && [ "$notified_warned" -eq 0 ]; then
        notify-send -u normal "LOW BATTERY" "Battery ${cap}%" -i "$ICON_DIR/low-battery-warning.png"
        notified_warned=1
    fi
}

check_level

exec udevadm monitor --property --subsystem-match=power_supply 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" == "POWER_SUPPLY_ONLINE=1" && "$prev_online" != "1" ]]; then
        notify-send -u normal "PLUGGED IN" "Charging started" -i "$ICON_DIR/plugged.png"
        notified_warned=0; notified_crited=0
        prev_online=1
    elif [[ "$line" == "POWER_SUPPLY_ONLINE=0" && "$prev_online" != "0" ]]; then
        notify-send -u normal "UNPLUGGED" "Running on battery" -i "$ICON_DIR/unplugged.png"
        prev_online=0
        check_level
    fi
    [[ "$line" == "POWER_SUPPLY_CAPACITY="* ]] && check_level
done
