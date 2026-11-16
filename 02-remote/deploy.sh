#!/usr/bin/env bash
# Asks for the VM IP + SSH key, then over plain SSH:
#   1) installs puppet-agent on the VM (if missing)
#   2) copies nginx.pp to the VM
#   3) runs `puppet apply` (dry run first) with sudo
set -euo pipefail
trap 'echo "ERROR at line $LINENO: $BASH_COMMAND" >&2' ERR
cd "$(dirname "$0")"

read -rp "Remote VM IP or hostname: " VM_IP
[ -n "$VM_IP" ] || { echo "IP is required."; exit 1; }

read -rp "SSH user [ubuntu]: " SSH_USER
SSH_USER="${SSH_USER:-ubuntu}"

read -rp "SSH port [22]: " SSH_PORT
SSH_PORT="${SSH_PORT:-22}"

read -rp "Path to SSH private key [~/.ssh/id_ed25519]: " KEY
KEY="${KEY:-~/.ssh/id_ed25519}"
KEY="${KEY/#\~/$HOME}"

# ---- Key missing? offer to create + copy ----
if [ ! -f "$KEY" ]; then
  echo "Key not found: $KEY"
  read -rp "Generate a new ed25519 key there? [Y/n] " g
  [[ "${g:-Y}" =~ ^[Nn]$ ]] && exit 1
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "puppet-lab"
  echo "Copying public key to the VM (password prompt, once)..."
  ssh-copy-id -i "${KEY}.pub" -p "$SSH_PORT" "${SSH_USER}@${VM_IP}"
fi
chmod 600 "$KEY"

SSH_OPTS=(-i "$KEY" -p "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
SCP_OPTS=(-i "$KEY" -P "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
TARGET="${SSH_USER}@${VM_IP}"
rssh()       { ssh -n "${SSH_OPTS[@]}" "$TARGET" "$@"; }   # no stdin
rssh_stdin() { ssh    "${SSH_OPTS[@]}" "$TARGET" "$@"; }   # reads heredoc

# ---- Test SSH ----
echo "[1/6] Testing SSH..."
SSH_OUT="$(rssh 'echo SSH_OK' 2>&1 || true)"
if ! grep -q SSH_OK <<<"$SSH_OUT"; then
  echo "SSH key login failed. SSH said:"
  echo "$SSH_OUT"
  read -rp "Run ssh-copy-id now? [y/N] " c
  if [[ "$c" =~ ^[Yy]$ ]]; then
    ssh-copy-id -i "${KEY}.pub" -p "$SSH_PORT" "$TARGET"
  else
    exit 1
  fi
fi
echo "      SSH OK"

# ---- sudo check ----
echo "[2/6] Checking passwordless sudo..."
if ! rssh 'sudo -n true' 2>/dev/null; then
  echo "Passwordless sudo is required on the VM. Run this ON THE VM:"
  echo "  echo '${SSH_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${SSH_USER}"
  exit 1
fi
echo "      sudo OK"

# ---- Find or install puppet on the VM ----
find_puppet() {
  rssh 'for p in /opt/puppetlabs/bin/puppet /usr/bin/puppet /usr/local/bin/puppet; do
          if [ -x "$p" ]; then echo "$p"; break; fi
        done; true'
}

echo "[3/6] Looking for puppet on the VM..."
PUPPET_BIN="$(find_puppet)"

if [ -z "$PUPPET_BIN" ]; then
  echo "      Not found. Installing puppet-agent on the VM..."
  rssh_stdin 'bash -s' <<'REMOTE'
set -e
export DEBIAN_FRONTEND=noninteractive
. /etc/os-release
if wget -q "https://apt.puppet.com/puppet8-release-${VERSION_CODENAME}.deb" -O /tmp/puppet8-release.deb; then
  sudo dpkg -i /tmp/puppet8-release.deb
fi
sudo apt-get update -y
sudo apt-get install -y puppet-agent
REMOTE
  PUPPET_BIN="$(find_puppet)"
  [ -n "$PUPPET_BIN" ] || { echo "Puppet install failed on the VM."; exit 1; }
fi
echo "      Using $PUPPET_BIN ($(rssh "$PUPPET_BIN --version"))"

# ---- Copy manifest ----
echo "[4/6] Copying nginx.pp..."
scp "${SCP_OPTS[@]}" nginx.pp "${TARGET}:/tmp/nginx.pp"

# ---- Dry run, then apply ----
echo "[5/6] Dry run..."
rssh "sudo $PUPPET_BIN apply --noop /tmp/nginx.pp"

read -rp "Apply for real? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

echo "[6/6] Applying..."
rssh "sudo $PUPPET_BIN apply /tmp/nginx.pp"

echo "== Verify =="
curl -s --max-time 10 "http://${VM_IP}" || \
  echo "curl from here failed (VM may be firewalled). Test on the VM: ssh in and run: curl localhost"
