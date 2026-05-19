#!/usr/bin/env bash
set -euo pipefail

echo "=== GP VPN Uninstaller ==="
echo ""

# Stop tray if running
if [[ -f /tmp/gp-tray.lock ]]; then
    TRAY_PID=$(cat /tmp/gp-tray.lock 2>/dev/null || true)
    if [[ -n "$TRAY_PID" ]] && [[ -d "/proc/$TRAY_PID" ]]; then
        echo "Stopping gp-tray (pid $TRAY_PID)..."
        kill "$TRAY_PID" 2>/dev/null || true
        sleep 0.5
    fi
fi

# Disconnect VPN if connected
if [[ -f /tmp/gp-vpn.pid ]]; then
    echo "Disconnecting VPN..."
    "$HOME/.local/bin/gp-disconnect" 2>/dev/null \
        || sudo /usr/local/sbin/gp-vpn-disconnect 2>/dev/null \
        || true
fi

echo "Removing CLI scripts..."
rm -f \
    "$HOME/.local/bin/gp-connect" \
    "$HOME/.local/bin/gp-disconnect" \
    "$HOME/.local/bin/gp-status" \
    "$HOME/.local/bin/gp-tray"

echo "Removing root wrappers..."
sudo rm -f /usr/local/sbin/gp-vpn-connect /usr/local/sbin/gp-vpn-disconnect

echo "Removing sudoers entry..."
sudo rm -f /etc/sudoers.d/openconnect

echo "Removing icons..."
rm -f \
    "$HOME/.local/share/icons/gp-vpn-connected.svg" \
    "$HOME/.local/share/icons/gp-vpn-disconnected.svg"

echo "Removing autostart..."
rm -f "$HOME/.config/autostart/gp-tray.desktop"

echo ""
read -rp "Remove VPN config (~/.config/gp-vpn/)? [y/N] " REMOVE_CONFIG
if [[ "${REMOVE_CONFIG,,}" == "y" ]]; then
    rm -rf "$HOME/.config/gp-vpn"
    echo "Config removed."
fi

read -rp "Uninstall gp-saml-gui (pip)? [y/N] " REMOVE_SAML
if [[ "${REMOVE_SAML,,}" == "y" ]]; then
    pip3 uninstall -y gp-saml-gui 2>/dev/null || true
    echo "gp-saml-gui removed."
fi

echo ""
echo "=== Uninstall complete ==="
