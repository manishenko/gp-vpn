# gp-vpn

Command-line tools and a system tray indicator for connecting to **Palo Alto GlobalProtect VPN** using SAML/Okta authentication on Ubuntu/Debian.

Wraps [`gp-saml-gui`](https://github.com/dlenski/gp-saml-gui) and [`openconnect`](https://www.infradead.org/openconnect/) into a single command. The Okta login window appears only on the first connection (or when the session expires) — subsequent reconnects complete in under a second.

```
gp-connect       # connect (Okta window appears if session expired)
gp-disconnect    # disconnect
gp-status        # show connection status
gp-tray &        # start system tray indicator
```

---

## Requirements

- Ubuntu 22.04+ or Debian 12+ (GNOME on X11 or Wayland)
- `sudo` access
- Internet access to download packages during install

> **macOS / Windows**: not supported. See [Limitations](#limitations).

---

## Installation

```bash
git clone https://github.com/your-username/gp-vpn.git
cd gp-vpn
./install.sh
```

The installer will:
1. Install system packages via `apt`: `openconnect`, `python3-gi`, AppIndicator GIR bindings
2. Install `gp-saml-gui` via `pip3 install --user`
3. Ask for your VPN gateway hostname (e.g. `vpn.company.com`) and save it to `~/.config/gp-vpn/config`
4. Copy CLI scripts to `~/.local/bin/`
5. Install root wrappers to `/usr/local/sbin/` and configure passwordless `sudo` for them
6. Install tray icons and register the tray app for autostart on login

Make sure `~/.local/bin` is in your `PATH`. On Ubuntu 22.04 this is set by default; if not, add to `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## Usage

### CLI

```bash
gp-connect          # open Okta window (if needed), connect in background
gp-connect -v       # same with verbose openconnect output
gp-disconnect       # gracefully disconnect
gp-status           # print status; exit 0 = connected, exit 1 = disconnected
```

### System tray

```bash
gp-tray &
```

Starts a tray icon showing connection state. Left-click or right-click opens a menu with **Connect**, **Disconnect**, and the time connected since. The tray starts automatically on next login after installation.

Only one instance runs at a time — a second `gp-tray` call will exit with an error.

---

## Configuration

Gateway is stored in `~/.config/gp-vpn/config`:

```bash
GP_GATEWAY="vpn.your-company.com"
```

Edit this file to change the gateway without reinstalling. See `config/gp-vpn.conf.example` for reference.

---

## How it works

```
gp-connect
  └─ gp-saml-gui --gateway $GP_GATEWAY
       └─ WebKit2GTK window (Okta SAML login)
            └─ on success: prints HOST= USER= COOKIE= OS= to stdout
  └─ sudo /usr/local/sbin/gp-vpn-connect  (root wrapper)
       └─ openconnect --protocol=gp --background --pid-file=/tmp/gp-vpn.pid
            └─ tun0 interface up, PID written to /tmp/gp-vpn.pid

gp-disconnect
  └─ sudo /usr/local/sbin/gp-vpn-disconnect  (root wrapper)
       └─ kill $PID, rm /tmp/gp-vpn.pid

gp-status
  └─ reads /tmp/gp-vpn.pid
  └─ checks /proc/$PID and tun0 interface
```

Okta session cookies are cached in `~/.gp-saml-gui-cookies/` by `gp-saml-gui`. MFA (push notification / TOTP) is skipped on subsequent logins while the session is valid. The Okta session cookie (`sid`) is a **session cookie** — it is not persisted to disk by WebKit2GTK, so a full re-login is required after reboot or long inactivity. Persistent cookies (`DT`, `luf_*`) are saved, so MFA is not repeated.

---

## Uninstallation

```bash
./uninstall.sh
```

Removes CLI scripts, root wrappers, sudoers entry, icons, and autostart. Optionally removes the config directory and `gp-saml-gui`.

---

## Limitations

**Ubuntu/Debian only.**
The tray uses `gi.AyatanaAppIndicator3` (Linux-specific). The SAML window uses `gp-saml-gui` which requires WebKit2GTK — not natively available on macOS or Windows.

**GNOME with AppIndicator extension required.**
The tray icon needs the `gnome-shell-extension-appindicator` extension enabled. The installer installs it, but you may need to activate it manually:
```bash
gnome-extensions enable ubuntu-appindicators@ubuntu.com
```
Log out and back in after enabling.

**Okta session cookie is not persisted.**
WebKit2GTK 4.0 does not write session cookies (those without `Expires`) to disk. This means after a reboot or long idle period, `gp-connect` will show the full Okta login form again. Persistent cookies (device trust, MFA remember-me) are saved, so you won't need to re-enroll MFA — just enter your password.

**Root wrappers are required.**
`openconnect` must run as root to create a TUN interface. The installer configures passwordless `sudo` for two specific wrapper scripts only — no blanket root access is granted.

**Single gateway.**
The config supports one gateway. If you need to switch gateways, edit `~/.config/gp-vpn/config` directly.

---

## File layout

```
~/.local/bin/
  gp-connect           main connect command
  gp-disconnect        disconnect command
  gp-status            status check (exit 0 = connected)
  gp-tray              system tray indicator

/usr/local/sbin/
  gp-vpn-connect       root wrapper: runs openconnect, suppresses output
  gp-vpn-disconnect    root wrapper: kills openconnect, removes pid file

/etc/sudoers.d/openconnect   passwordless sudo for the two wrappers above
~/.config/gp-vpn/config      gateway hostname
~/.local/share/icons/        gp-vpn-connected.svg, gp-vpn-disconnected.svg
~/.config/autostart/         gp-tray.desktop
/tmp/gp-vpn.pid              runtime pid file (created by openconnect)
```

---

## Troubleshooting

**Tray icon does not appear**
Enable the AppIndicator extension and log out/in:
```bash
gnome-extensions enable ubuntu-appindicators@ubuntu.com
```

**`gp-saml-gui: command not found`**
`~/.local/bin` is not in PATH. Add `export PATH="$HOME/.local/bin:$PATH"` to `~/.bashrc` and restart the terminal.

**`gp-connect` asks for password every time**
The sudoers entry is missing or incorrect. Re-run `./install.sh` or check `/etc/sudoers.d/openconnect`.

**VPN connects but no traffic routes through it**
`openconnect` relies on `vpnc-script` to set up routes. Verify it is installed:
```bash
ls /usr/share/vpnc-scripts/vpnc-script
```
If missing: `sudo apt install vpnc`.
