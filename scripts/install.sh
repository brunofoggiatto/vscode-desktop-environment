#!/bin/bash

set -e

# CONFIGURAÇÕES BASICAS
WALLPAPER_URL="https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=60&w=1280&auto=format&fit=crop"
BG_COLOR="#282a36"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Iniciando instalação (Versão Anti-Blue Screen + ABNT2)..."

# Verifica root
if [ "$EUID" -ne 0 ]; then 
    echo "Erro!! Rode como root"
    exit 1
fi

# Identifica usuário real
if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo "Erro: Não foi possível identificar o usuário. Rode como sudo."
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)

# LIMPEZA 
rm -f /etc/apt/preferences.d/mozilla-firefox 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true

# PERGUNTAS DE INSTALAO

echo ""
echo -e "${YELLOW}Escolha os Programas ${NC}"

INSTALL_CHROME="n"
read -p "1. Deseja Instalar o Google Chrome? (s/n): " resp_chrome
if [[ "$resp_chrome" =~ ^[Ss]$ ]]; then INSTALL_CHROME="s"; fi

INSTALL_NOTES="n"
read -p "2. Deseja Instalar um Bloco de Notas? (s/n): " resp_notes
if [[ "$resp_notes" =~ ^[Ss]$ ]]; then INSTALL_NOTES="s"; fi

# 1. INSTALAÇÃO BASE 

echo -e "${GREEN}[1/8] Instalando Base Gráfica...${NC}"

apt-get update -qq
apt-get install -y wget gpg apt-transport-https

# Pacotes essenciais
apt-get install -y --no-install-recommends xrdp openbox obconf x11-xserver-utils dbus-x11 wmctrl tint2 curl gnupg build-essential git python3-pip fonts-liberation pcmanfm terminator feh ca-certificates

# 2. INSTALAÇÃO APPS 
echo -e "${GREEN}[2/8] Instalando aplicações...${NC}"

TINT2_LAUNCHERS=""

# Chrome
if [ "$INSTALL_CHROME" == "s" ]; then
    echo " -> Instalando Chrome..."
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y ./google-chrome-stable_current_amd64.deb || apt-get install -f -y
    rm -f google-chrome-stable_current_amd64.deb
    TINT2_LAUNCHERS+=$'\nlauncher_item_app = /usr/share/applications/google-chrome.desktop'
fi

# Apps Padrão
TINT2_LAUNCHERS+=$'\nlauncher_item_app = /usr/share/applications/pcmanfm.desktop'
TINT2_LAUNCHERS+=$'\nlauncher_item_app = /usr/share/applications/terminator.desktop'

# Featherpad
if [ "$INSTALL_NOTES" == "s" ]; then
    apt-get install -y --no-install-recommends featherpad
    FP_PATH=$(find /usr/share/applications -name "*featherpad.desktop" | head -n 1)
    if [ -n "$FP_PATH" ]; then
        TINT2_LAUNCHERS+=$'\nlauncher_item_app = '"$FP_PATH"
    else
        TINT2_LAUNCHERS+=$'\nlauncher_item_app = /usr/share/applications/featherpad.desktop'
    fi
fi

# 3. VSCODIUM 

echo -e "${GREEN}[3/8] Instalando Ambiente de Desenvolvimento...${NC}"

if ! command -v codium >/dev/null 2>&1; then
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' | tee /etc/apt/sources.list.d/vscodium.list
    apt-get update -qq
    apt-get install -y --no-install-recommends codium
fi

# 4. CONFIGURAÇÃO AMBIENTE

echo -e "${GREEN}[4/8] Configurando Ambiente...${NC}"
killall codium 2>/dev/null || true
mkdir -p "$HOME_DIR/.config/VSCodium/User"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"

# Instala extensões
sudo -u $USER_NAME codium --no-sandbox --user-data-dir "$HOME_DIR/.config/VSCodium" --install-extension dracula-theme.theme-dracula --force 
sudo -u $USER_NAME codium --no-sandbox --user-data-dir "$HOME_DIR/.config/VSCodium" --install-extension PKief.material-icon-theme --force 

# Configurações performance
cat > "$HOME_DIR/.config/VSCodium/User/settings.json" <<'EOF'
{
  "workbench.colorTheme": "Dracula",
  "workbench.iconTheme": "material-icon-theme",
  "editor.fontSize": 14,
  "editor.fontFamily": "'Cascadia Code', 'Fira Code', 'Consolas', monospace",
  "window.menuBarVisibility": "classic",
  "window.titleBarStyle": "native",
  "editor.minimap.enabled": false,
  "workbench.startupEditor": "none",
  "window.commandCenter": false,
  "security.workspace.trust.enabled": false,
  "git.openRepositoryInParentFolders": "always",
  "editor.smoothScrolling": false,
  "workbench.list.smoothScrolling": false,
  "terminal.integrated.smoothScrolling": false
}
EOF
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/VSCodium"

# 5. TINT2

echo -e "${GREEN}[5/8] Gerando Barra de Tarefas...${NC}"
mkdir -p "$HOME_DIR/.config/tint2"

cat > "$HOME_DIR/.config/tint2/tint2rc" <<EOF
# Configuração Tint2
panel_mode = multi_monitor
panel_position = bottom center horizontal
panel_size = 100% 65
panel_margin = 0 0
panel_padding = 4 4 4
panel_background_id = 1
wm_menu = 0
panel_dock = 0
panel_layer = top
strut_policy = follow_size
panel_window_name = tint2
panel_items = LTC

# LAUNCHERS
launcher_icon_theme = Adwaita
launcher_padding = 10 4 10
launcher_background_id = 0
launcher_icon_background_id = 0
launcher_icon_size = 48

$TINT2_LAUNCHERS

# TASKBAR
taskbar_mode = single_desktop
taskbar_padding = 4 4 4
taskbar_background_id = 0
taskbar_active_background_id = 2
taskbar_name = 1
taskbar_name_font_color = #f8f8f2 100
task_icon = 1
task_text = 1
task_centered = 1
task_maximum_size = 200 55

# RELOGIO
time1_format = %H:%M
time1_font = Sans Bold 14
time2_format = %d/%m
time2_font = Sans 10
clock_font_color = #f8f8f2 100
clock_padding = 10 4
clock_background_id = 0
clock_lclick_command = zenity --calendar

# ESTILOS (Opaco)
rounded = 0
border_width = 0
background_color = #282a36 100
border_color = #282a36 100
rounded = 4
border_width = 0
background_color = #6272a4 100
border_color = #6272a4 100
EOF

# 6. OPENBOX 

echo -e "${GREEN}[6/8] Configurando Openbox...${NC}"
mkdir -p "$HOME_DIR/.config/openbox"

# Wallpaper
wget -q "$WALLPAPER_URL" -O "$HOME_DIR/.config/openbox/wallpaper.jpg"
chown $USER_NAME:$USER_NAME "$HOME_DIR/.config/openbox/wallpaper.jpg"

echo '<?xml version="1.0" encoding="UTF-8"?>' > "$HOME_DIR/.config/openbox/rc.xml"
cat >> "$HOME_DIR/.config/openbox/rc.xml" <<'EOF'
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
  </placement>
  
  <theme>
    <name>Clearlooks</name>
    <keepBorder>no</keepBorder>
    <font place="ActiveWindow"><name>sans</name><size>14</size></font>
    <font place="InactiveWindow"><name>sans</name><size>14</size></font>
    <font place="MenuHeader"><name>sans</name><size>12</size></font>
    <font place="MenuItem"><name>sans</name><size>12</size></font>
    <font place="OnScreenDisplay"><name>sans</name><size>12</size></font>
  </theme>
  
  <desktops><number>1</number></desktops>
  <keyboard>
    <keybind key="A-Tab"><action name="NextWindow"/></keybind>
    <keybind key="A-S-Tab"><action name="PreviousWindow"/></keybind>
    <keybind key="C-A-t"><action name="Execute"><command>terminator</command></action></keybind>
  </keyboard>
  <applications>
    <application class="VSCodium">
      <decor>no</decor>
      <maximized>yes</maximized>
      <layer>below</layer>
      <skip_taskbar>yes</skip_taskbar>
      <skip_pager>yes</skip_pager>
    </application>
    
    <application class="FeatherPad"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Google-chrome"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Pcmanfm"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Terminator"><decor>yes</decor><maximized>no</maximized></application>
    <application class="tint2"><decor>no</decor></application>
  </applications>
</openbox_config>
EOF

# 7. START 

echo -e "${GREEN}[7/8] Finalizando...${NC}"

# Otimização TCP
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/tcp_nodelay=false/tcp_nodelay=true/g' /etc/xrdp/xrdp.ini || true
fi

# Cria .xsession para o usuário 
echo "openbox-session" > "$HOME_DIR/.xsession"
chown $USER_NAME:$USER_NAME "$HOME_DIR/.xsession"

# StartWM OTIMIZADO 
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then . /etc/default/locale; export LANG LANGUAGE; fi

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=openbox
export DESKTOP_SESSION=openbox

# Limpeza e Execução com DBUS
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec dbus-launch --exit-with-session openbox-session
EOF
chmod +x /etc/xrdp/startwm.sh

# --- AUTOSTART ---
cat > "$HOME_DIR/.config/openbox/autostart" <<EOF
#!/bin/bash

# Configura teclado ABNT2
setxkbmap -layout br -variant abnt2 &

xset s off &
xset -dpms &
xset s noblank &

# 1. Carrega o Wallpaper (Splash)
feh --bg-fill ~/.config/openbox/wallpaper.jpg &
tint2 &

# 2. Abre o VS Code (Delay de segurança 1s)
(sleep 1 && codium --disable-gpu --no-sandbox --disable-dev-shm-usage --disable-software-rasterizer --disable-smooth-scrolling) &

# 3. Transição para PERFORMANCE (Após 10 segundos fica cinza)
(sleep 10 && xsetroot -solid "$BG_COLOR") &

EOF
chmod +x "$HOME_DIR/.config/openbox/autostart"

# Ajustando Permissões Finais
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"
usermod -aG ssl-cert $USER_NAME
systemctl enable xrdp
systemctl restart xrdp

echo ""
echo -e "${GREEN} Instalação Finalizada!!! ${NC}"
echo "Reinicie a maquina."