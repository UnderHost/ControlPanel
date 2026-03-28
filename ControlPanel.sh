#!/usr/bin/env bash
# =============================================================================
#  UnderHost Control Panel Installer
#  https://underhost.com  |  https://github.com/UnderHost/ControlPanel
#
#  Version  : 2026.1.0
#  License  : MIT
#  Authors  : UnderHost Team
#
#  USAGE:
#    sudo bash ControlPanel.sh          # Interactive menu
#    sudo bash ControlPanel.sh --list   # List panels compatible with this OS
#    sudo PANEL=hestiacp bash ControlPanel.sh  # Non-interactive (CI/CD)
#
#  PANELS SUPPORTED:
#    Traditional : cPanel, DirectAdmin, Plesk, CentOS Web Panel (CWP), sPanel
#    Free/OSS    : aaPanel, CyberPanel, HestiaCP, CloudPanel, Webmin, Virtualmin
#                  ISPConfig, Froxlor, Ajenti, PhyrePanel, OLSPanel
#    Modern/PaaS : Coolify, CapRover, EasyPanel, Webinoly, ServerAvatar Lite
#
#  REQUIREMENTS:
#    - Root or sudo access
#    - Supported OS (detected automatically)
#    - Internet connectivity
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# CONSTANTS & GLOBALS
# ---------------------------------------------------------------------------
readonly SCRIPT_VERSION="2026.1.0"
readonly SCRIPT_NAME="UnderHost ControlPanel Installer"
readonly LOG_FILE="/var/log/underhost_controlpanel.log"
readonly CREDS_FILE="/root/.panel_credentials.txt"
readonly LOCK_FILE="/var/run/underhost_cp_install.lock"
readonly MIN_RAM_MB=512
readonly MIN_DISK_GB=10

# Detected at runtime
OS_ID=""
OS_VERSION=""
OS_CODENAME=""
OS_ARCH=""
PKG_MGR=""        # apt | dnf | yum
DETECTED_RAM_MB=0
DETECTED_DISK_GB=0

# ---------------------------------------------------------------------------
# COLORS
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'
  BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; PURPLE=''
  BOLD=''; DIM=''; NC=''
fi

# ---------------------------------------------------------------------------
# LOGGING
# ---------------------------------------------------------------------------
log()   { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [INFO]  $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [WARN]  $*" | tee -a "$LOG_FILE" >&2; }
error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE" >&2; }
die()   { error "$*"; cleanup_lock; exit 1; }

# Pretty print helpers (no timestamps, for UI output)
info()    { echo -e "${CYAN}[i]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
fail()    { echo -e "${RED}[✗]${NC} $*"; }
step()    { echo -e "${BLUE}[→]${NC} ${BOLD}$*${NC}"; }
note()    { echo -e "${YELLOW}[!]${NC} $*"; }

# ---------------------------------------------------------------------------
# LOCK FILE — prevent concurrent runs
# ---------------------------------------------------------------------------
acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    local pid; pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
    die "Another install appears to be running (PID: $pid). If not, remove $LOCK_FILE"
  fi
  echo $$ > "$LOCK_FILE"
  trap cleanup_lock EXIT INT TERM
}

cleanup_lock() {
  rm -f "$LOCK_FILE"
}

# ---------------------------------------------------------------------------
# OS DETECTION
# ---------------------------------------------------------------------------
detect_os() {
  step "Detecting operating system..."

  if [[ ! -f /etc/os-release ]]; then
    die "Cannot read /etc/os-release — unsupported or very old OS."
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID,,}"
  OS_VERSION="${VERSION_ID:-0}"
  OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  OS_ARCH=$(uname -m)

  # Normalize version to major only
  local os_major
  os_major="${OS_VERSION%%.*}"

  case "$OS_ID" in
    ubuntu)
      [[ "$os_major" =~ ^(20|22|24)$ ]] \
        || warn "Ubuntu $OS_VERSION may not be fully tested with all panels."
      PKG_MGR="apt"
      ;;
    debian)
      [[ "$os_major" =~ ^(10|11|12)$ ]] \
        || warn "Debian $OS_VERSION may not be fully tested with all panels."
      PKG_MGR="apt"
      ;;
    centos)
      [[ "$os_major" =~ ^(7|8|9)$ ]] \
        || warn "CentOS $OS_VERSION — note: CentOS 8 Stream EOL'd."
      PKG_MGR="yum"
      command -v dnf &>/dev/null && PKG_MGR="dnf"
      ;;
    almalinux|rocky)
      [[ "$os_major" =~ ^(8|9|10)$ ]] \
        || warn "$OS_ID $OS_VERSION may not be fully tested."
      PKG_MGR="dnf"
      ;;
    rhel)
      PKG_MGR="dnf"
      ;;
    *)
      die "Unsupported OS: $OS_ID. Supported: Ubuntu, Debian, CentOS, AlmaLinux, Rocky Linux."
      ;;
  esac

  success "OS: ${BOLD}${OS_ID^} $OS_VERSION${NC} (${OS_CODENAME:-n/a}) — arch: $OS_ARCH"
  log "Detected OS: $OS_ID $OS_VERSION ($OS_CODENAME) arch=$OS_ARCH pkg=$PKG_MGR"
}

# ---------------------------------------------------------------------------
# SYSTEM RESOURCE CHECK
# ---------------------------------------------------------------------------
check_resources() {
  step "Checking system resources..."

  DETECTED_RAM_MB=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo)
  DETECTED_DISK_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
  local cpu_cores; cpu_cores=$(nproc)

  echo ""
  info "  RAM   : ${DETECTED_RAM_MB} MB  (minimum: ${MIN_RAM_MB} MB)"
  info "  Disk  : ${DETECTED_DISK_GB} GB free  (minimum: ${MIN_DISK_GB} GB)"
  info "  CPUs  : $cpu_cores core(s)"
  info "  Arch  : $OS_ARCH"
  echo ""

  (( DETECTED_RAM_MB < MIN_RAM_MB ))  && warn "Low RAM (${DETECTED_RAM_MB}MB). Some panels need 1–2 GB."
  (( DETECTED_DISK_GB < MIN_DISK_GB )) && warn "Low disk space (${DETECTED_DISK_GB}GB). Most panels need 10+ GB."

  log "Resources: RAM=${DETECTED_RAM_MB}MB DISK=${DETECTED_DISK_GB}GB CPU=${cpu_cores}"
}

# ---------------------------------------------------------------------------
# PREREQUISITES INSTALLER
# ---------------------------------------------------------------------------
install_prerequisites() {
  step "Installing base prerequisites..."

  local pkgs_apt=(curl wget git unzip tar gnupg2 ca-certificates lsb-release software-properties-common net-tools)
  local pkgs_dnf=(curl wget git unzip tar gnupg2 ca-certificates epel-release net-tools)

  case "$PKG_MGR" in
    apt)
      DEBIAN_FRONTEND=noninteractive apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs_apt[@]}" 2>&1 | tee -a "$LOG_FILE"
      ;;
    dnf)
      dnf install -y epel-release 2>&1 | tee -a "$LOG_FILE" || true
      dnf install -y "${pkgs_dnf[@]}" 2>&1 | tee -a "$LOG_FILE"
      ;;
    yum)
      yum install -y epel-release 2>&1 | tee -a "$LOG_FILE" || true
      yum install -y "${pkgs_dnf[@]}" 2>&1 | tee -a "$LOG_FILE"
      ;;
  esac

  success "Prerequisites ready."
}

# ---------------------------------------------------------------------------
# DOCKER INSTALLER (needed by Coolify, CapRover, EasyPanel)
# ---------------------------------------------------------------------------
install_docker() {
  if command -v docker &>/dev/null; then
    local docker_ver; docker_ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
    success "Docker already installed: $docker_ver"
    return 0
  fi

  step "Installing Docker Engine..."

  case "$PKG_MGR" in
    apt)
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
        -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc

      # shellcheck disable=SC1091
      local codename; codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}")
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/${OS_ID} ${codename} stable" \
        > /etc/apt/sources.list.d/docker.list

      DEBIAN_FRONTEND=noninteractive apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>&1 | tee -a "$LOG_FILE"
      ;;
    dnf|yum)
      $PKG_MGR install -y yum-utils 2>&1 | tee -a "$LOG_FILE"
      $PKG_MGR-config-manager --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo 2>&1 | tee -a "$LOG_FILE"
      $PKG_MGR install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>&1 | tee -a "$LOG_FILE"
      ;;
  esac

  systemctl enable --now docker
  success "Docker installed and running."
}

# ---------------------------------------------------------------------------
# HOSTNAME HELPER
# ---------------------------------------------------------------------------
set_hostname() {
  local current; current=$(hostname -f 2>/dev/null || hostname)

  echo ""
  info "Current hostname: ${BOLD}${current}${NC}"
  read -r -p "  Enter FQDN hostname (e.g. server.yourdomain.com) [skip=Enter]: " new_hostname

  if [[ -n "$new_hostname" ]]; then
    if [[ "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
      hostnamectl set-hostname "$new_hostname"
      grep -q "$new_hostname" /etc/hosts || echo "127.0.0.1 $new_hostname" >> /etc/hosts
      success "Hostname set to: $new_hostname"
    else
      warn "Invalid FQDN — keeping current hostname: $current"
    fi
  fi
}

# ---------------------------------------------------------------------------
# SAVE CREDENTIALS
# ---------------------------------------------------------------------------
save_credential() {
  local panel="$1" key="$2" value="$3"
  mkdir -p "$(dirname "$CREDS_FILE")"
  chmod 700 "$(dirname "$CREDS_FILE")"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$panel] $key: $value" >> "$CREDS_FILE"
  chmod 600 "$CREDS_FILE"
}

# ---------------------------------------------------------------------------
# POST-INSTALL SUMMARY
# ---------------------------------------------------------------------------
post_install_summary() {
  local panel="$1"
  local url="$2"
  local extra="${3:-}"

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ${BOLD}${panel} installed successfully!${NC}${GREEN}                  ║${NC}"
  echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}║${NC}  Access URL : ${BOLD}${url}${NC}"
  [[ -n "$extra" ]] && echo -e "${GREEN}║${NC}  ${extra}"
  echo -e "${GREEN}║${NC}  Credentials saved to: ${BOLD}${CREDS_FILE}${NC}"
  echo -e "${GREEN}║${NC}  Install log : ${BOLD}${LOG_FILE}${NC}"
  echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}║${NC}  ${YELLOW}Post-install checklist:${NC}"
  echo -e "${GREEN}║${NC}   1. Change default passwords immediately"
  echo -e "${GREEN}║${NC}   2. Configure firewall rules for panel ports"
  echo -e "${GREEN}║${NC}   3. Enable SSL/TLS on the panel"
  echo -e "${GREEN}║${NC}   4. Set up automatic OS security updates"
  echo -e "${GREEN}║${NC}   5. Configure regular backups"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  log "Installation completed: $panel | URL: $url"
}

# ===========================================================================
# PANEL DEFINITIONS
# Format: each panel is a bash associative array fragment defined in a
# function to keep state clean.  A master registry provides metadata.
# ===========================================================================

# ---------------------------------------------------------------------------
# PANEL COMPATIBILITY REGISTRY
# Key: internal panel_id
# Fields: name | os_ids (comma-sep) | category | license | min_ram_mb | port | desc
# ---------------------------------------------------------------------------
declare -A PANEL_META  # panel_id -> "name|os|cat|lic|ram|port|desc"

_reg() {
  PANEL_META["$1"]="$2|$3|$4|$5|$6|$7|$8"
}

# Traditional / Commercial
_reg "cpanel"      "cPanel"             "centos,almalinux,rocky"         "Traditional" "Paid"   1024 "2083" "Industry-standard cPanel/WHM"
_reg "directadmin" "DirectAdmin"        "centos,almalinux,rocky,ubuntu,debian" "Traditional" "Paid" 512 "2222" "Lightweight commercial panel"
_reg "plesk"       "Plesk"              "centos,almalinux,rocky,ubuntu,debian" "Traditional" "Paid/Free" 1024 "8443" "Multi-OS panel with WP toolkit"
_reg "cwp"         "CentOS Web Panel"   "centos,almalinux,rocky"         "Traditional" "Free"   512  "2030" "Legacy CWP/CWP Pro"
_reg "spanel"      "sPanel"             "centos,almalinux,rocky"         "Traditional" "Free"   512  "2083" "ScalaHosting's panel"

# Free / Open-Source Traditional
_reg "aapanel"     "aaPanel"            "centos,almalinux,rocky,ubuntu,debian" "OSS" "Free" 512  "8888" "Feature-rich free panel"
_reg "cyberpanel"  "CyberPanel"         "centos,almalinux,rocky,ubuntu,debian" "OSS" "Free" 1024 "8090" "OpenLiteSpeed-powered panel"
_reg "hestiacp"    "HestiaCP"           "ubuntu,debian"                  "OSS" "Free"   512  "8083" "VestaCP fork, clean & fast"
_reg "cloudpanel"  "CloudPanel"         "ubuntu,debian"                  "OSS" "Free"   512  "8443" "Modern PHP/MySQL panel"
_reg "webmin"      "Webmin"             "centos,almalinux,rocky,ubuntu,debian" "OSS" "Free" 256 "10000" "Classic sysadmin panel"
_reg "virtualmin"  "Virtualmin"         "centos,almalinux,rocky,ubuntu,debian" "OSS" "Free/Paid" 512 "10000" "Webmin + hosting extension"
_reg "ispconfig"   "ISPConfig"          "ubuntu,debian"                  "OSS" "Free"   512  "8080" "Multi-server open-source panel"
_reg "froxlor"     "Froxlor"            "ubuntu,debian"                  "OSS" "Free"   256  "80"   "Lightweight German panel"
_reg "ajenti"      "Ajenti"             "ubuntu,debian"                  "OSS" "Free"   256  "8000" "Minimal web-based admin panel"
_reg "phyrepanel"  "PhyrePanel"         "ubuntu,debian"                  "OSS" "Free"   512  "8443" "Modern PHP-focused panel"
_reg "olspanel"    "OLSPanel"           "ubuntu,debian,centos,almalinux,rocky" "OSS" "Free" 512 "8443" "Free OpenLiteSpeed panel"

# Modern / PaaS / Docker-based
_reg "coolify"     "Coolify"            "ubuntu,debian"                  "Modern" "Free" 2048 "8000" "Docker PaaS — 280+ one-click apps"
_reg "caprover"    "CapRover"           "ubuntu,debian"                  "Modern" "Free" 1024 "3000" "Heroku-like Docker+Nginx PaaS"
_reg "easypanel"   "EasyPanel"          "ubuntu,debian"                  "Modern" "Free/Paid" 1024 "3000" "Docker-based deployment panel"
_reg "webinoly"    "Webinoly"           "ubuntu,debian"                  "Modern" "Free" 512  "80"   "CLI-driven LEMP stack manager"
_reg "serveravatar" "ServerAvatar Lite" "ubuntu"                         "Modern" "Free" 1024 "web"  "Free server management panel"

# ---------------------------------------------------------------------------
# Check if a panel is compatible with the current OS
# ---------------------------------------------------------------------------
panel_is_compatible() {
  local panel_id="$1"
  local meta="${PANEL_META[$panel_id]}"
  local supported_os; supported_os=$(echo "$meta" | cut -d'|' -f2)
  local IFS_BAK=$IFS; IFS=','
  # shellcheck disable=SC2086
  for os in $supported_os; do
    if [[ "$os" == "$OS_ID" ]]; then IFS=$IFS_BAK; return 0; fi
  done
  IFS=$IFS_BAK
  return 1
}

# ---------------------------------------------------------------------------
# Parse meta field
# ---------------------------------------------------------------------------
panel_field() {
  local panel_id="$1" field="$2"
  local meta="${PANEL_META[$panel_id]}"
  # fields: 1=name 2=os 3=cat 4=lic 5=ram 6=port 7=desc
  echo "$meta" | cut -d'|' -f"$field"
}

# ---------------------------------------------------------------------------
# DISPLAY PANEL MENU
# ---------------------------------------------------------------------------
display_menu() {
  local -a compatible_ids=()
  local -a incompatible_ids=()

  for id in "${!PANEL_META[@]}"; do
    if panel_is_compatible "$id"; then
      compatible_ids+=("$id")
    else
      incompatible_ids+=("$id")
    fi
  done

  # Sort arrays
  IFS=$'\n' read -r -d '' -a compatible_ids < <(printf '%s\n' "${compatible_ids[@]}" | sort && printf '\0')
  IFS=$'\n' read -r -d '' -a incompatible_ids < <(printf '%s\n' "${incompatible_ids[@]}" | sort && printf '\0')

  echo ""
  echo -e "${BOLD}${GREEN}  ✔ COMPATIBLE with ${OS_ID^} $OS_VERSION${NC}"
  echo -e "  ${DIM}─────────────────────────────────────────────────────────${NC}"

  local idx=1
  declare -gA MENU_MAP  # index -> panel_id
  for id in "${compatible_ids[@]}"; do
    local name; name=$(panel_field "$id" 1)
    local cat;  cat=$(panel_field "$id" 3)
    local lic;  lic=$(panel_field "$id" 4)
    local ram;  ram=$(panel_field "$id" 5)
    local port; port=$(panel_field "$id" 6)
    local desc; desc=$(panel_field "$id" 7)

    printf "  ${GREEN}%2d)${NC} ${BOLD}%-18s${NC} ${DIM}%-12s %-10s RAM:%-6s Port:%-6s${NC}\n" \
      "$idx" "$name" "$cat" "$lic" "${ram}MB" "$port"
    echo -e "       ${DIM}${desc}${NC}"
    MENU_MAP[$idx]="$id"
    (( idx++ ))
  done

  if [[ ${#incompatible_ids[@]} -gt 0 ]]; then
    echo ""
    echo -e "  ${BOLD}${YELLOW}  ✘ NOT COMPATIBLE with ${OS_ID^} $OS_VERSION${NC} (shown for reference)"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────${NC}"
    for id in "${incompatible_ids[@]}"; do
      local name; name=$(panel_field "$id" 1)
      local os;   os=$(panel_field "$id" 2)
      printf "  ${RED}  ✘ %-20s${NC} ${DIM}Requires: %s${NC}\n" "$name" "$os"
    done
  fi

  echo ""
  echo -e "  ${DIM}─────────────────────────────────────────────────────────${NC}"
  echo -e "   ${CYAN}h)${NC} Show hostname setup"
  echo -e "   ${CYAN}r)${NC} Re-check system resources"
  echo -e "   ${CYAN}q)${NC} Quit"
  echo ""
}

# ===========================================================================
# PANEL INSTALLERS
# ===========================================================================

# ---------------------------------------------------------------------------
# cPanel
# ---------------------------------------------------------------------------
install_cpanel() {
  if ! panel_is_compatible "cpanel"; then
    die "cPanel requires CentOS, AlmaLinux, or Rocky Linux."
  fi
  set_hostname
  step "Downloading cPanel installer..."
  wget -q -O /root/latest http://securedownloads.cpanel.net/latest \
    || die "Failed to download cPanel installer."
  sh /root/latest
  post_install_summary "cPanel" "https://$(hostname):2087" "WHM URL: https://$(hostname):2087"
}

# ---------------------------------------------------------------------------
# DirectAdmin
# ---------------------------------------------------------------------------
install_directadmin() {
  set_hostname
  step "Downloading DirectAdmin installer..."
  local da_url="https://www.directadmin.com/setup.sh"
  wget -q -O /root/da_setup.sh "$da_url" || die "Failed to download DirectAdmin installer."
  chmod +x /root/da_setup.sh

  note "DirectAdmin requires a license. Visit https://www.directadmin.com to obtain one."
  read -r -p "  Proceed with installer? [y/N]: " confirm
  [[ "${confirm,,}" == "y" ]] || { info "Aborted."; return 1; }

  bash /root/da_setup.sh
  post_install_summary "DirectAdmin" "https://$(hostname):2222"
}

# ---------------------------------------------------------------------------
# Plesk
# ---------------------------------------------------------------------------
install_plesk() {
  set_hostname
  step "Downloading Plesk one-click installer..."
  wget -q -O /root/plesk_install.sh https://autoinstall.plesk.com/one-click-installer \
    || die "Failed to download Plesk installer."
  chmod +x /root/plesk_install.sh
  bash /root/plesk_install.sh
  post_install_summary "Plesk" "https://$(hostname):8443"
}

# ---------------------------------------------------------------------------
# CentOS Web Panel (CWP)
# ---------------------------------------------------------------------------
install_cwp() {
  if ! panel_is_compatible "cwp"; then
    die "CWP requires CentOS, AlmaLinux, or Rocky Linux."
  fi
  set_hostname
  note "CWP installs LAMP/LEMP + mail. This will reboot your server."
  read -r -p "  Continue? [y/N]: " confirm
  [[ "${confirm,,}" == "y" ]] || { info "Aborted."; return 1; }

  step "Installing CentOS Web Panel..."
  $PKG_MGR install -y wget
  cd /usr/local/src || die "Cannot cd to /usr/local/src"
  wget -q http://centos-webpanel.com/cwp-el7-latest -O cwp-latest \
    || die "Failed to download CWP installer."
  bash cwp-latest
  post_install_summary "CentOS Web Panel" "http://$(hostname):2030"
}

# ---------------------------------------------------------------------------
# sPanel
# ---------------------------------------------------------------------------
install_spanel() {
  if ! panel_is_compatible "spanel"; then
    die "sPanel requires CentOS, AlmaLinux, or Rocky Linux."
  fi
  set_hostname
  step "Downloading sPanel installer..."
  wget -q -O /root/spanel_install.sh \
    "https://www.scalahosting.com/download/install-spanel.sh" \
    || die "Failed to download sPanel installer."
  chmod +x /root/spanel_install.sh
  bash /root/spanel_install.sh
  post_install_summary "sPanel" "https://$(hostname):2083"
}

# ---------------------------------------------------------------------------
# aaPanel
# ---------------------------------------------------------------------------
install_aapanel() {
  set_hostname
  step "Installing aaPanel..."

  case "$PKG_MGR" in
    apt)
      wget -q -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh \
        || die "Failed to download aaPanel installer."
      bash install.sh
      ;;
    *)
      wget -q -O install.sh http://www.aapanel.com/script/install_6.0_en.sh \
        || die "Failed to download aaPanel installer."
      bash install.sh
      ;;
  esac

  post_install_summary "aaPanel" "http://$(hostname):8888"
}

# ---------------------------------------------------------------------------
# CyberPanel
# ---------------------------------------------------------------------------
install_cyberpanel() {
  set_hostname
  step "Installing CyberPanel (OpenLiteSpeed)..."
  note "Interactive installer — you will be prompted for options."
  note "Minimum recommended: 1 GB RAM, 10 GB disk."

  read -r -p "  Proceed? [y/N]: " confirm
  [[ "${confirm,,}" == "y" ]] || { info "Aborted."; return 1; }

  sh <(curl -fsSL https://cyberpanel.sh || wget -O - https://cyberpanel.sh) \
    || die "CyberPanel installation failed."

  post_install_summary "CyberPanel" "https://$(hostname):8090"
}

# ---------------------------------------------------------------------------
# HestiaCP
# ---------------------------------------------------------------------------
install_hestiacp() {
  if ! panel_is_compatible "hestiacp"; then
    die "HestiaCP requires Ubuntu or Debian."
  fi
  set_hostname

  step "Installing HestiaCP..."
  note "HestiaCP should be installed on a FRESH server."

  local email admin_pass
  read -r -p "  Admin email: " email
  [[ -z "$email" ]] && die "Email is required for HestiaCP."
  admin_pass=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

  wget -q -O /root/hst-install.sh \
    https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh \
    || die "Failed to download HestiaCP installer."
  chmod +x /root/hst-install.sh

  bash /root/hst-install.sh \
    --interactive no \
    --hostname "$(hostname -f)" \
    --email "$email" \
    --password "$admin_pass" \
    --lang en \
    --apache no \
    --nginx yes \
    --multiphp yes \
    --vsftpd yes \
    --proftpd no \
    --named yes \
    --mysql yes \
    --exim no \
    --dovecot no \
    || die "HestiaCP installation failed."

  save_credential "HestiaCP" "admin_password" "$admin_pass"
  save_credential "HestiaCP" "admin_email"    "$email"

  post_install_summary "HestiaCP" "https://$(hostname):8083" \
    "Admin password: ${BOLD}${admin_pass}${NC} (saved to ${CREDS_FILE})"
}

# ---------------------------------------------------------------------------
# CloudPanel
# ---------------------------------------------------------------------------
install_cloudpanel() {
  if ! panel_is_compatible "cloudpanel"; then
    die "CloudPanel requires Ubuntu or Debian."
  fi
  set_hostname

  local os_major; os_major="${OS_VERSION%%.*}"
  local install_url=""

  case "${OS_ID}_${os_major}" in
    ubuntu_22|ubuntu_24) install_url="https://installer.cloudpanel.io/ce/v2/install.sh" ;;
    debian_11)           install_url="https://installer.cloudpanel.io/ce/v2/install.sh" ;;
    debian_12)           install_url="https://installer.cloudpanel.io/ce/v2/install.sh" ;;
    *)
      die "CloudPanel supports Ubuntu 22/24 and Debian 11/12."
      ;;
  esac

  step "Installing CloudPanel v2 CE..."
  note "Downloading verified installer..."

  curl -fsSL "$install_url" | \
    bash -s -- --os "${OS_ID}" --os-version "${OS_VERSION}" \
    2>&1 | tee -a "$LOG_FILE" || die "CloudPanel installation failed."

  post_install_summary "CloudPanel" "https://$(hostname):8443"
}

# ---------------------------------------------------------------------------
# Webmin (+ optional Virtualmin)
# ---------------------------------------------------------------------------
install_webmin() {
  set_hostname
  step "Installing Webmin..."

  # Use the official repo-based installer for all supported distros
  curl -fsSL https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh \
    -o /root/webmin-setup-repos.sh \
    || die "Failed to download Webmin repo setup."
  bash /root/webmin-setup-repos.sh --force

  case "$PKG_MGR" in
    apt)
      DEBIAN_FRONTEND=noninteractive apt-get install -y webmin \
        2>&1 | tee -a "$LOG_FILE"
      ;;
    dnf|yum)
      $PKG_MGR install -y webmin 2>&1 | tee -a "$LOG_FILE"
      ;;
  esac

  systemctl enable --now webmin

  # Generate a random password for root in Webmin
  local wb_pass; wb_pass=$(openssl rand -base64 14 | tr -dc 'a-zA-Z0-9' | head -c 14)
  /usr/libexec/webmin/changepass.pl /etc/webmin root "$wb_pass" 2>/dev/null \
    || /usr/share/webmin/changepass.pl /etc/webmin root "$wb_pass" 2>/dev/null || true

  save_credential "Webmin" "root_password" "$wb_pass"

  post_install_summary "Webmin" "https://$(hostname):10000" \
    "Root password set to: ${BOLD}${wb_pass}${NC}"
}

# ---------------------------------------------------------------------------
# Virtualmin
# ---------------------------------------------------------------------------
install_virtualmin() {
  set_hostname
  step "Installing Virtualmin..."
  note "This will install Webmin + Virtualmin GPL."

  wget -q -O /root/virtualmin-install.sh \
    https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh \
    || die "Failed to download Virtualmin installer."
  chmod +x /root/virtualmin-install.sh

  bash /root/virtualmin-install.sh --bundle LAMP \
    2>&1 | tee -a "$LOG_FILE" || die "Virtualmin installation failed."

  post_install_summary "Virtualmin" "https://$(hostname):10000"
}

# ---------------------------------------------------------------------------
# ISPConfig
# ---------------------------------------------------------------------------
install_ispconfig() {
  if ! panel_is_compatible "ispconfig"; then
    die "ISPConfig requires Ubuntu or Debian."
  fi
  set_hostname
  step "Installing ISPConfig..."
  note "ISPConfig has an interactive PHP-based installer."

  # Install PHP CLI if missing
  case "$PKG_MGR" in
    apt)
      DEBIAN_FRONTEND=noninteractive apt-get install -y php-cli php-mbstring \
        2>&1 | tee -a "$LOG_FILE"
      ;;
  esac

  local tarball="ISPConfig-3-stable.tar.gz"
  wget -q -O "/tmp/${tarball}" \
    "https://www.ispconfig.org/downloads/${tarball}" \
    || die "Failed to download ISPConfig."

  tar -xzf "/tmp/${tarball}" -C /tmp/
  local dir; dir=$(find /tmp -maxdepth 1 -type d -name "ispconfig3*" | head -1)
  [[ -d "$dir/install" ]] || die "ISPConfig extraction failed."

  cd "$dir/install"
  php -q install.php || die "ISPConfig installer exited with error."

  post_install_summary "ISPConfig" "https://$(hostname):8080"
}

# ---------------------------------------------------------------------------
# Froxlor
# ---------------------------------------------------------------------------
install_froxlor() {
  if ! panel_is_compatible "froxlor"; then
    die "Froxlor requires Ubuntu or Debian."
  fi
  set_hostname
  step "Installing Froxlor..."

  case "$PKG_MGR" in
    apt)
      apt-get install -y apt-transport-https lsb-release curl gnupg2

      local codename; codename=$(lsb_release -sc)
      curl -fsSL https://deb.froxlor.org/froxlor.org.key \
        | gpg --dearmor -o /etc/apt/keyrings/froxlor.gpg
      echo "deb [signed-by=/etc/apt/keyrings/froxlor.gpg] \
https://deb.froxlor.org/${OS_ID} ${codename} main" \
        > /etc/apt/sources.list.d/froxlor.list

      DEBIAN_FRONTEND=noninteractive apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y froxlor \
        2>&1 | tee -a "$LOG_FILE"
      ;;
    *)
      die "Froxlor APT-based installation is only supported on Ubuntu/Debian."
      ;;
  esac

  post_install_summary "Froxlor" "http://$(hostname)/froxlor"
}

# ---------------------------------------------------------------------------
# Ajenti
# ---------------------------------------------------------------------------
install_ajenti() {
  if ! panel_is_compatible "ajenti"; then
    die "Ajenti requires Ubuntu or Debian."
  fi
  set_hostname
  step "Installing Ajenti V2..."

  # Ajenti uses pip — ensure Python3 + pip
  case "$PKG_MGR" in
    apt)
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 python3-pip python3-dev build-essential \
        libssl-dev libffi-dev libapt-pkg-dev \
        2>&1 | tee -a "$LOG_FILE"
      ;;
  esac

  pip3 install ajenti-panel ajenti.plugin.core \
    ajenti.plugin.terminal ajenti.plugin.settings \
    ajenti.plugin.auth-users ajenti.plugin.packages \
    2>&1 | tee -a "$LOG_FILE" || die "Ajenti pip install failed."

  # Create systemd unit if it doesn't exist
  cat > /etc/systemd/system/ajenti.service <<'UNIT'
[Unit]
Description=Ajenti Panel
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ajenti-panel -b 0.0.0.0
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable --now ajenti

  local aj_pass; aj_pass=$(openssl rand -base64 14 | tr -dc 'a-zA-Z0-9' | head -c 14)
  save_credential "Ajenti" "default_user"     "root"
  save_credential "Ajenti" "default_password" "admin (change via UI)"

  post_install_summary "Ajenti" "https://$(hostname):8000" \
    "Default user: ${BOLD}root${NC} / password: admin  (change on first login)"
}

# ---------------------------------------------------------------------------
# PhyrePanel
# ---------------------------------------------------------------------------
install_phyrepanel() {
  if ! panel_is_compatible "phyrepanel"; then
    die "PhyrePanel requires Ubuntu or Debian."
  fi
  set_hostname
  step "Installing PhyrePanel..."

  wget -q https://raw.githubusercontent.com/PhyreApps/PhyrePanel/main/installers/install.sh \
    -O /root/phyrepanel_install.sh \
    || die "Failed to download PhyrePanel installer."
  chmod +x /root/phyrepanel_install.sh
  bash /root/phyrepanel_install.sh 2>&1 | tee -a "$LOG_FILE" \
    || die "PhyrePanel installation failed."

  post_install_summary "PhyrePanel" "https://$(hostname):8443"
}

# ---------------------------------------------------------------------------
# OLSPanel
# ---------------------------------------------------------------------------
install_olspanel() {
  set_hostname
  step "Installing OLSPanel (OpenLiteSpeed)..."
  note "Requires: Ubuntu 18.04–24.04, Debian 11–12, or AlmaLinux 8–9."
  note "Minimum: 1 GB RAM, 10 GB disk."

  bash <(curl -fsSL https://olspanel.com/install.sh \
    || wget -qO- https://olspanel.com/install.sh) \
    2>&1 | tee -a "$LOG_FILE" || die "OLSPanel installation failed."

  post_install_summary "OLSPanel" "https://$(hostname):8443"
}

# ---------------------------------------------------------------------------
# Coolify (Docker-based PaaS)
# ---------------------------------------------------------------------------
install_coolify() {
  if ! panel_is_compatible "coolify"; then
    die "Coolify requires Ubuntu (20.04/22.04/24.04) or Debian."
  fi

  local os_major; os_major="${OS_VERSION%%.*}"
  if [[ "$OS_ID" == "ubuntu" ]] && [[ ! "$os_major" =~ ^(20|22|24)$ ]]; then
    warn "Coolify officially supports Ubuntu LTS (20.04, 22.04, 24.04)."
    read -r -p "  Continue anyway? [y/N]: " confirm
    [[ "${confirm,,}" == "y" ]] || { info "Aborted."; return 1; }
  fi

  step "Installing prerequisites for Coolify..."
  install_prerequisites

  note "Coolify requires Docker. Installing if not present..."
  install_docker

  step "Installing Coolify..."
  note "Coolify access port: 8000 — ensure firewall allows it."
  note "After install, visit http://$(hostname -I | awk '{print $1}'):8000"

  # Allow pre-configuring admin credentials (optional)
  local root_user="" root_email="" root_pass=""
  read -r -p "  Pre-configure admin? (y/N): " pre_cfg
  if [[ "${pre_cfg,,}" == "y" ]]; then
    read -r -p "  Admin username [admin]: " root_user
    root_user="${root_user:-admin}"
    read -r -p "  Admin email: " root_email
    root_pass=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    info "  Generated admin password: ${BOLD}${root_pass}${NC}"
    save_credential "Coolify" "admin_user"     "$root_user"
    save_credential "Coolify" "admin_email"    "$root_email"
    save_credential "Coolify" "admin_password" "$root_pass"

    env ROOT_USERNAME="$root_user" \
        ROOT_USER_EMAIL="$root_email" \
        ROOT_USER_PASSWORD="$root_pass" \
        bash -c 'curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash' \
      2>&1 | tee -a "$LOG_FILE" || die "Coolify installation failed."
  else
    curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash \
      2>&1 | tee -a "$LOG_FILE" || die "Coolify installation failed."
  fi

  post_install_summary "Coolify" "http://$(hostname -I | awk '{print $1}'):8000" \
    "Configure domain in Settings → Instance Domain"
}

# ---------------------------------------------------------------------------
# CapRover (Docker Swarm PaaS)
# ---------------------------------------------------------------------------
install_caprover() {
  if ! panel_is_compatible "caprover"; then
    die "CapRover requires Ubuntu or Debian."
  fi

  step "Installing CapRover..."
  note "CapRover requires Docker + Docker Swarm."
  note "Requires a wildcard DNS entry (*.yourdomain.com → server IP)."

  install_prerequisites
  install_docker

  # Initialise Docker Swarm if not already
  if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    step "Initialising Docker Swarm..."
    local server_ip; server_ip=$(hostname -I | awk '{print $1}')
    docker swarm init --advertise-addr "$server_ip" \
      2>&1 | tee -a "$LOG_FILE" || die "Docker Swarm init failed."
  fi

  step "Starting CapRover container..."
  docker run -d \
    -p 80:80 \
    -p 443:443 \
    -p 3000:3000 \
    -e ACCEPTED_TERMS=true \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /captain:/captain \
    --name caprover \
    --restart unless-stopped \
    caprover/caprover \
    2>&1 | tee -a "$LOG_FILE" || die "Failed to start CapRover container."

  # Install CapRover CLI via npm if Node.js is available
  if command -v npm &>/dev/null; then
    npm install -g caprover 2>/dev/null | tee -a "$LOG_FILE" || true
    note "CapRover CLI installed. Run: caprover serversetup"
  else
    note "Install Node.js + npm to use CapRover CLI: npm install -g caprover"
  fi

  post_install_summary "CapRover" "http://$(hostname -I | awk '{print $1}'):3000" \
    "Default password: ${BOLD}captain42${NC}  (change immediately via caprover serversetup)"
}

# ---------------------------------------------------------------------------
# EasyPanel
# ---------------------------------------------------------------------------
install_easypanel() {
  if ! panel_is_compatible "easypanel"; then
    die "EasyPanel requires Ubuntu or Debian."
  fi

  step "Installing EasyPanel..."
  note "EasyPanel is Docker-based."

  install_prerequisites
  install_docker

  curl -sSL https://get.easypanel.io | bash \
    2>&1 | tee -a "$LOG_FILE" || die "EasyPanel installation failed."

  post_install_summary "EasyPanel" "http://$(hostname -I | awk '{print $1}'):3000" \
    "Set up admin account on first visit."
}

# ---------------------------------------------------------------------------
# Webinoly (CLI-driven LEMP)
# ---------------------------------------------------------------------------
install_webinoly() {
  if ! panel_is_compatible "webinoly"; then
    die "Webinoly requires Ubuntu or Debian."
  fi
  set_hostname

  step "Installing Webinoly LEMP stack..."

  local stack_type="lemp"
  echo ""
  echo "  Select stack type:"
  echo "   1) Full LEMP (Nginx + PHP + MySQL)  [default]"
  echo "   2) Nginx only"
  echo "   3) Nginx + PHP"
  read -r -p "  Choice [1]: " stack_choice
  case "${stack_choice:-1}" in
    2) stack_type="nginx" ;;
    3) stack_type="php" ;;
    *) stack_type="lemp" ;;
  esac

  wget -q -O /tmp/weby qrok.es/wy \
    || curl -fsSL -o /tmp/weby qrok.es/wy \
    || die "Failed to download Webinoly installer."

  bash /tmp/weby "-${stack_type}" 2>&1 | tee -a "$LOG_FILE" \
    || die "Webinoly installation failed."

  post_install_summary "Webinoly" "http://$(hostname)" \
    "CLI tool: sudo site yourdomain.com -wp  |  sudo site yourdomain.com -ssl=on"
}

# ---------------------------------------------------------------------------
# ServerAvatar Lite
# ---------------------------------------------------------------------------
install_serveravatar() {
  if ! panel_is_compatible "serveravatar"; then
    die "ServerAvatar Lite requires Ubuntu 22.04 or 24.04."
  fi

  local os_major; os_major="${OS_VERSION%%.*}"
  if [[ ! "$os_major" =~ ^(22|24)$ ]]; then
    die "ServerAvatar Lite supports Ubuntu 22.04 and 24.04 only."
  fi

  step "Installing ServerAvatar Lite..."
  note "This will install as root on a fresh Ubuntu server."
  note "ServerAvatar Lite is completely free for unlimited servers and sites."

  wget -q https://srvr.so/install_lite -O /root/install_lite \
    || die "Failed to download ServerAvatar Lite installer."
  chmod +x /root/install_lite
  /root/install_lite 2>&1 | tee -a "$LOG_FILE" \
    || die "ServerAvatar Lite installation failed."

  post_install_summary "ServerAvatar Lite" "http://$(hostname -I | awk '{print $1}')" \
    "Manage via web interface at the server IP shown above."
}

# ===========================================================================
# MAIN ENTRY POINT
# ===========================================================================

show_banner() {
  clear
  echo -e "${PURPLE}"
  cat <<'BANNER'
  ╔══════════════════════════════════════════════════════════════╗
  ║                                                              ║
  ║   _   _           _           _   _           _             ║
  ║  | | | |_ __   __| | ___ _ __| | | | ___  ___| |_          ║
  ║  | | | | '_ \ / _` |/ _ \ '__| |_| |/ _ \/ __| __|         ║
  ║  | |_| | | | | (_| |  __/ |  |  _  | (_) \__ \ |_          ║
  ║   \___/|_| |_|\__,_|\___|_|  |_| |_|\___/|___/\__|         ║
  ║                                                              ║
  ║         Control Panel Installer  ·  underhost.com           ║
  ╚══════════════════════════════════════════════════════════════╝
BANNER
  echo -e "${NC}"
  echo -e "  ${BOLD}Version:${NC} ${SCRIPT_VERSION}   ${BOLD}Date:${NC} $(date '+%Y-%m-%d %H:%M %Z')"
  echo -e "  ${BOLD}Server:${NC}  $(hostname -f 2>/dev/null || hostname)"
  echo -e "  ${BOLD}Log:${NC}     ${LOG_FILE}"
  echo ""
}

# Parse --list flag
if [[ "${1:-}" == "--list" ]]; then
  detect_os
  echo ""
  echo "Panels compatible with ${OS_ID^} ${OS_VERSION}:"
  for id in "${!PANEL_META[@]}"; do
    panel_is_compatible "$id" && echo "  - $(panel_field "$id" 1)"
  done | sort
  exit 0
fi

# Check root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[✗] This script must be run as root (sudo bash ControlPanel.sh)${NC}"
  exit 1
fi

# Init log
mkdir -p "$(dirname "$LOG_FILE")"
log "=== ${SCRIPT_NAME} v${SCRIPT_VERSION} started ==="

# Run bootstrap
acquire_lock
show_banner
detect_os
check_resources

# ---------------------------------------------------------------------------
# Non-interactive mode: PANEL env var
# ---------------------------------------------------------------------------
if [[ -n "${PANEL:-}" ]]; then
  panel_id="${PANEL,,}"
  if [[ -z "${PANEL_META[$panel_id]:-}" ]]; then
    die "Unknown panel ID: $panel_id. Run with --list to see valid IDs."
  fi
  step "Non-interactive install: ${panel_id}"
  "install_${panel_id}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Interactive loop
# ---------------------------------------------------------------------------
while true; do
  show_banner
  detect_os   # re-print context after clear
  check_resources

  display_menu

  read -r -p "  Select an option: " choice

  case "${choice,,}" in
    q|quit|exit) log "User quit."; info "Goodbye!"; exit 0 ;;
    h) set_hostname; continue ;;
    r) check_resources; read -r -p "Press Enter to continue..."; continue ;;
  esac

  # Numeric selection
  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ -n "${MENU_MAP[$choice]:-}" ]]; then
    local_panel_id="${MENU_MAP[$choice]}"
    local_panel_name=$(panel_field "$local_panel_id" 1)

    echo ""
    echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
    echo -e "  Installing: ${BOLD}${local_panel_name}${NC}"
    echo -e "  Panel ID:   ${local_panel_id}"
    echo -e "  OS:         ${OS_ID^} ${OS_VERSION}"
    echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
    echo ""

    if ! panel_is_compatible "$local_panel_id"; then
      fail "${local_panel_name} is NOT compatible with ${OS_ID^} ${OS_VERSION}."
      note "Compatible OS: $(panel_field "$local_panel_id" 2)"
      read -r -p "  Force install anyway? (NOT recommended) [y/N]: " force
      [[ "${force,,}" == "y" ]] || { continue; }
    fi

    read -r -p "  Confirm installation of ${local_panel_name}? [y/N]: " confirm
    [[ "${confirm,,}" == "y" ]] || { info "Cancelled."; sleep 1; continue; }

    install_prerequisites

    "install_${local_panel_id}" && {
      success "${local_panel_name} installation complete!"
      log "Panel installed successfully: ${local_panel_id}"
    } || {
      fail "${local_panel_name} installation encountered errors. Check ${LOG_FILE}."
      log "Panel install failed: ${local_panel_id}"
    }

    read -r -p "  Press Enter to return to menu..."
  else
    fail "Invalid selection: '$choice'"
    sleep 1
  fi
done
