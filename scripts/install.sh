#!/bin/bash
set -e

# Definição das cores
GREEN='\033[0;32m'
NC='\033[0m'

echo "Iniciando a configuracao do ambiente Kiosk (VS Code + Openbox)..."
echo "Correcao v3.1: Forcando ativacao do Tema Dracula via settings.json."

# Verifica se é root
if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute este script como root (sudo)."
    exit 1
fi

# Pega o nome do usuário real que chamou o sudo
if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo "Não foi possível identificar o usuário. Rode com sudo."
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)
echo "Configurando para o usuário: $USER_NAME"

echo -e "${GREEN}[1/7] Atualizando sistema...${NC}"
apt-get update -qq
apt-get upgrade -y -qq

echo -e "${GREEN}[2/7] Instalando dependências...${NC}"
apt-get install -y xrdp openbox obconf x11-xserver-utils dbus-x11 wmctrl

echo -e "${GREEN}[3/7] Instalando VS Code...${NC}"
if ! command -v code >/dev/null 2>&1; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms_vscode.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms_vscode.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    apt-get update -qq
    apt-get install -y code
else
    echo "VS Code já está instalado."
fi

echo -e "${GREEN}[4/7] Instalando Extensões...${NC}"

# Garante que o VS Code esteja fechado para não bloquear arquivos
killall code 2>/dev/null || true

# Cria diretório de config e ajusta permissão temporária
mkdir -p "$HOME_DIR/.config/Code/User"
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"

echo "Baixando tema Dracula e Ícones..."
# Instala extensões forçando modo sem sandbox
sudo -u $USER_NAME code --install-extension dracula-theme.theme-dracula --force --no-sandbox
sudo -u $USER_NAME code --install-extension PKief.material-icon-theme --force --no-sandbox

echo -e "${GREEN}[5/7] Aplicando Configurações (Tema e Layout)...${NC}"

# Escreve settings.json FORÇANDO o tema
cat > "$HOME_DIR/.config/Code/User/settings.json" <<'EOF'
{
  "workbench.colorTheme": "Dracula",
  "workbench.iconTheme": "material-icon-theme",
  "editor.fontSize": 14,
  "editor.fontFamily": "'Cascadia Code', 'Fira Code', 'Consolas', monospace",
  "window.menuBarVisibility": "classic",
  "window.titleBarStyle": "native",
  "editor.minimap.enabled": true,
  "workbench.startupEditor": "none",
  "window.commandCenter": false,
  "workbench.enableExperiments": false,
  "security.workspace.trust.enabled": false
}
EOF

# Ajusta permissões do settings.json imediatamente
chown $USER_NAME:$USER_NAME "$HOME_DIR/.config/Code/User/settings.json"

echo -e "${GREEN}[6/7] Configurando Openbox e RDP...${NC}"

# Script de boot do XRDP
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
exec openbox-session
EOF
chmod +x /etc/xrdp/startwm.sh

# Configuração XML do Openbox (Limpo e Seguro)
mkdir -p "$HOME_DIR/.config/openbox"
echo '<?xml version="1.0" encoding="UTF-8"?>' > "$HOME_DIR/.config/openbox/rc.xml"
cat >> "$HOME_DIR/.config/openbox/rc.xml" <<'EOF'
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
  </placement>
  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
  </focus>
  <theme>
    <name>Clearlooks</name>
    <titleLayout></titleLayout>
    <keepBorder>no</keepBorder>
    <animateIconify>no</animateIconify>
    <font place="ActiveWindow">
      <name>sans</name>
      <size>8</size>
    </font>
  </theme>
  <desktops>
    <number>1</number>
  </desktops>
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
  </keyboard>
  <mouse>
    <dragThreshold>8</dragThreshold>
  </mouse>
  <applications>
    <application class="*">
      <decor>no</decor>
      <maximized>yes</maximized>
      <fullscreen>yes</fullscreen>
    </application>
  </applications>
</openbox_config>
EOF

echo -e "${GREEN}[7/7] Configurando Inicialização...${NC}"
cat > "$HOME_DIR/.config/openbox/autostart" <<'EOF'
#!/bin/bash
# Desliga economia de energia
xset s off &
xset -dpms &
xset s noblank &

# Fundo preto
xsetroot -solid "#000000" &
sleep 2

# Inicia VS Code
code --disable-gpu --disable-gpu-sandbox --no-sandbox --start-fullscreen --disable-dev-shm-usage &

# Garante fullscreen
sleep 4
wmctrl -r "Visual Studio Code" -b add,fullscreen 2>/dev/null || true
EOF
chmod +x "$HOME_DIR/.config/openbox/autostart"

echo -e "${GREEN}Finalizando...${NC}"

# Ajuste final de permissões (Garante que o usuário é dono de tudo)
chown -R $USER_NAME:$USER_NAME "$HOME_DIR/.config"

usermod -aG ssl-cert $USER_NAME
systemctl enable xrdp
systemctl restart xrdp

echo ""
echo -e "${GREEN}Instalação concluída!!!${NC}"
echo "Reinicie a máquina."