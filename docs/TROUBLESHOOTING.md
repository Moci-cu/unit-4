# Troubleshooting

## Collect basic status

Run:

```bash
systemctl --user status \
  hyprland-session.target \
  graphical-session.target \
  quickshell.service \
  quickshell-ctrl.service

journalctl --user -b \
  -u quickshell.service \
  -u quickshell-ctrl.service \
  --no-pager
```

The session targets and both Quickshell services should be active after
Hyprland finishes starting.

## Quickshell crashes with an XCB error during login

Typical messages:

```text
could not connect to display
Could not load the Qt platform plugin "xcb"
```

This means Quickshell started before the Wayland environment was imported.
Check that desktop services are not enabled on `default.target`:

```bash
systemctl --user is-enabled \
  quickshell.service quickshell-ctrl.service
```

The expected result is `static`, not `enabled`. Rerun the installer to remove
legacy `default.target.wants` links.

Also verify:

```bash
systemctl --user show-environment | grep -E \
  '^(WAYLAND_DISPLAY|HYPRLAND_INSTANCE_SIGNATURE|XDG_CURRENT_DESKTOP)='
```

## Portal is inactive or applications use a light theme

Check:

```bash
systemctl --user status \
  graphical-session.target \
  xdg-desktop-portal.service \
  xdg-desktop-portal-hyprland.service
```

Read the current appearance preference:

```bash
gdbus call --session \
  --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.Read \
  org.freedesktop.appearance color-scheme
```

`uint32 1` means dark mode. If `graphical-session.target` is inactive, confirm
that `systemd-session.sh` is present and executable, then log out and back in.

## Wi-Fi shows only Loopback

First distinguish a system networking problem from a Control Center problem:

```bash
systemctl status NetworkManager iwd
nmcli -f DEVICE,TYPE,STATE,CONNECTION device status
rfkill list
ip -brief link
```

If `wlan0` or the relevant wireless interface is absent, inspect the current
boot:

```bash
journalctl -b -u NetworkManager -u iwd --no-pager
dmesg | grep -iE 'wifi|wlan|firmware|ath|iwl|rtw'
```

If `nmcli` sees Wi-Fi but Control Center does not, restart only the Control
Center:

```bash
systemctl --user restart quickshell-ctrl.service
```

The Scan action uses both Quickshell's native network API and:

```bash
nmcli --wait 8 device wifi list --rescan yes
```

You can test the fallback directly with that command.

## NetworkManager and iwd

Check the selected backend:

```bash
grep -R 'wifi.backend' \
  /etc/NetworkManager/NetworkManager.conf \
  /etc/NetworkManager/conf.d 2>/dev/null
```

When NetworkManager uses `wifi.backend=iwd`, both NetworkManager and iwd should
be running. Without that setting, do not independently enable iwd unless you
know it will not compete with NetworkManager.

## Missing or incorrect fonts

Check:

```bash
fc-match "Ndot 57"
fc-match "Ndot77JPExtended"
```

If they resolve to another family, install the required files:

```bash
./install.sh --no-packages --no-services --no-pam \
  --font-dir /path/to/fonts
```

Then restart Quickshell:

```bash
systemctl --user restart quickshell.service quickshell-ctrl.service
```

## Bar or Control Center does not reload

Validate service state and recent logs:

```bash
systemctl --user restart quickshell.service quickshell-ctrl.service
journalctl --user -u quickshell.service -u quickshell-ctrl.service \
  --since "-1 minute" --no-pager
```

`Configuration Loaded` without a following QML error means the configuration
parsed successfully.

## TLP controls are missing

Check:

```bash
command -v tlpctl
tlpctl get
systemctl status tlp.service tlp-pd.service
```

Install the integration with:

```bash
./install.sh --no-services --with-power
sudo systemctl enable --now tlp.service tlp-pd.service
```

Do not combine `tlp-pd` with `power-profiles-daemon` or `tuned-ppd`.

## Restore a backup

Backups are stored below:

```text
~/.local/state/unit-4/backups
```

Log out of Hyprland before restoring a full configuration. Example:

```bash
cp -a ~/.local/state/unit-4/backups/TIMESTAMP/config/quickshell/. \
  ~/.config/quickshell/
```

After restoring user units:

```bash
systemctl --user daemon-reload
```
