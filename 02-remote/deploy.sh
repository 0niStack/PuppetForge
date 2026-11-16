#!/usr/bin/env bash
# Interactive: asks for the VM IP and SSH key, builds inventory.yaml,
# tests SSH, then applies nginx.pp to the VM with Puppet Bolt.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v bolt >/dev/null 2>&1; then
  echo "Bolt not found."
  read -rp "Install it now? [Y/n] " a
  [[ "${a:-Y}" =~ ^[Nn]$ ]] && exit 1
  bash ./install-bolt.sh
fi

read -rp "Remote VM IP or hostname: " VM_IP
[ -n "$VM_IP" ] || { echo "IP is required."; exit 1; }

read -rp "SSH user [ubuntu]: " SSH_USER
SSH_USER="${SSH_USER:-ubuntu}"

read -rp "SSH port [22]: " SSH_PORT
SSH_PORT="${SSH_PORT:-22}"

read -rp "Path to SSH private key [~/.ssh/id_ed25519]: " KEY
KEY="${KEY:-~/.ssh/id_ed25519}"
KEY="${KEY/#\~/$HOME}"

if [ ! -f "$KEY" ]; then
  echo "Key not found: $KEY"
  read -rp "Generate a new ed25519 key there? [Y/n] " g
  [[ "${g:-Y}" =~ ^[Nn]$ ]] && exit 1
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "puppet-bolt"
  echo "Copying public key to the VM (you'll be asked for the VM password once)..."
  ssh-copy-id -i "${KEY}.pub" -p "$SSH_PORT" "${SSH_USER}@${VM_IP}"
fi
chmod 600 "$KEY"

echo "Testing SSH..."
if ! ssh -i "$KEY" -p "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=10 \
     -o StrictHostKeyChecking=accept-new "${SSH_USER}@${VM_IP}" 'echo SSH_OK' | grep -q SSH_OK; then
  echo "SSH key login failed."
  read -rp "Copy your public key to the VM now with ssh-copy-id? [y/N] " c
  if [[ "$c" =~ ^[Yy]$ ]]; then
    ssh-copy-id -i "${KEY}.pub" -p "$SSH_PORT" "${SSH_USER}@${VM_IP}"
  else
    exit 1
  fi
fi

cat > inventory.yaml <<YAML
targets:
  - name: web1
    uri: ${VM_IP}
config:
  transport: ssh
  ssh:
    user: ${SSH_USER}
    port: ${SSH_PORT}
    private-key: ${KEY}
    host-key-check: false   # lab setting; remove in production
    run-as: root
YAML
echo "Wrote inventory.yaml"

echo "Checking sudo on the VM..."
bolt command run 'whoami' --targets web1 || {
  echo "Bolt could not run as root. On the VM, enable passwordless sudo:"
  echo "  echo '${SSH_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${SSH_USER}"
  exit 1
}

echo "== Dry run =="
bolt apply nginx.pp --targets web1 --noop

read -rp "Apply for real? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

bolt apply nginx.pp --targets web1

echo "== Verify =="
curl -s --max-time 10 "http://${VM_IP}" || \
  echo "curl failed - open port 80 on the VM (sudo ufw allow 80/tcp) and in any cloud firewall."
