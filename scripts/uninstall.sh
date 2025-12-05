#!/bin/bash

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}--- INICIANDO DESINSTALAÇÃO DO AMBIENTE KIOSK ---${NC}"

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

echo -e "${YELLOW}Removendo pacotes principais...${NC}"

# Remove VSCodium, Openbox, Tint2, XRDP e outros instalados
apt-get purge -y codium openbox obconf tint2 xrdp pcmanfm terminator feh featherpad google-chrome-stable || true

echo -e "${YELLOW}Removendo repositórios e chaves...${NC}"
rm -f /etc/apt/sources.list.d/vscodium.list
rm -f /usr/share/keyrings/vscodium-archive-keyring.gpg
apt-get update -qq

echo -e "${YELLOW}Limpando configurações do usuário ($USER_NAME)...${NC}"

# Remove as pastas de configuração criadas
rm -rf "$HOME_DIR/.config/openbox"
rm -rf "$HOME_DIR/.config/tint2"

# Remove configurações do VSCodium 
rm -rf "$HOME_DIR/.config/VSCodium"

# Remove o arquivo de sessão que forçava o Openbox
rm -f "$HOME_DIR/.xsession"

# Remove configurações do XRDP
rm -rf /etc/xrdp

echo -e "${YELLOW}Limpando sistema (Autoremove)...${NC}"
apt-get autoremove -y
apt-get clean

echo ""
echo -e "${GREEN}Desinstalação concluída.${NC}"
echo "Reinicie a máquina: reboot"