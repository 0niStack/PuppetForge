#!/usr/bin/env bash
# Installs Puppet Bolt on Ubuntu/Debian (runs on YOUR machine, not the VM).
set -euo pipefail

if command -v bolt >/dev/null 2>&1; then
  echo "Bolt already installed: $(bolt --version)"
  exit 0
fi

. /etc/os-release
CODENAME="${VERSION_CODENAME:-$(lsb_release -cs)}"
URL="https://apt.puppet.com/puppet-tools-release-${CODENAME}.deb"

echo "Downloading $URL"
wget -q "$URL" -O /tmp/puppet-tools-release.deb
sudo dpkg -i /tmp/puppet-tools-release.deb
sudo apt-get update
sudo apt-get install -y puppet-bolt
echo "Installed: $(bolt --version)"
