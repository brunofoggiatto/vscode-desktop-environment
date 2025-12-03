#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}VS Code RDP Environment${NC}"
echo -e "${YELLOW}Desinstalador v2.0${NC}"
echo -e "${YELLOW}================================${NC}\n"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Por favor, execute como root (sudo)${NC}"
    exit 1
fi

if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo -e "${RED}Não foi possível determinar o usuário.${NC}"
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)

echo -e "${RED}ATENÇÃO: Esta operação irá:${NC}"
echo "  - Parar e remover xrdp"
echo "  - Remover Openbox"
echo "  - Remover configurações personalizadas"
echo "  - Opcionalmente remover VS Code"
echo ""
read -p "Deseja continuar? (s/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    exit 1
fi

echo -e "\n${GREEN}[1/5] Parando e desabilitando xrdp...${NC}"
systemctl stop xrdp
systemctl disable xrdp

echo -e "${GREEN}[2/5] Removendo xrdp...${NC}"
apt-get remove -y xrdp
apt-get autoremove -y

echo -e "${GREEN}[3/5] Removendo Openbox...${NC}"
apt-get remove -y openbox

echo -e "${GREEN}[4/5] Removendo configurações personalizadas...${NC}"
rm -rf $HOME_DIR/.config/openbox
rm -f /etc/xrdp/startwm.sh

echo ""
read -p "Deseja remover o VS Code também? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${GREEN}[5/5] Removendo VS Code...${NC}"
    apt-get remove -y code
    apt-get autoremove -y
    rm -f /etc/apt/sources.list.d/vscode.list
    rm -f /usr/share/keyrings/ms_vscode.gpg
    echo "VS Code removido."
else
    echo -e "${GREEN}[5/5] Mantendo VS Code instalado${NC}"
fi

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}✓ Desinstalação concluída!${NC}"
echo -e "${GREEN}================================${NC}\n"

echo -e "${YELLOW}Sistema restaurado ao estado original.${NC}\n"

exit 0