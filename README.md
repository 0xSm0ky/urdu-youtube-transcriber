# 🎙️ Urdu YouTube Transcriber

An interactive bash script that downloads YouTube videos or playlists, transcribes the audio using **faster-whisper**, and optionally translates to **English** or **Arabic (RTL)**. Designed to run fully locally on a Linux VPS — no API keys, no cloud services.

---

## ✨ Features

- **Single video or full playlist** support
- **Automatic transcription** using [faster-whisper](https://github.com/SYSTRAN/faster-whisper) (4× faster than openai-whisper on CPU)
- **Translation** to English (built-in Whisper) and/or Arabic with RTL formatting
- **Auto-detects `cookies.txt`** in the same directory for YouTube authentication
- **RAM check** before transcription to prevent out-of-memory crashes
- **Organized output folders** — audio, srt, and done
- **Interactive prompts** — no command-line flags to remember
- **Auto-installs** all dependencies on first run

---

## 🖥️ Requirements

| Requirement | Minimum |
|---|---|
| OS | Ubuntu 20.04+ |
| RAM | 2GB (4GB+ recommended) |
| Disk | 10GB free (models + audio) |
| Python | 3.9+ |
| Node.js | v18+ (for YouTube n-challenge solver) |

### Install Node.js (if not installed)
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
```

---

## 🚀 Setup

### 1. Download the script
```bash
wget -O urdu.sh https://your-host/urdu_transcribe.sh
chmod +x urdu.sh
```

### 2. Export YouTube cookies (required to bypass bot detection)

Install the **"Get cookies.txt LOCALLY"** extension in Chrome or Firefox:
- Chrome: [link](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
- Firefox: [link](https://addons.mozilla.org/en-US/firefox/addon/get-cookies-txt-locally/)

Then:
1. Go to [youtube.com](https://youtube.com) and make sure you're **logged in**
2. Click the extension icon → **Export** → save as `cookies.txt`
3. Place `cookies.txt` in the **same folder** as `urdu.sh`

```
/your-folder/
  urdu.sh
  cookies.txt       ← must be here
```

The script will detect and use it automatically.

---

## ▶️ Usage

```bash
bash urdu.sh
```

The script will walk you through 7 steps:

```
Step 1 — YouTube URL        (single video or playlist)
Step 2 — Authentication     (auto-uses cookies.txt if found)
Step 3 — Language           (default: Urdu)
Step 4 — Whisper Model      (tiny → large-v3)
Step 5 — Output Format      (SRT, TXT, VTT)
Step 6 — Translation        (none / English / Arabic / both)
Step 7 — Output Directory   (default: ~/urdu_transcripts)
```

---

## 📁 Output Structure

```
~/urdu_transcripts/
├── audio/          ← MP3 files (in progress)
├── srt/            ← SRT files (in progress)
└── done/           ← completed files (moved here after each video)
    ├── 1_VideoTitle.mp3
    ├── 1_VideoTitle.srt
    ├── 1_VideoTitle_en.srt   ← if English translation enabled
    ├── 1_VideoTitle_ar.srt   ← if Arabic translation enabled
    ├── 2_VideoTitle.mp3
    ├── 2_VideoTitle.srt
    └── ...
```

Files are moved to `done/` immediately after each video finishes, so you can access completed results while the rest of the playlist is still processing.

---

## 🤖 Whisper Models

| # | Model | Size | Speed | Accuracy | RAM needed |
|---|-------|------|-------|----------|------------|
| 1 | tiny | 75MB | ⚡⚡⚡⚡ | Low | ~400MB |
| 2 | base | 150MB | ⚡⚡⚡ | Decent | ~600MB |
| 3 | small | 500MB | ⚡⚡ | Good | ~1.2GB |
| 4 | medium | 1.5GB | ⚡ | Very good | ~3GB |
| 5 | large-v3-turbo | 1.6GB | ⚡⚡ | High | ~3.5GB ← recommended |
| 6 | large-v3 | 3GB | 🐢 | Best | ~5GB |

> **Recommended for 8GB RAM VPS:** `large-v3-turbo` — best balance of speed and accuracy.

Models are downloaded automatically on first use and cached at `~/.cache/huggingface/`.

---

## 🌐 Supported Transcription Languages

Type the full language name at the prompt — the script converts it to the correct code automatically.

| Type this | Code used |
|---|---|
| Urdu *(default)* | `ur` |
| Arabic | `ar` |
| English | `en` |
| Hindi | `hi` |
| Turkish | `tr` |
| Persian | `fa` |
| French | `fr` |
| Any other | Use the ISO 639-1 code directly (e.g. `ru`, `zh`, `de`) |

---

## 🔤 Translation

| Option | Engine | Output |
|---|---|---|
| English | Whisper built-in (`--task translate`) | Fast, high quality |
| Arabic | ArgosTranslate (`en→ar`) | Local, no API needed, RTL formatted |
| Both | English first, Arabic reuses it | No double Whisper run |

Arabic subtitles use Unicode RTL markers (`‫...‬`) for correct display in VLC, mpv, and most mobile players.

> **Note:** Arabic translation uses a two-hop pipeline: Urdu → English (Whisper) → Arabic (ArgosTranslate). This produces better results than direct Urdu→Arabic.

---

## 🔒 Running Long Jobs (Playlists)

For playlists, use `tmux` so the job keeps running if you disconnect from SSH:

```bash
# Install tmux
apt install tmux -y

# Start a named session
tmux new -s transcribe

# Run the script
bash urdu.sh

# Detach (keeps running in background)
# Press:  Ctrl+B  then  D

# Reattach later
tmux attach -t transcribe
```

---

## 🛠️ Dependencies

All installed automatically by the script on first run.

| Package | Purpose |
|---|---|
| `ffmpeg` | Audio processing |
| `nodejs` | YouTube n-challenge solver |
| `yt-dlp` | YouTube downloader |
| `faster-whisper` | Speech-to-text transcription |
| `argostranslate` | English→Arabic translation (only if Arabic selected) |

---

## ❗ Troubleshooting

### Download fails / bot detection
- Re-export `cookies.txt` from your browser (they expire)
- Make sure you're logged into YouTube when exporting
- Replace the old file on the server: `scp cookies.txt root@your-server:~/`

### Whisper process killed (OOM)
- Choose a smaller model (medium or small)
- Check available RAM: `free -h`

### `node` not found
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
```

### ArgosTranslate `en→ar` pack missing
```bash
python3 -c "
import argostranslate.package
argostranslate.package.update_package_index()
pkgs = argostranslate.package.get_available_packages()
pkg = next(p for p in pkgs if p.from_code=='en' and p.to_code=='ar')
argostranslate.package.install_from_path(pkg.download())
"
```

---

## 📄 License

MIT — free to use, modify, and distribute.
