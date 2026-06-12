#!/usr/bin/env bash

set -Eeuo pipefail
umask 022

readonly REPO_URL="https://github.com/Moci-cu/unit-4.git"
REPO_BRANCH="${UNIT4_BRANCH:-main}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SOURCE_DIR="${UNIT4_SOURCE_DIR:-}"
BACKUP_ROOT="${UNIT4_BACKUP_DIR:-$HOME/.local/state/unit-4/backups}"
BACKUP_DIR=""
WORK_DIR=""
STAGE_DIR=""
SUDO_KEEPALIVE_PID=""

ASSUME_YES=false
INSTALL_PACKAGES=true
ENABLE_SERVICES=true
INSTALL_PAM=true
INSTALL_SHELL=false
INSTALL_POWER=false
BACKUP_EXISTING=true
FONT_DIR=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Install unit-4 on Arch Linux, CachyOS, and other Arch-based distributions.

Options:
  -y, --yes              Use documented defaults without prompting
      --branch NAME      Git branch used by curl/remote installs (default: main)
      --source-dir PATH  Install from an explicit local checkout
      --no-packages      Do not install pacman dependencies
      --no-services      Do not enable system services
      --no-pam           Do not install /etc/pam.d/qs-lock
      --with-shell       Install the optional Unit-4 ~/.bashrc
      --with-power       Install TLP, tlp-pd, and tlp-rdw
      --font-dir PATH    Install Ndot57-Regular.otf and Ndot77JPExtended.ttf
                         from PATH into ~/.local/share/fonts
      --no-backup        Overlay configs without creating a backup
  -h, --help             Show this help

Defaults:
  Packages, NetworkManager/Bluetooth services, PAM, and backups are enabled.
  The optional bashrc and TLP integration are disabled.

Environment:
  UNIT4_BRANCH           Same as --branch
  UNIT4_SOURCE_DIR       Same as --source-dir
  UNIT4_BACKUP_DIR       Override the backup parent directory
EOF
}

while (($#)); do
    case "$1" in
        -y|--yes) ASSUME_YES=true ;;
        --branch)
            (($# >= 2)) || { echo "Missing value for --branch" >&2; exit 2; }
            REPO_BRANCH="$2"
            shift
            ;;
        --source-dir)
            (($# >= 2)) || { echo "Missing value for --source-dir" >&2; exit 2; }
            SOURCE_DIR="$2"
            shift
            ;;
        --no-packages) INSTALL_PACKAGES=false ;;
        --no-services) ENABLE_SERVICES=false ;;
        --no-pam) INSTALL_PAM=false ;;
        --with-shell) INSTALL_SHELL=true ;;
        --with-power) INSTALL_POWER=true ;;
        --font-dir)
            (($# >= 2)) || { echo "Missing value for --font-dir" >&2; exit 2; }
            FONT_DIR="$2"
            shift
            ;;
        --no-backup) BACKUP_EXISTING=false ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ -t 1 ]]; then
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_RESET=""
fi

log()   { printf '%s[*]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
fatal() { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

cleanup() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    [[ -z "$WORK_DIR" || ! -d "$WORK_DIR" ]] || rm -rf "$WORK_DIR"
    [[ -z "$STAGE_DIR" || ! -d "$STAGE_DIR" ]] || rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

ask() {
    local prompt="$1"
    local default="$2"
    local answer hint

    if $ASSUME_YES; then
        [[ "$default" == "yes" ]]
        return
    fi

    hint="[y/N]"
    [[ "$default" == "yes" ]] && hint="[Y/n]"
    while true; do
        read -r -p "$prompt $hint " answer
        answer="${answer:-$default}"
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) warn "Please answer yes or no." ;;
        esac
    done
}

load_os_release() {
    [[ -r /etc/os-release ]] || fatal "/etc/os-release is missing."
    # shellcheck disable=SC1091
    source /etc/os-release

    local family=" ${ID:-} ${ID_LIKE:-} "
    [[ "$family" == *" arch "* ]] \
        || fatal "Unsupported distribution: ${PRETTY_NAME:-unknown}. Arch-based systems only."

    if [[ "${ID:-}" == "cachyos" ]]; then
        ok "Detected CachyOS."
    else
        ok "Detected Arch-based distribution: ${PRETTY_NAME:-$ID}."
    fi
}

preflight() {
    [[ $EUID -ne 0 ]] || fatal "Run this installer as your normal user, not root."
    [[ -n "${HOME:-}" && "$HOME" != "/" ]] || fatal "HOME is not set correctly."
    command -v pacman >/dev/null || fatal "pacman was not found."
    command -v systemctl >/dev/null || fatal "systemd is required."
    load_os_release

    if [[ -n "$FONT_DIR" ]]; then
        FONT_DIR="$(realpath "$FONT_DIR")"
        [[ -d "$FONT_DIR" ]] || fatal "Font directory does not exist: $FONT_DIR"
    fi
    return 0
}

collect_choices() {
    if ! $ASSUME_YES; then
        ask "Install/update required pacman packages?" yes \
            && INSTALL_PACKAGES=true || INSTALL_PACKAGES=false
        ask "Enable NetworkManager and Bluetooth services?" yes \
            && ENABLE_SERVICES=true || ENABLE_SERVICES=false
        ask "Install the Quickshell lockscreen PAM service?" yes \
            && INSTALL_PAM=true || INSTALL_PAM=false
        ask "Install the optional Unit-4 bashrc?" no \
            && INSTALL_SHELL=true || INSTALL_SHELL=false
        ask "Install optional TLP power-profile integration?" no \
            && INSTALL_POWER=true || INSTALL_POWER=false
        ask "Back up existing managed files?" yes \
            && BACKUP_EXISTING=true || BACKUP_EXISTING=false
    fi
}

needs_sudo() {
    $INSTALL_PACKAGES || $ENABLE_SERVICES || $INSTALL_PAM
}

start_sudo_session() {
    needs_sudo || return 0
    command -v sudo >/dev/null || fatal "sudo is required for selected operations."
    log "Requesting sudo access..."
    sudo -v || fatal "sudo authentication failed."
    (
        while true; do
            sudo -n true
            sleep 50
        done
    ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
}

detect_local_source() {
    local script_path script_dir
    script_path="${BASH_SOURCE[0]:-}"
    [[ -f "$script_path" ]] || return 1
    script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"
    [[ -d "$script_dir/hypr" && -d "$script_dir/quickshell" ]] || return 1
    SOURCE_DIR="$script_dir"
}

prepare_source() {
    if [[ -n "$SOURCE_DIR" ]]; then
        SOURCE_DIR="$(realpath "$SOURCE_DIR")"
        [[ -f "$SOURCE_DIR/install.sh" && -d "$SOURCE_DIR/quickshell" ]] \
            || fatal "Invalid unit-4 source directory: $SOURCE_DIR"
        ok "Using local source: $SOURCE_DIR"
        return
    fi

    if detect_local_source; then
        ok "Using local source: $SOURCE_DIR"
        return
    fi

    if ! command -v git >/dev/null; then
        needs_sudo || fatal "git is required for a remote install."
        local -a git_install_args=(-Syu --needed)
        $ASSUME_YES && git_install_args+=(--noconfirm)
        log "Installing git..."
        sudo pacman "${git_install_args[@]}" git
    fi

    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/unit-4-install.XXXXXX")"
    log "Cloning $REPO_URL ($REPO_BRANCH)..."
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$WORK_DIR/repo"
    SOURCE_DIR="$WORK_DIR/repo"
}

read_package_file() {
    local file="$1"
    [[ -f "$file" ]] || fatal "Missing package manifest: $file"
    sed -E 's/[[:space:]]*#.*$//' "$file" | awk 'NF'
}

install_packages() {
    $INSTALL_PACKAGES || { warn "Skipping package installation."; return; }

    local -a packages pacman_args
    mapfile -t packages < <(read_package_file "$SOURCE_DIR/packages/core.txt")
    if $INSTALL_POWER; then
        local -a power_packages
        mapfile -t power_packages < <(read_package_file "$SOURCE_DIR/packages/power.txt")
        packages+=("${power_packages[@]}")
    fi

    pacman_args=(-Syu --needed)
    $ASSUME_YES && pacman_args+=(--noconfirm)

    log "Updating the system and installing ${#packages[@]} packages..."
    sudo pacman "${pacman_args[@]}" "${packages[@]}"
}

make_backup_dir() {
    $BACKUP_EXISTING || return 0
    [[ -n "$BACKUP_DIR" ]] && return 0

    local base candidate suffix=0
    base="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
    candidate="$base"
    while [[ -e "$candidate" ]]; do
        ((suffix += 1))
        candidate="$base-$suffix"
    done

    BACKUP_DIR="$candidate"
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
}

backup_path() {
    local path="$1"
    local relative="$2"
    $BACKUP_EXISTING || return 0
    [[ -e "$path" || -L "$path" ]] || return 0
    make_backup_dir
    mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
    cp -a "$path" "$BACKUP_DIR/$relative"
}

build_helpers() {
    local root="$1"
    command -v g++ >/dev/null || fatal "g++ is required to build helper binaries."

    log "Building native helper binaries..."
    g++ -O2 -std=c++17 -Wall -Wextra \
        "$root/quickshell/list-apps.cpp" -o "$root/quickshell/list-apps"
    g++ -O2 -std=c++17 -Wall -Wextra \
        "$root/quickshell/pixel_video.cpp" -o "$root/quickshell/pixel_video"
    g++ -O2 -std=c++17 -Wall -Wextra -Wno-missing-field-initializers \
        "$root/hypr/gen-lockbg.cpp" -o "$root/hypr/gen-lockbg"

    if command -v strip >/dev/null; then
        strip \
            "$root/quickshell/list-apps" \
            "$root/quickshell/pixel_video" \
            "$root/hypr/gen-lockbg"
    fi
}

stage_configs() {
    STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/unit-4-stage.XXXXXX")"

    for name in hypr quickshell kitty; do
        mkdir -p "$STAGE_DIR/$name"
        cp -a "$SOURCE_DIR/$name/." "$STAGE_DIR/$name/"
    done
    rm -rf "$STAGE_DIR/quickshell/backups"
    build_helpers "$STAGE_DIR"

    find "$STAGE_DIR/hypr" "$STAGE_DIR/quickshell" \
        -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod 755 {} +
}

deploy_configs() {
    stage_configs
    mkdir -p "$CONFIG_HOME"

    for name in hypr quickshell kitty; do
        local dest="$CONFIG_HOME/$name"
        if [[ -e "$dest" ]]; then
            backup_path "$dest" "config/$name"
        fi
        mkdir -p "$dest"

        local preserve=""
        if [[ "$name" == "hypr" ]]; then
            preserve="$(mktemp -d "${TMPDIR:-/tmp}/unit-4-user.XXXXXX")"
            [[ ! -f "$dest/user.conf" ]] || cp -a "$dest/user.conf" "$preserve/"
            [[ ! -f "$dest/user.lua" ]] || cp -a "$dest/user.lua" "$preserve/"
        fi

        cp -a "$STAGE_DIR/$name/." "$dest/"

        if [[ -n "$preserve" ]]; then
            [[ ! -f "$preserve/user.conf" ]] || cp -a "$preserve/user.conf" "$dest/user.conf"
            [[ ! -f "$preserve/user.lua" ]] || cp -a "$preserve/user.lua" "$dest/user.lua"
            rm -rf "$preserve"
        fi
        ok "Installed $dest"
    done

    rm -rf "$STAGE_DIR"
    STAGE_DIR=""
    mkdir -p "$HOME/Pictures/wallpapers" "$HOME/Screenshots"
}

deploy_user_units() {
    local unit_dir="$CONFIG_HOME/systemd/user"
    local -a units=(
        awww-daemon.service
        battery-warning.service
        hypridle.service
        hyprland-session.target
        quickshell-ctrl.service
        quickshell.service
        udiskie.service
        wave-check.service
    )
    mkdir -p "$unit_dir"

    local name unit
    for name in "${units[@]}"; do
        unit="$SOURCE_DIR/system/systemd/user/$name"
        [[ -f "$unit" ]] || fatal "Missing user unit: $unit"
        backup_path "$unit_dir/$name" "config/systemd/user/$name"
        install -m 644 "$unit" "$unit_dir/$name"
    done

    systemctl --user disable \
        quickshell.service quickshell-ctrl.service awww-daemon.service \
        hypridle.service battery-warning.service udiskie.service \
        wave-check.service wifi-powersave-off.service >/dev/null 2>&1 || true
    systemctl --user daemon-reload \
        || warn "User manager is unavailable; units will load at the next login."
    ok "Installed Hyprland session units."
}

deploy_pam() {
    $INSTALL_PAM || { warn "Skipping PAM configuration."; return; }
    local source="$SOURCE_DIR/system/pam.d/qs-lock"
    [[ -f "$source" ]] || fatal "Missing PAM file: $source"
    if $BACKUP_EXISTING && [[ -e /etc/pam.d/qs-lock ]]; then
        make_backup_dir
        sudo cp -a /etc/pam.d/qs-lock "$BACKUP_DIR/qs-lock.pam"
    fi
    sudo install -m 644 "$source" /etc/pam.d/qs-lock
    ok "Installed /etc/pam.d/qs-lock."
}

deploy_shell() {
    $INSTALL_SHELL || return 0
    local source="$SOURCE_DIR/bash/.bashrc"
    [[ -f "$source" ]] || fatal "Missing bashrc template: $source"
    backup_path "$HOME/.bashrc" "home/.bashrc"
    install -m 644 "$source" "$HOME/.bashrc"
    if [[ ! -e "$HOME/.bashrc.local" ]]; then
        install -m 644 /dev/null "$HOME/.bashrc.local"
    fi
    ok "Installed optional bash configuration."
}

deploy_fonts() {
    if [[ -z "$FONT_DIR" ]]; then
        if ! command -v fc-match >/dev/null; then
            warn "fontconfig is unavailable; Ndot font detection was skipped."
            return
        fi
        local missing=false
        fc-match "Ndot 57" 2>/dev/null | grep -qi 'Ndot' || missing=true
        fc-match "Ndot77JPExtended" 2>/dev/null | grep -qi 'Ndot' || missing=true
        $missing && warn "Ndot fonts were not found. See docs/INSTALLATION.md."
        return 0
    fi

    local font_dest="$DATA_HOME/fonts"
    mkdir -p "$font_dest"
    for font in Ndot57-Regular.otf Ndot77JPExtended.ttf; do
        [[ -f "$FONT_DIR/$font" ]] || fatal "Missing font in --font-dir: $font"
        install -m 644 "$FONT_DIR/$font" "$font_dest/$font"
    done
    command -v fc-cache >/dev/null \
        && fc-cache -f "$font_dest" \
        || warn "Fonts were installed, but fc-cache is unavailable."
    ok "Installed Ndot fonts."
}

enable_services() {
    $ENABLE_SERVICES || { warn "Skipping service activation."; return; }

    sudo systemctl enable NetworkManager.service bluetooth.service
    if $INSTALL_POWER; then
        sudo systemctl enable tlp.service tlp-pd.service
    fi

    if systemctl --user show-environment >/dev/null 2>&1; then
        systemctl --user enable \
            pipewire.socket pipewire-pulse.socket wireplumber.service \
            >/dev/null 2>&1 || warn "Could not enable all PipeWire user units."
    fi

    ok "Enabled system services. They will start normally on the next boot."
}

validate_install() {
    local failed=false
    if $INSTALL_PACKAGES; then
        for command in Hyprland qs kitty awww nmcli wpctl brightnessctl; do
            if ! command -v "$command" >/dev/null; then
                warn "Command unavailable: $command"
                failed=true
            fi
        done
    fi

    for file in \
        "$CONFIG_HOME/hypr/hyprland.conf" \
        "$CONFIG_HOME/hypr/scripts/systemd-session.sh" \
        "$CONFIG_HOME/quickshell/shell.qml" \
        "$CONFIG_HOME/quickshell/list-apps" \
        "$CONFIG_HOME/systemd/user/hyprland-session.target"; do
        [[ -e "$file" ]] || { warn "Missing installed file: $file"; failed=true; }
    done

    systemd-analyze --user verify \
        "$CONFIG_HOME/systemd/user/hyprland-session.target" \
        "$CONFIG_HOME/systemd/user/quickshell.service" \
        "$CONFIG_HOME/systemd/user/quickshell-ctrl.service" \
        >/dev/null || failed=true

    $failed && fatal "Installation validation failed. Review the warnings above."
    ok "Installation validation passed."
}

finalize() {
    printf '\n%s%sInstallation complete.%s\n\n' "$C_GREEN" "$C_BOLD" "$C_RESET"
    printf 'Next steps:\n'
    printf '  1. Log out and select the regular Hyprland session.\n'
    printf '  2. Put monitor and personal overrides in %s/hypr/user.conf.\n' "$CONFIG_HOME"
    printf '  3. Put wallpapers in %s/Pictures/wallpapers.\n' "$HOME"
    printf '  4. Read docs/INSTALLATION.md and docs/TROUBLESHOOTING.md.\n'
    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
        printf '\nBackup created at:\n  %s\n' "$BACKUP_DIR"
    fi
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        printf '\nYou installed from inside Hyprland. Log out before judging startup behavior.\n'
    fi
}

main() {
    preflight
    collect_choices
    start_sudo_session
    prepare_source
    install_packages
    deploy_configs
    deploy_user_units
    deploy_pam
    deploy_shell
    deploy_fonts
    enable_services
    validate_install
    finalize
}

main
