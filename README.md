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

### 🎯 Interactive Mode (Default)
```bash
bash urdu.sh
```

The script will walk you through 7 steps interactively:

```
Step 1 — YouTube URL        (single video or playlist)
Step 2 — Authentication     (auto-uses cookies.txt if found)
Step 3 — Language           (default: Urdu)
Step 4 — Whisper Model      (tiny → large-v3)
Step 5 — Output Format      (SRT, TXT, VTT)
Step 6 — Translation        (none / English / Arabic / both)
Step 7 — Output Directory   (default: ~/urdu_transcripts)
```

### 🚀 Command-Line Mode (Non-Interactive)

For automation and background execution, pass arguments directly:

```bash
bash urdu.sh "URL" "MODEL" "LANGUAGE" "FORMAT" "TRANSLATE" "OUTPUT_DIR"
```

**Parameters:**

| # | Parameter | Values | Default | Description |
|---|-----------|--------|---------|-------------|
| 1 | **URL** | YouTube link | Required | Video or playlist URL |
| 2 | **MODEL** | 1-6 | 5 | `1=tiny, 2=base, 3=small, 4=medium, 5=large-v3-turbo, 6=large-v3` |
| 3 | **LANGUAGE** | Language name | Urdu | `Urdu, Arabic, English, French, Hindi, Turkish, Persian, Russian, Chinese, Japanese, Korean, Spanish` |
| 4 | **FORMAT** | 1-4 | 1 | `1=SRT, 2=TXT, 3=SRT+TXT, 4=VTT` |
| 5 | **TRANSLATE** | 1-4 | 1 | `1=No translation, 2=English only, 3=Arabic only, 4=Both` |
| 6 | **OUTPUT_DIR** | Path | `~/urdu_transcripts/data` | Where files are saved (optional) |

#### Examples:

**Single video with SRT only:**
```bash
bash urdu.sh "https://www.youtube.com/watch?v=abc123" "5" "Urdu" "1" "1"
```

**Playlist with English translation:**
```bash
bash urdu.sh "https://www.youtube.com/playlist?list=xyz789" "5" "Urdu" "1" "2"
```

**Both English & Arabic, custom output:**
```bash
bash urdu.sh "https://www.youtube.com/watch?v=abc123" "5" "Urdu" "1" "4" "/mnt/transcripts"
```

### 🔄 Run in Background

#### Using `nohup` (Recommended — continues if terminal closes):
```bash
nohup bash urdu.sh "https://www.youtube.com/watch?v=abc123" "5" "Urdu" "1" "4" > /tmp/transcript.log 2>&1 &
```

#### Using `screen` (Detachable session):
```bash
screen -S transcribe -d -m bash urdu.sh "https://www.youtube.com/watch?v=abc123" "5" "Urdu" "1" "4"
# Reattach with: screen -r transcribe
```

#### Monitor progress:
```bash
tail -f /tmp/transcript.log
```

### 📜 Batch Processing Multiple Videos

Create a script `batch.sh`:
```bash
#!/bin/bash

VIDEOS=(
  "https://www.youtube.com/watch?v=video1"
  "https://www.youtube.com/watch?v=video2"
  "https://www.youtube.com/watch?v=video3"
)

for URL in "${VIDEOS[@]}"; do
  echo "Processing: $URL"
  nohup bash urdu.sh "$URL" "5" "Urdu" "1" "4" >> /tmp/batch.log 2>&1 &
  sleep 5  # Wait 5 seconds between submissions
done

echo "All jobs submitted!"
```

Run it:
```bash
bash batch.sh
```

---

## 📁 Output Structure

Files are organized by **URL** (video or playlist) with separate **audio** and **srt** folders:

```
~/urdu_transcripts/data/
├── audio/
│   ├── tmp/                              ← temporary downloads while processing
│   ├── video_abc123/                     ← organized by video ID
│   │   ├── 1_VideoTitle.mp3
│   │   └── 2_OtherVideo.mp3
│   └── playlist_xyz789/                  ← organized by playlist ID
│       ├── 1_VideoTitle.mp3
│       ├── 2_OtherVideo.mp3
│       └── 3_AnotherVideo.mp3
└── srt/
    ├── video_abc123/
    │   ├── 1_VideoTitle.srt
    │   ├── 1_VideoTitle_en.srt           ← if English translation enabled
    │   └── 1_VideoTitle_ar.srt           ← if Arabic translation enabled
    └── playlist_xyz789/
        ├── 1_VideoTitle.srt
        ├── 1_VideoTitle_en.srt
        ├── 1_VideoTitle_ar.srt
        ├── 2_OtherVideo.srt
        └── ...
```

**How it works:**
1. Audio downloads to `audio/tmp/` while processing
2. Transcription happens for the audio file
3. After successful transcription, audio moves from `tmp/` to `audio/{URL_FOLDER}/`
4. All subtitle files go directly to `srt/{URL_FOLDER}/`
5. Multiple runs with the same URL add to the same folder — no duplicates!

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

## 📋 Quick Reference

| Use Case | Command |
|----------|---------|
| **Interactive setup** | `bash urdu.sh` |
| **Single video → SRT** | `bash urdu.sh "URL" "5" "Urdu" "1" "1"` |
| **Single video → SRT + English** | `bash urdu.sh "URL" "5" "Urdu" "1" "2"` |
| **Playlist → SRT + English + Arabic** | `bash urdu.sh "URL" "5" "Urdu" "1" "4"` |
| **Background with logging** | `nohup bash urdu.sh "URL" "5" "Urdu" "1" "4" > log.txt 2>&1 &` |
| **Monitor progress** | `tail -f log.txt` |
| **List running jobs** | `ps aux \| grep urdu.sh` |
| **Kill job** | `pkill -f "bash urdu.sh"` |

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
