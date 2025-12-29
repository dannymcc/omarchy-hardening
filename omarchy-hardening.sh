#!/bin/bash
#
# Omarchy Hardening
# =================
#
# Interactive security hardening for Omarchy/Arch Linux installations.
#
# Addresses security gaps identified in default configurations:
#   https://xn--gckvb8fzb.com/a-word-on-omarchy/
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Unicode characters
CHECK="[${GREEN}x${NC}]"
UNCHECK="[ ]"
ARROW="${CYAN}>${NC}"

# State for each option
declare -A OPTIONS
OPTIONS[llmnr]=false
OPTIONS[firewall]=false
OPTIONS[tailscale]=false
OPTIONS[faillock]=false
OPTIONS[git]=false
OPTIONS[screensaver]=false

# Configuration values
SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
GITHUB_USERNAME=""
GIT_NAME=""
GIT_EMAIL=""
MAX_LOGIN_ATTEMPTS=3

print_banner() {
    clear
    echo -e "${MAGENTA}"
    cat << 'EOF'
                                      _
   ___  _ __ ___   __ _ _ __ ___ | |__  _   _
  / _ \| '_ ` _ \ / _` | '__/ __|| '_ \| | | |
 | (_) | | | | | | (_| | | | (__ | | | | |_| |
  \___/|_| |_| |_|\__,_|_|  \___||_| |_|\__, |
                                        |___/
EOF
    echo -e "${NC}"
    echo -e "${BOLD}  Security Hardening${NC}"
    echo -e "${DIM}  ─────────────────────────────────────────${NC}"
    echo ""
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}i${NC} $1"
}

show_menu() {
    print_banner
    echo -e "  ${BOLD}Select hardening options:${NC}"
    echo -e "  ${DIM}(Use number keys to toggle, Enter to continue)${NC}"
    echo ""

    local idx=1
    for key in llmnr firewall tailscale faillock git screensaver; do
        local label=""
        local desc=""
        case $key in
            llmnr)
                label="Disable LLMNR"
                desc="Prevents name poisoning attacks on local network"
                ;;
            firewall)
                label="Enable UFW Firewall"
                desc="For earlier Omarchy versions where UFW was not enabled"
                ;;
            tailscale)
                label="Tailscale-only SSH"
                desc="Restricts SSH to Tailscale network (requires Tailscale)"
                ;;
            faillock)
                label="Limit Login Attempts"
                desc="Reduces failed login attempts from 10 to $MAX_LOGIN_ATTEMPTS"
                ;;
            git)
                label="Configure Git Signing"
                desc="Enables SSH commit signing for verified commits"
                ;;
            screensaver)
                label="Disable GNOME Screensaver"
                desc="Prevents conflicts with hyprlock"
                ;;
        esac

        if [[ "${OPTIONS[$key]}" == true ]]; then
            echo -e "  ${CHECK} ${BOLD}$idx${NC}  $label"
        else
            echo -e "  ${UNCHECK} ${BOLD}$idx${NC}  $label"
        fi
        echo -e "      ${DIM}$desc${NC}"
        echo ""
        ((idx++))
    done

    echo -e "  ${DIM}─────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}c${NC}  Configure options    ${BOLD}Enter${NC}  Apply selected"
    echo -e "  ${BOLD}a${NC}  Select all           ${BOLD}q${NC}      Quit"
    echo -e "  ${BOLD}n${NC}  Select none"
    echo ""
}

toggle_option() {
    local idx=$1
    local keys=(llmnr firewall tailscale faillock git screensaver)
    local key="${keys[$((idx-1))]}"

    if [[ "${OPTIONS[$key]}" == true ]]; then
        OPTIONS[$key]=false
    else
        OPTIONS[$key]=true
    fi
}

select_all() {
    for key in llmnr firewall tailscale faillock git screensaver; do
        OPTIONS[$key]=true
    done
}

select_none() {
    for key in llmnr firewall tailscale faillock git screensaver; do
        OPTIONS[$key]=false
    done
}

configure_options() {
    print_banner
    echo -e "  ${BOLD}Configuration${NC}"
    echo ""

    # SSH Key Path
    echo -e "  ${CYAN}SSH Key Path${NC} ${DIM}(for Git signing)${NC}"
    echo -e "  Current: ${BOLD}$SSH_KEY_PATH${NC}"
    read -p "  New path (Enter to keep): " input
    [[ -n "$input" ]] && SSH_KEY_PATH="$input"
    echo ""

    # Max Login Attempts
    echo -e "  ${CYAN}Max Login Attempts${NC} ${DIM}(before lockout)${NC}"
    echo -e "  Current: ${BOLD}$MAX_LOGIN_ATTEMPTS${NC}"
    read -p "  New value (Enter to keep): " input
    [[ -n "$input" ]] && MAX_LOGIN_ATTEMPTS="$input"
    echo ""

    # Git Name
    echo -e "  ${CYAN}Git User Name${NC}"
    echo -e "  Current: ${BOLD}${GIT_NAME:-not set}${NC}"
    read -p "  New name (Enter to keep): " input
    [[ -n "$input" ]] && GIT_NAME="$input"
    echo ""

    # Git Email
    echo -e "  ${CYAN}Git Email${NC}"
    echo -e "  Current: ${BOLD}${GIT_EMAIL:-not set}${NC}"
    read -p "  New email (Enter to keep): " input
    [[ -n "$input" ]] && GIT_EMAIL="$input"
    echo ""

    # GitHub Username
    echo -e "  ${CYAN}GitHub Username${NC} ${DIM}(for credential helper)${NC}"
    echo -e "  Current: ${BOLD}${GITHUB_USERNAME:-not set}${NC}"
    read -p "  New username (Enter to keep): " input
    [[ -n "$input" ]] && GITHUB_USERNAME="$input"
    echo ""

    echo -e "  ${DIM}Press Enter to return to menu...${NC}"
    read
}

# ============================================================================
# Hardening Functions
# ============================================================================

harden_llmnr() {
    echo ""
    echo -e "  ${BOLD}Disabling LLMNR...${NC}"

    if [[ ! -d /etc/systemd/resolved.conf.d ]]; then
        sudo mkdir -p /etc/systemd/resolved.conf.d
    fi

    sudo tee /etc/systemd/resolved.conf.d/disable-llmnr.conf > /dev/null << 'EOF'
[Resolve]
LLMNR=no
EOF

    sudo systemctl restart systemd-resolved
    print_success "LLMNR disabled"
}

harden_firewall() {
    echo ""
    echo -e "  ${BOLD}Configuring UFW Firewall...${NC}"

    if ! command -v ufw &> /dev/null; then
        print_warning "UFW not installed, installing..."
        sudo pacman -S --noconfirm ufw
    fi

    sudo ufw --force reset > /dev/null
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    if [[ "${OPTIONS[tailscale]}" == true ]]; then
        TAILSCALE_IFACE=$(ip -o link show | grep -o 'tailscale[0-9]*' | head -1)
        if [[ -n "$TAILSCALE_IFACE" ]]; then
            sudo ufw allow in on "$TAILSCALE_IFACE"
            print_success "Allowed traffic on Tailscale interface ($TAILSCALE_IFACE)"
        else
            print_warning "Tailscale interface not found, using tailscale0"
            sudo ufw allow in on tailscale0
        fi
    else
        sudo ufw allow ssh
        print_success "Allowed SSH from all interfaces"
    fi

    sudo ufw --force enable
    print_success "UFW firewall enabled"
}

harden_tailscale_ssh() {
    echo ""
    echo -e "  ${BOLD}Configuring Tailscale-only SSH...${NC}"

    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")

    if [[ -n "$TAILSCALE_IP" ]]; then
        sudo mkdir -p /etc/ssh/sshd_config.d
        sudo tee /etc/ssh/sshd_config.d/tailscale-only.conf > /dev/null << EOF
# Bind SSH only to Tailscale interface
ListenAddress $TAILSCALE_IP

# Disable password authentication
PasswordAuthentication no
EOF
        sudo systemctl restart sshd
        print_success "SSH restricted to Tailscale IP: $TAILSCALE_IP"
    else
        print_error "Could not get Tailscale IP - is Tailscale running?"
        print_warning "Skipping Tailscale SSH configuration"
    fi
}

harden_faillock() {
    echo ""
    echo -e "  ${BOLD}Configuring Login Attempt Limiting...${NC}"

    if [[ -f /etc/security/faillock.conf ]]; then
        sudo sed -i "s/^deny = .*/deny = $MAX_LOGIN_ATTEMPTS/" /etc/security/faillock.conf
        sudo sed -i "s/^# *deny = .*/deny = $MAX_LOGIN_ATTEMPTS/" /etc/security/faillock.conf
        print_success "Max login attempts set to $MAX_LOGIN_ATTEMPTS"
    else
        print_warning "/etc/security/faillock.conf not found"
    fi
}

harden_git() {
    echo ""
    echo -e "  ${BOLD}Configuring Git...${NC}"

    GIT_CONFIG_DIR="$HOME/.config/git"
    mkdir -p "$GIT_CONFIG_DIR"

    if [[ -n "$GIT_NAME" ]]; then
        git config --global user.name "$GIT_NAME"
        print_success "Git user.name: $GIT_NAME"
    fi

    if [[ -n "$GIT_EMAIL" ]]; then
        git config --global user.email "$GIT_EMAIL"
        print_success "Git user.email: $GIT_EMAIL"
    fi

    if [[ -f "$SSH_KEY_PATH" ]]; then
        git config --global user.signingkey "$SSH_KEY_PATH"
        git config --global gpg.format ssh
        git config --global commit.gpgsign true
        git config --global tag.gpgsign true
        print_success "SSH signing enabled with: $SSH_KEY_PATH"
    else
        print_warning "SSH key not found at $SSH_KEY_PATH"
    fi

    # Workflow optimizations
    git config --global init.defaultBranch master
    git config --global pull.rebase true
    git config --global push.autoSetupRemote true
    git config --global diff.algorithm histogram
    git config --global diff.colorMoved plain
    git config --global diff.mnemonicPrefix true
    git config --global commit.verbose true
    git config --global column.ui auto
    git config --global branch.sort -committerdate
    git config --global tag.sort -version:refname
    git config --global rerere.enabled true
    git config --global rerere.autoupdate true
    print_success "Git workflow optimizations applied"

    if [[ -n "$GITHUB_USERNAME" ]] && command -v gh &> /dev/null; then
        git config --global credential.https://github.com.helper ""
        git config --global credential.https://github.com.helper "!/usr/bin/gh auth git-credential"
        git config --global credential.https://gist.github.com.helper ""
        git config --global credential.https://gist.github.com.helper "!/usr/bin/gh auth git-credential"
        print_success "GitHub credential helper configured"
    fi
}

harden_screensaver() {
    echo ""
    echo -e "  ${BOLD}Configuring Screensaver...${NC}"

    if command -v gsettings &> /dev/null; then
        if gsettings get org.gnome.desktop.screensaver idle-activation-enabled &> /dev/null; then
            gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
            print_success "GNOME screensaver disabled (hyprlock handles locking)"
        else
            print_info "GNOME screensaver settings not available"
        fi
    else
        print_info "gsettings not available"
    fi
}

apply_hardening() {
    print_banner
    echo -e "  ${BOLD}Applying Security Hardening${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────${NC}"

    local applied=0

    if [[ "${OPTIONS[llmnr]}" == true ]]; then
        harden_llmnr
        ((applied++))
    fi

    if [[ "${OPTIONS[firewall]}" == true ]]; then
        harden_firewall
        ((applied++))
    fi

    if [[ "${OPTIONS[tailscale]}" == true ]]; then
        harden_tailscale_ssh
        ((applied++))
    fi

    if [[ "${OPTIONS[faillock]}" == true ]]; then
        harden_faillock
        ((applied++))
    fi

    if [[ "${OPTIONS[git]}" == true ]]; then
        harden_git
        ((applied++))
    fi

    if [[ "${OPTIONS[screensaver]}" == true ]]; then
        harden_screensaver
        ((applied++))
    fi

    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}Hardening Complete${NC}"
    echo -e "  Applied ${BOLD}$applied${NC} security improvements"
    echo ""
    echo -e "  ${YELLOW}Recommended next steps:${NC}"
    echo -e "  ${DIM}•${NC} Add your SSH key to GitHub as a signing key"
    echo -e "  ${DIM}•${NC} Test SSH access before logging out"
    echo -e "  ${DIM}•${NC} Consider installing OpenSnitch for app-level firewall"
    if [[ "${OPTIONS[tailscale]}" == true ]]; then
        echo -e "  ${DIM}•${NC} Ensure Tailscale starts on boot: sudo systemctl enable tailscaled"
    fi
    echo ""
    echo -e "  ${DIM}For more context on these security improvements:${NC}"
    echo -e "  ${CYAN}https://xn--gckvb8fzb.com/a-word-on-omarchy/${NC}"
    echo ""
    echo -e "  ${DIM}Press Enter to return to menu...${NC}"
    read
}

# ============================================================================
# Main
# ============================================================================

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "Do not run as root. The script will use sudo when needed."
    exit 1
fi

# Main loop
while true; do
    show_menu
    read -rsn1 key

    case $key in
        1|2|3|4|5|6)
            toggle_option "$key"
            ;;
        a|A)
            select_all
            ;;
        n|N)
            select_none
            ;;
        c|C)
            configure_options
            ;;
        q|Q)
            echo ""
            echo -e "  ${DIM}Exiting...${NC}"
            echo ""
            exit 0
            ;;
        "")
            # Enter pressed - apply selected options
            apply_hardening
            ;;
    esac
done
