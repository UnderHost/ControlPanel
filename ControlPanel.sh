#!/bin/bash

# Check OS version
OS=$(cat /etc/*-release | grep '^ID=' | cut -d '=' -f 2 | tr -d '"')

# Check for prerequisites
function check_prerequisites() {
  echo "Checking prerequisites..."
  if ! command -v wget &>/dev/null || ! command -v unzip &>/dev/null; then
    echo "Some required tools are missing. Installing wget and unzip..."
    if [ -f /etc/debian_version ]; then
      sudo apt update && sudo apt install -y wget unzip
    elif [ -f /etc/redhat-release ]; then
      sudo yum install -y wget unzip
    else
      echo "Unsupported OS detected. Exiting."
      exit 1
    fi
  fi
}

# Script header
echo "======================================"
echo " Control Panel Installation Script"
echo "======================================"

# Function to display available control panels
function display_panels {
  echo "Available Control Panels:"
  echo "1. cPanel (requires CentOS)"
  echo "2. aaPanel"
  echo "3. DirectAdmin (requires CentOS)"
  echo "4. Plesk (requires CentOS or Ubuntu)"
  echo "5. CyberPanel (requires CentOS)"
  echo "6. CentOS Web Panel (requires CentOS)"
  echo "7. Webmin (requires CentOS or Ubuntu)"
  echo "8. sPanel (requires CentOS)"
}

# Function to set the hostname
function set_hostname {
  echo -n "Enter the hostname: "
  read hostname
  hostnamectl set-hostname $hostname
}

# Function to install the selected control panel
function install_panel {
  case $1 in
    1)
      if [[ $OS == "centos" ]]; then
        set_hostname
        yum install -y wget
        wget -O /root/cpanel.sh http://securedownloads.cpanel.net/latest
        sh /root/cpanel.sh
      else
        echo "cPanel requires CentOS."
      fi
      ;;
    2)
      set_hostname
      wget -O install.sh https://www.aapanel.com/script/install_6.0_en.sh
      bash install.sh
      ;;
    3)
      if [[ $OS == "centos" ]]; then
        set_hostname
        wget -O setup.sh https://www.directadmin.com/setup.sh
        chmod +x setup.sh
        ./setup.sh
      else
        echo "DirectAdmin requires CentOS."
      fi
      ;;
    4)
      if [[ $OS == "centos" || $OS == "ubuntu" ]]; then
        set_hostname
        wget -O - https://autoinstall.plesk.com/one-click-installer | sh
      else
        echo "Plesk requires CentOS or Ubuntu."
      fi
      ;;
    5)
      if [[ $OS == "centos" ]]; then
        set_hostname
        sh <(curl https://cyberpanel.sh || wget -O - https://cyberpanel.sh)
      else
        echo "CyberPanel requires CentOS."
      fi
      ;;
    6)
      if [[ $OS == "centos" ]]; then
        set_hostname
        yum -y install wget
        wget http://centos-webpanel.com/cwp-el7-latest
        sh cwp-el7-latest
      else
        echo "CentOS Web Panel requires CentOS."
      fi
      ;;
    7)
      if [[ $OS == "centos" || $OS == "ubuntu" ]]; then
        set_hostname
        wget -O webmin-install.sh http://www.webmin.com/jcameron-key.asc
        apt-key add jcameron-key.asc
        echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list
        apt-get update
        apt-get install -y webmin
      else
        echo "Webmin requires CentOS or Ubuntu."
      fi
      ;;
    8)
      if [[ $OS == "centos" ]]; then
        set_hostname
        yum install -y wget
        wget -O spanel-installer.sh https://install.spanel.io/install.sh
        chmod +x spanel-installer.sh
        ./spanel-installer.sh
      else
        echo "sPanel requires CentOS."
      fi
      ;;
    *)
      echo "Invalid option. Please try again."
      ;;
  esac
}

# Main script execution
while true; do
  display_panels
  echo -n "Enter the number of the control panel you want to install (or 'q' to quit): "
  read choice

  if [[ $choice == "q" ]]; then
    echo "Exiting..."
    exit 0
  fi

  install_panel $choice
  echo "======================================"
done

