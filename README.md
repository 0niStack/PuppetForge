# Puppet + nginx lab

| Folder | What it does |
|---|---|
| `01-local/`  | Installs Puppet and configures nginx on **this** machine with `puppet apply` |
| `02-remote/` | Asks for a VM's **IP + SSH key**, installs Puppet on the VM over SSH and applies the same manifest |

Written for Ubuntu/Debian. Run the scripts as a normal user with sudo.

## Why no Bolt?

Bolt 5.0 and later is only published in a protected repository that needs Puppet Core or
Puppet Enterprise credentials, so `apt install puppet-bolt` fails on Ubuntu 24.04 with
"Unable to locate package". `02-remote/` therefore uses plain `ssh` + `scp` + `puppet apply`.
It needs no extra tools on your machine and no credentials.

## Layout

```
puppet-nginx-lab/
├── README.md
├── 01-local/
│   ├── install-puppet.sh   # installs puppet-agent (Puppet 8)
│   ├── apply.sh            # dry run -> apply -> curl check
│   └── nginx.pp
└── 02-remote/
    ├── deploy.sh           # prompts for IP/user/key, installs puppet on VM, applies
    └── nginx.pp
```

## 01 - Local

```bash
cd 01-local
./install-puppet.sh
./apply.sh
```

Check: `curl http://localhost` prints `Hello from Puppet on <hostname>`.
Run `./apply.sh` again: it should report no changes.

## 02 - Remote VM

Needs: Ubuntu/Debian VM reachable over SSH, and a user with passwordless sudo.

```bash
cd 02-remote
./deploy.sh
```

Prompts: VM IP/hostname, SSH user (default `ubuntu`), port (default `22`),
private key path (default `~/.ssh/id_ed25519`).

Steps it performs (each prints its progress):

```
[1/6] Testing SSH
[2/6] Checking passwordless sudo
[3/6] Looking for puppet on the VM (installs puppet-agent if missing)
[4/6] Copying nginx.pp
[5/6] Dry run (puppet apply --noop), then asks to continue
[6/6] Applying, then curl check
```

If the key is missing, or login fails, it offers to generate a key and run `ssh-copy-id`.
Any failure prints `ERROR at line N: <command>`.

Passwordless sudo, run on the VM:

```bash
echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/ubuntu
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Script stops with no message | Run `bash -x ./deploy.sh`; the last `+` line is the failing command |
| Test SSH by hand | `ssh -v -i ~/.ssh/id_ed25519 -o BatchMode=yes user@VM_IP 'echo SSH_OK'` |
| `Permission denied (publickey)` | `ssh-copy-id -i ~/.ssh/id_ed25519.pub user@VM_IP`; on AWS you may need the `.pem` key path instead |
| `Passwordless sudo
