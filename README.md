# 🚀 ControlPanel.sh - One-Click Control Panel Installer  

# 🛠️ ControlPanel.sh  
_For best results, deploy on [UnderHost Dedicated Servers](https://underhost.com/servers.php) (24/7 support included)_

> **v2025.1** | *May 2025* | **Supports: CentOS, Ubuntu, Debian, AlmaLinux, Rocky Linux**  

---

## 🔥 **Full Panel List & Compatibility**  

| #  | Control Panel    | Supported OS                     | License   | Notes                          |  
|----|------------------|----------------------------------|-----------|--------------------------------|  
| 1  | **cPanel**       | CentOS, AlmaLinux, Rocky         | Paid      | Requires license key           |  
| 2  | **aaPanel**      | CentOS, Ubuntu, Debian           | Free      | Chinese alternative to cPanel  |  
| 3  | **DirectAdmin**  | CentOS, AlmaLinux, Rocky         | Paid      | Lightweight commercial panel   |  
| 4  | **Plesk**        | CentOS, Ubuntu, Debian, AlmaLinux| Paid/Free | WordPress toolkit included     |  
| 5  | **CyberPanel**   | CentOS, Ubuntu                   | Free      | With OpenLiteSpeed/Enterprise  |  
| 6  | **CentOS Web Panel** | CentOS, AlmaLinux            | Free      | Legacy (use with caution)      |  
| 7  | **Webmin**       | CentOS, Ubuntu, Debian           | Free      | Admin panel (no hosting focus) |  
| 8  | **sPanel**       | CentOS, AlmaLinux, Rocky         | Free      | For CentOS-based servers       |  
| 9  | **HestiaCP**     | Ubuntu, Debian                   | Free      | VestaCP fork                   |  
| 10 | **RunCloud**     | Ubuntu, Debian                   | Freemium  | Cloud-optimized                |  
| 11 | **CloudPanel**   | Ubuntu, Debian                   | Free      | PHP/MySQL focus                |  
| 12 | **Virtualmin**   | CentOS, Ubuntu, Debian           | Free/Paid | Webmin extension               |  
| 13 | **ISPConfig**    | CentOS, Ubuntu, Debian           | Free      | Advanced open-source panel     |  
| 14 | **Froxlor**      | CentOS, Ubuntu, Debian           | Free      | Lightweight German panel       |  

---

## 🛠️ **Installation**  

### **Method 1: One-Line Install**  
```
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/UnderHost/ControlPanel/main/ControlPanel.sh)"
```

### **Method 2: Manual Download**  
```
wget https://github.com/UnderHost/ControlPanel/archive/refs/heads/main.zip
unzip main.zip
cd ControlPanel-main
chmod +x ControlPanel.sh
sudo ./ControlPanel.sh
```

---

## 📖 **Usage Guide**  
1. **Run the script** as root or with `sudo`.  
2. **Select a panel** from the interactive menu.  
3. **Enter hostname** when prompted (e.g., `server.yourdomain.com`).  
4. **Wait** – The script handles dependencies automatically.  
5. **Post-install**:  
   - Credentials are saved to `/root/panel_credentials.txt`  
   - Installation logs: `/var/log/controlpanel_install.log`  

---

## ❓ **FAQ**  

### **Q: How do I update the script?**  
```
cd /path/to/ControlPanel-main && wget -qO ControlPanel.sh https://raw.githubusercontent.com/UnderHost/ControlPanel/main/ControlPanel.sh
```

### **Q: Can I automate installations?**  
Yes! For non-interactive mode (e.g., HestiaCP on Ubuntu):  
```
echo "9" | sudo ./ControlPanel.sh  # Installs HestiaCP (option #9)
```

### **Q: What if my OS isn’t supported?**  
The script will **block incompatible installations**. For manual overrides:  
```
sudo FORCE_INSTALL=1 ./ControlPanel.sh  # Use at your own risk!
```

---

## 🛡️ **Security Best Practices**  
1. **Always** set strong passwords post-install.  
2. **Enable firewalls**:  
   ```
   sudo ufw allow 22,80,443,2082,2083,2086,2087  # Common panel ports
   sudo ufw enable
   ```
3. **Disable root SSH**: Edit `/etc/ssh/sshd_config` and set `PermitRootLogin no`.  

---

## 📜 **License & Credits**  
- **License**: MIT (Free for personal/commercial use).  
- **Disclaimer**: Not affiliated with cPanel, Plesk, or other panel vendors.  
- **Support**: For issues, open a [GitHub Issue](https://github.com/UnderHost/ControlPanel/issues).  

---

### 🌟 **Why This Script?**  
- **Saves hours** of manual configuration.  
- **No hidden code** – Verify with `less ControlPanel.sh`.  
- **Used by UnderHost.com** for internal server deployments.  

