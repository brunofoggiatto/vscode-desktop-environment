#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  DESINSTALACAO AMBIENTE DE DESENVOLVIMENTO BY BRUNO FOGGIATTO ${NC}"
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

read -p "Tem certeza que deseja desinstalar? (s/n): " resp
if [[ ! "$resp" =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Operacao cancelada${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}[1/4] Parando servicos...${NC}"

systemctl stop xrdp 2>/dev/null || true
systemctl stop xrdp-sesman 2>/dev/null || true
systemctl disable xrdp 2>/dev/null || true
systemctl disable xrdp-sesman 2>/dev/null || true

echo -e "${GREEN}  Servicos parados${NC}"

echo ""
echo -e "${GREEN}[2/4] Removendo pacotes...${NC}"

apt-get remove --purge -y \
    xrdp \
    xorgxrdp \
    openbox \
    obconf \
    terminator \
    codium \
    2>/dev/null || true

apt-get autoremove -y 2>/dev/null || true

echo -e "${GREEN}  Pacotes removidos${NC}"

echo ""
echo -e "${GREEN}[3/4] Removendo configuracoes...${NC}"

rm -rf "$HOME_DIR/.config/openbox" 2>/dev/null || true
rm -rf "$HOME_DIR/.config/VSCodium" 2>/dev/null || true
rm -rf "$HOME_DIR/.config/terminator" 2>/dev/null || true
rm -f "$HOME_DIR/.xsession" 2>/dev/null || true

rm -f /etc/apt/sources.list.d/vscodium.list 2>/dev/null || true
rm -f /usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null || true

echo -e "${GREEN}  Configuracoes removidas${NC}"

echo ""
echo -e "${GREEN}[4/4] Limpando cache...${NC}"

apt-get clean
apt-get autoclean

echo -e "${GREEN}  Cache limpo${NC}"

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}   DESINSTALACAO CONCLUIDA COM SUCESSO!!!                      ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "  ${YELLOW}Reinicie a maquina:${NC}"
echo -e "  ${BLUE}sudo reboot${NC}"
echo ""
