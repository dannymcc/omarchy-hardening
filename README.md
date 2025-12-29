# Omarchy Hardening

Interactive security hardening for [Omarchy](https://github.com/basecamp/omakub/wiki/omarchy) and Arch Linux installations.

Addresses security gaps identified in default configurations. See [A Word on Omarchy](https://xn--gckvb8fzb.com/a-word-on-omarchy/) for context.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/dannymcc/omarchy-hardening/main/omarchy-hardening.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/dannymcc/omarchy-hardening.git
cd omarchy-hardening
./omarchy-hardening.sh
```

## What It Does

The script provides an interactive menu to select hardening options:

| Option | Description |
|--------|-------------|
| **Disable LLMNR** | Prevents name poisoning attacks on local networks |
| **Enable UFW Firewall** | For earlier Omarchy versions where UFW was not enabled |
| **Tailscale-only SSH** | Restricts SSH to your Tailscale network |
| **Limit Login Attempts** | Reduces failed attempts from 10 to 3 before lockout |
| **Configure Git Signing** | Enables SSH commit signing for verified commits |
| **Disable GNOME Screensaver** | Prevents conflicts with hyprlock |

## Usage

Run the script and use number keys to toggle options on/off:

```
  [ ] 1  Disable LLMNR
  [ ] 2  Enable UFW Firewall
  [ ] 3  Tailscale-only SSH
  [ ] 4  Limit Login Attempts
  [ ] 5  Configure Git Signing
  [ ] 6  Disable GNOME Screensaver

  c  Configure options    Enter  Apply selected
  a  Select all           q      Quit
  n  Select none
```

Press `c` to configure additional settings like SSH key path, Git name/email, and GitHub username.

## Security Issues Addressed

### LLMNR Enabled by Default

LLMNR (Link-Local Multicast Name Resolution) can be exploited for man-in-the-middle attacks. Attackers on the local network can respond to LLMNR queries and redirect traffic.

### Firewall Not Running (Earlier Versions)

Earlier versions of Omarchy shipped with UFW rules pre-configured but the service was not enabled, leaving the system exposed. This has since been fixed in newer releases.

### Relaxed Login Attempt Limits

Default faillock attempts increased from 3 to 10, making brute-force attacks easier.

### No Commit Signing

Git commits are trivially forgeable. SSH signing provides cryptographic proof of authorship.

## License

MIT
