#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gp-vpn"
CONFIG_FILE="$CONFIG_DIR/config"

echo "=== GP VPN Installer ==="
echo ""

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Do not run as root. The script uses sudo where needed." >&2
    exit 1
fi

# 1. System packages
echo "[1/7] Installing system packages..."
# AppIndicator GIR package name differs by Ubuntu release
if apt-cache show gir1.2-ayatanaappindicator3-0.1 >/dev/null 2>&1; then
    APPINDICATOR_PKG="gir1.2-ayatanaappindicator3-0.1"
else
    APPINDICATOR_PKG="gir1.2-appindicator3-0.1"
fi
sudo apt-get install -y \
    openconnect \
    python3-gi \
    python3-gi-cairo \
    "$APPINDICATOR_PKG" \
    gnome-shell-extension-appindicator \
    python3-pip
echo "    OK"

# 2. gp-saml-gui
echo "[2/7] Installing gp-saml-gui..."
pip3 install --user --quiet gp-saml-gui
echo "    OK"

# 3. Gateway config
echo "[3/7] Configuring VPN gateway..."
DEFAULT_GATEWAY=""
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    DEFAULT_GATEWAY="${GP_GATEWAY:-}"
fi

if [[ -n "$DEFAULT_GATEWAY" ]]; then
    read -rp "    VPN gateway [$DEFAULT_GATEWAY]: " INPUT_GATEWAY
    GP_GATEWAY="${INPUT_GATEWAY:-$DEFAULT_GATEWAY}"
else
    read -rp "    VPN gateway (e.g. vpn.company.com): " GP_GATEWAY
    while [[ -z "$GP_GATEWAY" ]]; do
        read -rp "    Gateway cannot be empty. Enter VPN gateway: " GP_GATEWAY
    done
fi

mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
GP_GATEWAY="$GP_GATEWAY"
EOF
echo "    Saved: $CONFIG_FILE"

# 4. CLI scripts
echo "[4/7] Installing CLI scripts..."
mkdir -p "$HOME/.local/bin"
cp "$REPO_DIR/bin/gp-connect"    "$HOME/.local/bin/gp-connect"
cp "$REPO_DIR/bin/gp-disconnect" "$HOME/.local/bin/gp-disconnect"
cp "$REPO_DIR/bin/gp-status"     "$HOME/.local/bin/gp-status"
cp "$REPO_DIR/bin/gp-tray"       "$HOME/.local/bin/gp-tray"
chmod +x \
    "$HOME/.local/bin/gp-connect" \
    "$HOME/.local/bin/gp-disconnect" \
    "$HOME/.local/bin/gp-status" \
    "$HOME/.local/bin/gp-tray"
echo "    OK"

# 5. Root wrappers
echo "[5/7] Installing root wrappers and sudoers..."
sudo cp "$REPO_DIR/sbin/gp-vpn-connect"    /usr/local/sbin/gp-vpn-connect
sudo cp "$REPO_DIR/sbin/gp-vpn-disconnect" /usr/local/sbin/gp-vpn-disconnect
sudo chmod 755 /usr/local/sbin/gp-vpn-connect /usr/local/sbin/gp-vpn-disconnect
sudo chown root:root /usr/local/sbin/gp-vpn-connect /usr/local/sbin/gp-vpn-disconnect

USER_LINE="$(whoami) ALL=(root) NOPASSWD: /usr/sbin/openconnect, /usr/local/sbin/gp-vpn-disconnect, /usr/local/sbin/gp-vpn-connect"
TMPFILE=$(mktemp)
echo "$USER_LINE" > "$TMPFILE"
if sudo visudo -cf "$TMPFILE" >/dev/null 2>&1; then
    sudo cp "$TMPFILE" /etc/sudoers.d/openconnect
    sudo chmod 440 /etc/sudoers.d/openconnect
    sudo chown root:root /etc/sudoers.d/openconnect
    rm -f "$TMPFILE"
    echo "    OK"
else
    echo "    ERROR: sudoers validation failed" >&2
    rm -f "$TMPFILE"
    exit 1
fi

# 6. Icons + autostart
echo "[6/7] Installing icons and autostart..."
mkdir -p "$HOME/.local/share/icons"
cp "$REPO_DIR/icons/gp-vpn-connected.svg"    "$HOME/.local/share/icons/"
cp "$REPO_DIR/icons/gp-vpn-disconnected.svg" "$HOME/.local/share/icons/"

mkdir -p "$HOME/.config/autostart"
sed "s|__HOME__|$HOME|g" "$REPO_DIR/desktop/gp-tray.desktop" \
    > "$HOME/.config/autostart/gp-tray.desktop"
echo "    OK"

# 7. Verify
echo "[7/7] Verifying..."
if sudo -n openconnect --version >/dev/null 2>&1; then
    echo "    sudo -n openconnect: OK"
else
    echo "    WARNING: passwordless sudo not working — check /etc/sudoers.d/openconnect"
fi
if command -v gp-saml-gui >/dev/null 2>&1; then
    echo "    gp-saml-gui: OK"
else
    echo "    WARNING: gp-saml-gui not found in PATH"
    echo "    Make sure ~/.local/bin is in PATH (add to ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\")"
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "  gp-connect      connect to VPN (gateway: $GP_GATEWAY)"
echo "  gp-connect -v   connect with verbose output"
echo "  gp-disconnect   disconnect"
echo "  gp-status       show connection status"
echo "  gp-tray &       start system tray indicator"
echo ""
echo "Tray will start automatically on next login."
echo "To start it now:  gp-tray &"
