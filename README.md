# MikroTik Installer

A lightweight and automated installation tool designed to simplify the deployment of MikroTik RouterOS (CHR) on virtual and dedicated servers.

This project automates the installation process, making MikroTik deployment faster, easier, and more reliable without requiring complicated manual configuration.

## Features

- Automated MikroTik RouterOS (CHR) installation
- Simplified deployment on virtual and dedicated servers
- Minimal user interaction required
- Designed for server infrastructure and virtualization environments
- Easy-to-use installation process

## Requirements

- Ubuntu 22.04 LTS or Ubuntu 24.04 LTS (recommended)
- Root privileges
- `curl` must be installed
- Internet connectivity

**Recommended OS:** We strongly recommend using Ubuntu 22.04 or Ubuntu 24.04 for the best compatibility and reliability.

## Installation

Run the following command as root to start the installation with a specific RouterOS version:

```bash
VERSION=7.24.2 bash <(curl -fsSL https://raw.githubusercontent.com/sajjad-MoBe/Mikrotik-Installer/refs/heads/main/installer.sh)
```

### Environment variables

| Variable | Description |
| --- | --- |
| `VERSION` | RouterOS version to install, such as `7.24.2`. If the image is unavailable, interactive mode displays available release versions for selection. |
| `AUTO` | Set to `true` to run without prompts. The installer uses the detected network settings and first detected eligible disk. If `VERSION` is missing or unavailable, it selects the latest v7 stable release. |
| `PASSWORD` | Admin password to set on the installed RouterOS system. If omitted, a short random password is generated. In automatic mode, the password is printed immediately before reboot. |

Example of a non-interactive installation with a specified version and password:

```bash
AUTO=true VERSION=7.24.2 PASSWORD=myPass123 bash <(curl -fsSL https://raw.githubusercontent.com/sajjad-MoBe/Mikrotik-Installer/refs/heads/main/installer.sh)
```

`AUTO=true` skips the disk confirmation prompt and writes the image to the first detected eligible disk. This erases the selected disk.

## Disclaimer

This tool may perform disk-related operations during installation. Make sure you have a complete backup of your data before running it.

Use this tool at your own risk.

---

**Built to simplify MikroTik deployment and server infrastructure automation.**

---

## Author

**Code by Sajjad MB**

- 📧 Email: [sajjad@cloudibash.com](mailto:sajjad@cloudibash.com)
- 💬 Telegram: [@imSajjadMB](https://t.me/imSajjadMB)
