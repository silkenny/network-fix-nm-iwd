# Network Fix: NetworkManager & iwd Conflict Resolution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)

## 🎯 Overview

This project resolves the common conflict between **NetworkManager** and **iwd** (Intel's wireless daemon used by `iwctl`) on Linux systems. This issue is particularly prevalent on Arch Linux, Fedora, and their derivatives.

## 🔍 The Problem

Both NetworkManager and iwd attempt to manage Wi-Fi interfaces simultaneously, leading to:

- 🚫 **Invisible interfaces** in `iwctl`
- 📡 **NetworkManager fails** to detect Wi-Fi networks properly
- 🔄 **Unstable connections** and frequent disconnects
- ⚡ **Performance degradation** in wireless connectivity

## ✨ Features

- 🛠️ **Automatic conflict resolution** - Disables iwd and configures NetworkManager as the primary Wi-Fi manager
- 🔄 **Reversible changes** - Restore previous configuration if needed
- 🎯 **Distribution agnostic** - Works on Arch, Fedora, Ubuntu, and derivatives
- 📋 **Comprehensive logging** - Track all changes made to the system
- ✅ **Safety checks** - Validates system state before making changes

## 🚀 Quick Start

### Prerequisites

- Linux system with both NetworkManager and iwd installed
- Root/sudo privileges
- Bash shell

### Installation

```bash
git clone https://github.com/silkenny/network-fix-nm-iwd.git
cd network-fix-nm-iwd
chmod +x fix-network.sh
```

### Usage

#### Apply the fix
```bash
sudo ./fix-network.sh
```

#### Restore original configuration
```bash
sudo ./restore-network.sh
```

#### Check current status
```bash
./check-status.sh
```

## 📁 Repository Structure

```
network-fix-nm-iwd/
├── fix-network.sh          # Main script to resolve the conflict
├── restore-network.sh      # Script to restore original configuration
├── check-status.sh         # Status checker for network services
├── backup/                 # Backup directory for original configs
├── logs/                   # Operation logs
├── README.md              # This file
├── CHANGELOG.log          # Version history
└── LICENSE                # MIT License
```

## 🔧 What the Script Does

1. **Backup Phase**
   - Creates backup of current network configurations
   - Saves systemd service states

2. **Resolution Phase**
   - Stops and disables iwd service
   - Configures NetworkManager to use wpa_supplicant
   - Restarts NetworkManager service
   - Verifies changes

3. **Verification Phase**
   - Checks service status
   - Tests network connectivity
   - Generates status report

## 🔄 Before and After

### Before (Conflicting State)
```bash
$ systemctl status iwd
● iwd.service - Wireless service
   Active: active (running)

$ systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Active: active (running)

$ iwctl device list
# No devices shown or unstable behavior
```

### After (Resolved State)
```bash
$ systemctl status iwd
● iwd.service - Wireless service
   Active: inactive (dead)

$ systemctl status NetworkManager
● NetworkManager.service - Network Manager
   Active: active (running)

$ nmcli device wifi list
# Wi-Fi networks properly displayed
```

## 🛡️ Safety Features

- **Automatic backups** of all modified configurations
- **Rollback capability** to restore original state
- **Pre-flight checks** to validate system compatibility
- **Detailed logging** of all operations
- **Non-destructive** operations with full reversibility

## 🔍 Troubleshooting

### Common Issues

#### NetworkManager not starting after fix
```bash
sudo systemctl restart NetworkManager
sudo systemctl enable NetworkManager
```

#### Wi-Fi adapter not detected
```bash
sudo rfkill unblock wifi
sudo modprobe -r iwlwifi && sudo modprobe iwlwifi
```

#### Connection drops frequently
```bash
# Check for power management issues
sudo iwconfig wlan0 power off
```

### Logs Location
- Operation logs: `./logs/fix-network-$(date).log`
- System logs: `journalctl -u NetworkManager`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add some improvement'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Open a Pull Request

## 📋 Tested Distributions

- ✅ Arch Linux
- ✅ Fedora 38+
- ✅ Ubuntu 22.04+
- ✅ openSUSE Tumbleweed
- ✅ Manjaro
- ✅ EndeavourOS

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Arch Wiki](https://wiki.archlinux.org/title/NetworkManager) for NetworkManager documentation
- [iwd project](https://iwd.wiki.kernel.org/) for wireless daemon information
- Community contributors and testers

## 📞 Support

If you encounter issues:

1. Check the [troubleshooting section](#-troubleshooting)
2. Review the logs in `./logs/`
3. Open an [issue](https://github.com/silkenny/network-fix-nm-iwd/issues)

---

⭐ **If this project helped you, please consider giving it a star!**
