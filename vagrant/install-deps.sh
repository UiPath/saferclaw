#!/bin/bash

set -euo pipefail

: "${AZURE_SUBSCRIPTION_ID:?AZURE_SUBSCRIPTION_ID must be set}"
: "${DEFENDER_SETUP_SCRIPT_URL:?DEFENDER_SETUP_SCRIPT_URL must be set}"

# Fix some weird hash mismatches happening on `apt update`, only on ARM devices,
# by disabling HTTP pipelining, caching and intermediate proxies.
echo "Acquire::http::Pipeline-Depth 0;" > /etc/apt/apt.conf.d/99custom && \
echo "Acquire::http::No-Cache true;" >> /etc/apt/apt.conf.d/99custom && \
echo "Acquire::BrokenProxy    true;" >> /etc/apt/apt.conf.d/99custom

# Install deps:
apt update
test -x "$(type -p curl)" || apt install -y curl
test -x "$(type -p gpg)"  || apt install -y gpg
test -x "$(type -p git)" || apt install -y git
test -x "$(type -p unzip)" || apt install -y unzip
test -x "$(type -p ca-certificates)" || apt install -y ca-certificates

## Install Microsoft Defender
echo "=== Installing Microsoft Defender ==="
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
wget https://raw.githubusercontent.com/microsoft/mdatp-xplat/master/linux/installation/mde_installer.sh \
    -O ~/mde_installer.sh
wget "$DEFENDER_SETUP_SCRIPT_URL" \
    -O ~/MicrosoftDefenderATPOnboardingLinuxServer.py
chmod +x ~/mde_installer.sh
~/mde_installer.sh \
    --install \
    --channel prod \
    --tag GROUP OPENCLAW \
    --pre-req \
    -y \
    -p
echo -e "=== END ===\n"

## Install Azure CLI
echo "=== Installing Azure CLI ==="
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
echo -e "=== END ===\n"

## Install nginx with Lua module
echo "=== Installing nginx ==="
apt install -y nginx libnginx-mod-http-lua
echo -e "=== END ===\n"

## Install fluent-bit
echo "=== Installing fluent-bit ==="
codename=$(
    grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release 2>/dev/null || \
    lsb_release -cs 2>/dev/null
)
curl https://packages.fluentbit.io/fluentbit.key | gpg --dearmor > /usr/share/keyrings/fluentbit-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/debian/$codename $codename main" | \
    sudo tee /etc/apt/sources.list.d/fluent-bit.list
apt update
apt install -y fluent-bit
echo -e "=== END ===\n"
## jq, used at runtime to extract information from the current state of openclaw
echo "=== Installing jq ==="
apt install -y jq
echo -e "=== END ===\n"

## install fast node manager
echo "=== Installing Node ==="
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
apt install -y nodejs
corepack enable pnpm
# Verify pnpm version:
pnpm -v
pnpm config set minimumReleaseAge 4320 && \
pnpm config set global-bin-dir /usr/local/bin && \
pnpm config set global-dir /usr/local/lib/node_modules && \
echo -e "=== END ===\n"

echo "=== Installing openclaw ==="
pnpm add -g openclaw --prod --ignore-scripts
echo -e "=== END ===\n"
