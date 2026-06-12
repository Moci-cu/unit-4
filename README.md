# unit-4

NieR-inspired Hyprland desktop built with Quickshell. This repository is a
personal fork of [samyns/Unit-3](https://github.com/samyns/Unit-3), with a
custom bar, control center, launcher, notifications, lock screen, networking,
and laptop power-profile integration.

The supported platform is Arch Linux and Arch-based distributions. CachyOS is
the primary development and test environment.

## Highlights

- Quickshell bar with Hyprland workspaces, system resources, battery state,
  Wi-Fi strength, date, and clock
- Keyboard-driven control center for Wi-Fi, Bluetooth, audio, brightness,
  notifications, and file sharing
- Application launcher with native desktop-entry parsing
- Quickshell Polkit prompt and lock screen
- Event-driven battery monitoring and optional TLP power profiles
- Hyprland session lifecycle integration without requiring UWSM
- Native helper binaries built locally during installation

## Requirements

- Arch Linux, CachyOS, or another distribution with `ID_LIKE=arch`
- systemd
- A normal user account with `sudo`
- A working network connection for package installation
- The regular Hyprland session from your display manager

The design uses two custom fonts:

- `Ndot57-Regular.otf`
- `Ndot77JPExtended.ttf`

They are not redistributed by this repository. The installer detects missing
fonts and prints a warning. See [Installation](docs/INSTALLATION.md#fonts).

## Install

Review the script before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/Moci-cu/unit-4/main/install.sh
```

Interactive installation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Moci-cu/unit-4/main/install.sh)
```

From a local checkout:

```bash
git clone https://github.com/Moci-cu/unit-4.git
cd unit-4
./install.sh
```

The installer:

1. Validates the Arch-based environment.
2. Performs a full `pacman -Syu` transaction with required packages.
3. Backs up existing managed files.
4. Builds the C++ helper programs locally.
5. Overlays `hypr`, `quickshell`, and `kitty` configuration.
6. Preserves `~/.config/hypr/user.conf` and `user.lua`.
7. Installs the Hyprland user-session units.
8. Optionally installs PAM, TLP integration, fonts, and the bundled bashrc.

After installation, log out and enter the regular **Hyprland** session again.

## Configuration

Keep personal Hyprland changes in:

```text
~/.config/hypr/user.conf
~/.config/hypr/user.lua
```

Those files are preserved across installer updates. Wallpapers belong in:

```text
~/Pictures/wallpapers
```

Default shortcuts include:

| Shortcut | Action |
|---|---|
| `Super` | Application launcher |
| `Super+Tab` | Control center |
| `Super+T` | Kitty |
| `Super+P` | Wallpaper picker |
| `Super+L` | Lock session |
| `Super+J` | Toggle bar |
| `Super+N` | Network panel |

## Updating

Pull the repository and rerun the installer:

```bash
git pull --ff-only
./install.sh
```

Reruns are supported. Existing managed directories are backed up and local
state files are retained. Arch partial upgrades are deliberately unsupported.

## Documentation

- [Installation and update guide](docs/INSTALLATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Tested versions](VERSIONS.md)

## License

MIT. See [LICENSE](LICENSE).
