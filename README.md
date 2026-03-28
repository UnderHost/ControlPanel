# 🚀 ControlPanel.sh - One-Click Control Panel Installer

> **v2026.1.0** | March 2026 | UnderHost.com
> _Fully interactive, OS-aware, production-ready installer for 20+ control panels._

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2026.1.0-green.svg)](https://github.com/UnderHost/one-domain/blob/main/docs/CHANGELOG.md)
[![UnderHost](https://img.shields.io/badge/by-UnderHost.com-orange)](https://underhost.com)

---

## 🔥 Panel List & Compatibility

### Traditional / Commercial

| # | Panel | Supported OS | License | Port |
|---|-------|-------------|---------|------|
| 1 | **cPanel** | CentOS, AlmaLinux, Rocky | Paid | 2087 |
| 2 | **DirectAdmin** | CentOS, AlmaLinux, Rocky, Ubuntu, Debian | Paid | 2222 |
| 3 | **Plesk** | CentOS, AlmaLinux, Rocky, Ubuntu, Debian | Paid/Free | 8443 |
| 4 | **CentOS Web Panel (CWP)** | CentOS, AlmaLinux, Rocky | Free | 2030 |
| 5 | **sPanel** | CentOS, AlmaLinux, Rocky | Free | 2083 |

### Free / Open-Source

| # | Panel | Supported OS | License | Port |
|---|-------|-------------|---------|------|
| 6 | **aaPanel** | All | Free | 8888 |
| 7 | **CyberPanel** | All | Free | 8090 |
| 8 | **HestiaCP** | Ubuntu, Debian | Free | 8083 |
| 9 | **CloudPanel** | Ubuntu, Debian | Free | 8443 |
| 10 | **Webmin** | All | Free | 10000 |
| 11 | **Virtualmin** | All | Free/Paid | 10000 |
| 12 | **ISPConfig** | Ubuntu, Debian | Free | 8080 |
| 13 | **Froxlor** | Ubuntu, Debian | Free | 80 |
| 14 | **Ajenti** | Ubuntu, Debian | Free | 8000 |
| 15 | **PhyrePanel** | Ubuntu, Debian | Free | 8443 |
| 16 | **OLSPanel** | Ubuntu, Debian, CentOS, AlmaLinux, Rocky | Free | 8443 |

### Modern / PaaS / Docker-based

| # | Panel | Supported OS | License | Port |
|---|-------|-------------|---------|------|
| 17 | **Coolify** | Ubuntu (LTS), Debian | Free | 8000 |
| 18 | **CapRover** | Ubuntu, Debian | Free | 3000 |
| 19 | **EasyPanel** | Ubuntu, Debian | Free/Paid | 3000 |
| 20 | **Webinoly** | Ubuntu, Debian | Free | 80 |
| 21 | **ServerAvatar Lite** | Ubuntu 22.04/24.04 | Free | web |

---

## 🛠️ Installation

### One-Line Install (recommended)

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/UnderHost/ControlPanel/main/ControlPanel.sh)"
```

### Download & Run

```bash
wget -O ControlPanel.sh https://raw.githubusercontent.com/UnderHost/ControlPanel/main/ControlPanel.sh
chmod +x ControlPanel.sh
sudo ./ControlPanel.sh
```

---

## 📖 Usage

### Interactive Mode (default)

```bash
sudo ./ControlPanel.sh
```

On launch, the script will:
1. Detect your OS and version automatically
2. Check RAM, disk, and CPU resources
3. Show only panels **compatible with your OS** in green
4. Show incompatible panels in red (for reference)
5. Prompt for any panel-specific settings (hostname, email, etc.)
6. Install prerequisites automatically before each panel

### List Compatible Panels (no install)

```bash
sudo ./ControlPanel.sh --list
```

### Non-Interactive / CI Mode

```bash
sudo PANEL=hestiacp ./ControlPanel.sh
sudo PANEL=coolify ./ControlPanel.sh
sudo PANEL=aapanel ./ControlPanel.sh
```

Valid `PANEL` IDs: `cpanel`, `directadmin`, `plesk`, `cwp`, `spanel`, `aapanel`, `cyberpanel`, `hestiacp`, `cloudpanel`, `webmin`, `virtualmin`, `ispconfig`, `froxlor`, `ajenti`, `phyrepanel`, `olspanel`, `coolify`, `caprover`, `easypanel`, `webinoly`, `serveravatar`

---

## 📁 Post-Install Files

| File | Description |
|------|-------------|
| `/root/.panel_credentials.txt` | Saved passwords & access info |
| `/var/log/underhost_controlpanel.log` | Full install log |
| `/var/run/underhost_cp_install.lock` | Prevents concurrent installs |

> Credentials file is `chmod 600` — readable only by root.

---

## ⚙️ What the Script Does

For **every panel**, the script:
- Detects OS, version, architecture, RAM, disk
- Validates compatibility before proceeding
- Installs base prerequisites (`curl`, `wget`, `git`, `gnupg2`, etc.)
- Installs Docker when required (Coolify, CapRover, EasyPanel)
- Prompts for hostname with FQDN validation
- Generates or saves credentials to `/root/.panel_credentials.txt`
- Logs everything to `/var/log/underhost_controlpanel.log`
- Shows a clear post-install summary with access URL

---

## 🔥 Firewall Ports Reference

Open these ports after install:

```bash
# Universal web
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS

# Panel-specific (open only the one you installed)
ufw allow 2083/tcp   # cPanel / sPanel
ufw allow 2087/tcp   # WHM (cPanel)
ufw allow 2222/tcp   # DirectAdmin
ufw allow 8443/tcp   # Plesk / CloudPanel / PhyrePanel / OLSPanel
ufw allow 8090/tcp   # CyberPanel
ufw allow 8083/tcp   # HestiaCP
ufw allow 8888/tcp   # aaPanel
ufw allow 10000/tcp  # Webmin / Virtualmin
ufw allow 8080/tcp   # ISPConfig
ufw allow 8000/tcp   # Coolify / Ajenti
ufw allow 3000/tcp   # CapRover / EasyPanel

ufw enable
```

---

## 🛡️ Security Best Practices

1. **Run on a fresh, clean server** — existing software can conflict
2. **Change default passwords** immediately after installation
3. **Enable SSL** on the panel interface
4. **Configure firewalls** — only open ports you actually need
5. **Enable automatic security updates**:
   ```bash
   # Ubuntu/Debian
   apt install unattended-upgrades -y
   dpkg-reconfigure -plow unattended-upgrades
   ```
6. **Disable root SSH login** once panel user is set up
7. **Configure regular backups** before going to production

---

## ❓ FAQ

**Q: What if my OS isn't listed as compatible for my chosen panel?**
The menu will show it in red. You can still force-install at your own risk by selecting it and confirming the warning prompt.

**Q: Which panels need Docker?**
Coolify, CapRover, and EasyPanel are Docker-based. The script installs Docker automatically using the official Docker repository (not `snap`).

**Q: Can I run this multiple times?**
Yes, but installing a second panel on the same server is risky. Most panels assume they own the web server configuration.

**Q: Where are my login credentials?**
Saved to `/root/.panel_credentials.txt` — readable by root only.

**Q: What is the log file?**
All output is logged to `/var/log/underhost_controlpanel.log`.

---

## 🏗️ Architecture Notes

| Panel | Web Server | Docker Required | Min RAM |
|-------|-----------|----------------|---------|
| Coolify | Caddy (internal) | ✅ | 2 GB |
| CapRover | Nginx (Docker) | ✅ | 1 GB |
| EasyPanel | Traefik (Docker) | ✅ | 1 GB |
| CloudPanel | Nginx | ❌ | 512 MB |
| HestiaCP | Nginx | ❌ | 512 MB |
| CyberPanel | OpenLiteSpeed | ❌ | 1 GB |
| OLSPanel | OpenLiteSpeed | ❌ | 1 GB |
| Webinoly | Nginx | ❌ | 512 MB |

---

## 📜 License & Credits

- **License**: MIT
- **Maintained by**: [UnderHost.com](https://underhost.com)
- **GitHub**: [UnderHost/ControlPanel](https://github.com/UnderHost/ControlPanel)
- **Not affiliated** with cPanel, Plesk, DirectAdmin, or any panel vendor

---

_For best results, deploy on [UnderHost Dedicated Servers or VPS](https://underhost.com/servers.php) — 24/7 support included._
