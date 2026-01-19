#!/bin/bash

set -e

BG_COLOR="#1e1e2e"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  INSTALACAO AMBIENTE DE DESENVOLVIMENTO BY BRUNO FOGGIATTO    ${NC}"
echo -e "${BLUE}  Versao 1.0.0                                                 ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Erro! Execute como root: sudo bash $0${NC}"
    exit 1
fi

if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo -e "${RED}Erro: Nao foi possivel identificar o usuario.${NC}"
    echo -e "${YELLOW}Execute como: sudo bash $0${NC}"
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)

echo -e "${GREEN}Usuario:${NC} $USER_NAME"
echo -e "${GREEN}Home:${NC} $HOME_DIR"
echo ""

if ! command -v apt-get &> /dev/null; then
    echo -e "${RED}Este script e para sistemas baseados em Debian/Ubuntu${NC}"
    exit 1
fi

echo -e "${YELLOW}[Preparacao] Limpando locks...${NC}"
rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
rm -f /var/lib/dpkg/lock 2>/dev/null || true
rm -f /var/cache/apt/archives/lock 2>/dev/null || true

echo ""
echo -e "${GREEN}[1/6] Instalando pacotes base...${NC}"

apt-get update -qq

apt-get install -y --no-install-recommends \
    xrdp \
    xorgxrdp \
    xserver-xorg-core \
    xserver-xorg-input-all \
    x11-xserver-utils \
    dbus-x11 \
    wget \
    gpg \
    apt-transport-https \
    ca-certificates \
    openbox \
    terminator \
    fonts-liberation

echo -e "${GREEN}  Pacotes base instalados${NC}"

echo ""
echo -e "${GREEN}[2/6] Instalando VSCodium...${NC}"

if ! command -v codium >/dev/null 2>&1; then
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    
    echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
        | tee /etc/apt/sources.list.d/vscodium.list
    
    apt-get update -qq
    apt-get install -y --no-install-recommends codium
    
    echo -e "${GREEN}  VSCodium instalado${NC}"
else
    echo -e "${GREEN}  VSCodium ja esta instalado${NC}"
fi

echo ""
echo -e "${GREEN}[3/6] Configurando VSCodium...${NC}"

killall codium 2>/dev/null || true
sleep 1

mkdir -p "$HOME_DIR/.config/VSCodium/User"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"

sudo -u $USER_NAME codium --no-sandbox \
    --user-data-dir "$HOME_DIR/.config/VSCodium" \
    --install-extension dracula-theme.theme-dracula --force 2>/dev/null || true

sudo -u $USER_NAME codium --no-sandbox \
    --user-data-dir "$HOME_DIR/.config/VSCodium" \
    --install-extension PKief.material-icon-theme --force 2>/dev/null || true

cat > "$HOME_DIR/.config/VSCodium/User/settings.json" <<'EOF'
{
  "workbench.colorTheme": "Dracula",
  "workbench.iconTheme": "material-icon-theme",
  "editor.fontSize": 14,
  "editor.fontFamily": "'Cascadia Code', 'Fira Code', 'Consolas', monospace",
  "window.menuBarVisibility": "toggle",
  "window.titleBarStyle": "native",
  "editor.minimap.enabled": false,
  "workbench.startupEditor": "none",
  "window.commandCenter": false,
  "security.workspace.trust.enabled": false,
  "git.openRepositoryInParentFolders": "always",
  "editor.smoothScrolling": false,
  "workbench.list.smoothScrolling": false,
  "terminal.integrated.smoothScrolling": false,
  "window.newWindowDimensions": "maximized",
  "window.restoreFullscreen": true,
  "zenMode.fullScreen": true,
  "zenMode.hideLineNumbers": false,
  "zenMode.hideTabs": false
}
EOF

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/VSCodium"

echo -e "${GREEN}  VSCodium configurado${NC}"

echo ""
echo -e "${GREEN}[4/6] Configurando Openbox...${NC}"

mkdir -p "$HOME_DIR/.config/openbox"

cat > "$HOME_DIR/.config/openbox/rc.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
  </placement>
  
  <theme>
    <name>Clearlooks</name>
    <keepBorder>no</keepBorder>
    <font place="ActiveWindow"><name>sans</name><size>12</size></font>
    <font place="InactiveWindow"><name>sans</name><size>12</size></font>
  </theme>
  
  <desktops><number>1</number></desktops>
  
  <keyboard>
    <keybind key="A-Tab"><action name="NextWindow"/></keybind>
    <keybind key="C-A-t"><action name="Execute"><command>terminator</command></action></keybind>
    <keybind key="A-F4"><action name="Close"/></keybind>
    <keybind key="F11"><action name="ToggleFullscreen"/></keybind>
  </keyboard>
  
  <applications>
    <application class="VSCodium">
      <decor>no</decor>
      <fullscreen>yes</fullscreen>
      <layer>normal</layer>
      <focus>yes</focus>
    </application>
    
    <application class="Terminator">
      <decor>yes</decor>
      <fullscreen>no</fullscreen>
      <layer>above</layer>
    </application>
  </applications>
</openbox_config>
EOF

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/openbox"

echo -e "${GREEN}  Openbox configurado${NC}"

echo ""
echo -e "${GREEN}[5/6] Configurando XRDP...${NC}"

if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/tcp_nodelay=false/tcp_nodelay=true/g' /etc/xrdp/xrdp.ini 2>/dev/null || true
    sed -i 's/max_bpp=32/max_bpp=24/g' /etc/xrdp/xrdp.ini 2>/dev/null || true
fi

cat > "$HOME_DIR/.xsession" <<'XSESSION_CONTENT'
#!/bin/bash
exec > /tmp/xsession-debug.log 2>&1
echo "Iniciando .xsession em $(date)"

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=openbox
export DESKTOP_SESSION=openbox

exec openbox-session
XSESSION_CONTENT

chmod +x "$HOME_DIR/.xsession"
chown $USER_NAME:$USER_NAME "$HOME_DIR/.xsession"

if [ -f /etc/xrdp/startwm.sh ]; then
    cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.backup.$(date +%Y%m%d-%H%M%S)
fi

cat > /etc/xrdp/startwm.sh <<'STARTWM_CONTENT'
#!/bin/sh
exec > /tmp/startwm-debug.log 2>&1
echo "Iniciando startwm.sh em $(date)"

if [ -r /etc/default/locale ]; then
    . /etc/default/locale
    export LANG LANGUAGE
fi

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=openbox
export DESKTOP_SESSION=openbox

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

if [ -f "$HOME/.xsession" ]; then
    exec dbus-launch --exit-with-session "$HOME/.xsession"
else
    exec dbus-launch --exit-with-session openbox-session
fi
STARTWM_CONTENT

chmod +x /etc/xrdp/startwm.sh

cat > "$HOME_DIR/.config/openbox/autostart" <<'AUTOSTART_CONTENT'
#!/bin/bash
exec > /tmp/openbox-autostart.log 2>&1
echo "Autostart iniciado em $(date)"

setxkbmap -layout br -variant abnt2 &

xset s off &
xset -dpms &
xset s noblank &

xsetroot -solid "#1e1e2e" &

sleep 1

codium --disable-gpu --no-sandbox --disable-dev-shm-usage --disable-software-rasterizer --disable-smooth-scrolling &

echo "VSCodium iniciado em $(date)"
AUTOSTART_CONTENT

chmod +x "$HOME_DIR/.config/openbox/autostart"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"

echo -e "${GREEN}  XRDP configurado${NC}"

echo ""
echo -e "${GREEN}[6/6] Finalizando...${NC}"

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"
chown $USER_NAME:$USER_NAME "$HOME_DIR/.xsession"

adduser $USER_NAME ssl-cert 2>/dev/null || true

if [ -f /etc/xrdp/key.pem ]; then
    chmod 640 /etc/xrdp/key.pem
    chgrp ssl-cert /etc/xrdp/key.pem
fi

systemctl enable xrdp
systemctl enable xrdp-sesman
systemctl restart xrdp
systemctl restart xrdp-sesman

sleep 2

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}   VERIFICANDO...                                               ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

[ -f "$HOME_DIR/.xsession" ] && echo -e "${GREEN}  .xsession OK${NC}" || echo -e "${RED}  .xsession ERRO${NC}"
[ -f /etc/xrdp/startwm.sh ] && echo -e "${GREEN}  startwm.sh OK${NC}" || echo -e "${RED}  startwm.sh ERRO${NC}"
command -v openbox-session >/dev/null && echo -e "${GREEN}  openbox OK${NC}" || echo -e "${RED}  openbox ERRO${NC}"
command -v codium >/dev/null && echo -e "${GREEN}  VSCodium OK${NC}" || echo -e "${RED}  VSCodium ERRO${NC}"
systemctl is-active --quiet xrdp && echo -e "${GREEN}  xrdp rodando${NC}" || echo -e "${RED}  xrdp parado${NC}"
systemctl is-active --quiet xrdp-sesman && echo -e "${GREEN}  xrdp-sesman rodando${NC}" || echo -e "${RED}  xrdp-sesman parado${NC}"

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}   INSTALACAO CONCLUIDA COM SUCESSO!!                          ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "  Usuario: ${GREEN}$USER_NAME${NC}"
echo -e "  Porta RDP: ${GREEN}3389${NC}"
echo -e "  Teclado: ${GREEN}ABNT2${NC}"
echo ""
echo -e "  ${YELLOW}Atalhos:${NC}"
echo -e "    ${GREEN}Ctrl+Alt+T${NC} - Abrir terminal"
echo -e "    ${GREEN}F11${NC}        - Toggle fullscreen"
echo -e "    ${GREEN}Alt+F4${NC}     - Fechar janela"
echo ""
echo -e "  ${YELLOW}Reinicie a maquina:${NC}"
echo -e "  ${BLUE}sudo reboot${NC}"
echo ""
