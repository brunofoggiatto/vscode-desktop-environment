#!/bin/bash

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}VS Code Desktop Environment${NC}"
echo -e "${GREEN}Instalador v1.0${NC}"
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

# Pega o usuário que executou sudo
if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo -e "${RED}Não foi possível determinar o usuário. Execute com sudo.${NC}"
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)

echo -e "${GREEN}Usuário detectado: $USER_NAME${NC}"
echo -e "${GREEN}Diretório home: $HOME_DIR${NC}\n"

echo -e "${GREEN}[1/6] Atualizando sistema...${NC}"
apt-get update
apt-get upgrade -y

echo -e "${GREEN}[2/6] Instalando X11 e dependências mínimas...${NC}"
apt-get install -y \
    xorg \
    xinit \
    x11-xserver-utils \
    dbus-x11 \
    wget \
    gpg \
    apt-transport-https

echo -e "${GREEN}[3/6] Instalando gerenciador de janelas leve (opcional)...${NC}"
# Openbox é útil para gerenciar janelas, mas é opcional
apt-get install -y openbox

echo -e "${GREEN}[4/6] Instalando Visual Studio Code...${NC}"
# Verifica se VS Code já está instalado
if ! command -v code >/dev/null 2>&1; then
    # Adiciona repositório oficial do VS Code
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms_vscode.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms_vscode.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    
    apt-get update
    apt-get install -y code
    echo "VS Code instalado com sucesso!"
else
    echo "VS Code já está instalado. Pulando instalação."
fi

echo -e "${GREEN}[5/6] Instalando scripts e configuração de auto-login + startx...${NC}"

# Copiar script de início da sessão
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p /opt/vscode-session

if [ -f "$SCRIPT_DIR/start-vscode-session" ]; then
    cp "$SCRIPT_DIR/start-vscode-session" /usr/local/bin/start-vscode-session
    chmod +x /usr/local/bin/start-vscode-session
    echo "Script start-vscode-session copiado."
else
    echo -e "${YELLOW}Aviso: start-vscode-session não encontrado em $SCRIPT_DIR${NC}"
    echo "Criando script padrão..."
    cat > /usr/local/bin/start-vscode-session <<'STARTSCRIPT'
#!/bin/bash
# Script para iniciar sessão VS Code

# Aguarda o X11 estar pronto
sleep 2

# Define variáveis de ambiente
export DISPLAY=:0

# Desabilita screensaver e power management
xset s off
xset -dpms
xset s noblank

# Inicia Openbox em background (gerenciador de janelas)
openbox &

# Aguarda Openbox iniciar
sleep 1

# Inicia VS Code em fullscreen
code --disable-gpu-sandbox --unity-launch &

# Mantém a sessão X ativa
wait
STARTSCRIPT
    chmod +x /usr/local/bin/start-vscode-session
fi

# Criar .xinitrc para o usuário
cat > "${HOME_DIR}/.xinitrc" <<'XINIT'
#!/bin/sh
# Arquivo .xinitrc — executa o start-vscode-session
exec /usr/local/bin/start-vscode-session
XINIT
chmod +x "${HOME_DIR}/.xinitrc"
chown ${USER_NAME}:${USER_NAME} "${HOME_DIR}/.xinitrc"
echo ".xinitrc criado."

# Configurar auto-login no tty1 usando override do systemd getty
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_NAME} --noclear %I \$TERM
EOF
echo "Auto-login configurado."

# Garantir que ao logar no tty1 o startx seja executado
cat > "${HOME_DIR}/.bash_profile" <<'BASHP'
# .bash_profile para autostart X on tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec /usr/bin/startx
fi
BASHP
chmod 644 "${HOME_DIR}/.bash_profile"
chown ${USER_NAME}:${USER_NAME} "${HOME_DIR}/.bash_profile"
echo ".bash_profile criado."

# Systemd daemon-reload
systemctl daemon-reload

# Enable getty autologin override (será usado automaticamente no boot)
systemctl enable getty@tty1.service

echo -e "${GREEN}[6/6] Configurações de permissão e finalização...${NC}"
chown -R ${USER_NAME}:${USER_NAME} "${HOME_DIR}"

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Instalação concluída!${NC}"
echo -e "${GREEN}================================${NC}\n"

echo -e "${YELLOW}Próximos passos:${NC}"
echo -e "1. Reinicie a máquina para entrar automaticamente no VS Code:"
echo -e "   ${GREEN}sudo reboot${NC}\n"
echo -e "2. Para testar sem reiniciar:"
echo -e "   ${GREEN}sudo systemctl restart getty@tty1.service && sudo chvt 1${NC}\n"

echo -e "${YELLOW}Sugestões pós-instalação:${NC}"
echo "  - Acesse a VM via console ou interface do hypervisor"
echo "  - Configure extensões do VS Code conforme necessário"
echo "  - Ajuste o layout do teclado se necessário (setxkbmap)"

exit 0