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
#  BANNER
# ───────────────────────────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║     Urdu YouTube Transcriber 🎙️            ║"
echo "  ║  faster-whisper + yt-dlp + ArgosTranslate ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# ───────────────────────────────────────────────────────
#  COMMAND-LINE ARGUMENTS (Optional)
# ───────────────────────────────────────────────────────
# Usage: bash urdu.sh [URL] [MODEL] [LANG] [FORMAT] [TRANSLATE] [OUTPUT_DIR]
# Example: bash urdu.sh "https://youtu.be/abc123" "5" "ur" "1" "1" "$HOME/urdu_transcripts/data"

if [ $# -ge 1 ]; then
  # Command-line mode (non-interactive)
  URL="${1}"
  MODEL_CHOICE="${2:-5}"
  LANG_INPUT="${3:-Urdu}"
  FORMAT_CHOICE="${4:-1}"
  TRANS_CHOICE="${5:-1}"
  CUSTOM_DIR="${6:-}"
  INTERACTIVE=false
else
  # Interactive mode
  INTERACTIVE=true
fi

# ───────────────────────────────────────────────────────
#  STEP 1 — YouTube URL
# ───────────────────────────────────────────────────────
if [ "$INTERACTIVE" = true ]; then
  section "Step 1: YouTube URL"
  echo -e "  Paste a ${BOLD}single video URL${NC} or a ${BOLD}playlist URL${NC}:"
  echo -e "  ${YELLOW}Example:${NC} https://youtube.com/watch?v=xxxx"
  echo -e "  ${YELLOW}Example:${NC} https://youtube.com/playlist?list=xxxx"
  echo ""
  read -rp "  🔗 URL: " URL
  [ -z "$URL" ] && err "No URL provided."
else
  section "Step 1: YouTube URL (from command-line argument)"
  log "URL: $URL"
  [ -z "$URL" ] && err "No URL provided."
fi

# ───────────────────────────────────────────────────────
#  SANITIZE URL FOR FOLDER NAME (Windows + Linux safe)
# ───────────────────────────────────────────────────────
sanitize_folder_name() {
  local name="$1"
  # Remove special characters, keep alphanumeric, dash, underscore
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

# Create safe folder name from URL
URL_FOLDER_NAME="$(sanitize_folder_name "${URL_TYPE}_${URL_ID}")"
log "URL Folder Name: $URL_FOLDER_NAME"

# ───────────────────────────────────────────────────────
#  STEP 2 — Cookies (auto-detect in script dir)
# ───────────────────────────────────────────────────────
if [ "$INTERACTIVE" = true ]; then
  section "Step 2: YouTube Authentication"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_COOKIES="$SCRIPT_DIR/cookies.txt"
COOKIES_ARG=""

if [ -f "$AUTO_COOKIES" ]; then
  COOKIES_ARG="--cookies $AUTO_COOKIES"
  log "cookies.txt found — using automatically ✅"
elif [ "$INTERACTIVE" = true ]; then
  echo -e "  No cookies.txt found in script directory."
  echo -e "  ${YELLOW}[1]${NC} Continue without cookies"
  echo -e "  ${YELLOW}[2]${NC} Provide path to cookies.txt manually"
  echo ""
  read -rp "  Choice [1/2, default=1]: " COOKIE_CHOICE
  if [ "$COOKIE_CHOICE" = "2" ]; then
    read -rp "  📁 Path to cookies.txt: " COOKIES_PATH
    if [ -f "$COOKIES_PATH" ]; then
      COOKIES_ARG="--cookies $COOKIES_PATH"
      log "Cookies loaded: $COOKIES_PATH"
    else
      warn "File not found — continuing without cookies."
    fi
  fi
fi

# ───────────────────────────────────────────────────────
#  STEP 3 — Transcription Language (default: Urdu)
# ───────────────────────────────────────────────────────
if [ "$INTERACTIVE" = true ]; then
  section "Step 3: Transcription Language"
  echo -e "  What language is spoken in the video?"
  echo -e "  ${YELLOW}Press Enter for default (Urdu)${NC}"
  echo -e "  Or type a language: Arabic, English, French, Hindi, Turkish..."
  echo ""
  read -rp "  🌐 Language [default: Urdu]: " LANG_INPUT
else
  section "Step 3: Transcription Language (from command-line argument)"
  log "Language: $LANG_INPUT"
fi
LANG_NAME="${LANG_INPUT:-Urdu}"
declare -A LANG_CODES=([urdu]="ur" [arabic]="ar" [english]="en" [french]="fr" [hindi]="hi" [turkish]="tr" [persian]="fa" [russian]="ru" [chinese]="zh" [japanese]="ja" [korean]="ko" [spanish]="es")
LANG_KEY="${LANG_NAME,,}"
TRANSCRIBE_LANG="${LANG_CODES[$LANG_KEY]:-$LANG_KEY}"
log "Transcription language: $TRANSCRIBE_LANG"

# ───────────────────────────────────────────────────────
#  STEP 4 — Whisper Model
# ───────────────────────────────────────────────────────
if [ "$INTERACTIVE" = true ]; then
  section "Step 4: Whisper Model"
  echo -e "  Choose transcription model:"
  echo ""
  echo -e "  ${YELLOW}[1]${NC} tiny           — Fastest, lower accuracy   (~75MB)"
  echo -e "  ${YELLOW}[2]${NC} base           — Fast, decent accuracy      (~150MB)"
  echo -e "  ${YELLOW}[3]${NC} small          — Balanced                   (~500MB)"
  echo -e "  ${YELLOW}[4]${NC} medium         — Good accuracy              (~1.5GB)"
  echo -e "  ${YELLOW}[5]${NC} large-v3-turbo — Fast + high accuracy       (~1.6GB) ← recommended"
  echo -e "  ${YELLOW}[6]${NC} large-v3       — Best accuracy              (~3GB)"
  echo ""
  read -rp "  Choice [1-6, default=5]: " MODEL_CHOICE
else
  section "Step 4: Whisper Model (from command-line argument)"
  log "Model choice: $MODEL_CHOICE"
fi

case "$MODEL_CHOICE" in
  1) MODEL="tiny" ;;
  2) MODEL="base" ;;
  3) MODEL="small" ;;
  4) MODEL="medium" ;;
  6) MODEL="large-v3" ;;
  *) MODEL="large-v3-turbo" ;;
esac
log "Model selected: $MODEL"

# ───────────────────────────────────────────────────────
#  STEP 5 — Output Format
# ───────────────────────────────────────────────────────
if [ "$INTERACTIVE" = true ]; then
  section "Step 5: Output Format"
  echo -e "  What subtitle format do you want?"
  echo ""
  echo -e "  ${YELLOW}[1]${NC} SRT only       — Standard subtitle (.srt) ← recommended"
  echo -e "  ${YELLOW}[2]${NC} TXT only       — Plain transcript (.txt)"
  echo -e "  ${YELLOW}[3]${NC} Both SRT + TXT"
  echo -e "  ${YELLOW}[4]${NC} VTT only       — Web subtitles (.vtt)"
  echo ""
  read -rp "  Choice [1-4, default=1]: " FORMAT_CHOICE
else
  section "Step 5: Output Format (from command-line argument)"
  log "Format choice: $FORMAT_CHOICE"
fi

case "$FORMAT_CHOICE" in
  2) FORMATS=("txt") ;;
  3) FORMATS=("srt" "txt") ;;
  4) FORMATS=("vtt") ;;
  *) FORMATS=("srt") ;;
esac
log "Output format(s): ${FORMATS[*]}"

# ───────────────────────────────────────────────────────
#  STEP 6 — Translation
# ───────────────────────────────────────────────────────
if [ "$INTERACTIVE" = true ]; then
  section "Step 6: Translation"
  echo -e "  Do you want to translate the transcript?"
  echo ""
  echo -e "  ${YELLOW}[1]${NC} No translation"
  echo -e "  ${YELLOW}[2]${NC} English only       (fast — built into Whisper)"
  echo -e "  ${YELLOW}[3]${NC} Arabic only        (RTL — via ArgosTranslate)"
  echo -e "  ${YELLOW}[4]${NC} Both English + Arabic"
  echo ""
  read -rp "  Choice [1-4, default=1]: " TRANS_CHOICE
else
  section "Step 6: Translation (from command-line argument)"
  log "Translation choice: $TRANS_CHOICE"
fi

TRANSLATE_EN=false
TRANSLATE_AR=false
case "$TRANS_CHOICE" in
  2) TRANSLATE_EN=true ;;
  3) TRANSLATE_AR=true ;;
  4) TRANSLATE_EN=true; TRANSLATE_AR=true ;;
esac

if $TRANSLATE_EN; then log "English translation: enabled"; fi
if $TRANSLATE_AR; then log "Arabic translation: enabled (RTL)"; fi

# ───────────────────────────────────────────────────────
#  STEP 7 — Output Directory
# ───────────────────────────────────────────────────────
if [ "$INTERACTIVE" = true ]; then
  section "Step 7: Output Directory"
  echo -e "  Where should transcripts be saved?"
  echo -e "  ${YELLOW}[default: $HOME/urdu_transcripts/data]${NC}"
  echo ""
  read -rp "  📁 Base Path (press Enter for default): " CUSTOM_DIR
else
  section "Step 7: Output Directory (from command-line argument)"
  [ -n "$CUSTOM_DIR" ] && log "Output directory: $CUSTOM_DIR" || log "Using default output directory"
fi
BASE_OUTPUT_DIR="${CUSTOM_DIR:-$HOME/urdu_transcripts/data}"

# Create directory structure: BASE_OUTPUT_DIR/audio/URL_FOLDER/ and BASE_OUTPUT_DIR/srt/URL_FOLDER/
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
      
      # Move from temp to URL folder after transcription
      mv "$TEMP_AUDIO_FILE" "$AUDIO_URL_DIR/${SAFE_TITLE}.mp3" 2>/dev/null || true
      log "Moved to permanent: audio/$URL_FOLDER_NAME/$SAFE_TITLE.mp3"
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
    
    # Move from temp to URL folder after transcription
    mv "$TEMP_AUDIO_FILE" "$AUDIO_URL_DIR/${TITLE}.mp3" 2>/dev/null || true
    log "Moved to permanent: audio/$URL_FOLDER_NAME/$TITLE.mp3"
    SUCCESS=1
  else
    rm -f "$TEMP_AUDIO_FILE"
    err "Download failed. Check cookies.txt is fresh and node is installed."
  fi
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
