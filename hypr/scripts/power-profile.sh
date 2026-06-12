#!/bin/bash

set -u

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PROFILE_STATE="${POWER_PROFILE_STATE:-$RUNTIME_DIR/dots-power-profile.state}"
AUTO_STATE="${POWER_PROFILE_AUTO_STATE:-$RUNTIME_DIR/dots-power-profile-auto.state}"
BAT="${BAT_PATH:-/sys/class/power_supply/BAT0}"
AC="${AC_PATH:-/sys/class/power_supply/AC}"
TLPCTL_BIN="${TLPCTL_BIN:-tlpctl}"

atomic_write() {
    local path="$1"
    local value="$2"
    local tmp

    if [ -r "$path" ] && [ "$(cat "$path")" = "$value" ]; then
        return
    fi

    mkdir -p "$(dirname "$path")"
    tmp=$(mktemp "${path}.XXXXXX") || return 1
    printf '%s\n' "$value" > "$tmp"
    mv -f "$tmp" "$path"
}

read_value() {
    local path="$1"
    local fallback="$2"
    local value

    if IFS= read -r value < "$path" 2>/dev/null; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}

active_profile() {
    "$TLPCTL_BIN" get 2>/dev/null | tail -n 1
}

sync_profile_state() {
    local profile
    profile=$(active_profile) || return 1
    [ -n "$profile" ] || return 1
    atomic_write "$PROFILE_STATE" "$profile"
    printf '%s\n' "$profile"
}

load_auto_state() {
    AUTO_MODE="idle"
    AUTO_PREVIOUS=""

    [ -r "$AUTO_STATE" ] || return
    while IFS='=' read -r key value; do
        case "$key" in
            mode) AUTO_MODE="$value" ;;
            previous) AUTO_PREVIOUS="$value" ;;
        esac
    done < "$AUTO_STATE"

    case "$AUTO_MODE" in
        idle|auto|override|manual) ;;
        *) AUTO_MODE="idle"; AUTO_PREVIOUS="" ;;
    esac
}

save_auto_state() {
    local mode="$1"
    local previous="${2:-}"
    atomic_write "$AUTO_STATE" "mode=$mode
previous=$previous"
}

power_state() {
    BAT_CAPACITY=$(read_value "$BAT/capacity" "100")
    BAT_STATUS=$(read_value "$BAT/status" "Unknown")
    AC_ONLINE=$(read_value "$AC/online" "0")

    case "$BAT_CAPACITY" in
        ''|*[!0-9]*) BAT_CAPACITY=100 ;;
    esac
}

is_low_discharging() {
    [ "$AC_ONLINE" != "1" ] \
        && [ "$BAT_STATUS" = "Discharging" ] \
        && [ "$BAT_CAPACITY" -le 30 ]
}

is_recovered() {
    [ "$AC_ONLINE" = "1" ] || [ "$BAT_CAPACITY" -ge 35 ]
}

set_profile() {
    local profile="$1"
    "$TLPCTL_BIN" "$profile" >/dev/null || return 1
    atomic_write "$PROFILE_STATE" "$profile"
}

set_manual_profile() {
    local profile="$1"
    local old_state=""

    case "$profile" in
        performance|balanced|power-saver) ;;
        *)
            printf 'Unsupported TLP profile: %s\n' "$profile" >&2
            return 2
            ;;
    esac

    [ -r "$AUTO_STATE" ] && old_state=$(cat "$AUTO_STATE")
    power_state
    if is_low_discharging; then
        if [ "$profile" = "power-saver" ]; then
            save_auto_state "manual"
        else
            save_auto_state "override"
        fi
    else
        save_auto_state "idle"
    fi

    if ! set_profile "$profile"; then
        if [ -n "$old_state" ]; then
            atomic_write "$AUTO_STATE" "$old_state"
        else
            rm -f "$AUTO_STATE"
        fi
        return 1
    fi
}

reconcile_battery() {
    local profile

    profile=$(sync_profile_state) || return 1
    power_state
    load_auto_state

    if is_low_discharging; then
        case "$AUTO_MODE" in
            override|manual)
                return
                ;;
            auto)
                [ "$profile" = "power-saver" ] && return
                save_auto_state "override"
                return
                ;;
        esac

        if [ "$profile" = "power-saver" ]; then
            save_auto_state "manual"
            return
        fi

        save_auto_state "auto" "$profile"
        if ! set_profile "power-saver"; then
            save_auto_state "idle"
            return 1
        fi
        return
    fi

    if is_recovered; then
        if [ "$AUTO_MODE" = "auto" ]; then
            local restore_profile="${AUTO_PREVIOUS:-balanced}"
            save_auto_state "idle"
            if ! set_profile "$restore_profile"; then
                save_auto_state "auto" "$restore_profile"
                return 1
            fi
        elif [ "$AUTO_MODE" != "idle" ]; then
            save_auto_state "idle"
        fi
    fi
}

reconcile_profile() {
    local profile

    profile=$(sync_profile_state) || return 1
    power_state
    load_auto_state

    if is_low_discharging; then
        case "$AUTO_MODE:$profile" in
            auto:power-saver|manual:power-saver|override:*)
                ;;
            *:power-saver)
                save_auto_state "manual"
                ;;
            *)
                save_auto_state "override"
                ;;
        esac
    elif is_recovered && [ "$AUTO_MODE" != "auto" ]; then
        save_auto_state "idle"
    fi
}

mkdir -p "$RUNTIME_DIR"
exec 9> "$RUNTIME_DIR/dots-power-profile.lock"
flock -x 9

case "${1:-}" in
    get|sync)
        sync_profile_state
        ;;
    set)
        [ "$#" -eq 2 ] || {
            printf 'Usage: %s set <performance|balanced|power-saver>\n' "$0" >&2
            exit 2
        }
        set_manual_profile "$2"
        ;;
    reconcile)
        case "${2:-}" in
            battery) reconcile_battery ;;
            profile) reconcile_profile ;;
            *)
                printf 'Usage: %s reconcile <battery|profile>\n' "$0" >&2
                exit 2
                ;;
        esac
        ;;
    *)
        printf 'Usage: %s {get|sync|set PROFILE|reconcile EVENT}\n' "$0" >&2
        exit 2
        ;;
esac
