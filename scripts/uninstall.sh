#!/bin/bash

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${RED} DESINSTALAÇÃO DO AMBIENTE DE DESENVOLVIMENTO ${NC}"
echo -e "${RED}  Versão 3.0.0 ${NC}"
echo ""

# Verifica root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Erro!! Execute como root: sudo bash $0${NC}"
    exit 1
fi

# Identifica usuário real
if [ -n "$SUDO_USER" ]; then
    USER_NAME=$SUDO_USER
else
    echo -e "${RED}Erro: Não foi possível identificar o usuário. Execute como: sudo bash $0${NC}"
    exit 1
fi

HOME_DIR=$(eval echo ~$USER_NAME)

echo -e "${GREEN}Usuário: ${NC}$USER_NAME"
echo -e "${GREEN}Home: ${NC}$HOME_DIR"
echo ""

# Confirmação
read -p "Tem certeza que deseja desinstalar TUDO? (s/n): " resp
if [[ ! "$resp" =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Desinstalação cancelada.${NC}"
    exit 0
fi

echo ""

# FASE 1: Para serviços
echo -e "${YELLOW}[1/6] Parando serviços...${NC}"
systemctl stop xrdp 2>/dev/null || true
systemctl stop xrdp-sesman 2>/dev/null || true
systemctl disable xrdp 2>/dev/null || true
systemctl disable xrdp-sesman 2>/dev/null || true
systemctl stop earlyoom 2>/dev/null || true
systemctl disable earlyoom 2>/dev/null || true
systemctl stop zramswap 2>/dev/null || true
systemctl disable zramswap 2>/dev/null || true
killall codium 2>/dev/null || true
killall tint2 2>/dev/null || true
killall openbox 2>/dev/null || true
killall rofi 2>/dev/null || true
echo -e "${GREEN}  Serviços parados${NC}"

# FASE 2: Remove pacotes
echo -e "${YELLOW}[2/6] Removendo pacotes...${NC}"

# Pacotes instalados pelo install.sh
apt purge -y \
    xrdp xorgxrdp xserver-xorg-core xserver-xorg-input-all x11-xserver-utils dbus-x11 \
    openbox wmctrl tint2 rofi \
    pcmanfm file-roller eog gnome-screenshot gnome-terminal mousepad gnome-calculator evince \
    zenity fonts-liberation yaru-theme-gtk yaru-theme-icon x11-xkb-utils dconf-cli libglib2.0-bin \
    codium google-chrome-stable \
    curl gnupg build-essential git python3-pip \
    zram-tools earlyoom \
    2>/dev/null || true

echo -e "${GREEN}  Pacotes removidos${NC}"

# FASE 3: Remove repositórios e chaves
echo -e "${YELLOW}[3/6] Removendo repositórios...${NC}"
rm -f /etc/apt/sources.list.d/vscodium.list
rm -f /usr/share/keyrings/vscodium-archive-keyring.gpg
apt update -qq 2>/dev/null || true
echo -e "${GREEN}  Repositórios removidos${NC}"

# FASE 4: Remove configurações do usuário
echo -e "${YELLOW}[4/6] Removendo configurações do usuário ($USER_NAME)...${NC}"

# Openbox
rm -rf "$HOME_DIR/.config/openbox"

# Tint2
rm -rf "$HOME_DIR/.config/tint2"

# Rofi (dashboard)
rm -rf "$HOME_DIR/.config/rofi"

# VSCodium
rm -rf "$HOME_DIR/.config/VSCodium"

# GTK3
rm -rf "$HOME_DIR/.config/gtk-3.0"

# Tema Openbox Dracula-Flat
rm -rf "$HOME_DIR/.themes/Dracula-Flat"

# Show Applications (script + .desktop + ícone)
rm -f "$HOME_DIR/.local/bin/show-applications"
rm -f "$HOME_DIR/.local/share/icons/show-apps.svg"

# Overrides de .desktop criados pelo install
rm -rf "$HOME_DIR/.local/share/applications"

# Sessão
rm -f "$HOME_DIR/.xsession"

# XRDP configs
rm -rf /etc/xrdp

# Logs de debug
rm -f /tmp/xsession-debug.log 2>/dev/null || true
rm -f /tmp/startwm-debug.log 2>/dev/null || true
rm -f /tmp/openbox-autostart.log 2>/dev/null || true

echo -e "${GREEN}  Configurações removidas${NC}"

# FASE 5: Reverte otimizações de sistema
echo -e "${YELLOW}[5/6] Revertendo otimizações de sistema...${NC}"

# Reverte sysctl (remove parâmetros adicionados pelo install)
echo "  → Revertendo sysctl..."
sed -i '/^vm.swappiness/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.vfs_cache_pressure/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.dirty_ratio/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.dirty_background_ratio/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.page-cluster/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^vm.watermark_boost_factor/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^kernel.nmi_watchdog/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^kernel.core_pattern/d' /etc/sysctl.conf 2>/dev/null || true
sysctl -p 2>/dev/null || true
echo -e "${GREEN}    sysctl revertido${NC}"

# Remove configuração do ZRAM
echo "  → Removendo configuração ZRAM..."
rm -f /etc/default/zramswap 2>/dev/null || true
echo -e "${GREEN}    ZRAM removido${NC}"

# Remove configuração do earlyoom
echo "  → Removendo configuração earlyoom..."
rm -f /etc/default/earlyoom 2>/dev/null || true
echo -e "${GREEN}    earlyoom removido${NC}"

# Remove limite do journal
echo "  → Revertendo journal..."
rm -f /etc/systemd/journald.conf.d/size-limit.conf 2>/dev/null || true
rmdir /etc/systemd/journald.conf.d 2>/dev/null || true
systemctl restart systemd-journald 2>/dev/null || true
echo -e "${GREEN}    Journal revertido${NC}"

# Remove core dumps config
echo "  → Revertendo core dumps..."
sed -i '/\* hard core 0/d' /etc/security/limits.conf 2>/dev/null || true
sed -i '/\* soft core 0/d' /etc/security/limits.conf 2>/dev/null || true
echo -e "${GREEN}    Core dumps revertidos${NC}"

# Desmascara serviços que foram mascarados
echo "  → Desmascarando serviços..."
MASKED_SERVICES=(
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

for svc in "${MASKED_SERVICES[@]}"; do
    systemctl unmask "$svc" 2>/dev/null || true
done
echo -e "${GREEN}    Serviços desmascarados${NC}"

echo -e "${GREEN}  Otimizações revertidas${NC}"

# FASE 6: Limpeza final
echo -e "${YELLOW}[6/6] Limpeza final...${NC}"
apt autoremove -y 2>/dev/null || true
apt clean 2>/dev/null || true
echo -e "${GREEN}  Sistema limpo${NC}"

echo ""
echo -e "${GREEN}Desinstalação concluída com sucesso!${NC}"
echo ""
echo -e "  ${YELLOW}Reinicie a máquina:${NC}"
echo -e "  ${BLUE}sudo reboot${NC}"
echo ""
