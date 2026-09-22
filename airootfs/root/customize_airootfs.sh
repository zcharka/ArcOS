#!/usr/bin/env bash

# Instalacja arcos-release osobno z --overwrite, bo koliduje z filesystem o /usr/lib/os-release
pacman -S --noconfirm --overwrite '/usr/lib/os-release' arcos-release

# Create user safely
if ! id liveuser >/dev/null 2>&1; then
    # If home exists for some reason, don't use -m, just create it manually
    if [ -d /home/liveuser ]; then
        useradd -G wheel,audio,video,storage,optical,input -s /bin/bash liveuser
    else
        useradd -m -G wheel,audio,video,storage,optical,input -s /bin/bash liveuser
    fi
fi

passwd -d liveuser

echo 'liveuser ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-liveuser
chmod 440 /etc/sudoers.d/10-liveuser

# Rebuild initramfs with Plymouth theme
plymouth-set-default-theme -R ArcOS

# Enable Display Manager and Network
systemctl enable sddm
systemctl enable NetworkManager

# BEGIN ARCOS BUILDER PLASMA SETUP
if pacman -Q plasma-welcome >/dev/null 2>&1; then
    pacman -Rdd --noconfirm plasma-welcome
fi

if [[ -f /etc/xdg/menus/plasma-applications.menu ]]; then
    install -Dm644 \
        /etc/xdg/menus/plasma-applications.menu \
        /etc/xdg/menus/applications.menu
fi

if id liveuser >/dev/null 2>&1; then
    install -d -m 700 -o liveuser -g liveuser /home/liveuser
    cp -a /etc/skel/. /home/liveuser/
    rm -rf /home/liveuser/.local/share/kscreen
    rm -f /home/liveuser/.config/kwinoutputconfig.json

    if [[ -f /etc/xdg/menus/applications.menu ]]; then
        install -Dm644 -o liveuser -g liveuser \
            /etc/xdg/menus/applications.menu \
            /home/liveuser/.config/menus/applications.menu
    fi

    install -d -m 700 -o liveuser -g liveuser \
        /home/liveuser/.cache \
        /home/liveuser/.local/share

    chown -R liveuser:liveuser /home/liveuser
fi
# END ARCOS BUILDER PLASMA SETUP

mkdir -p /usr/share/plasma/look-and-feel/org.arcos.desktop/contents/defaults
cat > /usr/share/plasma/look-and-feel/org.arcos.desktop/contents/defaults << 'INNER'
[Wallpaper][org.kde.image][General]
Image=ArcOS
INNER

cat > /usr/share/plasma/look-and-feel/org.arcos.desktop/metadata.json << 'INNER'
{
    "KPlugin": {
        "Id": "org.arcos.desktop",
        "Name": "ArcOS"
    }
}
INNER

mkdir -p /etc/xdg
cat > /etc/xdg/kdeglobals << 'INNER'
[KDE]
LookAndFeelPackage=org.arcos.desktop
INNER

# Instalacja kinexin-launcher z GitHuba
if [ ! -d "/usr/share/plasma/plasmoids/org.linexin.launcher" ]; then
    git clone https://github.com/Petexy/kinexin-launcher.git /tmp/kinexin-launcher
    # Instalacja plików widgetu globalnie dla wszystkich użytkowników
    mkdir -p /usr/share/plasma/plasmoids/org.linexin.launcher
    cp -r /tmp/kinexin-launcher/package/* /usr/share/plasma/plasmoids/org.linexin.launcher/
    
    # Instalacja ikony launchera globalnie
    mkdir -p /usr/share/icons/hicolor/scalable/apps
    cp /tmp/kinexin-launcher/package/contents/icons/linexin-launcher.svg /usr/share/icons/hicolor/scalable/apps/
    
    # Kompilacja tłumaczeń
    if command -v msgfmt &>/dev/null; then
        for pofile in /tmp/kinexin-launcher/po/*.po; do
            [[ -f "$pofile" ]] || continue
            lang="$(basename "$pofile" .po)"
            mo_dir="/usr/share/locale/$lang/LC_MESSAGES"
            mkdir -p "$mo_dir"
            msgfmt -o "$mo_dir/plasma_applet_org.linexin.launcher.mo" "$pofile"
        done
    fi
    
    rm -rf /tmp/kinexin-launcher
fi

# Instalacja apletu Window Title
if [ ! -d "/usr/share/plasma/plasmoids/org.kde.windowtitle" ]; then
    git clone https://github.com/dhruv8sh/plasma6-window-title-applet.git /tmp/window-title
    mkdir -p /usr/share/plasma/plasmoids/org.kde.windowtitle
    # Fix broken unused import for Plasma 6.7+
    sed -i '/org.kde.plasma.private.appmenu/d' /tmp/window-title/contents/ui/main.qml
    cp -r /tmp/window-title/* /usr/share/plasma/plasmoids/org.kde.windowtitle/
    rm -rf /tmp/window-title
fi

# Instalacja Ikon Tela
if [ ! -d "/usr/share/icons/Tela" ]; then
    git clone https://github.com/vinceliuice/Tela-icon-theme.git /tmp/tela-icons
    /tmp/tela-icons/install.sh
    rm -rf /tmp/tela-icons
fi

# Instalacja Layan KDE
if [ ! -d "/usr/share/plasma/look-and-feel/com.github.vinceliuice.Layan" ]; then
    git clone https://github.com/vinceliuice/Layan-kde.git /tmp/layan-kde
    /tmp/layan-kde/install.sh
    rm -rf /tmp/layan-kde
fi

# Instalacja Layan GTK
if [ ! -d "/usr/share/themes/Layan-Light" ]; then
    git clone https://github.com/vinceliuice/Layan-gtk-theme.git /tmp/layan-gtk
    /tmp/layan-gtk/install.sh
    rm -rf /tmp/layan-gtk
fi

# Instalacja Bibata-Modern-Classic
if [ ! -d "/usr/share/icons/Bibata-Modern-Classic" ]; then
    curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz" -o /tmp/bibata.tar.xz
    tar -xf /tmp/bibata.tar.xz -C /usr/share/icons/
    rm -f /tmp/bibata.tar.xz
fi

# Instalacja rozszerzeń GNOME Shell (systemowo, offline po zbudowaniu ISO)
install_gnome_extension() {
    local UUID="$1"
    local SHELL_VERSION="50"
    local DEST="/usr/share/gnome-shell/extensions/${UUID}"

    if [ -d "$DEST" ]; then
        echo "Extension $UUID already installed, skipping."
        return 0
    fi

    echo "Installing GNOME extension: $UUID ..."

    # Pobierz info o rozszerzeniu z API
    local INFO
    INFO=$(curl -s "https://extensions.gnome.org/extension-info/?uuid=${UUID}&shell_version=${SHELL_VERSION}" 2>/dev/null)

    # Wyciągnij URL do pobrania
    local DOWNLOAD_URL
    DOWNLOAD_URL=$(echo "$INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('download_url',''))" 2>/dev/null)

    if [ -z "$DOWNLOAD_URL" ]; then
        echo "WARNING: Could not find download URL for $UUID (shell $SHELL_VERSION), skipping."
        return 1
    fi

    # Pobierz ZIP i rozpakuj
    mkdir -p "$DEST"
    curl -sL "https://extensions.gnome.org${DOWNLOAD_URL}" -o /tmp/ext.zip
    unzip -qo /tmp/ext.zip -d "$DEST"
    rm -f /tmp/ext.zip
    chmod -R 755 "$DEST"

    echo "Installed $UUID successfully."
}

GNOME_EXTENSIONS=(
    "blur-my-shell@aunetx"
    "accent-directories@taiwbi.com"
    "gtk4-ding@smedius.gitlab.com"
    "dash-to-dock@micxgx.gmail.com"
    "gsconnect@andyholmes.github.io"
    "appindicatorsupport@rgcjonas.gmail.com"
    "rounded-window-corners@fxgn"
    "quick-settings-audio-panel@rayzeq.github.io"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
)

for ext in "${GNOME_EXTENSIONS[@]}"; do
    install_gnome_extension "$ext"
done

