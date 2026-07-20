#!/bin/bash
# install.sh - Ein-Befehl-Installation für DanlTechOS

set -e

echo "========================================"
echo "  DanlTechOS Installer"
echo "========================================"

# Repository zu pacman.conf hinzufügen
if ! grep -q "^\[danltechos\]" /etc/pacman.conf; then
    echo "" | sudo tee -a /etc/pacman.conf
    echo "# DanlTechOS Custom Repository" | sudo tee -a /etc/pacman.conf
    echo "[danltechos]" | sudo tee -a /etc/pacman.conf
    echo "SigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf
    echo "Server = https://danltech.github.io/danltechos-repo/x86_64" | sudo tee -a /etc/pacman.conf
    echo "✓ Repository hinzugefügt"
else
    echo "ℹ Repository bereits vorhanden"
fi

# GPG-Schlüssel importieren
curl -sL https://danltech.github.io/danltechos-repo/danltechos-repo-key.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key "DanlTechOS Repository" 2>/dev/null || true

# Paketdatenbank aktualisieren und Setup installieren
sudo pacman -Sy --noconfirm
sudo pacman -S --noconfirm danltechos-setup

echo ""
echo "✅ DanlTechOS erfolgreich installiert!"
echo "Führe aus: danltechos-help für verfügbare Befehle"
