<div align="center">

# ⚙️ ps1-scripts-win

**A personal PowerShell CLI toolkit for everyday automation, media handling, and utilities.**

Install everything with **one command** — no admin required.

![Platform](https://img.shields.io/badge/platform-Windows-0078D6?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/license-Personal%20Use-lightgrey)

</div>

---

## 📑 Table of Contents

- [Installation](#-installation)
- [Post-Installation Setup](#️-post-installation-setup)
- [What This Does](#-what-this-does)
- [Available Commands](#-available-commands)
- [Instagram](#-instagram)
- [Toolkit Update](#-toolkit-update)
- [Help System](#-help-system)
- [Lyrics Setup](#-lyrics-setup-required-for-showlyrics)
- [Project Structure](#-project-structure)
- [Design Philosophy](#-design-philosophy)
- [Notes](#️-notes)
- [Uninstallation](#️-uninstallation)
- [Author](#-author)
- [License](#️-license)

---

## 🚀 Installation

**1.** Open a PowerShell terminal (version 5.1 or later) and allow local scripts to run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**2.** Run the one-line installer:
```powershell
irm https://raw.githubusercontent.com/therajatshahare/ps1-scripts-win/main/install.ps1 | iex
```

> ⚠️ **Restart PowerShell after installation.**

---

## 🖥️ Post-Installation Setup

After installing, configure your terminal so the toolkit runs the way it's meant to:

1. **Open PowerShell**
2. Go to **PowerShell → Settings** and set:
   - **Default Profile:** `PowerShell 7.x`
   - **Default Terminal Application:** `Windows Terminal`

> 💡 This ensures scripts run on the latest PowerShell engine inside Windows Terminal, avoiding quirks from the legacy `powershell.exe` host.

---

## 📂 What This Does

| | |
|---|---|
| 📥 **Installs scripts to** | `$HOME\ps1-scripts-win` |
| 🔗 **PATH** | Adds all scripts to your PATH |
| ⚙️ **Profile** | Configures your PowerShell profile automatically |

**Dependencies installed automatically:**

| Tool | Purpose |
|---|---|
| `yt-dlp` | Download YouTube video/audio |
| `ffmpeg` | Media conversion & processing |
| `aria2` | Fast multi-connection downloads |
| `python` | Runs helper scripts |
| `lyricsgenius` | Fetches song lyrics |
| `fastfetch` | System info display |

---

## 🧰 Available Commands

### 🎥 Media / YouTube
```powershell
ytvideo
vytvideo
ytaudio
```

### 🎵 Metadata / Lyrics
```powershell
showmeta
showformat
showlyrics
```

### 📁 File Utilities
```powershell
folders
hide
unhide
exifpic
```

### ⚡ System Utilities
```powershell
update
upgrade
aria
fastfetch
```

---

## 📸 Instagram

Add a user account — this triggers a prompt for the account's username & password. Once detected, it saves the credentials and assigns an account number (`1`, `2`, `3`, ...):
```powershell
insta <username> full ask
```

Once an account has a number, use that number to run sessions with it:
```powershell
insta <username> full "1/2/3/..."
insta <username> update "1/2/3/..."
```

---

## 🔁 Toolkit Update
```powershell
update-scripts
```

---

## 📖 Help System

Get help directly in the terminal:
```powershell
toolkit-help
```

Command-specific help:
```powershell
toolkit-help ytvideo
toolkit-help insta
toolkit-help exifpic
toolkit-help "script names"
```

---

## 🎵 Lyrics Setup (Required for `showlyrics`)

### 🔑 How to get your Genius Token

1. Go to [genius.com/api-clients](https://genius.com/api-clients) and sign in (or create a free Genius account).
2. Click **"New API Client."**
3. Fill in an **App Name** and **App Website URL** — these don't need to be real.
4. Click **"Save."** Your new client will appear under API Clients.
5. Click **"Generate Access Token"** next to it.
6. Copy the generated **Client Access Token** — this is your `GENIUS_TOKEN`.

### Set the token
```powershell
[Environment]::SetEnvironmentVariable("GENIUS_TOKEN", "your_token_here", "User")
```
> ⚠️ **Restart PowerShell after setting.**

---

## 📦 Project Structure
```
ps1-scripts-win/
│
├── install.ps1
└── scripts/
    ├── ytvideo.ps1
    ├── vytvideo.ps1
    ├── ytaudio.ps1
    ├── showmeta.ps1
    ├── showlyrics.ps1
    ├── showformat.ps1
    ├── hide.ps1
    ├── unhide.ps1
    ├── update.ps1
    ├── upgrade.ps1
    ├── aria.ps1
    ├── exifpic.ps1
    ├── folders.ps1
    ├── insta.ps1
    ├── insta_fallback.py
    ├── encrypt.ps1
    ├── toolkit-help.ps1
    └── lyrics.py
```

---

## 🧠 Design Philosophy

- ✅ One-command setup
- ✅ No admin required
- ✅ Portable across systems
- ✅ Self-healing configuration
- ✅ Minimal dependencies

---

## ⚠️ Notes

- Designed for **Windows + PowerShell**
- Works best **without** Administrator mode

---

## 🗑️ Uninstallation
```powershell
irm https://raw.githubusercontent.com/therajatshahare/ps1-scripts-win/main/uninstall.ps1 | iex
```

---

## ⭐ Author

**Rajat Shahare**
[github.com/therajatshahare](https://github.com/therajatshahare)

---

## 🛠️ License

Personal toolkit — use freely and modify as needed.
