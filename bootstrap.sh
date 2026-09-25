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
# mise exec` installs/activates them ad hoc for this one
# command without touching any config file, leaving ~/.config/mise untouched
# for --adopt to clone into. They're already declared under [tools] in this
# repo's config, so this is only needed for this bootstrapping chicken-and-egg
# step.
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

    echo "[-] Running bootstrap through fnox..."
    fnox exec -- mise $BOOTSTRAP_ENV_FLAG bootstrap --adopt nikokultalahti/mise-bootstrap-dotfiles
'
