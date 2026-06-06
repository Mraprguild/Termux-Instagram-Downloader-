#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX_BIN="${PREFIX:-/data/data/com.termux/files/usr}/bin"
LAUNCHER="$PREFIX_BIN/instadl"
SCRIPT="$PROJECT_DIR/instagram-downloader.sh"

if [ ! -x "$(command -v pkg 2>/dev/null || true)" ]; then
  echo "Error: This installer must be run inside Termux." >&2
  exit 1
fi

echo "Installing required Termux packages..."
pkg update -y
pkg install -y python ffmpeg termux-tools

python -m pip install --upgrade yt-dlp

chmod +x "$SCRIPT" "$PROJECT_DIR/install.sh" "$PROJECT_DIR/uninstall.sh"
mkdir -p "$PREFIX_BIN"
ln -sfn "$SCRIPT" "$LAUNCHER"

if [ ! -d "$HOME/storage/downloads" ]; then
  echo "Requesting Android shared-storage permission..."
  termux-setup-storage || true
fi

printf '\nInstallation complete.\nRun: instadl\n'
