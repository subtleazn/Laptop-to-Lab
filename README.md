# 💻 Laptop-to-Lab (L2L)
### Turn your old laptop into a production-grade Home Server in minutes.

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Bash](https://img.shields.io/badge/language-Bash-green.svg) ![Platform](https://img.shields.io/badge/platform-Linux%20Mint%20%7C%20Ubuntu-orange.svg)

**Don't let your old hardware gather dust.** Laptop-to-Lab is a battle-tested automation suite that converts consumer laptops (specifically Lenovo, but adaptable) into optimized, headless, silent servers for Docker, Plex, Jellyfin, and the *Arr stack.

---

## 🚀 Why use this?
Setting up a server on a laptop is annoying. Consumer hardware isn't designed to run 24/7.
* **The Screen Problem:** It burns in if you leave it on, but the laptop sleeps if you close the lid.
* **The Battery Problem:** Leaving it plugged in 100% of the time swells the battery.
* **The Wifi Problem:** Consumer wifi cards "sleep" to save power, killing your server latency.
* **The Config Problem:** Manually editing `/etc/systemd/logind.conf` and `fstab` is tedious and error-prone.

**L2L solves all of this automatically.**

## ✨ Features

### 🔧 Hardware Optimization (The "Laptop" Part)
* **Lid-Close Handling:** Forces the laptop to stay awake when the lid is closed (Server Mode).
* **Screen Management:** Disables screensavers and turns off the backlight to save power/prevent burn-in.
* **Battery Protection:** (Lenovo Specific) Locks battery charge to 60% to prevent swelling while plugged in 24/7.
* **Wifi Fixes:** Disables power-saving mode on wireless cards for low-latency connections.

### 🛡️ System & Security
* **Forensic Audit:** A detailed `audit.sh` script that scans your hardware, network, and storage.
* **Auto-Firewall:** Installs and configures **UFW**, opening only essential ports (SSH, SMB, Portainer, Web Apps).
* **Windows Access:** Auto-configures **Samba (SMB)** so you can map `/data` as a network drive on Windows.
* **Performance Tuning:** Adjusts `vm.swappiness` to 10 (from the desktop default of 60) to prioritize RAM over disk usage.

### 🐳 Docker & Media Readiness
* **One-Click Stack:** Auto-installs Docker and Docker Compose.
* **Portainer Ready:** Auto-deploys **Portainer Agent** (Standard or Edge) so you can control the laptop remotely.
* **TRaSH Guides Compliance:** The audit script specifically checks if your `torrents` and `media` folders are on the same physical partition to ensure **Atomic Moves** (Instant hardlinks) work correctly.

---

## 📦 Installation

### Prerequisites
* A laptop running a fresh install of **Linux Mint** (Recommended) or **Ubuntu**.
* Connected to the internet.

### Quick Start
1.  **Open a terminal** and clone the repository:
    ```bash
    git clone [https://github.com/yourusername/laptop-to-lab.git](https://github.com/yourusername/laptop-to-lab.git)
    cd laptop-to-lab
    ```

2.  **Run the Audit** (The Doctor):
    See exactly what is wrong with your system before you fix it.
    ```bash
    sudo ./audit.sh
    ```

3.  **Run the Setup** (The Surgeon):
    Apply the fixes, install Docker, and secure the system.
    ```bash
    sudo ./setup.sh
    ```

---

## 🔍 The Scripts Explained

### 1. `audit.sh` (Read-Only)
This is a **Safe** script. It changes nothing. It runs a forensic analysis of your machine and reports:
* **Network:** Interface IPs, MAC Address (for router reservation), and open ports.
* **Storage:** Verifies if `/data` exists and checks **Hardlink compatibility** (Device IDs) for TRaSH guides.
* **Security:** Checks UFW status, Samba configuration, and Git identity.
* **Hardware:** Checks actual values of `swappiness`, Grub boot params, and Lid switch settings.

### 2. `setup.sh` (Idempotent Fixer)
This script enforces the desired state. You can run it 100 times; it will only fix what is broken.
* **If Docker is missing:** Installs it.
* **If Firewall is off:** Enables it and opens ports 22, 445, 9001, 8096, etc.
* **If Samba is missing:** Injects the `[Data]` config block and restarts the service.
* **If Lid Switch is default:** Patches `logind.conf` to ignore lid close.

---

## 📋 Compatibility
* **OS:** Designed for Debian-based systems (Linux Mint 21+, Ubuntu 22.04+).
* **Hardware:**
    * **Generic Laptops:** Lid close, screen, wifi, and system tuning work on ANY laptop.
    * **Lenovo Laptops:** Battery conservation mode (locking charge to 60%) is optimized for Lenovo Ideapads/Thinkpads using the `ideapad_acpi` driver.

## 🤝 Contributing
Have a Dell or HP? Feel free to submit a Pull Request to add battery conservation drivers for other manufacturers!

## 📄 License
MIT License. Use it, fork it, build your empire.
