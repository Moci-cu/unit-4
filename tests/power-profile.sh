#!/bin/bash

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
HELPER="$ROOT/hypr/scripts/power-profile.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/BAT0" "$TMP/AC" "$TMP/runtime" "$TMP/bin"

cat > "$TMP/bin/tlpctl" <<'EOF'
#!/bin/bash
set -eu
case "${1:-}" in
    get) cat "$FAKE_TLP_PROFILE" ;;
    performance|balanced|power-saver) printf '%s\n' "$1" > "$FAKE_TLP_PROFILE" ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$TMP/bin/tlpctl"

export BAT_PATH="$TMP/BAT0"
export AC_PATH="$TMP/AC"
export XDG_RUNTIME_DIR="$TMP/runtime"
export TLPCTL_BIN="$TMP/bin/tlpctl"
export FAKE_TLP_PROFILE="$TMP/profile"

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [ "$actual" != "$expected" ]; then
        printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

profile() {
    cat "$FAKE_TLP_PROFILE"
}

auto_state() {
    cat "$XDG_RUNTIME_DIR/dots-power-profile-auto.state"
}

set_power() {
    printf '%s\n' "$1" > "$BAT_PATH/capacity"
    printf '%s\n' "$2" > "$BAT_PATH/status"
    printf '%s\n' "$3" > "$AC_PATH/online"
}

reset_case() {
    printf '%s\n' "$1" > "$FAKE_TLP_PROFILE"
    rm -f "$XDG_RUNTIME_DIR/dots-power-profile.state" \
        "$XDG_RUNTIME_DIR/dots-power-profile-auto.state"
}

reset_case balanced
set_power 31 Discharging 0
bash "$HELPER" reconcile battery
assert_eq balanced "$(profile)" "31% must keep balanced"

set_power 30 Discharging 0
bash "$HELPER" reconcile battery
assert_eq power-saver "$(profile)" "30% must enable power-saver"
assert_eq $'mode=auto\nprevious=balanced' "$(auto_state)" "auto mode must remember balanced"

set_power 34 Discharging 0
bash "$HELPER" reconcile battery
assert_eq power-saver "$(profile)" "34% must remain in auto power-saver"

set_power 35 Discharging 0
bash "$HELPER" reconcile battery
assert_eq balanced "$(profile)" "35% must restore the previous profile"
assert_eq $'mode=idle\nprevious=' "$(auto_state)" "recovery must clear auto mode"

reset_case performance
set_power 25 Discharging 0
bash "$HELPER" reconcile battery
set_power 25 Charging 1
bash "$HELPER" reconcile battery
assert_eq performance "$(profile)" "AC must restore performance after auto power-saver"

reset_case balanced
set_power 25 Discharging 0
bash "$HELPER" set power-saver
set_power 25 Charging 1
bash "$HELPER" reconcile battery
assert_eq power-saver "$(profile)" "manual power-saver must survive AC recovery"

reset_case balanced
set_power 25 Discharging 0
bash "$HELPER" reconcile battery
bash "$HELPER" set performance
bash "$HELPER" reconcile battery
assert_eq performance "$(profile)" "manual override must be respected below 30%"
assert_eq $'mode=override\nprevious=' "$(auto_state)" "manual override must be recorded"

set_power 35 Discharging 0
bash "$HELPER" reconcile battery
set_power 30 Discharging 0
bash "$HELPER" reconcile battery
assert_eq power-saver "$(profile)" "auto power-saver must reactivate after recovery"
assert_eq $'mode=auto\nprevious=performance' "$(auto_state)" "reactivated auto mode must remember override profile"

printf 'power-profile tests: ok\n'
