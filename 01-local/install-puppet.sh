#!/usr/bin/env bash
# Installs puppet-agent (Puppet 8) on Ubuntu/Debian.
set -euo pipefail

if [ -x /opt/puppetlabs/bin/puppet ]; then
  echo "Puppet already installed: $(/opt/puppetlabs/bin/puppet --version)"
  exit 0
fi

. /etc/os-release
CODENAME="${VERSION_CODENAME:-$(lsb_release -cs)}"
URL="https://apt.puppet.com/puppet8-release-${CODENAME}.deb"

echo "Downloading $URL"
wget -q "$URL" -O /tmp/puppet8-release.deb
sudo dpkg -i /tmp/puppet8-release.deb
sudo apt-get update
sudo apt-get install -y puppet-agent

echo "Installed: $(/opt/puppetlabs/bin/puppet --version)"
echo "Tip: add to PATH ->  echo 'export PATH=\$PATH:/opt/puppetlabs/bin' >> ~/.bashrc"
