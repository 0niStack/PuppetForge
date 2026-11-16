#!/usr/bin/env bash
# Usage: ./apply.sh          -> dry run (--noop) then asks to apply
#        ./apply.sh --yes    -> apply without asking
set -euo pipefail
cd "$(dirname "$0")"

PUPPET=/opt/puppetlabs/bin/puppet
[ -x "$PUPPET" ] || { echo "Puppet not found. Run ./install-puppet.sh first."; exit 1; }

echo "== Dry run =="
sudo "$PUPPET" apply --noop nginx.pp

if [ "${1:-}" != "--yes" ]; then
  read -rp "Apply for real? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

echo "== Applying =="
sudo "$PUPPET" apply nginx.pp

echo "== Verify =="
curl -s http://localhost || echo "curl failed - check: systemctl status nginx"
