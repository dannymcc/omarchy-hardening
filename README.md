# Omarchy Hardening

```
 ██████  ███    ███  █████  ██████   ██████ ██   ██ ██    ██
██    ██ ████  ████ ██   ██ ██   ██ ██      ██   ██  ██  ██
██    ██ ██ ████ ██ ███████ ██████  ██      ███████   ████
██    ██ ██  ██  ██ ██   ██ ██   ██ ██      ██   ██    ██
 ██████  ██      ██ ██   ██ ██   ██  ██████ ██   ██    ██

█ █ ▄▀█ █▀█ █▀▄ █▀▀ █▄ █ █ █▄ █ █▀▀
█▀█ █▀█ █▀▄ █▄▀ ██▄ █ ▀█ █ █ ▀█ █▄█
```

Interactive security hardening for [Omarchy](https://github.com/basecamp/omakub/wiki/omarchy) and Arch Linux installations.

## A Word of Caution

**You should not rely on automation to secure your system.**

This tool exists to demonstrate security improvements, but the best approach is to understand your distribution and make these changes yourself. Read the source code, understand each command, and run them manually. This builds knowledge you'll need when things go wrong.

See [A Word on Omarchy](https://xn--gckvb8fzb.com/a-word-on-omarchy/) for the context behind these recommendations.

## Before You Begin

1. **Create a snapshot**: `omarchy-snapshot create`
2. **Read the source code**: Understand what each option does before enabling it

## Quick Start

```bash
git clone https://github.com/dannymcc/omarchy-hardening.git
cd omarchy-hardening
./omarchy-hardening.sh
```

## Options

The script provides an interactive menu with five hardening options. None are selected by default - you must explicitly choose what to apply.

### 1. Disable LLMNR

**What it is:** LLMNR (Link-Local Multicast Name Resolution) is a protocol that resolves hostnames on local networks when DNS fails.

**Why disable it:** LLMNR is a well-known attack vector. Attackers on your local network can respond to LLMNR queries before legitimate hosts, redirecting your traffic to malicious destinations. Tools like Responder exploit this for credential theft.

**What the script does:**
1. Creates `/etc/systemd/resolved.conf.d/disable-llmnr.conf` with `LLMNR=no`
2. Restarts systemd-resolved

**Manual equivalent:**
```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
echo -e "[Resolve]\nLLMNR=no" | sudo tee /etc/systemd/resolved.conf.d/disable-llmnr.conf
sudo systemctl restart systemd-resolved
```

### 2. Enable UFW Firewall

**What it is:** UFW (Uncomplicated Firewall) is a frontend for iptables that simplifies firewall management.

**Why enable it:** Earlier versions of Omarchy shipped with UFW rules pre-configured but the service was not enabled, leaving systems exposed. This has since been fixed in newer releases.

**What the script does:**
1. Resets all existing UFW rules (`ufw --force reset`)
2. Sets default policy: deny incoming, allow outgoing
3. Allows SSH connections (port 22)
4. Enables the UFW service

**Manual equivalent:**
```bash
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable
```

**Note:** The reset step removes any existing rules. If you have custom firewall rules, apply this option carefully or configure UFW manually.

### 3. Tailscale-only SSH

**What it is:** Restricts SSH to only accept connections from your Tailscale network.

**Why use it:** SSH exposed to the public internet is constantly targeted by brute-force attacks. By binding SSH only to your Tailscale IP, the service becomes invisible to the public internet. Attackers cannot connect to a service they cannot reach.

**What the script does:**
1. Creates `/etc/ssh/sshd_config.d/tailscale-only.conf`
2. Sets `ListenAddress` to your Tailscale IPv4 address
3. Disables password authentication (keys only)
4. Restarts sshd

**Manual equivalent:**
```bash
TAILSCALE_IP=$(tailscale ip -4)
sudo mkdir -p /etc/ssh/sshd_config.d
cat << EOF | sudo tee /etc/ssh/sshd_config.d/tailscale-only.conf
ListenAddress $TAILSCALE_IP
PasswordAuthentication no
EOF
sudo systemctl restart sshd
```

**Prerequisites:** Tailscale must be installed and connected. Ensure you can SSH via Tailscale before enabling this option, or you may lock yourself out.

### 4. Limit Login Attempts

**What it is:** Configures PAM faillock to lock accounts after repeated failed login attempts.

**Why reduce it:** Omarchy increases the default faillock attempts from 3 to 10, making brute-force attacks against local accounts easier. If someone gains physical access or a shell, they have more attempts to guess passwords.

**What the script does:**
1. Edits `/etc/security/faillock.conf`
2. Sets `deny=3` (or your configured value)

**Manual equivalent:**
```bash
sudo sed -i 's/^deny = .*/deny = 3/' /etc/security/faillock.conf
```

### 5. Configure Git Signing

**What it is:** Enables SSH-based commit signing for Git.

**Why use it:** Git commits are trivially forgeable - anyone can set any name and email in their git config. SSH signing cryptographically proves that commits came from someone with access to your private key. GitHub displays a "Verified" badge on signed commits.

**What the script does:**
1. Sets `user.signingkey` to your SSH public key
2. Enables commit and tag signing (`gpg.format=ssh`, `commit.gpgsign=true`, `tag.gpgsign=true`)
3. Applies workflow optimizations (pull.rebase, rerere, etc.)
4. Optionally configures GitHub credential helper

**Manual equivalent:**
```bash
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global gpg.format ssh
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```

**Next step:** Add your SSH key to GitHub as a signing key (Settings > SSH and GPG keys > New SSH key > Key type: Signing Key).

## Configuration

Press `c` in the menu to configure:
- **SSH Key Path**: Location of your SSH public key for Git signing (default: `~/.ssh/id_ed25519.pub`)
- **Max Login Attempts**: Failed attempts before lockout (default: 3)
- **Git Name/Email**: Your identity for commits
- **GitHub Username**: For credential helper configuration

## License

MIT
