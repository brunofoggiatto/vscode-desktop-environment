#!/bin/bash
set -e

# Definição das cores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Iniciando a REMOCAO do ambiente Kiosk (Uninstall)..."
echo "Isso removera o VS Code, XRDP, Openbox e as configuracoes criadas."

# Verifica se é root
if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute este script como root (sudo)."
    exit 1
fi

# Pega o nome do usuário real
if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo "Não foi possível identificar o usuário. Rode com sudo."
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)
echo "Removendo configurações do usuário: $USER_NAME"

echo -e "${GREEN}[1/5] Parando serviços...${NC}"
systemctl stop xrdp 2>/dev/null || true
systemctl disable xrdp 2>/dev/null || true

echo -e "${GREEN}[2/5] Removendo pacotes (VS Code, Openbox, XRDP)...${NC}"
# Remove os programas instalados pelo script anterior
apt-get purge -y code xrdp openbox obconf wmctrl
# Remove dependências que não são mais usadas
apt-get autoremove -y

echo -e "${GREEN}[3/5] Limpando configurações do usuário...${NC}"
# Remove pasta do Openbox criada
rm -rf "$HOME_DIR/.config/openbox"

# Remove pasta de configurações do VS Code 
# Se quiser manter dados de outros projetos, comente a linha abaixo.
rm -rf "$HOME_DIR/.config/Code"
rm -rf "$HOME_DIR/.vscode"

echo -e "${GREEN}[4/5] Limpando repositórios e chaves...${NC}"
rm -f /etc/apt/sources.list.d/vscode.list
rm -f /usr/share/keyrings/ms_vscode.gpg
rm -rf /etc/xrdp

echo -e "${GREEN}[5/5] Atualizando lista de pacotes...${NC}"
apt-get update -qq

echo ""
echo -e "${GREEN}Desinstalação concluída!${NC}"
echo "O sistema foi limpo e os serviços removidos."