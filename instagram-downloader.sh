#!/data/data/com.termux/files/usr/bin/bash
set -o pipefail

APP_NAME="Mraprguild Instagram Downloader"
VERSION="1.1.0"
DOWNLOAD_DIR="$HOME/storage/downloads/Instagram"
CONFIG_DIR="$HOME/.config/mraprguild-instagram-downloader"
ARCHIVE_FILE="$CONFIG_DIR/download-archive.txt"
LOG_FILE="$CONFIG_DIR/download.log"

RESET='\033[0m'; BOLD='\033[1m'; RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'

header() {
  clear
  printf "%b" "$CYAN$BOLD"
  cat <<'BANNER'
╔══════════════════════════════════════════════╗
║       MRAPRGUILD INSTAGRAM DOWNLOADER        ║
║        Reels • Posts • Carousels • Video     ║
╚══════════════════════════════════════════════╝
BANNER
  printf "%b\n\n" "$RESET$BLUE Version $VERSION$RESET"
}
info(){ printf "%b[INFO]%b %s\n" "$CYAN" "$RESET" "$1"; }
ok(){ printf "%b[SUCCESS]%b %s\n" "$GREEN" "$RESET" "$1"; }
warn(){ printf "%b[WARNING]%b %s\n" "$YELLOW" "$RESET" "$1"; }
fail(){ printf "%b[ERROR]%b %s\n" "$RED" "$RESET" "$1" >&2; }
pause(){ printf "\n"; read -r -p "Press Enter to continue..." _; }

ensure_storage() {
  mkdir -p "$CONFIG_DIR"
  if [ ! -d "$HOME/storage/downloads" ]; then
    warn "Android storage permission is required."
    termux-setup-storage
    read -r -p "Grant storage permission, then press Enter..." _
  fi
  mkdir -p "$DOWNLOAD_DIR" || { fail "Cannot create $DOWNLOAD_DIR"; exit 1; }
}

check_dependencies() {
  local missing=0
  command -v python >/dev/null 2>&1 || { fail "Python is missing. Run install.sh."; missing=1; }
  command -v ffmpeg >/dev/null 2>&1 || { fail "FFmpeg is missing. Run install.sh."; missing=1; }
  command -v yt-dlp >/dev/null 2>&1 || { fail "yt-dlp is missing. Run install.sh."; missing=1; }
  [ "$missing" -eq 0 ] || exit 1
}

valid_url() {
  case "$1" in
    https://instagram.com/*|https://www.instagram.com/*|https://m.instagram.com/*|http://instagram.com/*|http://www.instagram.com/*) return 0 ;;
    *) return 1 ;;
  esac
}

output_template() {
  printf '%s' "$DOWNLOAD_DIR/%(uploader|instagram)s/%(upload_date>%Y-%m-%d|unknown-date)s_%(title).80B_%(id)s.%(ext)s"
}

run_download() {
  local url="$1" cookie_file="${2:-}"
  [ -n "$url" ] || { fail "URL cannot be empty."; return 1; }
  valid_url "$url" || { fail "Enter a valid Instagram URL."; return 1; }

  local args=(
    --continue
    --no-overwrites
    --ignore-errors
    --no-abort-on-error
    --restrict-filenames
    --trim-filenames 180
    --format "bv*+ba/b"
    --merge-output-format mp4
    --embed-metadata
    --write-thumbnail
    --convert-thumbnails jpg
    --embed-thumbnail
    --write-info-json
    --download-archive "$ARCHIVE_FILE"
    --newline
    --progress
    --output "$(output_template)"
  )

  if [ -n "$cookie_file" ]; then
    [ -f "$cookie_file" ] || { fail "Cookie file not found: $cookie_file"; return 1; }
    args+=(--cookies "$cookie_file")
  fi

  info "Downloading media..."
  yt-dlp "${args[@]}" "$url" 2>&1 | tee -a "$LOG_FILE"
  local status=${PIPESTATUS[0]}
  if [ "$status" -eq 0 ]; then
    ok "Download finished."
    printf "Saved to: %s\n" "$DOWNLOAD_DIR"
  else
    fail "Download failed. Update yt-dlp or use cookies for content you are permitted to access."
  fi
  return "$status"
}

download_single() {
  local url
  read -r -p "Paste Instagram URL: " url
  run_download "$url"
}

download_with_cookies() {
  local url cookie_file
  read -r -p "Paste Instagram URL: " url
  read -r -p "Path to cookies.txt: " cookie_file
  warn "Keep cookies.txt private. It may provide access to your account."
  run_download "$url" "$cookie_file"
}

download_list() {
  local file url
  read -r -p "Path to text file containing URLs: " file
  [ -f "$file" ] || { fail "File not found: $file"; return 1; }
  while IFS= read -r url || [ -n "$url" ]; do
    [ -z "$url" ] && continue
    case "$url" in \#*) continue ;; esac
    if valid_url "$url"; then run_download "$url"; else warn "Skipped invalid URL: $url"; fi
  done < "$file"
}

show_files() {
  printf "\nRecent media:\n"
  find "$DOWNLOAD_DIR" -type f \( -name '*.mp4' -o -name '*.webm' -o -name '*.jpg' \) -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null | sort -r | head -30
}

update_ytdlp() {
  info "Updating yt-dlp..."
  python -m pip install --upgrade yt-dlp && ok "yt-dlp is up to date." || fail "Update failed."
}

menu() {
  while true; do
    header
    cat <<'MENU'
1. Download public Instagram URL
2. Download with cookies.txt
3. Download URLs from a text file
4. Show downloaded files
5. Update yt-dlp
6. Show download folder
7. Exit
MENU
    printf "\n"
    read -r -p "Choose [1-7]: " choice
    case "$choice" in
      1) download_single; pause ;;
      2) download_with_cookies; pause ;;
      3) download_list; pause ;;
      4) show_files; pause ;;
      5) update_ytdlp; pause ;;
      6) printf "\n%s\n" "$DOWNLOAD_DIR"; command -v termux-open >/dev/null 2>&1 && termux-open "$DOWNLOAD_DIR"; pause ;;
      7) ok "Goodbye."; exit 0 ;;
      *) fail "Invalid selection."; sleep 1 ;;
    esac
  done
}

show_help() {
  cat <<EOF
$APP_NAME $VERSION

Usage:
  instadl                 Open the interactive menu
  instadl URL             Download one Instagram URL
  instadl --cookies FILE URL
  instadl --version
  instadl --help
EOF
}

main() {
  ensure_storage
  check_dependencies

  case "${1:-}" in
    --help|-h) show_help ;;
    --version|-v) printf "%s %s\n" "$APP_NAME" "$VERSION" ;;
    --cookies)
      [ "$#" -eq 3 ] || { fail "Usage: instadl --cookies FILE URL"; exit 2; }
      run_download "$3" "$2"
      ;;
    "") menu ;;
    *) run_download "$1" ;;
  esac
}

main "$@"
