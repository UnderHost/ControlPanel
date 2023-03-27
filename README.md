# ControlPanel.sh - small bash script to easily install control panel

## Description:
This one-click installation script allows users to easily install multiple control panels on their servers. The script supports the installation of cPanel, aaPanel, DirectAdmin, Plesk, CyberPanel, CentOS Web Panel, Webmin, and sPanel. It checks the server's OS for compatibility and prompts the user for their hostname before proceeding with the installation. The user can select the desired control panel from a menu, and the script will display the installation progress.

# FAQ:

### Q: Which control panels does this script support?
A: The script supports cPanel, aaPanel, DirectAdmin, Plesk, CyberPanel, CentOS Web Panel, Webmin, and sPanel.

### Q: What are the OS compatibility requirements for each control panel?
A: The compatibility requirements are as follows:

* cPanel: CentOS, CloudLinux, or AlmaLinux
* aaPanel: CentOS, Ubuntu, or Debian
* DirectAdmin: CentOS, Debian, or Ubuntu
* Plesk: CentOS, Ubuntu, Debian, or AlmaLinux
* CyberPanel: CentOS
* CentOS Web Panel: CentOS
* Webmin: CentOS, Ubuntu, or Debian
* sPanel: CentOS

### Q: How do I use the script?
A: Save the script as a .sh file, give it executable permissions (e.g., chmod +x script.sh), and run it using the command ./script.sh. The script will display a list of control panels and prompt you for your choice. Enter the number corresponding to your desired control panel, and the script will proceed with the installation.

### Q: Can I install multiple control panels using this script?
A: Yes, you can run the script multiple times to install different control panels. However, it's not recommended to install multiple control panels on the same server, as they may conflict with one another.

# Usage:

* Download the script from the GitHub repository by running the following command: wget https://github.com/UnderHost/ControlPanel/archive/refs/heads/main.zip
* Unzip the downloaded file: unzip main.zip
* Change the directory to the unzipped folder: cd ControlPanel-main
* Give the script executable permissions: chmod +x install_control_panels.sh
* Run the script: ./install_control_panels.sh
* The script will display a list of available control panels and prompt you for your choice. Enter the number corresponding to the control panel you wish to install.
* The script will prompt you for your hostname. Enter your desired hostname and press Enter.
* The script will check your server's OS for compatibility and proceed with the installation if the requirements are met.
* Monitor the installation progress displayed by the script.
* Once the installation is complete, follow the control panel's official documentation for further configuration and setup.

# Install

wget https://github.com/UnderHost/ControlPanel/archive/refs/heads/main.zip && unzip main.zip && cd ControlPanel-main && chmod +x ControlPanel.sh && ./ControlPanel.sh

