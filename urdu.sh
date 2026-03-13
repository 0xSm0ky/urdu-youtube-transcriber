#!/bin/bash

# ═══════════════════════════════════════════════════════
#  Urdu YouTube Transcriber + Translator
#  faster-whisper (4x faster than openai-whisper on CPU)
#  Supports: single video & playlists
#  Outputs:  Urdu SRT + English SRT + Arabic RTL SRT
# ═══════════════════════════════════════════════════════

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
err()     { echo -e "${RED}[✘]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"; }

# ───────────────────────────────────────────────────────
#  USAGE & HELP
# ───────────────────────────────────────────────────────
usage() {
  cat << 'EOF'

  ╔═══════════════════════════════════════════════════════════════════╗
  ║          Urdu YouTube Transcriber 🎙️ CLI Tool                     ║
  ║       faster-whisper + yt-dlp + ArgosTranslate                   ║
  ╚═══════════════════════════════════════════════════════════════════╝

USAGE:
  urdu.sh -u <URL> [OPTIONS]

REQUIRED FLAGS:
  -u, --url <URL>           YouTube video or playlist URL

OPTIONAL FLAGS:
  -m, --model <1-6>         Whisper model (default: 5)
                            1=tiny, 2=base, 3=small, 4=medium
                            5=large-v3-turbo, 6=large-v3
  
  -l, --language <LANG>     Transcription language (default: Urdu)
                            Urdu, Arabic, English, French, Hindi, Turkish, Persian, etc.
  
  -f, --format <1-4>        Output format (default: 1)
                            1=SRT, 2=TXT, 3=SRT+TXT, 4=VTT
  
  -t, --translate <1-4>     Translation (default: 1)
                            1=No translation, 2=English only
                            3=Arabic only, 4=Both
  
  -o, --output <PATH>       Output directory (default: ~/urdu_transcripts/data)
  
  -c, --cookies <PATH>      Path to cookies.txt (auto-detects in script dir)
  
  -F, --foreground          Run in foreground (default: background)
  
  -L, --log <PATH>          Log file path (default: /tmp/urdu_transcribe.log)
  
  -h, --help                Show this help message
  
  -v, --verbose             Enable verbose output

EXAMPLES:
  # Single video with default settings (runs in background)
  urdu.sh -u "https://www.youtube.com/watch?v=abc123"
  
  # Playlist with English translation
  urdu.sh -u "https://www.youtube.com/playlist?list=xyz" -t 2
  
  # Both languages, large model, foreground mode
  urdu.sh -u "https://youtu.be/abc123" -m 6 -t 4 -F
  
  # Custom output folder with logging
  urdu.sh -u "https://youtu.be/abc123" -o /mnt/transcripts -L /var/log/transcribe.log
  
  # Monitor background job
  tail -f /tmp/urdu_transcribe.log

EOF
  exit 0
}

# ───────────────────────────────────────────────────────
#  PARSE COMMAND-LINE FLAGS
# ───────────────────────────────────────────────────────
URL=""
MODEL_CHOICE="5"
LANG_INPUT="Urdu"
FORMAT_CHOICE="1"
TRANS_CHOICE="1"
CUSTOM_DIR=""
COOKIES_PATH=""
FOREGROUND=false
LOG_FILE="/tmp/urdu_transcribe.log"
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)
      URL="$2"
      shift 2
      ;;
    -m|--model)
      MODEL_CHOICE="$2"
      shift 2
      ;;
    -l|--language)
      LANG_INPUT="$2"
      shift 2
      ;;
    -f|--format)
      FORMAT_CHOICE="$2"
      shift 2
      ;;
    -t|--translate)
      TRANS_CHOICE="$2"
      shift 2
      ;;
    -o|--output)
      CUSTOM_DIR="$2"
      shift 2
      ;;
    -c|--cookies)
      COOKIES_PATH="$2"
      shift 2
      ;;
    -F|--foreground)
      FOREGROUND=true
      shift
      ;;
    -L|--log)
      LOG_FILE="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}[✘] Unknown option: $1${NC}" >&2
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# ───────────────────────────────────────────────────────
#  VALIDATE REQUIRED FLAGS
# ───────────────────────────────────────────────────────
[ -z "$URL" ] && err "Required flag -u/--url not provided. Use -h for help."

# ───────────────────────────────────────────────────────
#  RUN IN BACKGROUND BY DEFAULT (unless -F flag set)
# ───────────────────────────────────────────────────────
if [ "$FOREGROUND" = false ] && [ -t 1 ]; then
  # Not in foreground and connected to terminal, run in background
  nohup "$0" -u "$URL" -m "$MODEL_CHOICE" -l "$LANG_INPUT" -f "$FORMAT_CHOICE" \
         -t "$TRANS_CHOICE" -o "$CUSTOM_DIR" -c "$COOKIES_PATH" -L "$LOG_FILE" -F > "$LOG_FILE" 2>&1 &
  BG_PID=$!
  sleep 0.2
  echo -e "${GREEN}[✔] Job started in background${NC}"
  echo -e "${GREEN}    PID: $BG_PID${NC}"
  echo -e "${GREEN}    Log: $LOG_FILE${NC}"
  echo -e "${GREEN}${BOLD}Monitor with: tail -f $LOG_FILE${NC}"
  exit 0
fi

# ───────────────────────────────────────────────────────
#  BANNER
# ───────────────────────────────────────────────────────
if [ "$FOREGROUND" = true ]; then
  clear
  echo -e "${CYAN}${BOLD}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║     Urdu YouTube Transcriber 🎙️            ║"
  echo "  ║  faster-whisper + yt-dlp + ArgosTranslate ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${NC}"
fi

# ───────────────────────────────────────────────────────
#  SETUP LOGGING
# ───────────────────────────────────────────────────────
if [ "$FOREGROUND" = false ]; then
  # Redirect output to log file
  exec > >(tee -a "$LOG_FILE")
  exec 2>&1
  echo "=== Urdu YouTube Transcriber Started ===" >> "$LOG_FILE"
  echo "Time: $(date)" >> "$LOG_FILE"
  echo "URL: $URL" >> "$LOG_FILE"
  echo "Model: $MODEL_CHOICE, Format: $FORMAT_CHOICE, Translate: $TRANS_CHOICE" >> "$LOG_FILE"
fi

# ───────────────────────────────────────────────────────
#  SANITIZE URL FOR FOLDER NAME (Windows + Linux safe)
# ───────────────────────────────────────────────────────
sanitize_folder_name() {
  local name="$1"
  echo "$name" | tr -cd '[:alnum:]_-' | cut -c1-100
}

# Extract URL identifier (playlist ID or video ID)
if [[ "$URL" =~ list=([a-zA-Z0-9_-]+) ]]; then
  URL_ID="${BASH_REMATCH[1]}"
  URL_TYPE="playlist"
elif [[ "$URL" =~ v=([a-zA-Z0-9_-]+) ]]; then
  URL_ID="${BASH_REMATCH[1]}"
  URL_TYPE="video"
else
  URL_ID=$(echo "$URL" | md5sum | cut -c1-12)
  URL_TYPE="unknown"
fi

URL_FOLDER_NAME="$(sanitize_folder_name "${URL_TYPE}_${URL_ID}")"
log "URL Folder Name: $URL_FOLDER_NAME"

# ───────────────────────────────────────────────────────
#  HANDLE COOKIES
# ───────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_COOKIES="$SCRIPT_DIR/cookies.txt"
COOKIES_ARG=""

if [ -n "$COOKIES_PATH" ] && [ -f "$COOKIES_PATH" ]; then
  COOKIES_ARG="--cookies $COOKIES_PATH"
  log "Cookies loaded: $COOKIES_PATH"
elif [ -f "$AUTO_COOKIES" ]; then
  COOKIES_ARG="--cookies $AUTO_COOKIES"
  log "cookies.txt found — using automatically ✅"
else
  warn "No cookies.txt found (will try without authentication)"
fi

# ───────────────────────────────────────────────────────
#  PROCESS OPTIONS
# ───────────────────────────────────────────────────────
log "Configuration:"
log "  Language: $LANG_INPUT"
log "  Model: $MODEL_CHOICE"
log "  Format: $FORMAT_CHOICE"
log "  Translate: $TRANS_CHOICE"
[ "$FOREGROUND" = true ] && log "  Mode: Foreground" || log "  Mode: Background"

# Language processing
LANG_NAME="${LANG_INPUT:-Urdu}"
declare -A LANG_CODES=([urdu]="ur" [arabic]="ar" [english]="en" [french]="fr" [hindi]="hi" [turkish]="tr" [persian]="fa" [russian]="ru" [chinese]="zh" [japanese]="ja" [korean]="ko" [spanish]="es")
LANG_KEY="${LANG_NAME,,}"
TRANSCRIBE_LANG="${LANG_CODES[$LANG_KEY]:-$LANG_KEY}"

# Model selection
case "$MODEL_CHOICE" in
  1) MODEL="tiny" ;;
  2) MODEL="base" ;;
  3) MODEL="small" ;;
  4) MODEL="medium" ;;
  6) MODEL="large-v3" ;;
  *) MODEL="large-v3-turbo" ;;
esac

# Format selection
case "$FORMAT_CHOICE" in
  2) FORMATS=("txt") ;;
  3) FORMATS=("srt" "txt") ;;
  4) FORMATS=("vtt") ;;
  *) FORMATS=("srt") ;;
esac

# Translation selection
TRANSLATE_EN=false
TRANSLATE_AR=false
case "$TRANS_CHOICE" in
  2) TRANSLATE_EN=true ;;
  3) TRANSLATE_AR=true ;;
  4) TRANSLATE_EN=true; TRANSLATE_AR=true ;;
esac

if $TRANSLATE_EN; then log "  English translation: enabled"; fi
if $TRANSLATE_AR; then log "  Arabic translation: enabled (RTL)"; fi

# ───────────────────────────────────────────────────────
#  SETUP OUTPUT DIRECTORIES
# ───────────────────────────────────────────────────────
BASE_OUTPUT_DIR="${CUSTOM_DIR:-$HOME/urdu_transcripts/data}"
log "Output directory: $BASE_OUTPUT_DIR"

AUDIO_FOLDER="$BASE_OUTPUT_DIR/audio"
SRT_FOLDER="$BASE_OUTPUT_DIR/srt"
AUDIO_TEMP_DIR="$AUDIO_FOLDER/tmp"
AUDIO_URL_DIR="$AUDIO_FOLDER/$URL_FOLDER_NAME"
SRT_URL_DIR="$SRT_FOLDER/$URL_FOLDER_NAME"

mkdir -p "$AUDIO_TEMP_DIR" || err "Failed to create $AUDIO_TEMP_DIR"
mkdir -p "$AUDIO_URL_DIR" || err "Failed to create $AUDIO_URL_DIR"
mkdir -p "$SRT_URL_DIR" || err "Failed to create $SRT_URL_DIR"

log "Output structure created:"
log "  � Audio (temp): $AUDIO_TEMP_DIR"
log "  � Audio (done): $AUDIO_URL_DIR"
log "  📁 Subtitles  : $SRT_URL_DIR"

# ───────────────────────────────────────────────────────
#  INSTALL DEPENDENCIES
# ───────────────────────────────────────────────────────
section "Installing Dependencies"

apt-get install -y ffmpeg -qq

# Node.js for yt-dlp n-challenge solver
if ! command -v node &>/dev/null; then
  apt-get install -y nodejs -qq
fi
log "ffmpeg + node $(node --version) ready."

# faster-whisper: 4x faster than openai-whisper on CPU
pip install -q --upgrade "yt-dlp[default]" faster-whisper --break-system-packages
log "yt-dlp + faster-whisper ready."

# ArgosTranslate only if Arabic translation needed
if $TRANSLATE_AR; then
  pip install -q argostranslate --break-system-packages
  log "ArgosTranslate installed."
  # Install en→ar language pack if not already present
  python3 -c "
import argostranslate.package, argostranslate.translate
installed = [str(p) for p in argostranslate.translate.get_installed_languages()]
if not any('Arabic' in p for p in installed):
    print('Downloading en→ar language pack...')
    argostranslate.package.update_package_index()
    pkgs = argostranslate.package.get_available_packages()
    pkg = next((p for p in pkgs if p.from_code == 'en' and p.to_code == 'ar'), None)
    if pkg:
        argostranslate.package.install_from_path(pkg.download())
        print('en→ar pack installed.')
    else:
        print('Warning: en→ar pack not found.')
else:
    print('en→ar pack already installed.')
"
fi

# ───────────────────────────────────────────────────────
#  yt-dlp ARGS — node + EJS solver for n-challenge
# ───────────────────────────────────────────────────────
BASE_YTDLP_ARGS="--js-runtimes node --remote-components ejs:github --extractor-args youtube:player_client=web $COOKIES_ARG"

# ───────────────────────────────────────────────────────
#  DETECT PLAYLIST vs SINGLE
# ───────────────────────────────────────────────────────
section "Fetching Video Info"
VIDEO_COUNT=$(yt-dlp --flat-playlist --get-id $BASE_YTDLP_ARGS "$URL" 2>/dev/null | wc -l)

if [ "$VIDEO_COUNT" -gt 1 ]; then
  echo -e "  ${CYAN}Playlist detected:${NC} $VIDEO_COUNT videos found."
  PLAYLIST_MODE=true
else
  echo -e "  ${CYAN}Single video detected.${NC}"
  PLAYLIST_MODE=false
fi

# ───────────────────────────────────────────────────────
#  TRANSCRIBE FUNCTION (faster-whisper)
# ───────────────────────────────────────────────────────
transcribe_audio() {
  local AUDIO_FILE="$1"
  local OUT_NAME="$2"

  # Validate input file exists
  [ ! -f "$AUDIO_FILE" ] && err "Audio file not found: $AUDIO_FILE"

  # RAM check
  AVAILABLE_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  declare -A MODEL_RAM=([tiny]=400 [base]=600 [small]=1200 [medium]=3000 [large-v3-turbo]=3500 [large-v3]=5000)
  REQUIRED_MB=${MODEL_RAM[$MODEL]:-3000}
  if [ "$AVAILABLE_MB" -lt "$REQUIRED_MB" ]; then
    warn "⚠️  Low RAM: ${AVAILABLE_MB}MB available, $MODEL needs ~${REQUIRED_MB}MB"
    read -rp "   Continue anyway? [y/N]: " RAMCONTINUE
    [[ "$RAMCONTINUE" != "y" && "$RAMCONTINUE" != "Y" ]] && err "Aborted. Re-run and pick a smaller model."
  else
    log "RAM OK: ${AVAILABLE_MB}MB available (need ~${REQUIRED_MB}MB)"
  fi

  for FMT in "${FORMATS[@]}"; do
    local EXT="$FMT"
    local OUT_FILE="$SRT_URL_DIR/${OUT_NAME}.${EXT}"

    # faster-whisper via python — uses int8 quantization for max CPU speed
    python3 << PYEOF || err "Transcription failed"
from faster_whisper import WhisperModel
import sys

try:
    model = WhisperModel("$MODEL", device="cpu", compute_type="int8", cpu_threads=2)
    segments, info = model.transcribe(
        "$AUDIO_FILE",
        language="${TRANSCRIBE_LANG}",
        beam_size=5,
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=500)
    )

    def fmt_time(s):
        h = int(s // 3600)
        m = int((s % 3600) // 60)
        sec = s % 60
        return f"{h:02}:{m:02}:{sec:06.3f}".replace('.', ',')

    segments = list(segments)
    if not segments:
        print(f"Warning: No speech detected in audio", file=sys.stderr)
        sys.exit(0)

    if "$FMT" == "srt":
        with open("$OUT_FILE", "w", encoding="utf-8") as f:
            for i, seg in enumerate(segments, 1):
                f.write(f"{i}\n{fmt_time(seg.start)} --> {fmt_time(seg.end)}\n{seg.text.strip()}\n\n")
    elif "$FMT" == "txt":
        with open("$OUT_FILE", "w", encoding="utf-8") as f:
            for seg in segments:
                f.write(seg.text.strip() + "\n")
    elif "$FMT" == "vtt":
        with open("$OUT_FILE", "w", encoding="utf-8") as f:
            f.write("WEBVTT\n\n")
            for seg in segments:
                f.write(f"{fmt_time(seg.start).replace(',','.')} --> {fmt_time(seg.end).replace(',','.')}\n{seg.text.strip()}\n\n")

    print(f"✓ Transcription saved: $OUT_FILE")

except Exception as e:
    print(f"ERROR: {str(e)}", file=sys.stderr)
    sys.exit(1)
PYEOF

    [ -f "$OUT_FILE" ] && log "Saved: $OUT_FILE"
  done

  # ── English translation (Whisper built-in) ──
  if $TRANSLATE_EN; then
    local EN_FILE="$SRT_URL_DIR/${OUT_NAME}_en.srt"

    python3 << PYEOF || warn "English translation failed"
from faster_whisper import WhisperModel

try:
    model = WhisperModel("$MODEL", device="cpu", compute_type="int8", cpu_threads=2)
    segments, _ = model.transcribe(
        "$AUDIO_FILE",
        language="${TRANSCRIBE_LANG}",
        task="translate",
        beam_size=5,
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=500)
    )

    def fmt_time(s):
        h = int(s // 3600)
        m = int((s % 3600) // 60)
        sec = s % 60
        return f"{h:02}:{m:02}:{sec:06.3f}".replace('.', ',')

    with open("$EN_FILE", "w", encoding="utf-8") as f:
        for i, seg in enumerate(list(segments), 1):
            f.write(f"{i}\n{fmt_time(seg.start)} --> {fmt_time(seg.end)}\n{seg.text.strip()}\n\n")

    print(f"✓ English translation saved: $EN_FILE")
except Exception as e:
    print(f"ERROR: {str(e)}", file=sys.stderr)
PYEOF
    [ -f "$EN_FILE" ] && log "Saved (EN): $EN_FILE"
  fi

  # ── Arabic translation (RTL) ──
  if $TRANSLATE_AR; then
    local AR_FILE="$SRT_URL_DIR/${OUT_NAME}_ar.srt"
    local TEMP_EN_FILE="/tmp/${OUT_NAME}_temp_en_$RANDOM.srt"

    CLEANUP_TEMP=true
    if $TRANSLATE_EN && [ -f "$SRT_URL_DIR/${OUT_NAME}_en.srt" ]; then
      TEMP_EN_FILE="$SRT_URL_DIR/${OUT_NAME}_en.srt"
      CLEANUP_TEMP=false
    else
      python3 << PYEOF || { warn "Failed to generate English for Arabic translation"; return; }
from faster_whisper import WhisperModel

try:
    model = WhisperModel("$MODEL", device="cpu", compute_type="int8", cpu_threads=2)
    segments, _ = model.transcribe(
        "$AUDIO_FILE",
        language="${TRANSCRIBE_LANG}",
        task="translate",
        beam_size=5,
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=500)
    )

    def fmt_time(s):
        h = int(s // 3600)
        m = int((s % 3600) // 60)
        sec = s % 60
        return f"{h:02}:{m:02}:{sec:06.3f}".replace('.', ',')

    with open("$TEMP_EN_FILE", "w", encoding="utf-8") as f:
        for i, seg in enumerate(list(segments), 1):
            f.write(f"{i}\n{fmt_time(seg.start)} --> {fmt_time(seg.end)}\n{seg.text.strip()}\n\n")
except Exception as e:
    print(f"ERROR: {str(e)}", file=sys.stderr)
PYEOF
    fi

    python3 << PYEOF || { warn "Arabic translation failed"; [ "$CLEANUP_TEMP" = "true" ] && rm -f "$TEMP_EN_FILE"; return; }
import argostranslate.translate

try:
    langs = argostranslate.translate.get_installed_languages()
    en_lang = next((l for l in langs if l.code == 'en'), None)
    ar_lang = next((l for l in langs if l.code == 'ar'), None)
    
    if not en_lang or not ar_lang:
        raise Exception("Arabic language pack not installed")
    
    translator = en_lang.get_translation(ar_lang)

    RTL_START = '\u202B'
    RTL_END   = '\u202C'

    with open("$TEMP_EN_FILE", "r", encoding="utf-8") as f:
        content = f.read()

    blocks = content.strip().split('\n\n')
    out_lines = []

    for block in blocks:
        lines = block.strip().split('\n')
        if len(lines) < 3:
            out_lines.append(block)
            continue
        idx      = lines[0]
        timing   = lines[1]
        text_en  = ' '.join(lines[2:])
        text_ar  = translator.translate(text_en)
        text_ar_rtl = f"{RTL_START}{text_ar}{RTL_END}"
        out_lines.append(f"{idx}\n{timing}\n{text_ar_rtl}")

    with open("$AR_FILE", "w", encoding="utf-8") as f:
        f.write('\n\n'.join(out_lines) + '\n')

    print(f"✓ Arabic RTL translation saved: $AR_FILE")
except Exception as e:
    print(f"ERROR: {str(e)}", file=sys.stderr)
PYEOF

    [ -f "$AR_FILE" ] && log "Saved (AR): $AR_FILE"
    if [ "$CLEANUP_TEMP" = "true" ] && [ -f "$TEMP_EN_FILE" ]; then
      rm -f "$TEMP_EN_FILE"
    fi
  fi
}

# ───────────────────────────────────────────────────────
#  DOWNLOAD HELPER
# ───────────────────────────────────────────────────────
download_audio() {
  local VID_URL="$1"
  local AUDIO_FILE="$2"
  yt-dlp -x --audio-format mp3 --audio-quality 0 \
    $BASE_YTDLP_ARGS \
    -o "$AUDIO_FILE" \
    "$VID_URL"
}

# ───────────────────────────────────────────────────────
#  MAIN — DOWNLOAD + TRANSCRIBE
# ───────────────────────────────────────────────────────
section "Downloading & Transcribing"

FAILED=0
SUCCESS=0

if [ "$PLAYLIST_MODE" = true ]; then
  mapfile -t VIDEO_IDS < <(yt-dlp --flat-playlist --get-id $BASE_YTDLP_ARGS "$URL" 2>/dev/null)
  TOTAL=${#VIDEO_IDS[@]}
  echo -e "  Processing ${BOLD}$TOTAL videos${NC}...\n"

  for i in "${!VIDEO_IDS[@]}"; do
    VID_ID="${VIDEO_IDS[$i]}"
    VID_URL="https://www.youtube.com/watch?v=$VID_ID"
    IDX=$((i + 1))

    echo -e "\n${CYAN}  [$IDX/$TOTAL]${NC} https://youtu.be/$VID_ID"

    TITLE=$(yt-dlp --get-title $BASE_YTDLP_ARGS "$VID_URL" 2>/dev/null \
      | tr ' ' '_' | tr -cd '[:alnum:]_-' | cut -c1-60)
    TITLE="${TITLE:-video_${IDX}}"

    SAFE_TITLE="${IDX}_${TITLE}"
    
    # Download to temp folder
    TEMP_AUDIO_FILE="$AUDIO_TEMP_DIR/${SAFE_TITLE}.mp3"

    if download_audio "$VID_URL" "$TEMP_AUDIO_FILE" && [ -f "$TEMP_AUDIO_FILE" ]; then
      log "Downloaded: $SAFE_TITLE.mp3 (temp)"
      warn "Transcribing... ($IDX/$TOTAL)"
      transcribe_audio "$TEMP_AUDIO_FILE" "$SAFE_TITLE"
      
      # Delete audio file after successful transcription
      if [ -f "$TEMP_AUDIO_FILE" ]; then
        rm -f "$TEMP_AUDIO_FILE"
        log "Deleted: $SAFE_TITLE.mp3 (audio removed after transcription)"
      fi
      SUCCESS=$((SUCCESS + 1))
    else
      warn "Skipped (download failed): $VID_ID"
      rm -f "$TEMP_AUDIO_FILE"
      FAILED=$((FAILED + 1))
    fi
  done

else
  TITLE=$(yt-dlp --get-title $BASE_YTDLP_ARGS "$URL" 2>/dev/null \
    | tr ' ' '_' | tr -cd '[:alnum:]_-' | cut -c1-60)
  TITLE="${TITLE:-urdu_transcript}"
  
  # Download to temp folder
  TEMP_AUDIO_FILE="$AUDIO_TEMP_DIR/${TITLE}.mp3"

  if download_audio "$URL" "$TEMP_AUDIO_FILE" && [ -f "$TEMP_AUDIO_FILE" ]; then
    log "Downloaded: ${TITLE}.mp3 (temp)"
    warn "Transcribing..."
    transcribe_audio "$TEMP_AUDIO_FILE" "$TITLE"
    
    # Delete audio file after successful transcription
    if [ -f "$TEMP_AUDIO_FILE" ]; then
      rm -f "$TEMP_AUDIO_FILE"
      log "Deleted: ${TITLE}.mp3 (audio removed after transcription)"
    fi
    SUCCESS=1
  else
    rm -f "$TEMP_AUDIO_FILE"
    err "Download failed. Check cookies.txt is fresh and node is installed."
  fi
fi

# ───────────────────────────────────────────────────────
#  CLEAN UP EMPTY TEMP FOLDER
# ───────────────────────────────────────────────────────
if [ -d "$AUDIO_TEMP_DIR" ] && [ -z "$(ls -A "$AUDIO_TEMP_DIR" 2>/dev/null)" ]; then
  rmdir "$AUDIO_TEMP_DIR" 2>/dev/null
  log "Removed empty temp folder: $AUDIO_TEMP_DIR"
fi

# ───────────────────────────────────────────────────────
#  SUMMARY
# ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ All Done!${NC}"
if [ "$PLAYLIST_MODE" = true ]; then
  echo -e "${GREEN}  ✔ Processed : ${SUCCESS} / $TOTAL videos${NC}"
  [ "$FAILED" -gt 0 ] && echo -e "${YELLOW}  ✘ Skipped   : ${FAILED} videos (download errors)${NC}"
fi
echo -e "${GREEN}  📁 Base Dir : $BASE_OUTPUT_DIR${NC}"
echo -e "${GREEN}  📂 Audio    : $AUDIO_URL_DIR${NC}"
echo -e "${GREEN}  📂 Subtitles: $SRT_URL_DIR${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════${NC}"
echo ""
