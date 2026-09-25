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
# 2. Select Machine Purpose (Personal vs Work)
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
export BOOTSTRAP_ENV_FLAG

# ------------------------------------------------------------------------------
# 3. Authenticate Bitwarden and run bootstrap through fnox
#
# bitwarden/fnox are pulled in via `mise exec` here instead of `mise use -g`:
# `mise use -g` would write ~/.config/mise/config.toml, which makes
# `mise bootstrap --adopt` refuse to adopt the repo afterwards.
#
# fnox needs fnox.toml on disk before it will resolve anything. That
# file only exists once this repo is cloned into ~/.config/mise. So we
# clone it ourselves with plain git first (a no-op if already cloned).
# ------------------------------------------------------------------------------
echo ""
echo "[-] Preparing Bitwarden + fnox and running bootstrap..."
mise exec bitwarden@latest fnox@latest -- bash -c '
    set -euo pipefail

    echo "[-] Configuring Bitwarden server (https://vault.bitwarden.eu)..."
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
    export BW_SESSION="$(bw unlock --raw)"
    echo "[✓] Bitwarden vault unlocked"

    DOTFILES_REPO="nikokultalahti/mise-bootstrap-dotfiles"
    DOTFILES_DIR="$HOME/.config/mise"

    if [ ! -d "$DOTFILES_DIR/.git" ]; then
        echo "[-] Cloning dotfiles repo into $DOTFILES_DIR..."
        git clone "https://github.com/${DOTFILES_REPO}.git" "$DOTFILES_DIR"
    else
        echo "[✓] $DOTFILES_DIR is already a git checkout"
    fi

    cd "$DOTFILES_DIR"
    echo "[-] Running bootstrap through fnox..."
    fnox exec -- mise $BOOTSTRAP_ENV_FLAG bootstrap --adopt "$DOTFILES_REPO"
'
