#!/bin/bash

set -e

# CONFIGURAÇÕES BÁSICAS
WALLPAPER_URL="https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=60&w=1280&auto=format&fit=crop"
BG_COLOR="#282a36"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE} INSTALAÇÃO DE AMBIENTE DE DESENVOLVIMENTO XUXU-BELEZA ${NC}"
echo -e "${BLUE}  Versão 1.0.3 ${NC}"
echo ""

# VERIFICAÇÕES INICIAIS

# Verifica se é root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Erro!!! Execute como root: sudo bash $0${NC}"
    exit 1
fi

# Identifica usuário real
if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo -e "${RED}Erro: Não foi possível identificar o usuário.${NC}"
    echo -e "${YELLOW}Execute como: sudo bash $0${NC}"
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)

echo -e "${GREEN}Usuário identificado: ${NC}$USER_NAME"
echo -e "${GREEN}Diretório home: ${NC}$HOME_DIR"
echo ""

# Verifica distribuição
if ! command -v apt-get &> /dev/null; then
    echo -e "${RED}Este script é para sistemas baseados em Debian/Ubuntu${NC}"
    exit 1
fi

# LIMPEZA PRÉVIA

echo -e "${YELLOW}[Preparação] Limpando locks e caches...${NC}"
rm -f /etc/apt/preferences.d/mozilla-firefox 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
rm -f /var/lib/dpkg/lock 2>/dev/null || true
rm -f /var/cache/apt/archives/lock 2>/dev/null || true

# PERGUNTAS DE INSTALAÇÃO

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  ESCOLHA OS PROGRAMAS PARA INSTALAR${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

INSTALL_CHROME="n"
read -p "Deseja instalar o Google Chrome? (s/n): " resp_chrome
if [[ "$resp_chrome" =~ ^[Ss]$ ]]; then 
    INSTALL_CHROME="s"
    echo -e "${GREEN} Chrome será instalado${NC}"
else
    echo -e "${YELLOW}  - Chrome NÃO será instalado${NC}"
fi

INSTALL_NOTES="n"
read -p "Deseja instalar o Featherpad (Bloco de Notas)? (s/n): " resp_notes
if [[ "$resp_notes" =~ ^[Ss]$ ]]; then 
    INSTALL_NOTES="s"
    echo -e "${GREEN}  Featherpad será instalado${NC}"
else
    echo -e "${YELLOW}  - Featherpad NÃO será instalado${NC}"
fi

echo ""

# FASE 1: INSTALAÇÃO BASE

echo -e "${GREEN}[1/8] Instalando Base Gráfica...${NC}"

apt-get update -qq

# Pacotes essenciais do XRDP e X11
echo "  Instalando XRDP e componentes X11..."
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
    ca-certificates

# Gerenciador de janelas e utilitários
echo "  Instalando Openbox e utilitários..."
apt-get install -y --no-install-recommends \
    openbox \
    obconf \
    wmctrl \
    tint2 \
    pcmanfm \
    terminator \
    feh \
    zenity \
    fonts-liberation

# Ferramentas de desenvolvimento
echo "  → Instalando ferramentas..."
apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    build-essential \
    git \
    python3-pip

echo -e "${GREEN}  ✓ Base gráfica instalada com sucesso${NC}"
echo ""

# FASE 2: APPS

echo -e "${GREEN}[2/8] Instalando Aplicações...${NC}"

TINT2_LAUNCHERS=""

# Chrome
if [ "$INSTALL_CHROME" == "s" ]; then
    echo "  Baixando e instalando Google Chrome..."
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    apt-get install -y /tmp/chrome.deb || apt-get install -f -y
    rm -f /tmp/chrome.deb
    TINT2_LAUNCHERS+=$'\nlauncher_item_app = /usr/share/applications/google-chrome.desktop'
    echo -e "${GREEN}    Chrome instalado${NC}"
fi

# Apps Padrão (sempre instalados)
TINT2_LAUNCHERS+=$'\nlauncher_item_app = /usr/share/applications/pcmanfm.desktop'
TINT2_LAUNCHERS+=$'\nlauncher_item_app = /usr/share/applications/terminator.desktop'

# Featherpad
if [ "$INSTALL_NOTES" == "s" ]; then
    echo "  → Instalando Featherpad..."
    apt-get install -y --no-install-recommends featherpad
    FP_PATH=$(find /usr/share/applications -name "*featherpad.desktop" 2>/dev/null | head -n 1)
    if [ -n "$FP_PATH" ]; then
        TINT2_LAUNCHERS+=$'\nlauncher_item_app = '"$FP_PATH"
    fi
    echo -e "${GREEN}    Featherpad instalado${NC}"
fi

echo -e "${GREEN}  Aplicações instaladas${NC}"
echo ""

# FASE 3: VSCODIUM

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}[3/8] Instalando VSCodium...${NC}"
echo -e "${BLUE}============================================${NC}"

if ! command -v codium >/dev/null 2>&1; then
    echo "  → Adicionando repositório VSCodium..."
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    
    echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
        | tee /etc/apt/sources.list.d/vscodium.list
    
    apt-get update -qq
    
    echo "  Instalando VSCodium..."
    apt-get install -y --no-install-recommends codium
    
    echo -e "${GREEN}    VSCodium instalado${NC}"
else
    echo -e "${GREEN}    VSCodium já está instalado${NC}"
fi

echo ""

# FASE 4: CONFIGURAÇÃO VSCODIUM

echo -e "${GREEN}[4/8] Configurando VSCodium...${NC}"

# Para processos do codium do usuário
killall codium 2>/dev/null || true
sleep 1

# Cria diretórios de configuração
mkdir -p "$HOME_DIR/.config/VSCodium/User"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"

echo "  → Instalando extensões..."

# Instala extensões como o usuário correto
sudo -u $USER_NAME codium --no-sandbox \
    --user-data-dir "$HOME_DIR/.config/VSCodium" \
    --install-extension dracula-theme.theme-dracula --force 2>/dev/null || true

sudo -u $USER_NAME codium --no-sandbox \
    --user-data-dir "$HOME_DIR/.config/VSCodium" \
    --install-extension PKief.material-icon-theme --force 2>/dev/null || true

echo "  → Criando configurações..."

# Configurações do VSCodium
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

echo -e "${GREEN}  ✓ VSCodium configurado${NC}"
echo ""

# FASE 5: TINT2 (BARRA DE TAREFAS)

echo -e "${GREEN}[5/8] Configurando Barra de Tarefas...${NC}"

mkdir -p "$HOME_DIR/.config/tint2"

cat > "$HOME_DIR/.config/tint2/tint2rc" <<EOF
# Configuração Tint2 - Barra de Tarefas
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

# RELÓGIO
time1_format = %H:%M
time1_font = Sans Bold 14
time2_format = %d/%m
time2_font = Sans 10
clock_font_color = #f8f8f2 100
clock_padding = 10 4
clock_background_id = 0
clock_lclick_command = zenity --calendar

# ESTILOS
rounded = 0
border_width = 0
background_color = #282a36 100
border_color = #282a36 100

rounded = 4
border_width = 0
background_color = #6272a4 100
border_color = #6272a4 100
EOF

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/tint2"

echo -e "${GREEN}  Tint2 configurado${NC}"
echo ""

# FASE 6: OPENBOX

echo -e "${GREEN}[6/8] Configurando Openbox...${NC}"

mkdir -p "$HOME_DIR/.config/openbox"

# Baixa wallpaper
echo "  Baixando wallpaper..."
wget -q "$WALLPAPER_URL" -O "$HOME_DIR/.config/openbox/wallpaper.jpg" 2>/dev/null || true
chown $USER_NAME:$USER_NAME "$HOME_DIR/.config/openbox/wallpaper.jpg" 2>/dev/null || true

# Configuração do Openbox
echo "  → Criando configuração do Openbox..."

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

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/openbox"

echo -e "${GREEN}  ✓ Openbox configurado${NC}"
echo ""

# FASE 7: CONFIGURAÇÃO XRDP 

echo -e "${GREEN}[7/8] Configurando XRDP....${NC}"

# Otimizações no xrdp.ini
echo "  → Otimizando xrdp.ini..."
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/tcp_nodelay=false/tcp_nodelay=true/g' /etc/xrdp/xrdp.ini 2>/dev/null || true
    sed -i 's/max_bpp=32/max_bpp=24/g' /etc/xrdp/xrdp.ini 2>/dev/null || true
fi

# Cria .xsession correto no home do usuário
echo "  Criando .xsession "

cat > "$HOME_DIR/.xsession" <<'XSESSION_CONTENT'
#!/bin/bash

# Log de debug
exec > /tmp/xsession-debug.log 2>&1
echo "========================================="
echo "Iniciando .xsession em $(date)"
echo "USER: $USER"
echo "HOME: $HOME"
echo "========================================="

# Variáveis de ambiente essenciais
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=openbox
export DESKTOP_SESSION=openbox

echo "Variáveis de ambiente configuradas"

# Verifica se openbox existe
if ! command -v openbox-session >/dev/null 2>&1; then
    echo "ERRO: openbox-session não encontrado!"
    exit 1
fi

echo "Iniciando openbox-session..."

# Inicia openbox
exec openbox-session
XSESSION_CONTENT

chmod +x "$HOME_DIR/.xsession"
chown $USER_NAME:$USER_NAME "$HOME_DIR/.xsession"

echo -e "${GREEN}    .xsession criado: $(wc -c < "$HOME_DIR/.xsession") bytes${NC}"

# Cria startwm.sh 
echo "  → Criando startwm.sh..."

if [ -f /etc/xrdp/startwm.sh ]; then
    cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.backup.$(date +%Y%m%d-%H%M%S)
fi

cat > /etc/xrdp/startwm.sh <<'STARTWM_CONTENT'
#!/bin/sh

# Log de debug
exec > /tmp/startwm-debug.log 2>&1
echo "Iniciando startwm.sh em $(date)"
echo "USER: $USER"
echo "HOME: $HOME"

# Carrega locale
if [ -r /etc/default/locale ]; then
    . /etc/default/locale
    export LANG LANGUAGE
    echo "Locale carregado: LANG=$LANG"
fi

# Variáveis de ambiente
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=openbox
export DESKTOP_SESSION=openbox

echo "Variáveis XDG configuradas"

# Limpa variáveis problemáticas
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

echo "Variáveis limpas"

# Verifica .xsession do usuário
if [ -f "$HOME/.xsession" ]; then
    echo "Usando $HOME/.xsession"
    exec dbus-launch --exit-with-session "$HOME/.xsession"
else
    echo "AVISO: .xsession não encontrado, usando openbox-session direto"
    exec dbus-launch --exit-with-session openbox-session
fi
STARTWM_CONTENT

chmod +x /etc/xrdp/startwm.sh

echo -e "${GREEN}    startwm.sh criado: $(wc -c < /etc/xrdp/startwm.sh) bytes${NC}"

# Autostart do Openbox
echo "  → Criando autostart..."

cat > "$HOME_DIR/.config/openbox/autostart" <<AUTOSTART_CONTENT
#!/bin/bash

# Log de debug
exec > /tmp/openbox-autostart.log 2>&1
echo "Autostart iniciado em \$(date)"

# Configura teclado ABNT2
setxkbmap -layout br -variant abnt2 &

# Desabilita screensaver
xset s off &
xset -dpms &
xset s noblank &

# Background inicial
if [ -f ~/.config/openbox/wallpaper.jpg ]; then
    feh --bg-fill ~/.config/openbox/wallpaper.jpg &
    echo "Wallpaper carregado"
else
    xsetroot -solid "$BG_COLOR" &
    echo "Background sólido aplicado"
fi

# Inicia tint2
sleep 1
tint2 &
echo "Tint2 iniciado"

# Abre VSCodium
sleep 2
codium --disable-gpu --no-sandbox --disable-dev-shm-usage --disable-software-rasterizer --disable-smooth-scrolling &
echo "VSCodium iniciado"

# Transição para cor sólida após 10s
(sleep 10 && xsetroot -solid "$BG_COLOR") &

echo "Autostart finalizado em \$(date)"
AUTOSTART_CONTENT

chmod +x "$HOME_DIR/.config/openbox/autostart"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"

echo -e "${GREEN}  Configuração XRDP finalizada${NC}"
echo ""

# FASE 8: FINALIZAÇÃO

echo -e "${GREEN}[8/8] Finalizando Instalação...${NC}"

# Permissões finais
echo "  Ajustando permissões..."
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"
chown $USER_NAME:$USER_NAME "$HOME_DIR/.xsession"

# Adiciona usuário aos grupos
echo "Configurando grupos..."
adduser $USER_NAME ssl-cert 2>/dev/null || true

# Corrige permissões do certificado XRDP
echo "  Corrigindo permissões XRDP..."
if [ -f /etc/xrdp/key.pem ]; then
    chmod 640 /etc/xrdp/key.pem
    chgrp ssl-cert /etc/xrdp/key.pem
fi

# Habilita e reinicia serviços
echo "Habilitando serviços..."
systemctl enable xrdp
systemctl enable xrdp-sesman

echo "  → Reiniciando serviços XRDP..."
systemctl restart xrdp
systemctl restart xrdp-sesman

sleep 2

# Verificação final
echo ""
echo -e "${GREEN}  VERIFICAÇÃO FINAL${NC}"
echo ""

# Verifica .xsession
if [ -f "$HOME_DIR/.xsession" ] && [ -s "$HOME_DIR/.xsession" ]; then
    echo -e "${GREEN}.xsession: OK ($(wc -c < "$HOME_DIR/.xsession") bytes)${NC}"
else
    echo -e "${RED}.xsession: PROBLEMA!${NC}"
fi

# Verifica startwm.sh
if [ -f /etc/xrdp/startwm.sh ] && [ -s /etc/xrdp/startwm.sh ]; then
    echo -e "${GREEN}startwm.sh: OK ($(wc -c < /etc/xrdp/startwm.sh) bytes)${NC}"
else
    echo -e "${RED}startwm.sh: PROBLEMA!${NC}"
fi

# Verifica openbox
if command -v openbox-session >/dev/null 2>&1; then
    echo -e "${GREEN}openbox-session: INSTALADO${NC}"
else
    echo -e "${RED}openbox-session: NÃO ENCONTRADO!${NC}"
fi

# Verifica xorgxrdp
if dpkg -l | grep -q xorgxrdp; then
    echo -e "${GREEN}xorgxrdp: INSTALADO${NC}"
else
    echo -e "${RED}xorgxrdp: NÃO INSTALADO!${NC}"
fi

# Verifica serviços
if systemctl is-active --quiet xrdp; then
    echo -e "${GREEN}xrdp: RODANDO${NC}"
else
    echo -e "${RED}xrdp: PARADO!${NC}"
fi

if systemctl is-active --quiet xrdp-sesman; then
    echo -e "${GREEN}xrdp-sesman: RODANDO${NC}"
else
    echo -e "${RED}xrdp-sesman: PARADO!${NC}"
fi

# MENSAGEM FINAL

echo ""
echo -e "${GREEN}INSTALAÇÃO CONCLUÍDA COM SUCESSO!!!${NC}"
echo ""
echo -e "${YELLOW}INFORMAÇÕES IMPORTANTES:${NC}"
echo ""
echo -e "  Usuário: ${GREEN}$USER_NAME${NC}"
echo -e "  Porta RDP: ${GREEN}3389${NC}"
echo -e "  Teclado: ${GREEN}ABNT2 (Português BR)${NC}"
echo ""
echo -e "  ${GREEN}Reinicie a máquina:${NC}"
echo -e "  ${BLUE}sudo reboot${NC}"
echo ""
