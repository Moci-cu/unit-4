# Installation

## Supported systems

The installer supports distributions whose `/etc/os-release` identifies them
as Arch Linux or includes `arch` in `ID_LIKE`. It is primarily tested on
CachyOS.

It intentionally does not support Debian, Fedora, NixOS, immutable systems, or
non-systemd sessions.

## Recommended installation

Clone the repository so you can inspect changes and update cleanly:

```bash
git clone https://github.com/Moci-cu/unit-4.git
cd unit-4
./install.sh
```

For an unattended install using the documented defaults:

```bash
./install.sh --yes
```

The defaults enable:

- package installation
- NetworkManager and Bluetooth services
- the Quickshell lockscreen PAM service
- timestamped backups

The defaults do not install:

- the bundled bashrc
- TLP power-profile integration
- custom Ndot fonts

## Installer options

```text
-y, --yes              Accept documented defaults
    --branch NAME      Remote Git branch, default main
    --source-dir PATH  Use a specific local checkout
    --no-packages      Skip pacman
    --no-services      Do not enable system services
    --no-pam           Do not install /etc/pam.d/qs-lock
    --with-shell       Install the bundled ~/.bashrc
    --with-power       Install TLP, tlp-pd, and tlp-rdw
    --font-dir PATH    Install the two required Ndot font files from PATH
    --no-backup        Do not create a timestamped backup
```

Example for a CachyOS laptop:

```bash
./install.sh --with-power --font-dir ~/Downloads/unit-4-fonts
```

## Package policy

Packages are listed in:

```text
packages/core.txt
packages/power.txt
```

The installer uses:

```bash
sudo pacman -Syu --needed ...
```

This is deliberate. Installing packages against stale repository metadata can
create an unsupported partial upgrade on Arch.

Quickshell and awww are currently available from official Arch and CachyOS
repositories, so an AUR helper is not required.

## Existing configurations and backups

Before updating managed files, the installer copies existing data to:

```text
~/.local/state/unit-4/backups/YYYYMMDD-HHMMSS
```

The new configuration is overlaid rather than deleting unknown files. These
personal override files are explicitly preserved:

```text
~/.config/hypr/user.conf
~/.config/hypr/user.lua
```

Application shortcuts for Zen Browser and Spotify reflect the maintainer's
setup and are not installed as dependencies. Override or remove those bindings
in `user.conf` when using different applications.

To use a different backup parent directory:

```bash
UNIT4_BACKUP_DIR=/path/to/backups ./install.sh
```

To restore a backup, log out of Hyprland and copy the relevant directory back:

```bash
cp -a ~/.local/state/unit-4/backups/TIMESTAMP/config/hypr/. ~/.config/hypr/
```

## Native helper programs

The installer builds these programs from source:

```text
~/.config/quickshell/list-apps
~/.config/quickshell/pixel_video
~/.config/hypr/gen-lockbg
```

This avoids shipping binaries compiled for the maintainer's CPU or C library.
`base-devel` supplies the required compiler and linker.

## Hyprland session lifecycle

unit-4 does not require UWSM. Hyprland starts:

```text
~/.config/hypr/scripts/systemd-session.sh
```

The helper waits for the Hyprland IPC socket, imports the Wayland environment,
starts `graphical-session.target`, and then starts the unit-4 desktop services.
They stop with the Hyprland session.

Do not enable these services manually on `default.target`:

```text
quickshell.service
quickshell-ctrl.service
awww-daemon.service
hypridle.service
battery-warning.service
udiskie.service
wave-check.service
```

Starting them before Wayland exists causes Qt to fall back to XCB and crash.

## Fonts

The UI expects these exact filenames:

```text
Ndot57-Regular.otf
Ndot77JPExtended.ttf
```

Place both files in one directory and run:

```bash
./install.sh --no-packages --no-services --no-pam \
  --font-dir /path/to/font-directory
```

The files are installed under `~/.local/share/fonts`, followed by `fc-cache`.
When the fonts are absent, Qt uses fallback fonts and the layout may differ.

## PAM and lockscreen

The lockscreen uses the PAM service:

```text
/etc/pam.d/qs-lock
```

The installer enables it by default. Use `--no-pam` only when you do not use
the bundled lockscreen or intend to manage PAM yourself.

Existing `qs-lock` configuration is included in the timestamped backup.

## Optional TLP integration

`--with-power` installs:

```text
tlp
tlp-pd
tlp-rdw
```

`tlp-pd` provides `tlpctl`, which is used by the bar, launcher, and automatic
power-saver logic.

Important: `tlp-pd` conflicts with `power-profiles-daemon` and `tuned-ppd`.
In interactive mode, review pacman's transaction before accepting a change to
an existing laptop power-management stack. `--yes` also passes `--noconfirm`,
so use it only when that replacement is intentional.

Without `tlpctl`, the desktop still works; TLP-specific indicators and actions
remain unavailable.

## Network management

The installer enables NetworkManager and Bluetooth. It does not overwrite your
NetworkManager Wi-Fi backend.

Both the default `wpa_supplicant` backend and an existing NetworkManager `iwd`
backend are supported. Do not run standalone iwd against the same interface
unless NetworkManager is configured to use it.

The repository's legacy `wifi-powersave-off.service` is not installed. Keeping
Wi-Fi power saving enabled is a better default for laptops, and interface names
are not guaranteed to be `wlan0`.

## Updating

From a checkout:

```bash
git pull --ff-only
./install.sh
```

When testing another branch:

```bash
./install.sh --branch hyprland-lua
```

`--branch` matters only for remote installs. A local checkout always installs
its current working tree, including uncommitted changes.

## Removing unit-4

There is intentionally no destructive automated uninstall command. To remove
the user configuration:

```bash
systemctl --user stop hyprland-session.target
rm -rf ~/.config/hypr ~/.config/quickshell ~/.config/kitty
rm -f ~/.config/systemd/user/{hyprland-session.target,quickshell.service}
rm -f ~/.config/systemd/user/{quickshell-ctrl.service,awww-daemon.service}
rm -f ~/.config/systemd/user/{hypridle.service,battery-warning.service}
rm -f ~/.config/systemd/user/{udiskie.service,wave-check.service}
systemctl --user daemon-reload
```

Review backups before deleting anything. Packages are not automatically
removed because they may be used by other desktops or applications.
