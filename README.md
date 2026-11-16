# Puppet + nginx lab

| Folder | What it does |
|---|---|
| `01-local/`  | Installs Puppet and configures nginx on **this** machine with `puppet apply` |
| `02-remote/` | Asks for a VM's **IP + SSH key**, then configures nginx on the VM over SSH with **Puppet Bolt** |

Written for Ubuntu/Debian. Run the scripts as a normal user with sudo.
Classic Puppet agent/server uses certificates, not SSH, which is why Bolt is used for the remote VM.

## Layout

```
puppet-nginx-lab/
├── README.md
├── 01-local/
│   ├── install-puppet.sh   # installs puppet-agent (Puppet 8)
│   ├── apply.sh            # dry run -> apply -> curl check
│   └── nginx.pp            # the manifest
└── 02-remote/
    ├── install-bolt.sh     # installs puppet-bolt
    ├── deploy.sh           # prompts for IP/user/key, builds inventory, applies
    └── nginx.pp            # same manifest
```

## 01 - Local

```bash
cd 01-local
./install-puppet.sh
./apply.sh            # shows a --noop dry run, then asks before applying
```

Check: `curl http://localhost` should print `Hello from Puppet on <hostname>`.
Run `./apply.sh` again: it should report no changes (idempotent).

## 02 - Remote VM

Prerequisites on the VM: Ubuntu/Debian, SSH reachable, your user has sudo
(passwordless sudo is easiest).

```bash
cd 02-remote
./deploy.sh
```

It will ask for:

1. VM IP or hostname
2. SSH user (default `ubuntu`)
3. SSH port (default `22`)
4. Path to your private key (default `~/.ssh/id_ed25519`)

Then it:

- installs Bolt if missing
- generates the key and runs `ssh-copy-id` if the key doesn't exist or login fails
- tests key-based SSH login
- writes `inventory.yaml` (git-ignored)
- checks it can run as root via sudo
- runs `bolt apply nginx.pp --noop`, asks to continue, then applies for real
- curls the VM to verify

### Passwordless sudo on the VM (if the check fails)

```bash
echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/ubuntu
```

### Manual commands (what the script runs)

```bash
bolt command run 'hostname && whoami' --targets web1
bolt apply nginx.pp --targets web1 --noop
bolt apply nginx.pp --targets web1
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `curl` to the VM hangs | `sudo ufw allow 80/tcp` on the VM, and open port 80 in your cloud/hypervisor firewall |
| `Permission denied (publickey)` | Run `ssh-copy-id -i ~/.ssh/id_ed25519.pub user@VM_IP`; check the key path |
| `puppet: command not found` | Use `/opt/puppetlabs/bin/puppet` or add it to PATH |
| `.deb` download 404 | Your distro codename isn't published; see https://apt.puppet.com and edit the URL in the install script |
| Rocky/RHEL | Replace `apt`/`dpkg` in the install scripts with the matching `.rpm` release package from https://yum.puppet.com |

## Security notes

- `host-key-check: false` is for labs only. Remove it in production and pin host keys.
- Never commit private keys. `inventory.yaml` is git-ignored because it contains your key path and IP.

## Next steps

- Add more VMs under `targets:` in `inventory.yaml` and use `--targets all`.
- Turn `nginx.pp` into a module with `.epp` templates for `/etc/nginx/conf.d/`.
- Use `notify => Service['nginx']` on config files so nginx reloads on change.
