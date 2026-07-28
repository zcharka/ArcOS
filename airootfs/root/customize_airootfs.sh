#!/usr/bin/env bash

useradd -m -G wheel,audio,video,storage,optical,input -s /bin/bash arcos
passwd -d arcos

echo 'arcos ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-arcos
chmod 440 /etc/sudoers.d/10-arcos

systemctl enable sddm
systemctl enable NetworkManager

# BEGIN ARCOS BUILDER PLASMA SETUP
# Ten blok jest zarządzany automatycznie przez ArcOS Builder.

# Plasma 6 uruchamia Welcome Center przez moduł KDED. Usunięcie pakietu
# jest bardziej deterministyczne niż poleganie na kluczu ShouldShow.
if pacman -Q plasma-welcome >/dev/null 2>&1; then
    pacman -Rdd --noconfirm plasma-welcome
fi

# Używamy zwykłego applications.menu, aby launcher nie zależał od tego,
# czy XDG_MENU_PREFIX został odziedziczony przez całą sesję SDDM/Plasma.
if [[ -f /etc/xdg/menus/plasma-applications.menu ]]; then
    install -Dm644 \
        /etc/xdg/menus/plasma-applications.menu \
        /etc/xdg/menus/applications.menu
fi

if id arcos >/dev/null 2>&1; then
    install -d -m 700 -o arcos -g arcos /home/arcos

    # Skopiuj aktualny /etc/skel nawet wtedy, gdy konto istniało wcześniej.
    cp -a /etc/skel/. /home/arcos/

    # Usuń konfiguracje ekranu przeniesione przypadkiem z hosta.
    rm -rf /home/arcos/.local/share/kscreen
    rm -f /home/arcos/.config/kwinoutputconfig.json

    # Daj użytkownikowi własną kopię menu.
    if [[ -f /etc/xdg/menus/applications.menu ]]; then
        install -Dm644 -o arcos -g arcos \
            /etc/xdg/menus/applications.menu \
            /home/arcos/.config/menus/applications.menu
    fi

    install -d -m 700 -o arcos -g arcos \
        /home/arcos/.cache \
        /home/arcos/.local/share

    chown -R arcos:arcos /home/arcos

fi
# END ARCOS BUILDER PLASMA SETUP
