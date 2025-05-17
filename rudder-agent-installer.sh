#!/bin/bash
# Rudder Agent Installer for Rudder 8.3+ (auto-detect OS, handles pinning + approval pause)

set -e

# Prompt for Rudder server instead of using a static variable
read -p "Enter the Rudder server FQDN or IP (e.g. rudder.example.com): " RUDDER_SERVER
INSECURE=true

echo "[*] Starting Rudder agent bootstrap..."

# Exit if Alpine (unsupported)
if grep -qi alpine /etc/os-release; then
    echo "[❌] Alpine Linux is not supported by Rudder. Exiting."
    exit 1
fi

# OS Detection
source /etc/os-release
OS="$ID"
VER_ID="${VERSION_ID%%.*}"

echo "[*] Detected OS: $OS $VERSION_ID"

# Determine compatible repo codename
case "$OS" in
  debian)
    case "$VER_ID" in
      10) RUDDER_REPO_DIST="buster" ;;
      11) RUDDER_REPO_DIST="bullseye" ;;
      12) RUDDER_REPO_DIST="bookworm" ;;
      *) echo "[!] Unsupported Debian version: $VERSION_ID"; exit 1 ;;
    esac
    ;;
  ubuntu)
    case "$VER_ID" in
      20|22|24) RUDDER_REPO_DIST="bookworm" ;;
      *) echo "[!] Unsupported Ubuntu version: $VERSION_ID"; exit 1 ;;
    esac
    ;;
  *)
    echo "[!] Unsupported OS: $OS"
    exit 1
    ;;
esac

echo "[*] Using Rudder APT repo for: $RUDDER_REPO_DIST"

# Add Rudder APT repository
echo "deb [trusted=yes] https://repository.rudder.io/apt/8.3/ $RUDDER_REPO_DIST main" > /etc/apt/sources.list.d/rudder.list

# Install agent
apt update
apt install -y rudder-agent

# Pin to Rudder server (use --insecure on first contact)
if [ "$INSECURE" = true ]; then
    echo "[*] Pinning to Rudder server with --insecure bootstrap..."
    rudder agent policy-server "$RUDDER_SERVER" --insecure
else
    rudder agent policy-server "$RUDDER_SERVER"
fi

# Submit initial inventory
echo "[*] Submitting initial inventory..."
rudder agent inventory

# Pause and wait for user to approve the node
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋  Rudder agent has submitted inventory."
echo "🕹️  Please approve the node in the Rudder Web UI:"
echo "    ➜ Nodes → Accept new nodes"
echo
read -n 1 -s -r -p "✅ Once approved, press any key to finish agent registration..."
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Final policy pull + compliance run
echo "[*] Finishing setup: pulling policies and submitting report..."
rudder agent update
rudder agent check
rudder agent inventory
rudder agent run

echo "[✅] Rudder agent fully registered and policy-compliant with $RUDDER_SERVER"
