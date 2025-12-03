#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}VS Code RDP Environment${NC}"
echo -e "${GREEN}Ultra Minimal Edition v2.0${NC}"
echo -e "${GREEN}================================${NC}\n"

# Verifica se é root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Por favor, execute como root (sudo)${NC}"
    exit 1
fi

# Verifica Ubuntu 22.04
if ! grep -q "22.04" /etc/os-release; then
    echo -e "${YELLOW}Aviso: Este script foi testado apenas no Ubuntu 22.04${NC}"
    read -p "Deseja continuar? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Pega o usuário
if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo -e "${RED}Não foi possível determinar o usuário. Execute com sudo.${NC}"
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)

echo -e "${GREEN}Usuário: $USER_NAME${NC}"
echo -e "${GREEN}Home: $HOME_DIR${NC}\n"

echo -e "${GREEN}[1/7] Atualizando sistema...${NC}"
apt-get update
apt-get upgrade -y

echo -e "${GREEN}[2/7] Instalando xrdp...${NC}"
apt-get install -y xrdp

echo -e "${GREEN}[3/7] Instalando Openbox (gerenciador de janelas minimalista)...${NC}"
apt-get install -y \
    openbox \
    x11-xserver-utils \
    dbus-x11

echo -e "${GREEN}[4/7] Instalando VS Code...${NC}"
if ! command -v code >/dev/null 2>&1; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms_vscode.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms_vscode.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    apt-get update
    apt-get install -y code
    echo "VS Code instalado com sucesso!"
else
    echo "VS Code já está instalado."
fi

echo -e "${GREEN}[5/7] Configurando sessão para exibir APENAS VS Code em tela cheia...${NC}"

# Cria startwm.sh que inicia Openbox
cat > /etc/xrdp/startwm.sh <<'STARTWM'
#!/bin/sh
# xrdp X session start script - VS Code Full Screen Mode

if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi

# Inicia Openbox (invisível, só para gerenciar janelas)
exec openbox-session
STARTWM

chmod +x /etc/xrdp/startwm.sh

# Cria diretório de config do Openbox
mkdir -p $HOME_DIR/.config/openbox

# Configuração do Openbox - VS Code sem bordas e em tela cheia
cat > $HOME_DIR/.config/openbox/rc.xml <<'RCXML'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc" 
                xmlns:xi="http://www.w3.org/2001/XInclude">
  
  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>

  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
  </focus>

  <placement>
    <policy>Smart</policy>
  </placement>

  <theme>
    <name>Clearlooks</name>
    <titleLayout></titleLayout>
    <keepBorder>no</keepBorder>
    <animateIconify>no</animateIconify>
  </theme>

  <desktops>
    <number>1</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Desktop</name>
    </names>
    <popupTime>0</popupTime>
  </desktops>

  <applications>
    <!-- VS Code: sem bordas, tela cheia, maximizado -->
    <application class="code" type="normal">
      <decor>no</decor>
      <maximized>yes</maximized>
      <fullscreen>yes</fullscreen>
      <focus>yes</focus>
      <desktop>1</desktop>
      <layer>normal</layer>
      <skip_pager>yes</skip_pager>
      <skip_taskbar>yes</skip_taskbar>
    </application>
    
    <!-- Qualquer outra aplicação também sem bordas -->
    <application type="normal">
      <decor>no</decor>
      <maximized>yes</maximized>
    </application>
  </applications>

  <!-- Remove todos os keybindings para evitar fechar janelas acidentalmente -->
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
  </keyboard>

  <!-- Remove mouse bindings do Openbox -->
  <mouse>
    <dragThreshold>1</dragThreshold>
    <doubleClickTime>200</doubleClickTime>
  </mouse>

</openbox_config>
RCXML

# Autostart - Inicia VS Code automaticamente
cat > $HOME_DIR/.config/openbox/autostart <<'AUTOSTART'
#!/bin/bash

# Desabilita screensaver e power management
xset s off &
xset -dpms &
xset s noblank &

# Remove qualquer barra de tarefas ou painel
killall tint2 2>/dev/null
killall lxpanel 2>/dev/null
killall plank 2>/dev/null

# Define fundo preto (caso VS Code demore para abrir)
xsetroot -solid "#000000" &

# Aguarda Openbox carregar completamente
sleep 3

# Inicia VS Code em tela cheia
code \
    --disable-gpu \
    --disable-gpu-sandbox \
    --no-sandbox \
    --start-fullscreen \
    --disable-dev-shm-usage &

# Aguarda VS Code abrir
sleep 2

# Força fullscreen usando wmctrl (se disponível)
if command -v wmctrl >/dev/null 2>&1; then
    wmctrl -r "Visual Studio Code" -b add,fullscreen
fi
AUTOSTART

chmod +x $HOME_DIR/.config/openbox/autostart

# Ajusta permissões
chown -R $USER_NAME:$USER_NAME $HOME_DIR/.config

echo -e "${GREEN}[6/7] Configurando xrdp para iniciar automaticamente...${NC}"

# Habilita e inicia xrdp
systemctl enable xrdp
systemctl restart xrdp

# Adiciona usuário ao grupo ssl-cert
usermod -aG ssl-cert $USER_NAME

echo -e "${GREEN}[7/7] Finalizando...${NC}"

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN} Instalação concluída!${NC}"
echo -e "${GREEN}================================${NC}\n"







