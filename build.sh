#!/bin/bash
set -e  # Bei Fehler abbrechen

# =====================================================
# DANLTECHOS ISO Builder
# =====================================================

# Konfiguration
ISO_NAME="danltechos"
REPO_NAME="danltechos-repo"
REPO_URL="https://${GITHUB_USERNAME}.github.io/${REPO_NAME}/x86_64"
GITHUB_USERNAME="danltech"  # HIER ANPASSEN!
BUILD_DIR="$HOME/danltechos-builder"
ISO_REPO_DIR="$BUILD_DIR/endeavouros-iso"
ASSETS_DIR="$BUILD_DIR/assets"
REPO_DIR="$BUILD_DIR/repo"

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== DANLTECHOS ISO Builder ===${NC}"

# 1. Repository klonen oder aktualisieren
if [ -d "$ISO_REPO_DIR" ]; then
    echo -e "${YELLOW}Repository existiert bereits, aktualisiere...${NC}"
    cd "$ISO_REPO_DIR"
    git pull
else
    echo -e "${GREEN}Klone EndeavourOS-ISO Repository...${NC}"
    git clone https://github.com/endeavouros-team/EndeavourOS-ISO.git "$ISO_REPO_DIR"
    cd "$ISO_REPO_DIR"
fi

# 2. Assets in airootfs kopieren
echo -e "${GREEN}Kopiere angepasste Dateien...${NC}"
cp -r "$ASSETS_DIR/etc/"* "$ISO_REPO_DIR/airootfs/etc/" 2>/dev/null || true
cp -r "$ASSETS_DIR/usr/"* "$ISO_REPO_DIR/airootfs/usr/" 2>/dev/null || true
cp -r "$ASSETS_DIR/skel/"* "$ISO_REPO_DIR/airootfs/etc/skel/" 2>/dev/null || true

# 3. pacman.conf anpassen (eigenes Repository hinzufügen)
echo -e "${GREEN}Füge eigenes Repository zu pacman.conf hinzu...${NC}"
cat >> "$ISO_REPO_DIR/airootfs/etc/pacman.conf" << EOF

# DANLTECHOS Custom Repository
[${REPO_NAME}]
SigLevel = Optional TrustAll
Server = ${REPO_URL}
EOF

# 4. GPG-Key für Repository einrichten (falls vorhanden)
if [ -f "$BUILD_DIR/gpg/public.asc" ]; then
    echo -e "${GREEN}Richte GPG-Key ein...${NC}"
    mkdir -p "$ISO_REPO_DIR/airootfs/etc/pacman.d/gnupg"
    cp "$BUILD_DIR/gpg/public.asc" "$ISO_REPO_DIR/airootfs/etc/pacman.d/gnupg/"
    # Key in den Trust-Store importieren
    cat >> "$ISO_REPO_DIR/run_before_squashfs.sh" << 'EOF'
# GPG Key für eigenes Repository importieren
gpg --import /etc/pacman.d/gnupg/public.asc 2>/dev/null || true
EOF
fi

# 5. packages.x86_64 anpassen (eigene Pakete hinzufügen)
# HIER deine eigenen Pakete aus dem Repo eintragen
echo -e "${YELLOW}HINWEIS: Füge deine Pakete manuell zu packages.x86_64 hinzu${NC}"
echo "# DANLTECHOS Custom Packages" >> "$ISO_REPO_DIR/packages.x86_64"
echo "# mein-eigenes-paket" >> "$ISO_REPO_DIR/packages.x86_64"

# 6. profiledef.sh anpassen (ISO-Metadaten)
echo -e "${GREEN}Passe ISO-Metadaten an...${NC}"
sed -i "s/iso_name=.*/iso_name=\"${ISO_NAME}\"/" "$ISO_REPO_DIR/profiledef.sh"
sed -i "s/iso_label=.*/iso_label=\"${ISO_NAME^^}_\$(date +%Y%m)\"/" "$ISO_REPO_DIR/profiledef.sh"
sed -i "s/iso_publisher=.*/iso_publisher=\"DanlTechOS <https:\/\/github.com\/${GITHUB_USERNAME}\>\"/" "$ISO_REPO_DIR/profiledef.sh"
sed -i "s/iso_application=.*/iso_application=\"DanlTechOS Linux Distribution\"/" "$ISO_REPO_DIR/profiledef.sh"

# 7. eos-hooks deaktivieren (optional)
# echo -e "${YELLOW}Deaktiviere eos-hooks (für eigene Branding)...${NC}"
# sed -i 's/^eos-hooks/#eos-hooks/' "$ISO_REPO_DIR/packages.x86_64"

# 8. ISO bauen
echo -e "${GREEN}Baue ISO... (dies kann einige Zeit dauern)${NC}"
cd "$ISO_REPO_DIR"
sudo rm -rf work/
sudo ./mkarchiso -v .

# 9. ISO in den Build-Ordner kopieren
echo -e "${GREEN}Kopiere fertige ISO...${NC}"
if [ -d "out" ]; then
    cp out/*.iso "$BUILD_DIR/"
    echo -e "${GREEN}ISO erfolgreich erstellt:${NC}"
    ls -lh "$BUILD_DIR"/*.iso
fi

# 10. Repository-Pakete bauen (optional)
echo -e "\n${YELLOW}Möchtest du jetzt Pakete für dein Repository bauen? (j/n)${NC}"
read -r answer
if [[ "$answer" == "j" || "$answer" == "J" ]]; then
    echo -e "${GREEN}Baue Pakete...${NC}"
    cd "$REPO_DIR/x86_64"

    # Beispiel: Ein eigenes Paket bauen
    # for pkg in *.PKGBUILD; do
    #     makepkg -si --noconfirm
    # done

    # Repository-Datenbank aktualisieren
    repo-add "${REPO_NAME}.db.tar.gz" *.pkg.tar.zst
    echo -e "${GREEN}Repository aktualisiert!${NC}"
fi

echo -e "${GREEN}=== Build abgeschlossen! ===${NC}"
