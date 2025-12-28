#!/bin/bash

# ==============================================================================
# MASTER SERVER SETUP SCRIPT (CUMULATIVE & IDEMPOTENT)
# Includes: Docker, Portainer Agent, SSH, Samba, Firewall, Hardware, Runtime, Git
# ==============================================================================

# --- CONFIGURATION ---
# All the ports your stack needs
SERVER_PORTS="22 80 443 445 137 138 139 9001 8096 9000 9443 8123 8384 8090 7878 8989 8686 8787 6767 9696 4533 5000 13378 4567"
GIT_NAME="PinoySeoul Server"
GIT_EMAIL="server@pinoyseoul.com"

# --- SETUP VARIABLES ---
REAL_USER=${SUDO_USER:-$(whoami)}
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$REAL_USER" = "root" ]; then
    echo "ERROR: Run with 'sudo ./setup.sh'"
    exit 1
fi

echo -e "${BLUE}=== STARTING COMPLETE SERVER SETUP FOR: $REAL_USER ===${NC}"

# ==============================================================================
# PHASE 1: CORE SOFTWARE & SSH
# ==============================================================================
echo -e "\n${BLUE}[1] INSTALLING SOFTWARE STACK${NC}"
PACKAGES="curl git ufw openssh-server samba"

apt-get update -qq > /dev/null
for pkg in $PACKAGES; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        echo -e "   - $pkg:\t${GREEN}INSTALLED${NC}"
    else
        echo -e "   - $pkg:\t${YELLOW}INSTALLING...${NC}"
        apt-get install -y $pkg > /dev/null 2>&1
    fi
done

# ENSURE SSH IS RUNNING
if systemctl is-active --quiet ssh; then
    echo -e "   - SSH Service:\t${GREEN}ACTIVE${NC}"
else
    echo -e "   - SSH Service:\t${YELLOW}STARTING${NC}"
    systemctl enable --now ssh > /dev/null 2>&1
fi

# ==============================================================================
# PHASE 2: DOCKER INSTALLATION
# ==============================================================================
echo -e "\n${BLUE}[2] DOCKER ENVIRONMENT${NC}"
if command -v docker > /dev/null; then
    echo -e "   - Docker:\t\t${GREEN}INSTALLED${NC}"
else
    echo -e "   - Docker:\t\t${YELLOW}INSTALLING...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    usermod -aG docker $REAL_USER
fi

# ==============================================================================
# PHASE 3: PORTAINER AGENT (Smart Check)
# ==============================================================================
echo -e "\n${BLUE}[3] PORTAINER AGENT${NC}"
# We check for EITHER the standard agent OR the edge agent to prevent duplicates
if docker ps --format '{{.Names}}' | grep -qE "portainer_agent|portainer_edge_agent"; then
    echo -e "   - Agent:\t\t${GREEN}RUNNING${NC}"
else
    # Check if stopped
    if docker ps -a --format '{{.Names}}' | grep -qE "portainer_agent|portainer_edge_agent"; then
        echo "Starting Portainer Agent..."
        docker start portainer_agent 2>/dev/null || docker start portainer_edge_agent 2>/dev/null
    else
        echo "Deploying Standard Portainer Agent..."
        # Only deploy standard if NO agent exists at all
        docker run -d -p 9001:9001 --name portainer_agent --restart=always \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v /var/lib/docker/volumes:/var/lib/docker/volumes \
          portainer/agent:2.19.4 > /dev/null
    fi
    echo -e "   - Agent:\t\t${GREEN}DEPLOYED/ACTIVE${NC}"
fi

# ==============================================================================
# PHASE 4: FIREWALL (UFW)
# ==============================================================================
echo -e "\n${BLUE}[4] FIREWALL & SECURITY${NC}"
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null

CHANGES=0
for port in $SERVER_PORTS; do
    if ! ufw status | grep -q "$port"; then
        echo "     > Opening Port $port..."
        ufw allow "$port"/tcp > /dev/null
        CHANGES=1
    fi
done

if [ $CHANGES -eq 0 ]; then
    echo -e "   - Ports:\t\t${GREEN}ALL OPEN${NC}"
else
    echo -e "   - Ports:\t\t${GREEN}UPDATED${NC}"
fi

if ufw status | grep -q "Status: active"; then
     echo -e "   - Status:\t\t${GREEN}ACTIVE${NC}"
else
     echo -e "   - Status:\t\t${YELLOW}ENABLING...${NC}"
     ufw --force enable > /dev/null
fi

# ==============================================================================
# PHASE 5: SAMBA (WINDOWS ACCESS)
# ==============================================================================
echo -e "\n${BLUE}[5] SAMBA CONFIGURATION${NC}"
if grep -q "\[Data\]" /etc/samba/smb.conf; then
    echo -e "   - Share [Data]:\t${GREEN}EXISTS${NC}"
else
    echo -e "   - Share [Data]:\t${YELLOW}CREATING...${NC}"
    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
    cat >> /etc/samba/smb.conf <<EOF

[Data]
   path = /data
   browseable = yes
   read only = no
   guest ok = no
   create mask = 0755
   directory mask = 0755
   valid users = $REAL_USER
EOF
    systemctl restart smbd
fi

if pdbedit -L | grep -q "$REAL_USER"; then
    echo -e "   - SMB User:\t\t${GREEN}EXISTS${NC}"
else
    echo -e "   - SMB User:\t\t${YELLOW}MISSING${NC}"
    echo "     ACTION REQUIRED: Set your Windows Access Password now:"
    smbpasswd -a $REAL_USER
fi

# ==============================================================================
# PHASE 6: HARDWARE HACKS (LENOVO SPECIFIC)
# ==============================================================================
echo -e "\n${BLUE}[6] HARDWARE TUNING${NC}"
# Grub
if grep -q "acpi_backlight=video" /etc/default/grub; then
    echo -e "   - Grub Driver:\t${GREEN}FIXED${NC}"
else
    echo -e "   - Grub Driver:\t${YELLOW}PATCHING...${NC}"
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_backlight=video"/' /etc/default/grub
    update-grub > /dev/null 2>&1
fi

# Lid Switch
if grep -E "^HandleLidSwitch=ignore" /etc/systemd/logind.conf > /dev/null; then
    echo -e "   - Lid Switch:\t${GREEN}FIXED${NC}"
else
    echo -e "   - Lid Switch:\t${YELLOW}PATCHING...${NC}"
    sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
    sed -i 's/HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
    systemctl restart systemd-logind
fi

# Swappiness
if grep -q "vm.swappiness=10" /etc/sysctl.conf; then
    echo -e "   - Swappiness:\t${GREEN}OPTIMIZED${NC}"
else
    echo -e "   - Swappiness:\t${YELLOW}TUNING (10)...${NC}"
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
fi

# ==============================================================================
# PHASE 7: RUNTIME GENERATOR
# ==============================================================================
echo -e "\n${BLUE}[7] GENERATING RUNTIME.SH${NC}"
mkdir -p /data/config/lenovo
cat > /data/config/lenovo/runtime.sh <<'EOF'
#!/bin/sh
log() { echo "[$(date +'%H:%M:%S')] $1"; }
apk add --no-cache iw > /dev/null 2>&1
for iface in $(ls /sys/class/net | grep '^w'); do
    iw dev $iface set power_save off 2>/dev/null
done
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > $cpu 2>/dev/null
done
# Immediate screen off check
if [ -d /sys/class/backlight/acpi_video0 ]; then
    echo 0 > /sys/class/backlight/acpi_video0/brightness
fi
# Boot cleanup (wait 60s then force off once)
( sleep 60; echo 0 > /sys/class/backlight/acpi_video0/brightness ) &
# Battery Loop
BAT_PATH="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"
while true; do
    if [ -f "$BAT_PATH" ]; then
        current=$(cat $BAT_PATH)
        if [ "$current" != "1" ]; then
            echo 1 > $BAT_PATH
        fi
    fi
    sleep 300
done
EOF
chmod +x /data/config/lenovo/runtime.sh
echo -e "   - Runtime Script:\t${GREEN}GENERATED${NC}"

# ==============================================================================
# PHASE 8: FINAL CONFIGS
# ==============================================================================
echo -e "\n${BLUE}[8] GIT & PERMISSIONS${NC}"
# Git
CURRENT_NAME=$(git config --global user.name)
if [ -n "$CURRENT_NAME" ]; then
    echo -e "   - Git Identity:\t${GREEN}SET${NC}"
else
    echo -e "   - Git Identity:\t${YELLOW}SETTING...${NC}"
    sudo -u $REAL_USER git config --global user.name "$GIT_NAME"
    sudo -u $REAL_USER git config --global user.email "$GIT_EMAIL"
fi
# Permissions
chown -R $REAL_USER:$REAL_USER /data
echo -e "   - /data Owner:\t${GREEN}FIXED${NC}"

echo -e "\n${GREEN}=== SETUP COMPLETE ===${NC}"
