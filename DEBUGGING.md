# 🔍 Debugging & Logging Guide

## Overview

The Urdu YouTube Transcriber now includes **comprehensive logging and debugging capabilities** to help troubleshoot issues and monitor performance.

---

## 📋 Logging Features

### Automatic Logging

All sessions are automatically logged to `/tmp/urdu_transcribe.log` (or custom path via `-L` flag).

**Log file includes:**
- Session start/end times (ISO 8601 format)
- System information (CPU, RAM, Disk, Hostname)
- Configuration settings used
- Performance metrics (elapsed time, processing speed)
- All operations with timestamps
- Error messages with context

### Log Format

Each line includes a timestamp and log level:

```
2026-03-13 10:45:23 [OK] Configuration:
2026-03-13 10:45:24 [INFO] URL: https://www.youtube.com/watch?v=abc123
2026-03-13 10:45:25 [DEBUG] Available RAM: 2048MB
2026-03-13 10:45:26 [WARN] Low disk space available (< 5GB)
2026-03-13 10:45:27 [ERROR] Audio file not found
```

**Log Levels:**
- `[OK]` - Successful operation
- `[INFO]` - Informational message
- `[SUCCESS]` - Task completed successfully
- `[DEBUG]` - Debug information (verbose mode)
- `[TRACE]` - Detailed execution trace (verbose mode)
- `[WARN]` - Warning message
- `[ERROR]` - Error condition
- `[SECTION]` - Section header

---

## 🐛 Verbose Mode (Debugging)

Enable verbose mode to see detailed debug and trace information:

```bash
./urdu.sh -u "https://youtu.be/abc123" -v
```

Or in background:
```bash
./urdu.sh -u "https://youtu.be/abc123" -v
tail -f /tmp/urdu_transcribe.log
```

**Verbose mode outputs:**
- System resource checks (RAM, CPU, disk)
- Environment variables
- Function entry/exit traces
- Variable values at key points
- Detailed operation sequence
- Performance timestamps

---

## 📊 What Gets Logged

### Session Information

```
═════════════════════════════════════════════════════════
Urdu YouTube Transcriber - Session Start
═════════════════════════════════════════════════════════
Start Time:    2026-03-13 10:45:23
Start Time (ISO): 2026-03-13T10:45:23Z
Script Version: 2.0
Script PID:    12345
User:          root
Working Dir:   /root/urdu_transcripts
Hostname:      srv1407525.hstgr.cloud
```

### System Resources

```
[DEBUG] System Resources:
[DEBUG]   Total RAM: 7.8G
[DEBUG]   Available RAM: 5.2G
[DEBUG]   Total Disk: 100G
[DEBUG]   Available Disk: 45G
[DEBUG]   CPU Cores: 4
```

### Configuration

```
Configuration:
  URL: https://www.youtube.com/playlist?list=PLzufeTFnhupw5WKMf4SgXScoLrtUYXh0Q
  Model: 5 (large-v3-turbo)
  Language: Urdu (ur)
  Format: 1 (srt)
  Translation: EN=false, AR=false
  Output Dir: /root/urdu_transcripts/data
  Cookies: /root/urdu_transcripts/cookies.txt
  Log File: /tmp/urdu_transcribe.log
  Verbose: true
  Foreground: false
```

### Processing Details

Each video/operation is logged with:
- Operation type (download, transcribe, translate)
- Input file/URL
- Output location
- Success/failure status
- File sizes
- Timestamps

### Performance Summary

```
═════════════════════════════════════════════════════════
Session Summary:
═════════════════════════════════════════════════════════
End Time:      2026-03-13 10:50:42
End Time (ISO): 2026-03-13T10:50:42Z
Elapsed Time:  0h 5m 19s
Total Seconds: 319
```

---

## 📖 Log File Locations

| Configuration | Log Path | Size Limit |
|---|---|---|
| Default | `/tmp/urdu_transcribe.log` | 10MB |
| Custom | `-L /custom/path.log` | 10MB |
| Multiple sessions | Rotated with `.{timestamp}` suffix | Last 5 kept |

**Check logs:**
```bash
# View live
tail -f /tmp/urdu_transcribe.log

# View specific session (last 50 lines)
tail -50 /tmp/urdu_transcribe.log

# Search for errors
grep "\[ERROR\]" /tmp/urdu_transcribe.log

# Search for warnings
grep "\[WARN\]" /tmp/urdu_transcribe.log

# View entire log
cat /tmp/urdu_transcribe.log

# Search with context
grep -B 5 -A 5 "Transcription failed" /tmp/urdu_transcribe.log
```

---

## 🔧 Debugging Common Issues

### Issue: Download Failed

**What to check:**
```bash
# Check for download errors in log
grep "download" /tmp/urdu_transcribe.log -i

# Enable verbose to see yt-dlp output
./urdu.sh -u "URL" -v -F

# Check cookies validity
grep "cookies" /tmp/urdu_transcribe.log -i
```

### Issue: Transcription Failed

**What to check:**
```bash
# Check RAM usage during transcription
grep "RAM" /tmp/urdu_transcribe.log

# Check model size requirement
grep "large-v3" /tmp/urdu_transcribe.log

# Check for Python errors
grep "Error\|Failed\|Traceback" /tmp/urdu_transcribe.log -i
```

### Issue: Process Killed / Out of Memory

**What to check:**
```bash
# Check available RAM warning
grep "Low RAM\|MemAvailable" /tmp/urdu_transcribe.log

# Check disk space
grep "disk space" /tmp/urdu_transcribe.log -i

# Kill and retry with smaller model
pkill -f "urdu.sh"
./urdu.sh -u "URL" -m 3  # Use smaller model
```

### Issue: Translation Failed

**What to check:**
```bash
# Check for ArgosTranslate errors
grep "transl" /tmp/urdu_transcribe.log -i

# Check if language packs installed
python3 -c "import argostranslate; print(argostranslate.__version__)"

# Install missing packs (Arabic)
python3 << 'EOF'
import argostranslate.package
argostranslate.package.update_package_index()
pkgs = argostranslate.package.get_available_packages()
pkg = next(p for p in pkgs if p.from_code=='en' and p.to_code=='ar')
argostranslate.package.install_from_path(pkg.download())
EOF
```

### Issue: Slow Processing

**What to check:**
```bash
# Check model vs system resources
grep "Model\|RAM" /tmp/urdu_transcribe.log

# Check elapsed time
grep "Elapsed Time" /tmp/urdu_transcribe.log

# Optimize next run
./urdu.sh -u "URL" -m 3 -F  # Smaller model, foreground for monitoring
```

---

## 📈 Performance Monitoring

### Real-time Monitoring

In background, watch logs in another terminal:
```bash
# Watch entire log
tail -f /tmp/urdu_transcribe.log

# Watch only important lines
tail -f /tmp/urdu_transcribe.log | grep -E "\[OK\]|\[ERROR\]|\[WARN\]"

# Watch with timestamps and line numbers
tail -f /tmp/urdu_transcribe.log | nl -v 1
```

### Performance Metrics

Extract performance data from logs:
```bash
# Find processing speed
grep "Elapsed Time" /tmp/urdu_transcribe.log | tail -1

# Count successful operations
grep -c "\[OK\]" /tmp/urdu_transcribe.log

# Count errors
grep -c "\[ERROR\]" /tmp/urdu_transcribe.log

# Count warnings
grep -c "\[WARN\]" /tmp/urdu_transcribe.log

# List all sessions
grep "Session Start\|End Time" /tmp/urdu_transcribe.log
```

### Resource Usage During Run

Check what the script detected:
```bash
grep "Available RAM\|Available Disk\|CPU Cores" /tmp/urdu_transcribe.log
```

---

## 🎯 Verbose Debug Example

Running with `-v` (verbose) flag:

```bash
./urdu.sh -u "https://youtu.be/abc123" -m 5 -v -F
```

**Output includes:**
```
[DEBUG] System Resources:
[DEBUG]   Total RAM: 7.8G
[DEBUG]   Available RAM: 5.2G
[DEBUG]   Total Disk: 100G
[DEBUG]   Available Disk: 45G
[DEBUG]   CPU Cores: 4
[DEBUG] Environment Information:
[DEBUG]   Bash Version: 5.1.16
[DEBUG]   Working Directory: /root/urdu_transcripts
[DEBUG]   User: root
[DEBUG]   Hostname: srv1407525.hstgr.cloud
[DEBUG]   Kernel: 5.15.0-1066-aws
[DEBUG] Analyzing URL: https://youtu.be/abc123
[DEBUG] Video count detected: 1
[DEBUG] Mode: Single video
[DEBUG] Starting transcription of: /root/urdu_transcripts/data/audio/tmp/1_Video_Title.mp3
[DEBUG] Output name: 1_Video_Title
[DEBUG] Format(s): srt
[DEBUG] Language: ur
[DEBUG] Model: large-v3-turbo
[DEBUG] RAM Check: Available=5242MB, Required=3500MB
[DEBUG] Transcribing to format: srt → /root/urdu_transcripts/data/srt/video_abc123/1_Video_Title.srt
[TRACE] Starting transcription of: /root/urdu_transcripts/data/audio/tmp/1_Video_Title.mp3
```

---

## 📝 Log Rotation

Logs are automatically rotated when they exceed 10MB:

```
/tmp/urdu_transcribe.log           ← Current log
/tmp/urdu_transcribe.log.1710336323  ← Rotated (older)
/tmp/urdu_transcribe.log.1710335987  ← Rotated (older)
...
```

**Only last 5 rotated logs are kept** (oldest deleted automatically).

To prevent rotation, use a different log file for each session:
```bash
./urdu.sh -u "URL" -L /tmp/urdu_transcribe_$(date +%s).log
```

---

## 🔐 Privacy & Security

Logs contain:
- ✅ URLs being processed
- ✅ File paths and names
- ✅ System information
- ✅ Configuration used

Logs do **NOT** contain:
- ❌ Passwords or authentication tokens
- ❌ API keys or credentials
- ❌ Audio file contents
- ❌ Subtitle contents

**For secure deletion:**
```bash
# Securely overwrite log file
shred -vfz -n 5 /tmp/urdu_transcribe.log

# Or just delete it
rm /tmp/urdu_transcribe.log
```

---

## 💡 Pro Tips

1. **Always enable verbose when troubleshooting:**
   ```bash
   ./urdu.sh -u "URL" -v -F 2>&1 | tee debug.log
   ```

2. **Save logs for each important run:**
   ```bash
   ./urdu.sh -u "URL" -L /home/logs/session_$(date +%Y%m%d_%H%M%S).log
   ```

3. **Monitor background jobs:**
   ```bash
   ./urdu.sh -u "URL" &
   BG_PID=$!
   tail -f /tmp/urdu_transcribe.log
   wait $BG_PID  # Wait for completion
   ```

4. **Analyze logs after completion:**
   ```bash
   # Check how long transcription took
   grep "Elapsed Time" /tmp/urdu_transcribe.log | tail -1
   
   # Check for any warnings
   grep "\[WARN\]" /tmp/urdu_transcribe.log
   
   # See final status
   tail -20 /tmp/urdu_transcribe.log
   ```

5. **Create a log analysis script:**
   ```bash
   #!/bin/bash
   LOG="/tmp/urdu_transcribe.log"
   echo "=== Session Summary ==="
   grep "Start Time:" $LOG | tail -1
   grep "End Time:" $LOG | tail -1
   grep "Elapsed Time:" $LOG | tail -1
   echo "=== Statistics ==="
   echo "Successes: $(grep -c '\[OK\]' $LOG)"
   echo "Errors: $(grep -c '\[ERROR\]' $LOG)"
   echo "Warnings: $(grep -c '\[WARN\]' $LOG)"
   ```

---

## 🆘 Need Help?

If you're still having issues:

1. **Save the log file:**
   ```bash
   cp /tmp/urdu_transcribe.log ~/urdu_issue_$(date +%s).log
   ```

2. **Run with maximum verbosity:**
   ```bash
   ./urdu.sh -u "URL" -v -F > ~/debug_output.txt 2>&1
   ```

3. **Check GitHub Issues:** [Issues](https://github.com/0xSm0ky/urdu-youTube-transcriber/issues)

4. **Create a new issue** with:
   - The error from the log
   - System info (OS, RAM, CPU)
   - The command you ran
   - Output of `./urdu.sh -h`

---

**Last Updated:** March 13, 2026  
**Script Version:** 2.0
