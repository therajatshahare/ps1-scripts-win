# ⚙️ Cmd-Scripts Toolkit

A personal **PowerShell CLI toolkit** for everyday automation, media handling, and utilities — install everything with **one command**.

---

## 🚀 One-Line Install

```powershell
irm https://raw.githubusercontent.com/therajatshahare/ps1-scripts-win/main/install.ps1 | iex
```

> ⚠️ Restart PowerShell after installation.

---

## 📂 What This Does

* Installs all scripts to:

  ```
  $HOME\cmd-scripts
  ```
* Adds scripts to PATH
* Configures PowerShell profile automatically
* Installs required dependencies:

  * yt-dlp
  * ffmpeg
  * aria2
  * python
  * lyricsgenius

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
```

### 📸 Instagram

* To add the user accounts use "ask" command. It'll trigger to add the new user account ID & Password. If the new account detected then it'll ask to save the userid and allot the specific number ex. 1,2,3,... etc.
```powershell
insta <username> full ask
```
* Once the account get allotment number after that user can use that number to trigger the account to use for the session.
```powershell
insta <username> full "1/2/3/..."
insta <username> update "1/2/3/..."
```

### 🔁 Toolkit Update

```powershell
update-scripts
```

---

### 📖 Help System

Get help directly in terminal:

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

## 🎵 Lyrics Setup (Required for showlyrics)

```powershell
[Environment]::SetEnvironmentVariable("GENIUS_TOKEN", "your_token_here", "User")
```

Restart PowerShell after setting.

---

## 📦 Project Structure

```
cmd-scripts/
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
    ├── toolkit-help.ps1
    └── lyrics.py
```

---

## 🧠 Design Philosophy

* One-command setup
* No admin required
* Portable across systems
* Self-healing configuration
* Minimal dependencies

---

## ⚠️ Notes

* Designed for Windows + PowerShell
* Works best without Administrator mode

---

## ⭐ Author

Rajat Shahare
https://github.com/therajatshahare

---

## 🛠️ License

Personal toolkit — use freely and modify as needed.
