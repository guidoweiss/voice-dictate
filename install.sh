#!/usr/bin/env bash
# install.sh — instala o voice-dictate no sistema do usuário.
#
# Uso:
#   ./install.sh                    → instala com defaults
#   KEY="XF86AudioMicMute" ./install.sh   → usa outra tecla (GNOME X11)
#   NO_KEYBINDING=1 ./install.sh    → só copia binários, não registra tecla
#
# O que faz:
#   1. Copia os binários para ~/.local/bin/
#   2. Garante o Python virtualenv com faster-whisper (~/.local/share/voice-dictate/venv)
#   3. Registra o custom-keybinding GNOME (opcional, tecla configurável)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
VENV_DIR="$HOME/.local/share/voice-dictate/venv"
KEY="${KEY:-<Super><Shift>XF86TouchpadOff}"
NO_KEYBINDING="${NO_KEYBINDING:-0}"

# Detecta sessão (X11 vs Wayland)
SESSION_TYPE="${XDG_SESSION_TYPE:-}"
if [ "$SESSION_TYPE" = "wayland" ]; then
  echo "⚠️  Sessão Wayland detectada: o binding de tecla usa GNOME X11 (custom-keybindings)."
  echo "    Em Wayland, configure a tecla manualmente ou use o instalador de tecla do seu ambiente."
  NO_KEYBINDING=1
fi

echo "==> 1/3 Copiando binários para $BIN_DIR"
mkdir -p "$BIN_DIR"
install -m 0755 "$SRC_DIR/bin/voice-dictate" "$BIN_DIR/"
install -m 0755 "$SRC_DIR/bin/voice-transcribe.py" "$BIN_DIR/"
install -m 0755 "$SRC_DIR/bin/check-audio-level.py" "$BIN_DIR/"

echo "==> 2/3 Verificando dependências"
MISSING=""
for cmd in ffmpeg ffplay python3 xdotool xclip notify-send; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "   ⚠️  ausente: $cmd"
    MISSING="$MISSING $cmd"
  fi
done
if [ -n "$MISSING" ]; then
  echo ""
  echo "   ⚠️  Dependências ausentes:$MISSING"
  echo "   Instale com:"
  echo "     Debian/Ubuntu: sudo apt install ffmpeg xdotool xclip libnotify-bin"
  echo "   (ffplay vem junto do ffmpeg)"
  echo ""
fi

echo "==> 3/3 Preparando ambiente Python (faster-whisper)"
if [ ! -x "$VENV_DIR/bin/python" ]; then
  python3 -m venv "$VENV_DIR"
fi
if ! "$VENV_DIR/bin/python" -c "import faster_whisper" 2>/dev/null; then
  echo "   Instalando faster-whisper (pode demorar)..."
  "$VENV_DIR/bin/pip" install --quiet faster-whisper
fi

if [ "$NO_KEYBINDING" = "0" ]; then
  echo "==> Registrando tecla GNOME: $KEY"
  BINDINGS_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-dictate/"
  # Adiciona à lista de custom-keybindings se ainda não estiver
  CURRENT=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "@as []")
  if ! echo "$CURRENT" | grep -q "voice-dictate"; then
    NEW=$(echo "$CURRENT" | sed "s|@as \[\],|@as ['${BINDINGS_PATH}'],|" | sed "s|@as \[\]|@as ['${BINDINGS_PATH}']|")
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW"
  fi
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDINGS_PATH" name "Voice Dictate"
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDINGS_PATH" command "$BIN_DIR/voice-dictate"
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDINGS_PATH" binding "$KEY"
else
  echo "==> (pulando registro de tecla)"
fi

echo ""
echo "✅ Instalado! Teste com:"
echo "   voice-dictate status"
echo "   # e aperte a tecla para gravar/ditar"
echo ""
echo "Se a transcrição for lenta em CPU, baixe um modelo menor:"
echo "   WHISPER_MODEL=tiny voice-dictate stop   # (ou edite o env no seu ambiente)"