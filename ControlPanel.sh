#!/bin/bash

# Global variables
VERSION="2025.1"
SUPPORTED_OS=("centos" "ubuntu" "debian" "almalinux" "rocky")
PANEL_REQUIREMENTS=(
    "cPanel:centos,almalinux,rocky"
    "aaPanel:centos,ubuntu,debian,almalinux,rocky"
    "DirectAdmin:centos,almalinux,rocky"
    "Plesk:centos,ubuntu,debian,almalinux,rocky"
    "CyberPanel:centos,ubuntu,debian,almalinux,rocky"
    "CentOS Web Panel:centos,almalinux,rocky"
    "Webmin:centos,ubuntu,debian,almalinux,rocky"
    "sPanel:centos,almalinux,rocky"
    "HestiaCP:ubuntu,debian"
    "RunCloud:ubuntu,debian"
    "CloudPanel:ubuntu,debian"
    "Virtualmin:centos,ubuntu,debian,almalinux,rocky"
    "ISPConfig:centos,ubuntu,debian,almalinux,rocky"
    "Froxlor:centos,ubuntu,debian,almalinux,rocky"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check OS version and compatibility
function detect_os() {
    echo -e "${BLUE}Detecting operating system...${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/centos-release ]; then
        OS="centos"
        OS_VERSION=$(cat /etc/centos-release | awk '{print $4}')
    else
        echo -e "${RED}Unable to detect OS. Only supported Linux distributions are compatible.${NC}"
        exit 1
    fi

    # Check if OS is supported
    if [[ ! " ${SUPPORTED_OS[@]} " =~ " ${OS} " ]]; then
        echo -e "${RED}Unsupported OS detected: $OS. Exiting.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Detected OS: $OS $OS_VERSION${NC}"
}

# Check for prerequisites
function check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    local missing=()
    
    # Check for required commands
    for cmd in wget curl unzip; do
        if ! command -v $cmd &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${YELLOW}Missing packages: ${missing[*]}. Installing...${NC}"
        case $OS in
            centos|almalinux|rocky)
                yum install -y epel-release
                yum install -y ${missing[@]}
                ;;
            ubuntu|debian)
                apt update
                apt install -y ${missing[@]}
                ;;
            *)
                echo -e "${RED}Unsupported OS for automatic package installation.${NC}"
                exit 1
                ;;
        esac
    fi
    
    # Check for systemd
    if ! command -v systemctl &>/dev/null; then
        echo -e "${RED}Systemd is required but not found. This script only supports systemd-based systems.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All prerequisites are satisfied.${NC}"
}

# Check system requirements
function check_system_requirements() {
    echo -e "${BLUE}Checking system requirements...${NC}"
    
    local total_ram=$(free -m | awk '/Mem:/ {print $2}')
    local total_disk=$(df -h / | awk 'NR==2 {print $2}')
    local cpu_cores=$(nproc)
    
    echo -e "System Resources:"
    echo -e "- RAM: ${total_ram}MB"
    echo -e "- Disk: ${total_disk}"
    echo -e "- CPU Cores: ${cpu_cores}"
    
    if [ $total_ram -lt 1024 ]; then
        echo -e "${YELLOW}Warning: For optimal performance, 1GB or more of RAM is recommended.${NC}"
    fi
    
    if [ $cpu_cores -lt 1 ]; then
        echo -e "${YELLOW}Warning: Your system has only 1 CPU core. Some panels may require more.${NC}"
    fi
}

# Set hostname with validation
function set_hostname() {
    while true; do
        echo -n -e "${BLUE}Enter the hostname (e.g., server.example.com): ${NC}"
        read hostname
        
        # Basic validation
        if [[ "$hostname" =~ ^[a-zA-Z0-9.-]+$ ]] && [[ "$hostname" =~ [.] ]]; then
            hostnamectl set-hostname "$hostname"
            
            # Update /etc/hosts if needed
            if ! grep -q "$hostname" /etc/hosts; then
                echo "127.0.0.1 $hostname" >> /etc/hosts
            fi
            
            echo -e "${GREEN}Hostname set to: $hostname${NC}"
            break
        else
            echo -e "${RED}Invalid hostname. Please use a valid FQDN (e.g., server.example.com).${NC}"
        fi
    done
}

# Check if panel is compatible with OS
function is_panel_compatible() {
    local panel_name=$1
    local compatible_os
    
    for requirement in "${PANEL_REQUIREMENTS[@]}"; do
        if [[ "$requirement" == "$panel_name:"* ]]; then
            compatible_os=${requirement#*:}
            compatible_os=${compatible_os//,/ }
            
            for os in $compatible_os; do
                if [[ "$os" == "$OS" ]]; then
                    return 0
                fi
            done
        fi
    done
    
    return 1
}

# Display available control panels with compatibility info
function display_panels() {
    echo -e "\n${BLUE}Available Control Panels:${NC}"
    
    local index=1
    for requirement in "${PANEL_REQUIREMENTS[@]}"; do
        panel_name=${requirement%%:*}
        compatible_os=${requirement#*:}
        
        if is_panel_compatible "$panel_name"; then
            echo -e "${GREEN}$index. $panel_name${NC} (Compatible with your OS)"
        else
            echo -e "${RED}$index. $panel_name${NC} (Requires: ${compatible_os//,/ })"
        fi
        ((index++))
    done
}

# Install cPanel
function install_cpanel() {
    echo -e "${BLUE}Installing cPanel...${NC}"
    
    if [[ "$OS" != "centos" && "$OS" != "almalinux" && "$OS" != "rocky" ]]; then
        echo -e "${RED}cPanel requires CentOS, AlmaLinux, or Rocky Linux.${NC}"
        return 1
    fi
    
    set_hostname
    yum install -y wget
    wget -O /root/cpanel.sh http://securedownloads.cpanel.net/latest
    sh /root/cpanel.sh
    
    echo -e "${GREEN}cPanel installation initiated. This may take a while.${NC}"
}

# Install aaPanel
function install_aapanel() {
    echo -e "${BLUE}Installing aaPanel...${NC}"
    
    set_hostname
    wget -O install.sh https://www.aapanel.com/script/install_6.0_en.sh
    bash install.sh
    
    echo -e "${GREEN}aaPanel installation initiated.${NC}"
}

# Install DirectAdmin
function install_directadmin() {
    echo -e "${BLUE}Installing DirectAdmin...${NC}"
    
    if [[ "$OS" != "centos" && "$OS" != "almalinux" && "$OS" != "rocky" ]]; then
        echo -e "${RED}DirectAdmin requires CentOS, AlmaLinux, or Rocky Linux.${NC}"
        return 1
    fi
    
    set_hostname
    wget -O setup.sh https://www.directadmin.com/setup.sh
    chmod +x setup.sh
    ./setup.sh
    
    echo -e "${GREEN}DirectAdmin installation initiated.${NC}"
}

# Install Plesk
function install_plesk() {
    echo -e "${BLUE}Installing Plesk...${NC}"
    
    set_hostname
    wget -O - https://autoinstall.plesk.com/one-click-installer | sh
    
    echo -e "${GREEN}Plesk installation initiated.${NC}"
}

# Install CyberPanel
function install_cyberpanel() {
    echo -e "${BLUE}Installing CyberPanel...${NC}"
    
    set_hostname
    sh <(curl https://cyberpanel.sh || wget -O - https://cyberpanel.sh)
    
    echo -e "${GREEN}CyberPanel installation initiated.${NC}"
}

# Install CentOS Web Panel
function install_cwp() {
    echo -e "${BLUE}Installing CentOS Web Panel...${NC}"
    
    if [[ "$OS" != "centos" && "$OS" != "almalinux" && "$OS" != "rocky" ]]; then
        echo -e "${RED}CentOS Web Panel requires CentOS, AlmaLinux, or Rocky Linux.${NC}"
        return 1
    fi
    
    set_hostname
    yum -y install wget
    wget http://centos-webpanel.com/cwp-el7-latest
    sh cwp-el7-latest
    
    echo -e "${GREEN}CentOS Web Panel installation initiated.${NC}"
}

# Install Webmin
function install_webmin() {
    echo -e "${BLUE}Installing Webmin...${NC}"
    
    set_hostname
    
    case $OS in
        centos|almalinux|rocky)
            cat > /etc/yum.repos.d/webmin.repo <<EOL
[Webmin]
name=Webmin Distribution Neutral
baseurl=https://download.webmin.com/download/yum
enabled=1
gpgcheck=1
gpgkey=https://download.webmin.com/download/yum/webmin-release.gpg
EOL
            yum install -y webmin
            ;;
        ubuntu|debian)
            wget -qO - http://www.webmin.com/jcameron-key.asc | apt-key add -
            echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            apt update
            apt install -y webmin
            ;;
        *)
            echo -e "${RED}Unsupported OS for Webmin installation.${NC}"
            return 1
            ;;
    esac
    
    /usr/libexec/webmin/changepass.pl /etc/webmin root "$(openssl rand -base64 12)"
    
    echo -e "${GREEN}Webmin installed successfully.${NC}"
    echo -e "Access Webmin at: ${YELLOW}https://$(hostname):10000${NC}"
}

# Install sPanel
function install_spanel() {
    echo -e "${BLUE}Installing sPanel...${NC}"
    
    if [[ "$OS" != "centos" && "$OS" != "almalinux" && "$OS" != "rocky" ]]; then
        echo -e "${RED}sPanel requires CentOS, AlmaLinux, or Rocky Linux.${NC}"
        return 1
    fi
    
    set_hostname
    yum install -y wget
    wget -O spanel-installer.sh https://install.spanel.io/install.sh
    chmod +x spanel-installer.sh
    ./spanel-installer.sh
    
    echo -e "${GREEN}sPanel installation initiated.${NC}"
}

# Install HestiaCP
function install_hestiacp() {
    echo -e "${BLUE}Installing HestiaCP...${NC}"
    
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        echo -e "${RED}HestiaCP requires Ubuntu or Debian.${NC}"
        return 1
    fi
    
    set_hostname
    wget https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh
    bash hst-install.sh
    
    echo -e "${GREEN}HestiaCP installation initiated.${NC}"
}

# Install RunCloud
function install_runcloud() {
    echo -e "${BLUE}Installing RunCloud...${NC}"
    
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        echo -e "${RED}RunCloud requires Ubuntu or Debian.${NC}"
        return 1
    fi
    
    set_hostname
    wget -qO https://manage.runcloud.io/bootstrap.sh | bash
    
    echo -e "${GREEN}RunCloud installation initiated.${NC}"
}

# Install CloudPanel
function install_cloudpanel() {
    echo -e "${BLUE}Installing CloudPanel...${NC}"
    
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        echo -e "${RED}CloudPanel requires Ubuntu or Debian.${NC}"
        return 1
    fi
    
    set_hostname
    wget -O install.sh https://installer.cloudpanel.io/ce/v2/install.sh
    bash install.sh
    
    echo -e "${GREEN}CloudPanel installation initiated.${NC}"
}

# Install Virtualmin
function install_virtualmin() {
    echo -e "${BLUE}Installing Virtualmin...${NC}"
    
    set_hostname
    wget https://software.virtualmin.com/gpl/scripts/install.sh
    chmod +x install.sh
    ./install.sh
    
    echo -e "${GREEN}Virtualmin installation initiated.${NC}"
}

# Install ISPConfig
function install_ispconfig() {
    echo -e "${BLUE}Installing ISPConfig...${NC}"
    
    set_hostname
    wget -O ispconfig.tar.gz https://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz
    tar xfz ispconfig.tar.gz
    cd ispconfig3*/install/
    php -q install.php
    
    echo -e "${GREEN}ISPConfig installation initiated.${NC}"
}

# Install Froxlor
function install_froxlor() {
    echo -e "${BLUE}Installing Froxlor...${NC}"
    
    set_hostname
    
    case $OS in
        centos|almalinux|rocky)
            yum install -y epel-release
            yum install -y https://rpm.froxlor.org/froxlor-release-latest.noarch.rpm
            yum install -y froxlor
            ;;
        ubuntu|debian)
            apt install -y wget
            wget -O - https://deb.froxlor.org/froxlor.org.key | apt-key add -
            echo "deb https://deb.froxlor.org/ubuntu focal main" > /etc/apt/sources.list.d/froxlor.list
            apt update
            apt install -y froxlor
            ;;
        *)
            echo -e "${RED}Unsupported OS for Froxlor installation.${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}Froxlor installed successfully.${NC}"
}

# Post-installation checklist
function post_install_checklist() {
    echo -e "\n${BLUE}Post-Installation Checklist:${NC}"
    echo -e "1. Change default passwords for admin accounts"
    echo -e "2. Configure firewall to allow panel ports"
    echo -e "3. Set up regular backups"
    echo -e "4. Enable automatic security updates"
    echo -e "5. Configure SSL/TLS for the panel interface"
    echo -e "6. Review and harden server security settings"
    echo -e "7. Monitor server resources regularly"
}

# Main menu
function main_menu() {
    clear
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE} Control Panel Installation Script ${NC}"
    echo -e "${BLUE} Version: $VERSION | Detected OS: $OS $OS_VERSION ${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    check_system_requirements
    
    while true; do
        display_panels
        
        echo -e "\n${YELLOW}Additional Options:${NC}"
        echo -e "s. Set hostname only"
        echo -e "c. Check system requirements"
        echo -e "q. Quit"
        
        echo -n -e "\n${BLUE}Enter your choice (1-${#PANEL_REQUIREMENTS[@]}, s, c, or q): ${NC}"
        read choice
        
        case $choice in
            1) install_cpanel ;;
            2) install_aapanel ;;
            3) install_directadmin ;;
            4) install_plesk ;;
            5) install_cyberpanel ;;
            6) install_cwp ;;
            7) install_webmin ;;
            8) install_spanel ;;
            9) install_hestiacp ;;
            10) install_runcloud ;;
            11) install_cloudpanel ;;
            12) install_virtualmin ;;
            13) install_ispconfig ;;
            14) install_froxlor ;;
            s|S) set_hostname ;;
            c|C) check_system_requirements ;;
            q|Q) 
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
        
        if [[ $choice =~ ^[0-9]+$ ]]; then
            post_install_checklist
        fi
        
        echo -e "\nPress any key to return to the menu..."
        read -n 1 -s
        clear
    done
}

# Script execution starts here
detect_os
check_prerequisites
main_menu
