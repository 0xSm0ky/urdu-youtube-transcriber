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
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════
#  LOGGING & DEBUGGING FUNCTIONS
# ═══════════════════════════════════════════════════════

_get_timestamp() {
  echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

_get_timestamp_iso() {
  echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
}

log()     { 
  echo -e "${GREEN}[✔]${NC} $1"
  [ -n "$LOG_FILE" ] && echo "$(_get_timestamp) [OK] $1" >> "$LOG_FILE"
}

warn()    { 
  echo -e "${YELLOW}[!]${NC} $1" >&2
  [ -n "$LOG_FILE" ] && echo "$(_get_timestamp) [WARN] $1" >> "$LOG_FILE"
}

err()     { 
  echo -e "${RED}[✘]${NC} $1" >&2
  [ -n "$LOG_FILE" ] && echo "$(_get_timestamp) [ERROR] $1" >> "$LOG_FILE"
  exit 1
}

debug()   {
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    [ -n "$LOG_FILE" ] && echo "$(_get_timestamp) [DEBUG] $1" >> "$LOG_FILE"
  fi
}

section() { 
  echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"
  [ -n "$LOG_FILE" ] && echo "" >> "$LOG_FILE" && echo "$(_get_timestamp) [SECTION] ── $1 ──" >> "$LOG_FILE"
}

info()    {
  echo -e "${BLUE}[i]${NC} $1"
  [ -n "$LOG_FILE" ] && echo "$(_get_timestamp) [INFO] $1" >> "$LOG_FILE"
}

success() {
  echo -e "${GREEN}[✓]${NC} $1"
  [ -n "$LOG_FILE" ] && echo "$(_get_timestamp) [SUCCESS] $1" >> "$LOG_FILE"
}

trace()   {
  if [ "$VERBOSE" = true ]; then
    echo -e "${GRAY}[TRACE]${NC} ${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]} in ${FUNCNAME[1]}()"
    echo -e "${GRAY}         $1${NC}"
    [ -n "$LOG_FILE" ] && echo "$(_get_timestamp) [TRACE] ${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]} in ${FUNCNAME[1]}() - $1" >> "$LOG_FILE"
  fi
}

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
#  SYSTEM DIAGNOSTICS & LOGGING
# ───────────────────────────────────────────────────────
check_system_resources() {
  local total_ram=$(free -b | awk 'NR==2 {print $2}')
  local available_ram=$(free -b | awk 'NR==2 {print $7}')
  local total_disk=$(df / | awk 'NR==2 {print $2}')
  local available_disk=$(df / | awk 'NR==2 {print $4}')
  local cpu_cores=$(nproc 2>/dev/null || echo "unknown")
  
  debug "System Resources:"
  debug "  Total RAM: $(numfmt --to=iec $total_ram 2>/dev/null || echo $((total_ram / 1024 / 1024))MB)"
  debug "  Available RAM: $(numfmt --to=iec $available_ram 2>/dev/null || echo $((available_ram / 1024 / 1024))MB)"
  debug "  Total Disk: $(numfmt --to=iec $total_disk 2>/dev/null || echo $((total_disk / 1024 / 1024))MB)"
  debug "  Available Disk: $(numfmt --to=iec $available_disk 2>/dev/null || echo $((available_disk / 1024 / 1024))MB)"
  debug "  CPU Cores: $cpu_cores"
  
  # Warn if low disk space
  if [ "$available_disk" -lt 5242880 ]; then
    warn "Low disk space available (< 5GB). Transcription may fail."
  fi
}

log_environment() {
  debug "Environment Information:"
  debug "  Bash Version: ${BASH_VERSION}"
  debug "  Working Directory: $(pwd)"
  debug "  User: $(whoami)"
  debug "  Hostname: $(hostname)"
  debug "  Kernel: $(uname -r)"
}

log_script_start() {
  echo "" >> "$LOG_FILE"
  echo "═════════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "Urdu YouTube Transcriber - Session Start" >> "$LOG_FILE"
  echo "═════════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "Start Time:    $(_get_timestamp)" >> "$LOG_FILE"
  echo "Start Time (ISO): $(_get_timestamp_iso)" >> "$LOG_FILE"
  echo "Script Version: 2.0" >> "$LOG_FILE"
  echo "Script PID:    $$" >> "$LOG_FILE"
  echo "User:          $(whoami)" >> "$LOG_FILE"
  echo "Working Dir:   $(pwd)" >> "$LOG_FILE"
  echo "Hostname:      $(hostname)" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
}

log_configuration() {
  echo "Configuration:" >> "$LOG_FILE"
  echo "  URL: $URL" >> "$LOG_FILE"
  echo "  Model: $MODEL_CHOICE ($MODEL)" >> "$LOG_FILE"
  echo "  Language: $LANG_INPUT ($LANG_KEY → $TRANSCRIBE_LANG)" >> "$LOG_FILE"
  echo "  Format: $FORMAT_CHOICE (${FORMATS[*]})" >> "$LOG_FILE"
  echo "  Translation: EN=$TRANSLATE_EN, AR=$TRANSLATE_AR" >> "$LOG_FILE"
  echo "  Output Dir: $BASE_OUTPUT_DIR" >> "$LOG_FILE"
  echo "  Cookies: ${COOKIES_ARG:-none}" >> "$LOG_FILE"
  echo "  Log File: $LOG_FILE" >> "$LOG_FILE"
  echo "  Verbose: $VERBOSE" >> "$LOG_FILE"
  echo "  Foreground: $FOREGROUND" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
}

rotate_logs() {
  if [ -f "$LOG_FILE" ]; then
    local filesize=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
    # Rotate if larger than 10MB
    if [ "$filesize" -gt 10485760 ]; then
      local rotated="${LOG_FILE}.$(date +%s)"
      mv "$LOG_FILE" "$rotated"
      debug "Rotated old log to: $rotated"
      # Keep only last 5 rotated logs
      ls -t "${LOG_FILE}".* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
    fi
  fi
}

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
rotate_logs  # Rotate logs if too large

if [ "$FOREGROUND" = false ]; then
  # Redirect output to log file
  exec > >(tee -a "$LOG_FILE")
  exec 2>&1
fi

# Log the session start
log_script_start

# Check system resources and log environment
check_system_resources
log_environment

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

# Log configuration to file
log_configuration

# Track start time for performance metrics
SCRIPT_START_TIME=$(date +%s)
debug "Script start timestamp: $SCRIPT_START_TIME"

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
debug "Analyzing URL: $URL"
VIDEO_COUNT=$(yt-dlp --flat-playlist --get-id $BASE_YTDLP_ARGS "$URL" 2>/dev/null | wc -l)
debug "Video count detected: $VIDEO_COUNT"

if [ "$VIDEO_COUNT" -gt 1 ]; then
  echo -e "  ${CYAN}Playlist detected:${NC} $VIDEO_COUNT videos found."
  PLAYLIST_MODE=true
  debug "Mode: Playlist"
else
  echo -e "  ${CYAN}Single video detected.${NC}"
  PLAYLIST_MODE=false
  debug "Mode: Single video"
fi

# ───────────────────────────────────────────────────────
#  TRANSCRIBE FUNCTION (faster-whisper)
# ───────────────────────────────────────────────────────
transcribe_audio() {
  local AUDIO_FILE="$1"
  local OUT_NAME="$2"

  # Validate input file exists
  [ ! -f "$AUDIO_FILE" ] && err "Audio file not found: $AUDIO_FILE"

  trace "Starting transcription of: $AUDIO_FILE"
  debug "Output name: $OUT_NAME"
  debug "Format(s): ${FORMATS[*]}"
  debug "Language: $TRANSCRIBE_LANG"
  debug "Model: $MODEL"

  # RAM check
  AVAILABLE_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  declare -A MODEL_RAM=([tiny]=400 [base]=600 [small]=1200 [medium]=3000 [large-v3-turbo]=3500 [large-v3]=5000)
  REQUIRED_MB=${MODEL_RAM[$MODEL]:-3000}
  debug "RAM Check: Available=${AVAILABLE_MB}MB, Required=${REQUIRED_MB}MB"
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
    
    debug "Transcribing to format: $FMT → $OUT_FILE"

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
  debug "Total videos in playlist: $TOTAL"
  echo -e "  Processing ${BOLD}$TOTAL videos${NC}...\n"

  for i in "${!VIDEO_IDS[@]}"; do
    VID_ID="${VIDEO_IDS[$i]}"
    VID_URL="https://www.youtube.com/watch?v=$VID_ID"
    IDX=$((i + 1))
    
    debug "Processing video $IDX/$TOTAL: $VID_ID"

    echo -e "\n${CYAN}  [$IDX/$TOTAL]${NC} https://youtu.be/$VID_ID"

    TITLE=$(yt-dlp --get-title $BASE_YTDLP_ARGS "$VID_URL" 2>/dev/null \
      | tr ' ' '_' | tr -cd '[:alnum:]_-' | cut -c1-60)
    TITLE="${TITLE:-video_${IDX}}"
    debug "Video title: $TITLE"

    SAFE_TITLE="${IDX}_${TITLE}"
    debug "Safe title: $SAFE_TITLE"
    
    # Download to temp folder
    TEMP_AUDIO_FILE="$AUDIO_TEMP_DIR/${SAFE_TITLE}.mp3"
    debug "Downloading to: $TEMP_AUDIO_FILE"

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
#  PERFORMANCE SUMMARY
# ───────────────────────────────────────────────────────
log_performance_summary() {
  local end_time=$(date +%s)
  local elapsed=$((end_time - SCRIPT_START_TIME))
  local hours=$((elapsed / 3600))
  local minutes=$(((elapsed % 3600) / 60))
  local seconds=$((elapsed % 60))
  
  echo "" >> "$LOG_FILE"
  echo "═════════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "Session Summary:" >> "$LOG_FILE"
  echo "═════════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "End Time:      $(_get_timestamp)" >> "$LOG_FILE"
  echo "End Time (ISO): $(_get_timestamp_iso)" >> "$LOG_FILE"
  echo "Elapsed Time:  ${hours}h ${minutes}m ${seconds}s" >> "$LOG_FILE"
  echo "Total Seconds: $elapsed" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  
  debug "Performance Summary:"
  debug "  Total Time: ${hours}h ${minutes}m ${seconds}s"
  debug "  Output Directory: $BASE_OUTPUT_DIR"
}

log_performance_summary

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
