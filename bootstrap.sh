#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "🚀 Workstation Bootstrap (Mise + Bitwarden + Fnox)"
echo "=================================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. Install & Activate Mise
# ------------------------------------------------------------------------------
if ! command -v mise &>/dev/null && [ ! -x "$HOME/.local/bin/mise" ]; then
    echo "[-] Installing Mise..."
    curl -fsSL https://mise.run | sh
    echo "[✓] Mise installed"
else
    echo "[✓] Mise is already installed"
fi

export PATH="$HOME/.local/bin:$PATH"
CURRENT_SHELL="$(basename "${SHELL:-bash}")"
eval "$("$HOME/.local/bin/mise" activate "$CURRENT_SHELL" 2>/dev/null || "$HOME/.local/bin/mise" activate bash)"

# ------------------------------------------------------------------------------
# 2. Install Bitwarden CLI and fnox
# ------------------------------------------------------------------------------
echo "[-] Ensuring bitwarden and fnox are installed globally via Mise..."
mise use -g bitwarden fnox
echo "[✓] Bitwarden CLI and fnox ready"

# ------------------------------------------------------------------------------
# 3. Configure and Authenticate Bitwarden
# ------------------------------------------------------------------------------
# Check if bw CLI is available
if ! command -v bw &>/dev/null; then
    echo "[!] Bitwarden CLI not found. Please ensure bitwarden is installed via mise."
    echo "    Run: mise use -g bitwarden"
    exit 1
fi

echo "[-] Configuring Bitwarden server (https://vault.bitwarden.eu)..."
# Only set server if not already configured to the correct URL
CURRENT_SERVER=$(bw config server 2>/dev/null || true)
if [[ "$CURRENT_SERVER" != "https://vault.bitwarden.eu" ]]; then
    bw config server https://vault.bitwarden.eu
    echo "[✓] Bitwarden server configured"
else
    echo "[✓] Bitwarden server already configured"
fi

if ! bw login --check &>/dev/null; then
    echo "[-] Logging in to Bitwarden..."
    bw login
else
    echo "[✓] Bitwarden already logged in"
fi

echo "[-] Unlocking Bitwarden vault..."
BW_SESSION="$(bw unlock --raw)"
export BW_SESSION
echo "[✓] Bitwarden vault unlocked"

# ------------------------------------------------------------------------------
# 5. Select Machine Purpose (Personal vs Work)
# ------------------------------------------------------------------------------
echo ""
echo "Select the configuration profile for this machine:"
echo "  1) Personal (Linux) [Default]"
echo "  2) Work (macOS)"
read -r -p "Enter choice [1/2, default: 1]: " CHOICE
CHOICE="${CHOICE:-1}"

if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "work" ]; then
    echo "[✓] Selected Work profile (-E work)"
    BOOTSTRAP_ENV_FLAG="-E work"
else
    echo "[✓] Selected Personal profile (-E personal)"
    BOOTSTRAP_ENV_FLAG="-E personal"
fi

# ------------------------------------------------------------------------------
# 6. Run Bootstrap via fnox
# ------------------------------------------------------------------------------
echo ""
echo "[-] Running bootstrap through fnox..."
fnox exec -- mise "$BOOTSTRAP_ENV_FLAG" bootstrap --adopt nikokultalahti/mise-bootstrap-dotfiles
