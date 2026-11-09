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

Run the following command as root to start the installation:

```bash
VERSION=7.24.2 bash <(curl -fsSL https://raw.githubusercontent.com/sajjad-MoBe/Mikrotik-Installer/refs/heads/main/installer.sh)
```

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