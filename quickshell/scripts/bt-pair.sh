#!/usr/bin/env bash
set -u

mac="${1:-}"

bt() {
    timeout 5 bluetoothctl "$@"
}

device_field() {
    local key="$1"
    bt info "$mac" 2>/dev/null | awk -F': ' -v key="$key" '$1 ~ key { print $2; exit }'
}

if [[ ! "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
    echo "Invalid Bluetooth address: $mac"
    read -r -p "Press Enter to close..."
    exit 2
fi

echo "Preparing Bluetooth pairing for $mac"
echo "Confirm the same code on phone and laptop."
echo

echo "Resetting stale BlueZ state..."
bt scan off >/dev/null 2>&1 || true
bt cancel-pairing "$mac" >/dev/null 2>&1 || true
bt power on >/dev/null 2>&1 || true
bt pairable on >/dev/null 2>&1 || true

paired="$(device_field "Paired")"
trusted="$(device_field "Trusted")"
if [[ "$trusted" == "yes" && "$paired" != "yes" ]]; then
    echo "Removing stale trusted-but-unpaired entry..."
    bt remove "$mac" >/dev/null 2>&1 || true
fi

echo "Re-discovering device..."
for _ in {1..3}; do
    timeout 6 bluetoothctl --timeout 4 scan on >/dev/null 2>&1 || true
    if bt info "$mac" >/dev/null 2>&1; then
        break
    fi
done
bt scan off >/dev/null 2>&1 || true

if ! bt info "$mac" >/dev/null 2>&1; then
    echo "Device $mac is not available after scanning."
    echo "Open the phone Bluetooth settings screen, then try Pair again."
    echo
    read -r -p "Press Enter to close..."
    exit 1
fi

echo
bluetoothctl --agent=DisplayYesNo pair "$mac"
rc=$?

if [[ $rc -ne 0 ]]; then
    echo
    echo "Retrying once with a clean BlueZ entry..."
    bt cancel-pairing "$mac" >/dev/null 2>&1 || true
    bt remove "$mac" >/dev/null 2>&1 || true
    timeout 6 bluetoothctl --timeout 4 scan on >/dev/null 2>&1 || true
    bt scan off >/dev/null 2>&1 || true
    bluetoothctl --agent=DisplayYesNo pair "$mac"
    rc=$?
fi

if [[ $rc -eq 0 ]]; then
    bt trust "$mac"
    echo
    bt info "$mac" | grep -E "Paired:|Bonded:|Trusted:|Connected:"
    echo
    echo "Pairing complete if Paired is yes."
else
    echo
    echo "Pairing failed."
fi

echo
read -r -p "Press Enter to close..."
exit "$rc"
