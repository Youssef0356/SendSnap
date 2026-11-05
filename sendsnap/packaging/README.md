# SendSnap Desktop Packaging Guide

This directory contains the packaging configurations and automated build scripts for releasing **SendSnap Desktop** on **Windows** and **Linux**.

---

## 🪟 Windows (x64)

### Prerequisites:
1. Flutter SDK with Windows desktop support (`flutter config --enable-windows-desktop`).
2. Visual Studio 2022 / Build Tools with "Desktop development with C++".
3. *(Optional for Installer)* [Inno Setup 6](https://jrsoftware.org/isdl.php).

### How to Build:
From PowerShell, run:
```powershell
.\packaging\windows\build_windows.ps1
```
* **Installer**: Generates `dist\windows\SendSnap-Setup-x64.exe` (with automatic Windows Defender Firewall rules).
* **Portable Release**: Standalone binary and assets are located at `build\windows\x64\runner\Release\`.

---

## 🐧 Linux (x86_64)

### Prerequisites:
1. Flutter SDK with Linux desktop support (`flutter config --enable-linux-desktop`).
2. Linux build tools: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.
3. *(Optional for AppImage)* `appimagetool`.

### How to Build Universal AppImage:
```bash
bash packaging/linux/build_appimage.sh
```
Produces `dist/linux/SendSnap-x86_64.AppImage` (runs on Ubuntu, Fedora, Arch, Mint with zero installation).

### How to Build Debian/Ubuntu Package (`.deb`):
```bash
bash packaging/linux/build_deb.sh
```
Produces `dist/linux/sendsnap_2.2.2_amd64.deb`.
