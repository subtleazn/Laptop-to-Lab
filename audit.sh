#!/bin/bash

# ==============================================================================
# ULTIMATE SYSTEM AUDIT: FORENSIC + EDUCATIONAL + TRASH COMPLIANCE
# Purpose: Deep inspection with explanations for every check.
# ==============================================================================

# CONFIG
REAL_USER=${SUDO_USER:-$(whoami)}
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}   FULL SYSTEM AUDIT REPORT${NC}"
echo -e "${BLUE}   User: $REAL_USER | Kernel: $(uname -r)${NC}"
echo -e "${BLUE}   Time: $(date)${NC}"
echo -e "${BLUE}==========================================================${NC}"

# ------------------------------------------------------------------------------
# 1. NETWORK & HARDWARE FORENSICS
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[1] NETWORK IDENTIFICATION${NC}"
echo "    > WHY: You need the MAC Address to set a 'Static IP' in your Router."
echo "      You need the IP to know how to connect via SSH or Portainer."

IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$IFACE" ]; then IFACE=$(ls /sys/class/net | grep -v lo | head -n1); fi
IP=$(hostname -I | awk '{print $1}')
MAC=$(cat /sys/class/net/$IFACE/address 2>/dev/null)
GATEWAY=$(ip route | grep default | awk '{print $3}')

echo "   - Interface:     $IFACE"
echo "   - MAC Address:   $MAC"
echo "   - IP Address:    $IP"
echo "   - Gateway:       $GATEWAY"

# LISTENING PORTS
echo -e "\n${YELLOW}[1.1] OPEN PORTS (LISTENING)${NC}"
echo "    > WHY: These are the doors currently open on your server."
echo "      You should see 22 (SSH), 445 (SMB), and 9001 (Portainer)."
echo "   - Ports:         $(ss -tuln | awk 'NR>1 {print $5}' | cut -d: -f2 | sort -nu | tr '\n' ' ')"

# ------------------------------------------------------------------------------
# 2. FILESYSTEM LOGIC (TRaSH Guides)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2] TRaSH GUIDES COMPLIANCE (Hardlinks)${NC}"
echo "    > WHY: For 'Atomic Moves' (Instant transfers), your Torrents and Media"
echo "      folders MUST be on the same physical disk partition. If they differ,"
echo "      files will copy slowly and take up double space."

# Check Folders
if [ -d "/data/torrents" ] && [ -d "/data/media" ]; then
    # Get Physical Device IDs
    DEV_TOR=$(stat -c '%d' /data/torrents)
    DEV_MED=$(stat -c '%d' /data/media)

    if [ "$DEV_TOR" == "$DEV_MED" ]; then
        echo -e "   - Hardlinks:     ${GREEN}ACTIVE${NC} (Device ID: $DEV_TOR)"
        echo "     > VERDICT: Perfect. Downloads will import instantly."
    else
        echo -e "   - Hardlinks:     ${RED}FAILED${NC}"
        echo "     > Torrents on Device $DEV_TOR"
        echo "     > Media on Device    $DEV_MED"
        echo "     > VERDICT: Bad. Imports will be slow copies."
    fi
else
    echo -e "   - Folders:       ${RED}MISSING${NC}"
    echo "     > Please create /data/torrents and /data/media to use the *Arr stack."
fi

# Permissions Check
echo -e "\n${YELLOW}[2.1] PERMISSIONS CHECK${NC}"
echo "    > WHY: If 'root' owns your data, your apps (running as user) cannot"
echo "      write to the folders."
OWNER=$(stat -c '%U' /data 2>/dev/null)
if [ "$OWNER" == "$REAL_USER" ]; then
    echo -e "   - Ownership:     ${GREEN}CORRECT ($OWNER)${NC}"
else
    echo -e "   - Ownership:     ${RED}WRONG ($OWNER)${NC} (Run setup.sh to fix)"
fi

# ------------------------------------------------------------------------------
# 3. PERFORMANCE TUNING
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3] PERFORMANCE TUNING (Swappiness)${NC}"
echo "    > WHY: Linux defaults to 60, which uses the slow disk too often."
echo "      For a server, we want 10 or 1, to keep data in fast RAM."

SWAP=$(cat /proc/sys/vm/swappiness 2>/dev/null)
if [ "$SWAP" -le 10 ]; then
    echo -e "   - Swappiness:    ${GREEN}OPTIMIZED ($SWAP)${NC}"
else
    echo -e "   - Swappiness:    ${RED}HIGH ($SWAP)${NC} (Recommended: 10)"
fi

# ------------------------------------------------------------------------------
# 4. CONFIGURATION FORENSICS (Samba & Security)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4] WINDOWS ACCESS (Samba)${NC}"
echo "    > WHY: Allows you to see '/data' as a Network Drive on Windows."

if grep -q "\[Data\]" /etc/samba/smb.conf 2>/dev/null; then
    echo -e "   - Samba Share:   ${GREEN}FOUND${NC}"
    # Show the actual config block so you can verify it
    grep -A 2 "\[Data\]" /etc/samba/smb.conf | grep "path" | sed 's/^/     /'
    
    if pdbedit -L 2>/dev/null | grep -q "$REAL_USER"; then
        echo -e "   - Samba User:    ${GREEN}OK ($REAL_USER)${NC}"
    else
        echo -e "   - Samba User:    ${RED}MISSING${NC} (Windows login will fail)"
    fi
else
    echo -e "   - Samba Share:   ${RED}MISSING${NC} ([Data] block not found in config)"
fi

echo -e "\n${YELLOW}[4.1] FIREWALL STATUS (UFW)${NC}"
echo "    > WHY: You need a firewall to block random internet traffic, but allow"
echo "      your specific apps (SSH, Plex, Sonarr)."

if ufw status | grep -q "Status: active"; then
    echo -e "   - Firewall:      ${GREEN}ACTIVE${NC}"
else
    echo -e "   - Firewall:      ${RED}INACTIVE${NC} (ALL PORTS ARE OPEN - RISKY)"
fi

# ------------------------------------------------------------------------------
# 5. SOFTWARE VERSIONS
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[5] SOFTWARE STACK${NC}"
check_ver() {
    if command -v $1 >/dev/null; then
        VER=$($1 --version 2>&1 | head -n 1 | awk '{print $NF}' | tr -d ',')
        echo -e "   - $1:          ${GREEN}INSTALLED${NC} (v$VER)"
    else
        echo -e "   - $1:          ${RED}MISSING${NC}"
    fi
}
check_ver "docker"
check_ver "git"
check_ver "curl"
check_ver "ufw"

# ------------------------------------------------------------------------------
# 6. DOCKER RUNTIME
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[6] RUNNING CONTAINERS${NC}"
echo "    > WHY: Verifies that the 'Portainer Agent' is alive so the remote"
echo "      server can control this machine."

if systemctl is-active --quiet docker; then
    # WE CHECK FOR BOTH AGENT NAMES HERE (Standard or Edge)
    if docker ps --format '{{.Names}}' | grep -qE "portainer_agent|portainer_edge_agent"; then
        echo -e "   - Portainer Agt: ${GREEN}ONLINE${NC}"
    else
        echo -e "   - Portainer Agt: ${RED}OFFLINE${NC} (Remote control broken)"
    fi

    # Print Table
    echo "   - Container List:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | sed 's/^/     /'
else
    echo -e "   - Docker Daemon: ${RED}STOPPED${NC}"
fi

echo -e "${BLUE}==========================================================${NC}"
