# Tested versions

Last verified on 2026-06-12 using CachyOS.

| Component | Tested version |
|---|---:|
| Hyprland | 0.55.3 |
| Hyprlock | 0.9.5 |
| Hypridle | 0.1.7 |
| Quickshell | 0.3.0 |
| awww | 0.12.1 |
| NetworkManager | 1.56.1 |
| iwd backend | 3.12 |
| PipeWire | 1.6.6 |
| TLP / tlp-pd | 1.10.1 |

Arch and CachyOS are rolling distributions. These versions describe the most
recent validated environment; they are not strict pins.

The installer deliberately performs a full `pacman -Syu` transaction and does
not fetch isolated historical packages from the Arch Linux Archive. Partial
upgrades are unsupported on Arch.

When a current package update causes a regression:

1. Confirm the failure in `journalctl`.
2. Check the package's upstream issue tracker.
3. Use an existing package from `/var/cache/pacman/pkg` only as a temporary
   rollback.
4. Add the package to `IgnorePkg` only while tracking the incompatibility.

See [Troubleshooting](docs/TROUBLESHOOTING.md) for service-specific checks.
