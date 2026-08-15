#!/usr/bin/env bash
# uninstall.sh — remove o voice-dictate do sistema.
# Remove: binários, venv, custom-keybinding GNOME.
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
VENV_DIR="$HOME/.local/share/voice-dictate"

echo "==> Removendo binários"
rm -f "$BIN_DIR/voice-dictate" "$BIN_DIR/voice-transcribe.py" "$BIN_DIR/check-audio-level.py"

echo "==> Removendo venv"
rm -rf "$VENV_DIR"

echo "==> Removendo custom-keybinding GNOME 'Voice Dictate'"
BINDINGS_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-dictate/"
if command -v gsettings >/dev/null 2>&1; then
  gsettings reset-recursively "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${BINDINGS_PATH}" 2>/dev/null || true
  CURRENT=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || true)
  if echo "$CURRENT" | grep -q "voice-dictate"; then
    NEW=$(echo "$CURRENT" | sed "s| *'${BINDINGS_PATH}',\?||g")
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW" 2>/dev/null || true
  fi
fi

echo ""
echo "✅ voice-dictate removido."