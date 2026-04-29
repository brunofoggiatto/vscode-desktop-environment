#!/bin/bash

set -eo pipefail

# CONFIGURAÇÕES BÁSICAS
BG_COLOR="#282a36"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

trap 'echo -e "${RED}Instalação interrompida!${NC}"; exit 1' INT TERM

echo ""
echo -e "${BLUE} INSTALAÇÃO DE AMBIENTE DE DESENVOLVIMENTO ${NC}"
echo -e "${BLUE}  Versão 3.0.0 ${NC}"
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

# Detecta versão do Ubuntu
UBUNTU_VERSION=$(grep -oP '(?<=^VERSION_ID=")\d+\.\d+' /etc/os-release 2>/dev/null || echo "unknown")

echo -e "${GREEN}Usuário identificado: ${NC}$USER_NAME"
echo -e "${GREEN}Diretório home: ${NC}$HOME_DIR"
echo -e "${GREEN}Ubuntu: ${NC}$UBUNTU_VERSION"
echo ""

# Verifica distribuição e versão suportada
if ! command -v apt &> /dev/null; then
    echo -e "${RED}Erro: este script requer um sistema baseado em Debian/Ubuntu${NC}"
    exit 1
fi

if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then
    echo -e "${RED}Erro: Ubuntu $UBUNTU_VERSION nao suportado. Use 22.04 ou 24.04.${NC}"
    exit 1
fi

# SELEÇÃO DO EDITOR

echo ""
echo -e "${BLUE}Selecione o editor principal:${NC}"
echo ""
echo "  [1] VS Code    (padrao, recomendado)"
echo "  [2] VSCodium   (mais leve, sem telemetria da Microsoft)"
echo "  [3] Neovim     (terminal, minimalista)"
echo ""
read -p "  Opcao [1]: " EDITOR_CHOICE
EDITOR_CHOICE=${EDITOR_CHOICE:-1}

case $EDITOR_CHOICE in
    2) EDITOR="vscodium" ; EDITOR_LABEL="VSCodium" ;;
    3) EDITOR="neovim"   ; EDITOR_LABEL="Neovim"   ;;
    *) EDITOR="vscode"   ; EDITOR_LABEL="VS Code"  ;;
esac

echo -e "${GREEN}Editor selecionado: ${NC}$EDITOR_LABEL"
echo ""

# LIMPEZA PRÉVIA

echo -e "${YELLOW}[Preparação] Limpando locks e caches...${NC}"

# Aguarda o apt terminar antes de remover locks
echo "  -> Aguardando processos apt/dpkg liberarem locks..."
LOCK_WAIT=0
while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
    sleep 2
    LOCK_WAIT=$((LOCK_WAIT + 2))
    if [ $LOCK_WAIT -ge 60 ]; then
        echo -e "${YELLOW}    Timeout aguardando locks. Removendo forçado.${NC}"
        break
    fi
done

rm -f /etc/apt/preferences.d/mozilla-firefox 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
rm -f /var/lib/dpkg/lock 2>/dev/null || true
rm -f /var/cache/apt/archives/lock 2>/dev/null || true

echo ""

# FASE 1: INSTALAÇÃO BASE

echo -e "${GREEN}[1/8] Instalando Base Gráfica...${NC}"

apt update -qq

# Pacotes essenciais do XRDP e X11
echo "  Instalando XRDP e componentes X11..."
apt install -y --no-install-recommends --no-install-suggests xrdp xorgxrdp xserver-xorg-core xserver-xorg-input-all x11-xserver-utils dbus-x11 wget gpg apt-transport-https ca-certificates

# Gerenciador de janelas e utilitários (apps leves para otimizar RAM)
echo "  Instalando Openbox e utilitários..."
apt install -y --no-install-recommends --no-install-suggests openbox wmctrl tint2 rofi pcmanfm file-roller eog gnome-screenshot gnome-terminal mousepad gnome-calculator evince zenity fonts-liberation yaru-theme-gtk yaru-theme-icon x11-xkb-utils dconf-cli libglib2.0-bin xdg-utils

# Ubuntu 24.04: portal GTK necessário para diálogos de arquivo no Openbox
if [ "$UBUNTU_VERSION" = "24.04" ]; then
    echo "  -> Instalando xdg-desktop-portal-gtk (Ubuntu 24.04)..."
    apt install -y --no-install-recommends --no-install-suggests xdg-desktop-portal-gtk 2>/dev/null || true
fi

# Ferramentas de desenvolvimento
echo "  -> Instalando ferramentas..."
apt install -y --no-install-recommends --no-install-suggests curl gnupg build-essential git python3-pip

echo -e "${GREEN}   Base gráfica instalada com sucesso${NC}"
echo ""

# FASE 2: APPS

echo -e "${GREEN}[2/8] Instalando Aplicações...${NC}"

# Chrome
echo "  Baixando e instalando Google Chrome..."
if ! wget -q --tries=3 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb; then
    echo -e "${RED}    ERRO: Falha ao baixar Chrome${NC}"
    exit 1
fi
if [ ! -s /tmp/chrome.deb ] || [ "$(stat -c%s /tmp/chrome.deb)" -lt 50000000 ]; then
    echo -e "${RED}    ERRO: Arquivo do Chrome corrompido ou incompleto${NC}"
    rm -f /tmp/chrome.deb
    exit 1
fi
apt install -y /tmp/chrome.deb || apt install -f -y
rm -f /tmp/chrome.deb
echo -e "${GREEN}    Chrome instalado${NC}"

echo -e "${GREEN}  Aplicações instaladas${NC}"
echo ""

# FASE 3: EDITOR

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}[3/8] Instalando $EDITOR_LABEL...${NC}"
echo -e "${BLUE}============================================${NC}"

if [ "$EDITOR" = "vscode" ]; then
    if ! command -v code >/dev/null 2>&1; then
        echo "  -> Adicionando repositório VS Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | tee /etc/apt/sources.list.d/vscode.list
        apt update -qq
        echo "  Instalando VS Code..."
        apt install -y --no-install-recommends --no-install-suggests code
        echo -e "${GREEN}    VS Code instalado${NC}"
    else
        echo -e "${GREEN}    VS Code ja esta instalado${NC}"
    fi

elif [ "$EDITOR" = "vscodium" ]; then
    if ! command -v codium >/dev/null 2>&1; then
        echo "  -> Adicionando repositório VSCodium..."
        wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
        echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' | tee /etc/apt/sources.list.d/vscodium.list
        apt update -qq
        echo "  Instalando VSCodium..."
        apt install -y --no-install-recommends --no-install-suggests codium
        echo -e "${GREEN}    VSCodium instalado${NC}"
    else
        echo -e "${GREEN}    VSCodium ja esta instalado${NC}"
    fi

elif [ "$EDITOR" = "neovim" ]; then
    echo "  -> Instalando Neovim..."
    apt install -y --no-install-recommends --no-install-suggests neovim
    echo -e "${GREEN}    Neovim instalado${NC}"
fi

echo ""

# FASE 4: CONFIGURAÇÃO DO EDITOR

echo -e "${GREEN}[4/8] Configurando $EDITOR_LABEL...${NC}"

if [ "$EDITOR" = "vscode" ]; then
    killall code 2>/dev/null || true
    sleep 1
    mkdir -p "$HOME_DIR/.config/Code/User"
    chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"
    echo "  -> Instalando extensões..."
    if ! sudo -u "$USER_NAME" code --no-sandbox --user-data-dir "$HOME_DIR/.config/Code" --install-extension dracula-theme.theme-dracula --force 2>&1; then
        echo -e "${YELLOW}    Extensão dracula-theme não instalada (continuando)${NC}"
    fi
    if ! sudo -u "$USER_NAME" code --no-sandbox --user-data-dir "$HOME_DIR/.config/Code" --install-extension ms-python.python --force 2>&1; then
        echo -e "${YELLOW}    Extensão ms-python.python não instalada (continuando)${NC}"
    fi
    echo "  -> Criando configurações..."
    cat > "$HOME_DIR/.config/Code/User/settings.json" <<'EOF'
{
  "workbench.colorTheme": "Dracula",
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
  "terminal.integrated.smoothScrolling": false,
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "extensions.autoCheckUpdates": false,
  "editor.renderWhitespace": "none",
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/node_modules/**": true
  }
}
EOF
    chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/Code"

elif [ "$EDITOR" = "vscodium" ]; then
    killall codium 2>/dev/null || true
    sleep 1
    mkdir -p "$HOME_DIR/.config/VSCodium/User"
    chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"
    echo "  -> Instalando extensões..."
    if ! sudo -u "$USER_NAME" codium --no-sandbox --user-data-dir "$HOME_DIR/.config/VSCodium" --install-extension dracula-theme.theme-dracula --force 2>&1; then
        echo -e "${YELLOW}    Extensão dracula-theme não instalada (continuando)${NC}"
    fi
    if ! sudo -u "$USER_NAME" codium --no-sandbox --user-data-dir "$HOME_DIR/.config/VSCodium" --install-extension ms-python.python --force 2>&1; then
        echo -e "${YELLOW}    Extensão ms-python.python não instalada (continuando)${NC}"
    fi
    echo "  -> Criando configurações..."
    cat > "$HOME_DIR/.config/VSCodium/User/settings.json" <<'EOF'
{
  "workbench.colorTheme": "Dracula",
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
  "terminal.integrated.smoothScrolling": false,
  "telemetry.enableTelemetry": false,
  "telemetry.enableCrashReporter": false,
  "update.mode": "none",
  "extensions.autoCheckUpdates": false,
  "editor.renderWhitespace": "none",
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/node_modules/**": true
  }
}
EOF
    chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/VSCodium"

elif [ "$EDITOR" = "neovim" ]; then
    mkdir -p "$HOME_DIR/.config/nvim"
    cat > "$HOME_DIR/.config/nvim/init.vim" <<'NVIMEOF'
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set termguicolors
set scrolloff=8
set signcolumn=yes
syntax enable
NVIMEOF
    chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/nvim"
fi

echo -e "${GREEN}   $EDITOR_LABEL configurado${NC}"
echo ""

# Configura GTK3 settings para que PCManFM, Mousepad e outros apps GTK
# usem o tema Yaru-dark + ícones Yaru corretamente no Openbox
echo "  -> Configurando tema GTK3 para aplicações..."
mkdir -p "$HOME_DIR/.config/gtk-3.0"
cat > "$HOME_DIR/.config/gtk-3.0/settings.ini" <<'GTKEOF'
[Settings]
gtk-theme-name=Yaru-dark
gtk-icon-theme-name=Yaru
gtk-font-name=Sans 11
gtk-cursor-theme-name=Yaru
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
GTKEOF
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/gtk-3.0"
echo -e "${GREEN}    GTK3 configurado com tema dark${NC}"

# Inicializa perfil padrão do gnome-terminal via dconf
# (sem isso, gnome-terminal pode falhar na primeira execução no Openbox)
echo "  -> Inicializando perfil do GNOME Terminal..."
PROFILE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "b1dcc9dd-5262-4d8d-a863-c897e6d979b9")
sudo -u $USER_NAME dbus-launch dconf write /org/gnome/terminal/legacy/profiles:/default "'$PROFILE_ID'" 2>/dev/null || true
sudo -u $USER_NAME dbus-launch dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/visible-name "'Default'" 2>/dev/null || true
sudo -u $USER_NAME dbus-launch dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/use-theme-colors "true" 2>/dev/null || true
echo -e "${GREEN}    Perfil GNOME Terminal inicializado${NC}"

# FASE 5: SHOW APPLICATIONS (DASHBOARD)

echo -e "${GREEN}[5/8] Configurando Show Applications...${NC}"

mkdir -p "$HOME_DIR/.config/tint2"
mkdir -p "$HOME_DIR/.config/rofi"
mkdir -p "$HOME_DIR/.local/bin"
mkdir -p "$HOME_DIR/.local/share/applications"
mkdir -p "$HOME_DIR/.local/share/icons"

# Cria ícone SVG do grid (Show Applications)
cat > "$HOME_DIR/.local/share/icons/show-apps.svg" <<'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <circle cx="10" cy="10" r="4" fill="#f8f8f2"/>
  <circle cx="24" cy="10" r="4" fill="#f8f8f2"/>
  <circle cx="38" cy="10" r="4" fill="#f8f8f2"/>
  <circle cx="10" cy="24" r="4" fill="#f8f8f2"/>
  <circle cx="24" cy="24" r="4" fill="#f8f8f2"/>
  <circle cx="38" cy="24" r="4" fill="#f8f8f2"/>
  <circle cx="10" cy="38" r="4" fill="#f8f8f2"/>
  <circle cx="24" cy="38" r="4" fill="#f8f8f2"/>
  <circle cx="38" cy="38" r="4" fill="#f8f8f2"/>
</svg>
SVGEOF

# Cria script do dashboard
cat > "$HOME_DIR/.local/bin/show-applications" <<'SCRIPTEOF'
#!/bin/bash
# Show Applications Dashboard - GNOME-style app grid via rofi
rofi -show drun -theme "$HOME/.config/rofi/dashboard.rasi" -drun-display-format "{name}" -show-icons -mesg "Esc para fechar  |  Scroll ou setas para navegar"
SCRIPTEOF

chmod +x "$HOME_DIR/.local/bin/show-applications"

# Cria .desktop para o botão Show Applications
cat > "$HOME_DIR/.local/share/applications/show-applications.desktop" <<'DESKTOPEOF'
[Desktop Entry]
Type=Application
Name=Show Applications
Icon=show-apps
Exec=show-applications
NoDisplay=true
DESKTOPEOF

# Tema rofi - dashboard fullscreen moderno
cat > "$HOME_DIR/.config/rofi/dashboard.rasi" <<'ROFIEOF'
* {
    bg:           #1a1b26ee;
    bg-solid:     #1a1b26;
    bg-card:      #44475a99;
    fg:           #f8f8f2;
    fg-dim:       #f8f8f2aa;
    selected:     #44475acc;
    background-color: transparent;
    text-color:   @fg;
    font:         "Sans 12";
}

window {
    fullscreen:   true;
    background-color: @bg;
    padding:      120px 150px;
}

mainbox {
    children:     [ inputbar, listview, message ];
    spacing:      40px;
}

inputbar {
    children:     [ prompt, entry ];
    background-color: @bg-card;
    border:       1px solid;
    border-color: #6272a444;
    border-radius: 16px;
    padding:      16px 24px;
    margin:       0 200px;
}

prompt {
    text-color:   #6272a4;
    margin:       0 12px 0 0;
    font:         "Sans Bold 12";
}

entry {
    placeholder:  "Buscar aplicativos...";
    placeholder-color: #6272a466;
    text-color:   @fg;
}

listview {
    columns:       5;
    lines:         3;
    spacing:       20px;
    cycle:         false;
    dynamic:       true;
    fixed-columns: true;
    layout:        vertical;
    scrollbar:     true;
}

scrollbar {
    handle-width:     8px;
    handle-color:     #6272a4;
    background-color: #44475a44;
    border-radius:    4px;
    margin:           0 0 0 10px;
}

message {
    background-color: transparent;
    padding:          10px 0 0 0;
}

textbox {
    text-color:       #6272a466;
    horizontal-align: 0.5;
    font:             "Sans 10";
}

element {
    orientation:      vertical;
    padding:          20px 10px;
    border-radius:    16px;
    cursor:           pointer;
}

/* Feedback Visual ao Selecionar */
element selected.normal {
    background-color: @selected;
    border:           1px solid;
    border-color:     #6272a466;
}

element-icon {
    size:             64px;
    horizontal-align: 0.5;
}

element-text {
    horizontal-align: 0.5;
    vertical-align:   0.5;
    font:             "Sans 10";
    margin:           10px 0px 0px 0px;
}
ROFIEOF

# Tint2 - dock moderno estilo Ubuntu 24 (flutuante, arredondado)
cat > "$HOME_DIR/.config/tint2/tint2rc" <<'TINT2EOF'
# Tint2 - Dock moderno estilo Ubuntu 24

# BACKGROUNDS
# ID 1 - Panel background (cor sólida)
rounded = 0
border_width = 0
border_sides = TBLR
background_color = #282a36 100
border_color = #282a36 0
background_color_hover = #282a36 100
border_color_hover = #282a36 0
background_color_pressed = #282a36 100
border_color_pressed = #282a36 0

# ID 2 - Launcher hover (botão Menu)
rounded = 10
border_width = 1
border_sides = TBLR
background_color = #282a36 0
border_color = #6272a4 0
background_color_hover = #6272a4 90
border_color_hover = #6272a4 60
background_color_pressed = #6272a4 100
border_color_pressed = #6272a4 80

# ID 3 - Taskbar item (app aberto) - normal
rounded = 8
border_width = 0
border_sides = TBLR
background_color = #44475a 60
border_color = #44475a 0
background_color_hover = #6272a4 80
border_color_hover = #6272a4 0
background_color_pressed = #8be9fd 90
border_color_pressed = #8be9fd 0

# ID 4 - Taskbar item ativo (app em foco)
rounded = 8
border_width = 0
border_sides = TBLR
background_color = #6272a4 90
border_color = #6272a4 0
background_color_hover = #6272a4 100
border_color_hover = #6272a4 0
background_color_pressed = #8be9fd 100
border_color_pressed = #8be9fd 0

# ID 5 - Indicador de ativo (linha inferior)
rounded = 3
border_width = 0
border_sides = TBLR
background_color = #6272a4 100
border_color = #6272a4 0
background_color_hover = #6272a4 100
border_color_hover = #6272a4 0
background_color_pressed = #6272a4 100
border_color_pressed = #6272a4 0

# PANEL
panel_items = LTFC
panel_size = 100% 44
panel_margin = 0 0
panel_padding = 8 0 8
panel_background_id = 1
panel_layer = top
panel_monitor = all
panel_position = bottom center horizontal
panel_dock = 0
strut_policy = follow_size
panel_window_name = tint2
wm_menu = 0
autohide = 0

# LAUNCHER (Show Applications button)
launcher_padding = 4 4 4
launcher_background_id = 0
launcher_icon_background_id = 2
launcher_icon_size = 32
launcher_icon_theme = Yaru
launcher_tooltip = 1
launcher_item_app = __HOME__/.local/share/applications/show-applications.desktop

# TASKBAR (apps abertos na barra)
taskbar_mode = single_desktop
taskbar_hide_if_empty = 0
taskbar_padding = 4 2 4
taskbar_background_id = 0
taskbar_active_background_id = 0
taskbar_name = 0
taskbar_hide_inactive_tasks = 0
taskbar_hide_different_monitor = 0
taskbar_always_show_all_desktop_tasks = 0
taskbar_sort_order = none

# TASK (cada app aberto)
task_text = 1
task_icon = 1
task_centered = 1
task_tooltip = 1
task_maximum_size = 200 40
task_padding = 6 3 6
task_font = Sans 11
task_font_color = #f8f8f2 80
task_icon_size = 22
task_background_id = 3
task_active_background_id = 4
task_active_font_color = #f8f8f2 100
task_urgent_background_id = 4
task_urgent_font_color = #ff5555 100

# Indicador do app ativo (linha na parte inferior do ícone)
task_active_icon_asb = 100 0 0
task_icon_asb = 100 0 -20

# Mouse actions nas tasks
mouse_left = toggle_iconify
mouse_middle = close
mouse_right = none
mouse_scroll_up = toggle
mouse_scroll_down = iconify

# CLOCK (canto inferior direito)
time1_format = %H:%M
time1_font = Sans Bold 12
time2_format = %a %d %b
time2_font = Sans 9
clock_font_color = #f8f8f2 100
clock_padding = 14 0
clock_background_id = 0
clock_lclick_command = zenity --calendar
clock_tooltip = %A, %d de %B de %Y
TINT2EOF

# Substitui __HOME__ pelo caminho real do usuário no tint2rc
sed -i "s|__HOME__|$HOME_DIR|g" "$HOME_DIR/.config/tint2/tint2rc"

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/tint2"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/rofi"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.local"

# Atualiza cache de ícones para que o SVG customizado seja encontrado
gtk-update-icon-cache -f -t "$HOME_DIR/.local/share/icons" 2>/dev/null || true
update-icon-caches /usr/share/icons/hicolor 2>/dev/null || true

echo -e "${GREEN}  Show Applications configurado${NC}"
echo ""

# FASE 6: OPENBOX

echo -e "${GREEN}[6/8] Configurando Openbox...${NC}"

mkdir -p "$HOME_DIR/.config/openbox"

# Cria tema Openbox personalizado (dark flat, estilo Dracula)
echo "  -> Criando tema Dracula-Flat para Openbox..."

THEME_DIR="$HOME_DIR/.themes/Dracula-Flat/openbox-3"
mkdir -p "$THEME_DIR"

cat > "$THEME_DIR/themerc" <<'THEMEEOF'
# Dracula-Flat - Tema Openbox dark moderno

# Título ativo
window.active.title.bg: flat solid
window.active.title.bg.color: #282a36
window.active.label.bg: parentrelative
window.active.label.text.color: #f8f8f2
window.active.label.text.font: shadow=n
window.active.label.text.justify: center

# Título inativo
window.inactive.title.bg: flat solid
window.inactive.title.bg.color: #21222c
window.inactive.label.bg: parentrelative
window.inactive.label.text.color: #6272a4
window.inactive.label.text.font: shadow=n
window.inactive.label.text.justify: center

# Botões ativos
window.active.button.unpressed.bg: flat solid
window.active.button.unpressed.bg.color: #282a36
window.active.button.unpressed.image.color: #bd93f9
window.active.button.hover.bg: flat solid
window.active.button.hover.bg.color: #44475a
window.active.button.hover.image.color: #ff79c6
window.active.button.pressed.bg: flat solid
window.active.button.pressed.bg.color: #6272a4
window.active.button.pressed.image.color: #f8f8f2
window.active.button.disabled.bg: flat solid
window.active.button.disabled.bg.color: #282a36
window.active.button.disabled.image.color: #44475a
window.active.button.toggled.unpressed.bg: flat solid
window.active.button.toggled.unpressed.bg.color: #282a36
window.active.button.toggled.unpressed.image.color: #50fa7b
window.active.button.toggled.hover.bg: flat solid
window.active.button.toggled.hover.bg.color: #44475a
window.active.button.toggled.hover.image.color: #50fa7b
window.active.button.toggled.pressed.bg: flat solid
window.active.button.toggled.pressed.bg.color: #6272a4
window.active.button.toggled.pressed.image.color: #f8f8f2

# Botões inativos
window.inactive.button.unpressed.bg: flat solid
window.inactive.button.unpressed.bg.color: #21222c
window.inactive.button.unpressed.image.color: #44475a
window.inactive.button.hover.bg: flat solid
window.inactive.button.hover.bg.color: #44475a
window.inactive.button.hover.image.color: #6272a4
window.inactive.button.pressed.bg: flat solid
window.inactive.button.pressed.bg.color: #6272a4
window.inactive.button.pressed.image.color: #f8f8f2
window.inactive.button.disabled.bg: flat solid
window.inactive.button.disabled.bg.color: #21222c
window.inactive.button.disabled.image.color: #282a36
window.inactive.button.toggled.unpressed.bg: flat solid
window.inactive.button.toggled.unpressed.bg.color: #21222c
window.inactive.button.toggled.unpressed.image.color: #44475a
window.inactive.button.toggled.hover.bg: flat solid
window.inactive.button.toggled.hover.bg.color: #44475a
window.inactive.button.toggled.hover.image.color: #6272a4
window.inactive.button.toggled.pressed.bg: flat solid
window.inactive.button.toggled.pressed.bg.color: #6272a4
window.inactive.button.toggled.pressed.image.color: #f8f8f2

# Handle e grip
window.active.handle.bg: flat solid
window.active.handle.bg.color: #282a36
window.active.grip.bg: flat solid
window.active.grip.bg.color: #44475a
window.inactive.handle.bg: flat solid
window.inactive.handle.bg.color: #21222c
window.inactive.grip.bg: flat solid
window.inactive.grip.bg.color: #282a36

# Bordas
border.width: 1
border.color: #191a21
window.active.border.color: #191a21
window.inactive.border.color: #191a21
window.active.client.color: #282a36
window.inactive.client.color: #21222c

# Padding
padding.width: 8
padding.height: 4
window.handle.width: 0
window.client.padding.width: 0
window.client.padding.height: 0

# Menu
menu.border.width: 1
menu.border.color: #44475a
menu.title.bg: flat solid
menu.title.bg.color: #282a36
menu.title.text.color: #bd93f9
menu.title.text.font: shadow=n
menu.title.text.justify: center
menu.items.bg: flat solid
menu.items.bg.color: #282a36
menu.items.text.color: #f8f8f2
menu.items.disabled.text.color: #6272a4
menu.items.font: shadow=n
menu.items.active.bg: flat solid
menu.items.active.bg.color: #44475a
menu.items.active.text.color: #f8f8f2
menu.separator.color: #44475a
menu.separator.width: 1
menu.separator.padding.width: 6
menu.separator.padding.height: 3

# OSD
osd.bg: flat solid
osd.bg.color: #282a36
osd.border.width: 1
osd.border.color: #44475a
osd.label.bg: flat solid
osd.label.bg.color: #282a36
osd.label.text.color: #f8f8f2
osd.hilight.bg: flat solid
osd.hilight.bg.color: #bd93f9
osd.unhilight.bg: flat solid
osd.unhilight.bg.color: #44475a
THEMEEOF

# Botões XBM (8x8 pixels)
cat > "$THEME_DIR/close.xbm" <<'XBM'
#define close_width 8
#define close_height 8
static unsigned char close_bits[] = {
   0xc3, 0x66, 0x3c, 0x18, 0x18, 0x3c, 0x66, 0xc3};
XBM

cat > "$THEME_DIR/max.xbm" <<'XBM'
#define max_width 8
#define max_height 8
static unsigned char max_bits[] = {
   0xff, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xff};
XBM

cat > "$THEME_DIR/max_toggled.xbm" <<'XBM'
#define max_toggled_width 8
#define max_toggled_height 8
static unsigned char max_toggled_bits[] = {
   0x00, 0x3c, 0x24, 0x24, 0x24, 0x3c, 0x00, 0x00};
XBM

cat > "$THEME_DIR/iconify.xbm" <<'XBM'
#define iconify_width 8
#define iconify_height 8
static unsigned char iconify_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0x00};
XBM

cat > "$THEME_DIR/desk.xbm" <<'XBM'
#define desk_width 8
#define desk_height 8
static unsigned char desk_bits[] = {
   0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
XBM

cat > "$THEME_DIR/desk_toggled.xbm" <<'XBM'
#define desk_toggled_width 8
#define desk_toggled_height 8
static unsigned char desk_toggled_bits[] = {
   0x7e, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
XBM

cat > "$THEME_DIR/bullet.xbm" <<'XBM'
#define bullet_width 8
#define bullet_height 8
static unsigned char bullet_bits[] = {
   0x00, 0x04, 0x0c, 0x1c, 0x3c, 0x1c, 0x0c, 0x04};
XBM

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.themes"
echo -e "${GREEN}    Tema Dracula-Flat criado${NC}"

# Configuração do Openbox
echo "  -> Criando configuração do Openbox..."

printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">' > "$HOME_DIR/.config/openbox/rc.xml"
cat >> "$HOME_DIR/.config/openbox/rc.xml" <<'RCEOF'
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
  </placement>
  <theme>
    <name>Dracula-Flat</name>
    <keepBorder>yes</keepBorder>
    <titleLayout>LIMC</titleLayout>
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
    <keybind key="C-A-t"><action name="Execute"><command>gnome-terminal</command></action></keybind>
    <keybind key="Super_L"><action name="Execute"><command>show-applications</command></action></keybind>
  </keyboard>
  <applications>
RCEOF

# Regra do editor selecionado (sem borda, maximizado, abaixo das janelas)
if [ "$EDITOR" = "vscode" ]; then
    echo '    <application class="Code"><decor>no</decor><maximized>yes</maximized><layer>below</layer><skip_taskbar>yes</skip_taskbar><skip_pager>yes</skip_pager></application>' >> "$HOME_DIR/.config/openbox/rc.xml"
elif [ "$EDITOR" = "vscodium" ]; then
    echo '    <application class="VSCodium"><decor>no</decor><maximized>yes</maximized><layer>below</layer><skip_taskbar>yes</skip_taskbar><skip_pager>yes</skip_pager></application>' >> "$HOME_DIR/.config/openbox/rc.xml"
fi

cat >> "$HOME_DIR/.config/openbox/rc.xml" <<'RCEOF2'
    <application class="Mousepad"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Google-chrome"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Gnome-terminal"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Pcmanfm"><decor>yes</decor><maximized>no</maximized></application>
    <application class="File-roller"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Eog"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Gnome-calculator"><decor>yes</decor><maximized>no</maximized></application>
    <application class="Evince"><decor>yes</decor><maximized>no</maximized></application>
    <application class="tint2"><decor>no</decor></application>
RCEOF2

# Para Neovim: regra por título após a regra da classe gnome-terminal (sobrepõe decorações)
if [ "$EDITOR" = "neovim" ]; then
    echo '    <application title="nvim-desktop"><decor>no</decor><maximized>yes</maximized><layer>below</layer><skip_taskbar>yes</skip_taskbar><skip_pager>yes</skip_pager></application>' >> "$HOME_DIR/.config/openbox/rc.xml"
fi

cat >> "$HOME_DIR/.config/openbox/rc.xml" <<'RCEOF3'
  </applications>
</openbox_config>
RCEOF3

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config/openbox"

echo -e "${GREEN}   Openbox configurado${NC}"
echo ""

# FASE 7: CONFIGURAÇÃO XRDP

echo -e "${GREEN}[7/8] Configurando XRDP...${NC}"

# Configura layout moderno e isola Xorg
echo "  -> Configurando logo PNG e tema Dracula na tela de login..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGO_DEST="/etc/xrdp/logo-vsde.bmp"
LOGO_SRC="$SCRIPT_DIR/assets/logo-vsde.bmp"

if [ -f "$LOGO_SRC" ]; then
    cp "$LOGO_SRC" "$LOGO_DEST"
    chmod 644 "$LOGO_DEST"
    echo -e "${GREEN}     Logo customizada copiada${NC}"
else
    echo -e "${YELLOW}    Logo customizada não encontrada em assets/. Se ela já estiver em /etc/xrdp/logo-vsde.bmp, será usada.${NC}"
fi

# Sempre força a configuração no xrdp.ini
LOGO_FILENAME="/etc/xrdp/logo-vsde.bmp"

python3 - <<PYEOF
import re, sys

ini_path = "/etc/xrdp/xrdp.ini"
try:
    with open(ini_path, "r") as f:
        content = f.read()
except FileNotFoundError:
    print(f"  ERRO: {ini_path} não encontrado")
    sys.exit(1)

def set_key(text, key, value):
    pattern = rf"^({re.escape(key)}\s*=).*\$"
    new_text, n = re.subn(pattern, rf"\g<1>{value}", text, count=1, flags=re.MULTILINE)
    if n > 0:
        return new_text
    pattern_commented = rf"^[#;]\s*{re.escape(key)}\s*=.*\$"
    new_text, n = re.subn(pattern_commented, f"{key}={value}", text, count=1, flags=re.MULTILINE)
    if n > 0:
        return new_text
    return re.sub(r"(\[Globals\])", rf"\1\n{key}={value}", text, count=1)

content = set_key(content, "blue",      "21113b")
content = set_key(content, "grey",      "8661e5")
content = set_key(content, "dark_grey", "44475a")

content = set_key(content, "ls_top_window_bg_color", "282a36")
content = set_key(content, "ls_bg_color",            "282a36")

# Limpa qualquer resquício de wallpaper antigo
content = set_key(content, "ls_background_image", "")

content = set_key(content, "ls_width",  "420")
content = set_key(content, "ls_height", "380")

content = set_key(content, "ls_title", "VSDe - Acesso Seguro")
content = set_key(content, "ls_label_text_color", "ffffff")
content = set_key(content, "ls_text_color", "ffffff")

logo_filename = "$LOGO_FILENAME"
content = set_key(content, "ls_logo_filename",  logo_filename)
content = set_key(content, "ls_logo_transform", "scale")
content = set_key(content, "ls_logo_width",     "175")
content = set_key(content, "ls_logo_height",    "175")
content = set_key(content, "ls_logo_x_pos",     "115")
content = set_key(content, "ls_logo_y_pos",     "40")

content = set_key(content, "ls_label_x_pos",  "-1000")
content = set_key(content, "ls_label_width",  "110")

content = set_key(content, "ls_input_x_pos",  "110")
content = set_key(content, "ls_input_width",  "200")
content = set_key(content, "ls_input_y_pos",  "210")

content = set_key(content, "ls_btn_ok_x_pos",     "167")
content = set_key(content, "ls_btn_ok_y_pos",     "310")
content = set_key(content, "ls_btn_ok_width",     "85")
content = set_key(content, "ls_btn_ok_height",    "30")
content = set_key(content, "ls_btn_cancel_x_pos", "-1000")
content = set_key(content, "ls_btn_cancel_y_pos", "-1000")
content = set_key(content, "ls_btn_cancel_width", "0")
content = set_key(content, "ls_btn_cancel_height","0")

sessions_to_keep = ["globals", "logging", "channels", "routing"]
lines = content.splitlines()
out_lines = []
current_section = "globals"

for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        current_section = stripped[1:-1].lower()
    
    if current_section in sessions_to_keep:
        out_lines.append(line)

content = "\n".join(out_lines) + "\n\n"
content += "[Xorg]\nname=Ambiente VSDe\nlib=libxup.so\nusername=ask\npassword=ask\nip=127.0.0.1\nport=-1\ncode=20\n"

with open(ini_path, "w") as f:
    f.write(content)

print("    xrdp.ini atualizado: paleta Dracula + layout moderno + Xorg isolado")
PYEOF

# Otimizações no xrdp.ini
echo "  -> Otimizando xrdp.ini (performance)..."
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/tcp_nodelay=false/tcp_nodelay=true/g' /etc/xrdp/xrdp.ini 2>/dev/null || true
    sed -i 's/max_bpp=\(32\|24\)/max_bpp=16/g' /etc/xrdp/xrdp.ini 2>/dev/null || true
    sed -i 's/#use_compression=yes/use_compression=yes/g' /etc/xrdp/xrdp.ini 2>/dev/null || true
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
echo "  -> Criando startwm.sh..."

if [ -f /etc/xrdp/startwm.sh ] && [ ! -f /etc/xrdp/startwm.sh.orig ]; then
    cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.orig
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
echo "  -> Criando autostart..."

cat > "$HOME_DIR/.config/openbox/autostart" <<AUTOSTART_CONTENT
#!/bin/bash

# Log de debug
exec > /tmp/openbox-autostart.log 2>&1
echo "Autostart iniciado em \$(date)"

# Garante ~/.local/bin no PATH
export PATH="\$HOME/.local/bin:\$PATH"

# Aplica tema GTK Yaru-dark (visual moderno Ubuntu)
export GTK_THEME=Yaru-dark

# GTK2 fallback (Yaru-dark gtk2 pode não existir no 22.04)
if [ -f /usr/share/themes/Yaru-dark/gtk-2.0/gtkrc ]; then
    export GTK2_RC_FILES=/usr/share/themes/Yaru-dark/gtk-2.0/gtkrc
fi

# Configura teclado ABNT2
setxkbmap -layout br -variant abnt2 &

# Desabilita screensaver
xset s off &
xset -dpms &
xset s noblank &

# Background sólido (cor escura estilo Ubuntu)
xsetroot -solid "$BG_COLOR" &
echo "Background sólido aplicado"

# Inicia tint2 (dock moderno com Show Applications + Relógio)
sleep 1
tint2 &
echo "Tint2 iniciado"

AUTOSTART_CONTENT

# Lança o editor fixado como wallpaper
if [ "$EDITOR" = "vscode" ]; then
    cat >> "$HOME_DIR/.config/openbox/autostart" <<'EDITOREOF'
sleep 2
code --disable-gpu --disable-dev-shm-usage --js-flags="--max-old-space-size=2048" &
echo "VS Code iniciado"

echo "Autostart finalizado em $(date)"
EDITOREOF
elif [ "$EDITOR" = "vscodium" ]; then
    cat >> "$HOME_DIR/.config/openbox/autostart" <<'EDITOREOF'
sleep 2
codium --disable-gpu --disable-dev-shm-usage --disable-smooth-scrolling --js-flags="--max-old-space-size=1024" &
echo "VSCodium iniciado"

echo "Autostart finalizado em $(date)"
EDITOREOF
elif [ "$EDITOR" = "neovim" ]; then
    cat >> "$HOME_DIR/.config/openbox/autostart" <<'EDITOREOF'
sleep 2
gnome-terminal --title="nvim-desktop" -- bash -c "while true; do nvim; sleep 0.5; done" &
echo "Neovim iniciado"

echo "Autostart finalizado em $(date)"
EDITOREOF
fi

chmod +x "$HOME_DIR/.config/openbox/autostart"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"

echo -e "${GREEN}  Configuração XRDP finalizada${NC}"
echo ""

# LIMPEZA DO MENU DE APLICATIVOS
# Mostra apenas os apps selecionados no Rofi, esconde o resto com NoDisplay=true

echo -e "${GREEN}[+] Limpando menu de aplicativos...${NC}"

ALLOWED_APPS=(
    "google-chrome.desktop"
    "pcmanfm.desktop"
    "org.gnome.FileRoller.desktop"
    "file-roller.desktop"
    "org.gnome.eog.desktop"
    "eog.desktop"
    "org.gnome.Screenshot.desktop"
    "gnome-screenshot.desktop"
    "org.gnome.Terminal.desktop"
    "gnome-terminal.desktop"
    "mousepad.desktop"
    "org.gnome.Evince.desktop"
    "evince.desktop"
    "org.gnome.Calculator.desktop"
    "gnome-calculator.desktop"
)

# Limpa overrides antigos de execuções anteriores para evitar lixo
echo "  Limpando overrides antigos..."
rm -f "$HOME_DIR/.local/share/applications"/*.desktop 2>/dev/null || true

# Função para esconder um .desktop (cria override com NoDisplay=true)
hide_desktop() {
    local file="$1"
    local filename=$(basename "$file")
    cp "$file" "$HOME_DIR/.local/share/applications/$filename"
    if ! grep -q "^NoDisplay=" "$HOME_DIR/.local/share/applications/$filename"; then
        echo "NoDisplay=true" >> "$HOME_DIR/.local/share/applications/$filename"
    else
        sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$HOME_DIR/.local/share/applications/$filename"
    fi
}

# Varre /usr/share/applications e esconde tudo que não está na lista
for desktop_file in /usr/share/applications/*.desktop; do
    [ -f "$desktop_file" ] || continue
    filename=$(basename "$desktop_file")

    is_allowed=false
    for allowed in "${ALLOWED_APPS[@]}"; do
        if [ "$filename" == "$allowed" ]; then
            is_allowed=true
            break
        fi
    done

    if [ "$is_allowed" == "false" ]; then
        hide_desktop "$desktop_file"
    fi
done

# Para apps permitidos com OnlyShowIn/NotShowIn, cria override local sem a restrição
# (rofi drun respeita OnlyShowIn e esconde apps que não pertencem ao desktop atual)
echo "  Corrigindo apps com OnlyShowIn (incompatível com Openbox)..."
for allowed in "${ALLOWED_APPS[@]}"; do
    src="/usr/share/applications/$allowed"
    dst="$HOME_DIR/.local/share/applications/$allowed"
    if [ -f "$src" ] && grep -qE "^(OnlyShowIn|NotShowIn)=" "$src"; then
        cp "$src" "$dst"
        sed -i '/^OnlyShowIn=/d' "$dst"
        sed -i '/^NotShowIn=/d' "$dst"
        echo "     $allowed (removido OnlyShowIn/NotShowIn)"
    fi
done

# Força esconder apps que podem estar em outros diretórios
# VSCodium (fixado no fundo, não deve aparecer no menu)
FORCE_HIDE=(
    "codium.desktop"
    "codium-url-handler.desktop"
    "code.desktop"
    "code-url-handler.desktop"
    "thunar.desktop"
    "org.xfce.thunar.desktop"
    "org.xfce.thunar-settings.desktop"
    "xfce4-about.desktop"
    "xfce4-terminal.desktop"
    "xfce4-terminal-emulator.desktop"
    "org.xfce.mousepad.desktop"
    "leafpad.desktop"
    "nautilus-autorun-software.desktop"
    "org.gnome.Nautilus.desktop"
    "nautilus.desktop"
    "org.gnome.TextEditor.desktop"
    "gnome-text-editor.desktop"
    "org.gnome.gedit.desktop"
    "gedit.desktop"
)

for app_name in "${FORCE_HIDE[@]}"; do
    src="/usr/share/applications/$app_name"
    if [ -f "$src" ]; then
        hide_desktop "$src"
    else
        printf '[Desktop Entry]\nType=Application\nName=Hidden\nNoDisplay=true\n' > "$HOME_DIR/.local/share/applications/$app_name"
    fi
done

# Reforço: esconde VSCodium em TODOS os diretórios XDG (garante que não aparece no rofi)
echo "  -> Reforçando ocultação do VSCodium em todos os diretórios XDG..."
for xdg_dir in /usr/share/applications /usr/local/share/applications /opt/codium /opt/vscodium; do
    [ -d "$xdg_dir" ] || continue
    for codium_file in "$xdg_dir"/codium*.desktop "$xdg_dir"/vscodium*.desktop "$xdg_dir"/VSCodium*.desktop; do
        [ -f "$codium_file" ] || continue
        filename=$(basename "$codium_file")
        cp "$codium_file" "$HOME_DIR/.local/share/applications/$filename"
        if grep -q "^NoDisplay=" "$HOME_DIR/.local/share/applications/$filename"; then
            sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$HOME_DIR/.local/share/applications/$filename"
        else
            echo "NoDisplay=true" >> "$HOME_DIR/.local/share/applications/$filename"
        fi
        echo "     $filename oculto (origem: $xdg_dir)"
    done
done
# Stubs para nomes conhecidos, independente de onde o VSCodium foi instalado
for stub in codium.desktop codium-url-handler.desktop vscodium.desktop vscodium-url-handler.desktop; do
    if [ ! -f "$HOME_DIR/.local/share/applications/$stub" ]; then
        printf '[Desktop Entry]\nType=Application\nName=Hidden\nNoDisplay=true\n' > "$HOME_DIR/.local/share/applications/$stub"
        echo "     Stub criado: $stub"
    fi
done

# Reforço: esconde VS Code em TODOS os diretórios XDG (igual ao bloco do VSCodium)
echo "  -> Reforçando ocultação do VS Code em todos os diretórios XDG..."
for xdg_dir in /usr/share/applications /usr/local/share/applications /opt/vscode /opt/microsoft/vscode; do
    [ -d "$xdg_dir" ] || continue
    for vscode_file in "$xdg_dir"/code*.desktop "$xdg_dir"/vscode*.desktop "$xdg_dir"/visual-studio-code*.desktop; do
        [ -f "$vscode_file" ] || continue
        filename=$(basename "$vscode_file")
        cp "$vscode_file" "$HOME_DIR/.local/share/applications/$filename"
        if grep -q "^NoDisplay=" "$HOME_DIR/.local/share/applications/$filename"; then
            sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$HOME_DIR/.local/share/applications/$filename"
        else
            echo "NoDisplay=true" >> "$HOME_DIR/.local/share/applications/$filename"
        fi
        echo "     $filename oculto (origem: $xdg_dir)"
    done
done
# Stubs para nomes conhecidos do VS Code
for stub in code.desktop code-url-handler.desktop visual-studio-code.desktop; do
    if [ ! -f "$HOME_DIR/.local/share/applications/$stub" ]; then
        printf '[Desktop Entry]\nType=Application\nName=Hidden\nNoDisplay=true\n' > "$HOME_DIR/.local/share/applications/$stub"
        echo "     Stub criado: $stub"
    fi
done

# Edita diretamente os arquivos de sistema para VS Code e VSCodium
# (override local nem sempre tem precedência no rofi — editar o sistema garante o resultado)
echo "  -> Aplicando NoDisplay=true direto nos .desktop do sistema..."
for sys_desktop in \
    /usr/share/applications/code.desktop \
    /usr/share/applications/code-url-handler.desktop \
    /usr/share/applications/codium.desktop \
    /usr/share/applications/codium-url-handler.desktop \
    /usr/share/applications/visual-studio-code.desktop \
    /usr/share/applications/vscodium.desktop; do
    [ -f "$sys_desktop" ] || continue
    if grep -q "^NoDisplay=" "$sys_desktop"; then
        sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$sys_desktop"
    else
        sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$sys_desktop"
    fi
    echo "     $(basename $sys_desktop) ocultado no sistema"
done

# Cria .desktop para apps que podem não ter um (garante que aparecem no rofi)
if [ ! -f /usr/share/applications/org.gnome.Terminal.desktop ] && [ ! -f /usr/share/applications/gnome-terminal.desktop ]; then
    cat > "$HOME_DIR/.local/share/applications/gnome-terminal.desktop" <<'TERMEOF'
[Desktop Entry]
Type=Application
Name=Terminal
Comment=GNOME Terminal
Exec=gnome-terminal
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;
TERMEOF
    echo "    + Criado gnome-terminal.desktop (não existia)"
fi

if [ ! -f /usr/share/applications/mousepad.desktop ]; then
    cat > "$HOME_DIR/.local/share/applications/mousepad.desktop" <<'MOUSEEOF'
[Desktop Entry]
Type=Application
Name=Editor de Texto
Comment=Mousepad
Exec=mousepad
Icon=accessories-text-editor
Terminal=false
Categories=Utility;TextEditor;
MOUSEEOF
    echo "    + Criado mousepad.desktop (não existia)"
fi

if [ ! -f /usr/share/applications/pcmanfm.desktop ]; then
    cat > "$HOME_DIR/.local/share/applications/pcmanfm.desktop" <<'PCMEOF'
[Desktop Entry]
Type=Application
Name=Arquivos
Comment=PCManFM - Gerenciador de Arquivos
Exec=pcmanfm
Icon=system-file-manager
Terminal=false
Categories=System;FileManager;
PCMEOF
    echo "    + Criado pcmanfm.desktop (não existia)"
fi

if [ ! -f /usr/share/applications/org.gnome.Calculator.desktop ] && [ ! -f /usr/share/applications/gnome-calculator.desktop ]; then
    cat > "$HOME_DIR/.local/share/applications/gnome-calculator.desktop" <<'CALCEOF'
[Desktop Entry]
Type=Application
Name=Calculator
Comment=GNOME Calculator
Exec=gnome-calculator
Icon=accessories-calculator
Terminal=false
Categories=Utility;Calculator;
CALCEOF
    echo "    + Criado gnome-calculator.desktop (não existia)"
fi

# Recria o .desktop do show-applications (foi apagado na limpeza)
cat > "$HOME_DIR/.local/share/applications/show-applications.desktop" <<'DESKTOPEOF'
[Desktop Entry]
Type=Application
Name=Show Applications
Icon=show-apps
Exec=show-applications
NoDisplay=true
DESKTOPEOF

chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.local/share/applications"
update-desktop-database "$HOME_DIR/.local/share/applications" 2>/dev/null || true
echo -e "${GREEN}   Menu limpo - apenas apps selecionados visíveis${NC}"
echo ""

# FASE 8: FINALIZAÇÃO

echo -e "${GREEN}[8/8] Finalizando Instalação...${NC}"

# Configura ZRAM (swap comprimido em RAM para reduzir latência em VM)
echo "  -> Configurando ZRAM..."
apt install -y --no-install-recommends --no-install-suggests zram-tools 2>/dev/null || true

# Configura ZRAM com lz4 (compressão ultra-rápida, ideal para VMs com CPU limitada)
cat > /etc/default/zramswap <<'ZRAMEOF'
ALGO=lz4
PERCENT=60
PRIORITY=100
ZRAMEOF
echo -e "${GREEN}    ZRAM configurado (60% da RAM, compressão lz4)${NC}"

# Tunagem do kernel para otimizar uso de memória
echo "  -> Configurando parâmetros de kernel (sysctl)..."
# Remove entradas antigas para evitar duplicatas
sed -i '/^vm.swappiness/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.vfs_cache_pressure/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.dirty_ratio/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.dirty_background_ratio/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.page-cluster/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.watermark_boost_factor/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^kernel.nmi_watchdog/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^kernel.numa_balancing/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.min_free_kbytes/d' /etc/sysctl.conf 2>/dev/null || true

cat >> /etc/sysctl.conf <<'SYSCTLEOF'
vm.swappiness=180
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.page-cluster=0
vm.watermark_boost_factor=0
vm.min_free_kbytes=65536
kernel.nmi_watchdog=0
kernel.numa_balancing=0
SYSCTLEOF
echo -e "${GREEN}    Parâmetros de kernel otimizados${NC}"

# Desabilita swap em disco se existir (zram é mais rápido em VM)
swapoff -a 2>/dev/null || true
# Remove entradas de swap de disco do fstab (mantém apenas zram)
sed -i '/\sswap\s/d' /etc/fstab 2>/dev/null || true

# Ativa zram
systemctl enable zramswap 2>/dev/null || true
systemctl restart zramswap 2>/dev/null || true

echo -e "${GREEN}    ZRAM ativo${NC}"

# Desabilita THP (Transparent Huge Pages) - causa bloat de memória em VMs
echo "  -> Desabilitando Transparent Huge Pages (THP)..."
echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
# Persiste via GRUB para sobreviver ao reboot
if [ -f /etc/default/grub ]; then
    # Remove entradas anteriores para evitar duplicatas
    sed -i 's/ transparent_hugepage=never//g' /etc/default/grub 2>/dev/null || true
    sed -i 's/ zswap\.enabled=0//g' /etc/default/grub 2>/dev/null || true
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 transparent_hugepage=never zswap.enabled=0"/' /etc/default/grub
    update-grub 2>/dev/null || true
fi

# Desabilita zswap imediatamente (conflita com ZRAM - dupla compressão em RAM)
[ -f /sys/kernel/mm/zswap/enabled ] && echo 0 > /sys/kernel/mm/zswap/enabled 2>/dev/null || true
echo -e "${GREEN}    THP e zswap desabilitados${NC}"

# Desabilita serviços desnecessários em VM (economia de RAM)
echo "  -> Desabilitando serviços desnecessários..."
DISABLE_SERVICES=(
    "ModemManager"
    "NetworkManager-wait-online"
    "accounts-daemon"
    "power-profiles-daemon"
    "switcheroo-control"
    "cups"
    "cups-browsed"
    "avahi-daemon"
    "bluetooth"
    "wpa_supplicant"
    "packagekit"
    "snapd"
    "snapd.seeded"
    "snapd.socket"
    "unattended-upgrades"
)

for svc in "${DISABLE_SERVICES[@]}"; do
    if systemctl list-unit-files "$svc.service" 2>/dev/null | grep -q "$svc"; then
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        systemctl mask "$svc" 2>/dev/null || true
        echo "    $svc desabilitado"
    fi
done
echo -e "${GREEN}    Serviços desnecessários desabilitados${NC}"

# Limita tamanho do journal do systemd (evita consumo crescente de RAM/disco)
echo "  -> Limitando journal do systemd..."
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size-limit.conf <<'JOURNALEOF'
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=64M
JOURNALEOF
systemctl restart systemd-journald 2>/dev/null || true
echo -e "${GREEN}    Journal limitado (50M disco, 16M runtime)${NC}"

# Desabilita core dumps (economia de disco e memória)
echo "  -> Desabilitando core dumps..."
sed -i '/\* hard core 0/d' /etc/security/limits.conf 2>/dev/null || true
sed -i '/\* soft core 0/d' /etc/security/limits.conf 2>/dev/null || true
echo "* hard core 0" >> /etc/security/limits.conf
echo "* soft core 0" >> /etc/security/limits.conf
if ! grep -q "kernel.core_pattern" /etc/sysctl.conf 2>/dev/null; then
    echo "kernel.core_pattern=/dev/null" >> /etc/sysctl.conf
fi
sysctl -p 2>/dev/null || true
echo -e "${GREEN}    Core dumps desabilitados${NC}"

# Instala earlyoom (proteção contra OOM - mata processo menos importante antes de congelar)
echo "  -> Instalando earlyoom..."
apt install -y --no-install-recommends --no-install-suggests earlyoom 2>/dev/null || true
if command -v earlyoom >/dev/null 2>&1; then
    EARLYOOM_VER=$(earlyoom --version 2>&1 | grep -oP '\d+\.\d+' | head -1 || echo "0.0")
    EARLYOOM_MAJOR=$(echo "${EARLYOOM_VER:-0.0}" | cut -d. -f1)
    EARLYOOM_MINOR=$(echo "${EARLYOOM_VER:-0.0}" | cut -d. -f2)
    # --prefer/--avoid disponíveis apenas no earlyoom >= 1.6
    if [ "${EARLYOOM_MAJOR:-0}" -gt 1 ] || { [ "${EARLYOOM_MAJOR:-0}" -eq 1 ] && [ "${EARLYOOM_MINOR:-0}" -ge 6 ]; }; then
        cat > /etc/default/earlyoom <<'EOOMEOF'
EARLYOOM_ARGS="-r 3600 -m 5 -s 5 --avoid '(codium|openbox|tint2|Xorg|xrdp)'"
EOOMEOF
        echo -e "${GREEN}    earlyoom >= 1.6: --prefer/--avoid ativos${NC}"
    else
        cat > /etc/default/earlyoom <<'EOOMEOF'
EARLYOOM_ARGS="-r 3600 -m 5 -s 5"
EOOMEOF
        echo -e "${YELLOW}    earlyoom < 1.6 detectado: flags --prefer/--avoid não disponíveis${NC}"
    fi
    systemctl enable earlyoom 2>/dev/null || true
    systemctl restart earlyoom 2>/dev/null || true
    echo -e "${GREEN}    earlyoom configurado${NC}"
else
    echo -e "${YELLOW}    earlyoom não instalado (pacote indisponível no repositório)${NC}"
fi

# Limpeza de cache apt (libera espaço em disco)
echo "  -> Limpando cache do apt..."
apt autoremove -y 2>/dev/null || true
apt clean 2>/dev/null || true
rm -rf /var/lib/apt/lists/* 2>/dev/null || true
echo -e "${GREEN}    Cache apt limpo${NC}"

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

echo "  -> Reiniciando serviços XRDP..."
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
