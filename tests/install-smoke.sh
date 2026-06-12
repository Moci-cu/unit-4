#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/unit-4-installer-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail() {
    printf 'installer smoke test: %s\n' "$*" >&2
    exit 1
}

mkdir -p \
    "$TMP/bin" \
    "$TMP/home/.config/hypr" \
    "$TMP/home/.local/share"

printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/systemctl"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/systemd-analyze"
chmod +x "$TMP/bin/systemctl" "$TMP/bin/systemd-analyze"

printf 'monitor = test\n' > "$TMP/home/.config/hypr/user.conf"
printf 'keep me\n' > "$TMP/home/.config/hypr/local-only.conf"
mkdir -p "$TMP/home/.config/quickshell/scripts"
printf 'legacy terminal pairing\n' > "$TMP/home/.config/quickshell/scripts/bt-pair.sh"

run_installer() {
    HOME="$TMP/home" \
    XDG_CONFIG_HOME="$TMP/home/.config" \
    XDG_DATA_HOME="$TMP/home/.local/share" \
    PATH="$TMP/bin:$PATH" \
    HYPRLAND_INSTANCE_SIGNATURE="" \
        "$ROOT/install.sh" \
        --yes \
        --source-dir "$ROOT" \
        --no-packages \
        --no-services \
        --no-pam \
        "$@"
}

run_installer

[[ -x "$TMP/home/.config/quickshell/list-apps" ]] \
    || fail "list-apps was not built"
[[ -x "$TMP/home/.config/quickshell/pixel_video" ]] \
    || fail "pixel_video was not built"
[[ -x "$TMP/home/.config/hypr/gen-lockbg" ]] \
    || fail "gen-lockbg was not built"
[[ -x "$TMP/home/.config/hypr/scripts/systemd-session.sh" ]] \
    || fail "session helper is not executable"
[[ -f "$TMP/home/.config/systemd/user/hyprland-session.target" ]] \
    || fail "Hyprland session target was not installed"
[[ ! -e "$TMP/home/.config/systemd/user/wifi-powersave-off.service" ]] \
    || fail "legacy Wi-Fi power-save override was installed"
[[ ! -e "$TMP/home/.config/quickshell/scripts/bt-pair.sh" ]] \
    || fail "legacy Bluetooth terminal pairing helper was retained"
[[ "$(cat "$TMP/home/.config/hypr/user.conf")" == "monitor = test" ]] \
    || fail "user.conf was overwritten"
[[ "$(cat "$TMP/home/.config/hypr/local-only.conf")" == "keep me" ]] \
    || fail "an unmanaged local file was removed"
find "$TMP/home/.local/state/unit-4/backups" -type f -name user.conf \
    -print -quit | grep -q . \
    || fail "existing configuration was not backed up"

run_installer --no-backup

[[ "$(cat "$TMP/home/.config/hypr/user.conf")" == "monitor = test" ]] \
    || fail "user.conf was overwritten on rerun"

printf 'installer smoke test: ok\n'
