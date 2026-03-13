# 🎙️ Urdu YouTube Transcriber + Translator

A **professional-grade CLI tool** that downloads YouTube videos or playlists, transcribes audio using **faster-whisper**, and optionally translates to **English** or **Arabic (RTL)**. Fully local — no API keys, no cloud services.

---

## ✨ Features

- ✅ **Single video or full playlist** support
- ✅ **Automatic transcription** using [faster-whisper](https://github.com/SYSTRAN/faster-whisper) (4× faster than openai-whisper on CPU)
- ✅ **Translation** to English (Whisper built-in) and/or Arabic with RTL formatting
- ✅ **CLI-style interface** with flags (like SQLMap) — no interactive prompts
- ✅ **Runs in background by default** with automatic logging
- ✅ **Auto-detects `cookies.txt`** for YouTube authentication
- ✅ **RAM check** before transcription to prevent crashes
- ✅ **Auto-delete audio files** after transcription (saves disk space)
- ✅ **Organized output** by URL (video/playlist ID)
- ✅ **Auto-installs** all dependencies on first run
- ✅ **Professional logging** to files or console

---

## 🖥️ Requirements

| Requirement | Minimum |
|---|---|
| OS | Ubuntu 20.04+ (Linux) |
| RAM | 2GB (4GB+ recommended) |
| Disk | 10GB free (for models + processing) |
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
git clone https://github.com/0xSm0ky/urdu-youTube-transcriber.git
cd urdu-youTube-transcriber
chmod +x urdu.sh
```

Or directly:
```bash
wget -O urdu.sh https://raw.githubusercontent.com/0xSm0ky/urdu-youTube-transcriber/main/urdu.sh
chmod +x urdu.sh
```

### 2. Export YouTube cookies (required to bypass bot detection)

**Install the extension:**
- Chrome: [Get cookies.txt LOCALLY](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
- Firefox: [Get cookies.txt LOCALLY](https://addons.mozilla.org/en-US/firefox/addon/get-cookies-txt-locally/)

**Export cookies:**
1. Go to [youtube.com](https://youtube.com) and **log in**
2. Click extension icon → **Export** → save as `cookies.txt`
3. Place `cookies.txt` in the **same folder** as `urdu.sh`

```
/your-folder/
  urdu.sh
  cookies.txt       ← required
```

The script auto-detects and uses it.

---

## 💻 Usage

### Show Help
```bash
./urdu.sh -h
```

### Simplest Usage (Runs in background, logs to `/tmp/urdu_transcribe.log`)
```bash
./urdu.sh -u "https://www.youtube.com/watch?v=abc123"
```

---

## 📚 CLI Flags

### Required Flags
- **`-u, --url <URL>`** — YouTube video or playlist URL

### Optional Flags

| Flag | Long | Argument | Default | Description |
|------|------|----------|---------|-------------|
| `-m` | `--model` | 1-6 | 5 | Whisper model (see table below) |
| `-l` | `--language` | Name | Urdu | Transcription language |
| `-f` | `--format` | 1-4 | 1 | Output format (1=SRT, 2=TXT, 3=SRT+TXT, 4=VTT) |
| `-t` | `--translate` | 1-4 | 1 | Translation (1=none, 2=EN, 3=AR, 4=both) |
| `-o` | `--output` | Path | ~/urdu_transcripts/data | Output directory |
| `-c` | `--cookies` | Path | auto-detect | Custom cookies.txt path |
| `-F` | `--foreground` | — | false | Run in foreground (no background) |
| `-L` | `--log` | Path | /tmp/urdu_transcribe.log | Log file path |
| `-v` | `--verbose` | — | false | Verbose output |
| `-h` | `--help` | — | — | Show help menu |

---

## 🎯 Usage Examples

### Single Video → SRT (Default Settings)
```bash
./urdu.sh -u "https://youtu.be/abc123"
```

### Single Video + English Translation
```bash
./urdu.sh -u "https://youtu.be/abc123" -t 2
```

### Playlist + Both English & Arabic
```bash
./urdu.sh -u "https://www.youtube.com/playlist?list=xyz789" -t 4
```

### Custom Output Directory
```bash
./urdu.sh -u "https://youtu.be/abc123" -o /mnt/transcripts
```

### High-Quality Model (Slow but Best Accuracy)
```bash
./urdu.sh -u "https://youtu.be/abc123" -m 6
```

### Different Language (Arabic)
```bash
./urdu.sh -u "https://youtu.be/abc123" -l Arabic
```

### Different Output Format (VTT for web)
```bash
./urdu.sh -u "https://youtu.be/abc123" -f 4
```

### Run in Foreground (See live output)
```bash
./urdu.sh -u "https://youtu.be/abc123" -F
```

### Custom Log File
```bash
./urdu.sh -u "https://youtu.be/abc123" -L /var/log/transcriptions.log
```

### Everything Combined
```bash
./urdu.sh -u "https://www.youtube.com/playlist?list=xyz" \
  -m 5 \
  -l Urdu \
  -f 1 \
  -t 4 \
  -o /mnt/transcripts \
  -L /var/log/transcribe.log
```

---

## 🔄 Background Job Management

### Check running jobs
```bash
ps aux | grep urdu.sh
```

### Monitor logs in real-time
```bash
tail -f /tmp/urdu_transcribe.log
```

### Kill a job
```bash
pkill -f "urdu.sh"
```

### View completed log
```bash
cat /tmp/urdu_transcribe.log
```

---

## 📁 Output Structure

Files are organized by URL with separate audio and srt folders. **Audio files are automatically deleted after successful transcription** to save disk space.

```
~/urdu_transcripts/data/
├── audio/
│   ├── tmp/                              ← temp downloads (deleted)
│   ├── video_abc123/                     ← organized by video ID
│   │   └── 1_VideoTitle.mp3              ← deleted after transcription ✓
│   └── playlist_xyz789/                  ← organized by playlist ID
│       ├── 1_VideoTitle.mp3              ← deleted after transcription ✓
│       └── 2_OtherVideo.mp3              ← deleted after transcription ✓
└── srt/
    ├── video_abc123/
    │   ├── 1_VideoTitle.srt              ← KEPT
    │   ├── 1_VideoTitle_en.srt           ← KEPT (if English enabled)
    │   └── 1_VideoTitle_ar.srt           ← KEPT (if Arabic enabled)
    └── playlist_xyz789/
        ├── 1_VideoTitle.srt              ← KEPT
        ├── 1_VideoTitle_en.srt
        ├── 1_VideoTitle_ar.srt
        └── 2_OtherVideo.srt
```

**How it works:**
1. Audio downloads to `audio/tmp/`
2. Transcription happens
3. Audio file **automatically deleted** 🗑️ (saves 50-100MB per video)
4. Subtitle files saved to `srt/{URL_FOLDER}/`
5. Multiple runs with same URL add to same folder (no duplicates)

---

## 🤖 Whisper Models

Choose based on your **RAM availability** and **speed vs accuracy** preference.

| # | Model | Size | Speed | Accuracy | RAM needed | Best For |
|---|-------|------|-------|----------|------------|----------|
| 1 | tiny | 75MB | ⚡⚡⚡⚡ | Low | ~400MB | Testing |
| 2 | base | 150MB | ⚡⚡⚡ | Decent | ~600MB | Quick runs |
| 3 | small | 500MB | ⚡⚡ | Good | ~1.2GB | **Balance** |
| 4 | medium | 1.5GB | ⚡ | Very good | ~3GB | Long videos |
| 5 | large-v3-turbo | 1.6GB | ⚡⚡ | High | ~3.5GB | **Recommended** |
| 6 | large-v3 | 3GB | 🐢 | Best | ~5GB | Critical accuracy |

Models auto-download on first use and cache at `~/.cache/huggingface/`.

---

## 🌐 Supported Languages

Type the full language name — the script converts it to language code automatically.

| Language | Type This |
|----------|-----------|
| Urdu | `Urdu` (default) |
| Arabic | `Arabic` |
| English | `English` |
| Hindi | `Hindi` |
| Turkish | `Turkish` |
| Persian | `Persian` |
| French | `French` |
| Russian | `Russian` |
| Chinese | `Chinese` |
| Japanese | `Japanese` |
| Korean | `Korean` |
| Spanish | `Spanish` |
| *Any other* | Use ISO 639-1 code (e.g., `ru`, `de`, `pt`) |

---

## 🔤 Translation

| Option | Engine | Output | Speed |
|--------|--------|--------|-------|
| English | Whisper built-in (`--task translate`) | High quality | Fast |
| Arabic | ArgosTranslate (`en→ar`) | Local, RTL formatted | Fast |
| Both | English first, Arabic reuses it | No double run | Fast |

**Note:** Arabic uses two-hop pipeline: Urdu → English (Whisper) → Arabic (ArgosTranslate).

---

## 📊 Advanced Examples

### Batch Processing Multiple Videos
```bash
#!/bin/bash

VIDEOS=(
  "https://www.youtube.com/watch?v=video1"
  "https://www.youtube.com/watch?v=video2"
  "https://www.youtube.com/watch?v=video3"
)

for URL in "${VIDEOS[@]}"; do
  ./urdu.sh -u "$URL" -t 4
  sleep 2
done

# Monitor all
tail -f /tmp/urdu_transcribe.log
```

### Process in Parallel
```bash
# Run all simultaneously
for URL in "url1" "url2" "url3"; do
  ./urdu.sh -u "$URL" -m 3 &
done
wait  # Wait for all to finish
```

### Speed-Optimized (Fastest)
```bash
./urdu.sh -u "https://youtu.be/short_clip" -m 1
```

### Accuracy-Optimized (Best Quality)
```bash
./urdu.sh -u "https://youtu.be/important_speech" -m 6 -t 4 -F
```

### Organize by Project
```bash
./urdu.sh -u "https://youtu.be/abc123" -o ~/projects/myproject/transcripts
```

---

## 🛠️ Dependencies

**Auto-installed on first run:**

| Package | Purpose |
|---------|---------|
| `ffmpeg` | Audio processing |
| `nodejs` | YouTube n-challenge solver |
| `yt-dlp` | YouTube downloader |
| `faster-whisper` | Speech-to-text transcription |
| `argostranslate` | English→Arabic translation (if Arabic selected) |

---

## ❗ Troubleshooting

### Download fails / Bot detection
- Re-export `cookies.txt` from your browser (they expire)
- Make sure you're **logged into YouTube** when exporting
- Replace old file: `cp cookies.txt ./urdu.sh` directory

### Whisper process killed (Out of Memory)
- Choose a **smaller model** (medium or small)
- Check available RAM: `free -h`
- Close other applications

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

### Permission denied when running
```bash
chmod +x urdu.sh
```

### Job stops after terminal closes (if using -F)
Use without `-F` flag (runs in background by default):
```bash
./urdu.sh -u "https://youtu.be/abc123"
```

Or use `nohup` explicitly:
```bash
nohup ./urdu.sh -u "https://youtu.be/abc123" -F > log.txt 2>&1 &
```

---

## 📋 Quick Reference

| Task | Command |
|------|---------|
| Show help | `./urdu.sh -h` |
| Single video | `./urdu.sh -u "URL"` |
| With English | `./urdu.sh -u "URL" -t 2` |
| With both languages | `./urdu.sh -u "URL" -t 4` |
| Fast (small model) | `./urdu.sh -u "URL" -m 3` |
| Accurate (large model) | `./urdu.sh -u "URL" -m 6` |
| Custom output | `./urdu.sh -u "URL" -o /path` |
| Check jobs | `ps aux \| grep urdu.sh` |
| Monitor log | `tail -f /tmp/urdu_transcribe.log` |
| Kill job | `pkill -f "urdu.sh"` |

---

## 🚀 Pro Tips

1. **Always check help first:** `./urdu.sh -h`
2. **Start with model 5** (large-v3-turbo) — best balance
3. **For playlists, use smaller model** (model 3) to save time
4. **Monitor with:** `tail -f /tmp/urdu_transcribe.log`
5. **Batch mode:** Run multiple with `&` in background
6. **Save cookies once** — they're auto-detected
7. **Audio auto-deletes** — only SRT files kept
8. **Logs are kept** — check them for debugging

---

## 🤝 Contributing

Found a bug or have a feature request? Open an issue on [GitHub](https://github.com/0xSm0ky/urdu-youTube-transcriber/issues).

---

## 📄 License

MIT License — Free to use, modify, and distribute.

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/0xSm0ky/urdu-youTube-transcriber/issues)
- **Discussions:** [GitHub Discussions](https://github.com/0xSm0ky/urdu-youTube-transcriber/discussions)

---

**Made with ❤️ for Urdu content creators**
