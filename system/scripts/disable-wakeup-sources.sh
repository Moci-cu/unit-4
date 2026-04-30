#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# disable-wakeup-sources.sh
# Disable PCI wakeup sources known to cause spurious wakeups
# on AMD laptops using s2idle (Modern Standby).
# ════════════════════════════════════════════════════════════════

for dev in 0000:00:08.1 0000:02:00.0 0000:04:00.3 0000:04:00.4; do
    path="/sys/bus/pci/devices/$dev/power/wakeup"
    if [ -f "$path" ]; then
        echo disabled > "$path" 2>/dev/null && echo "disabled $dev" || echo "failed $dev (need root)"
    fi
done
