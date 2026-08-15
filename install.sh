#!/usr/bin/env bash
# install.sh — instala o voice-dictate no sistema do usuário.
#
# Uso:
#   ./install.sh                        → instala com defaults (config gerado)
#   KEY="XF86AudioMicMute" ./install.sh → usa outra tecla (GNOME X11)
#   NO_KEYBINDING=1 ./install.sh        → só copia binários, não registra tecla
#
# O que faz:
#   1. Copia os binários para ~/.local/bin/
#   2. Garante o Python virtualenv com faster-whisper (~/.local/share/voice-dictate/venv)
#   3. Gera ~/.config/voice-dictate.conf se não existir (detecta CUDA automaticamente)
#   4. Registra o custom-keybinding GNOME com a tecla (config > env KEY > default)
#
# Depois da instalação, edite a configuração com:  voice-dictate config
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
VENV_DIR="$HOME/.local/share/voice-dictate/venv"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/voice-dictate.conf"
NO_KEYBINDING="${NO_KEYBINDING:-0}"

# Detecta sessão (X11 vs Wayland)
SESSION_TYPE="${XDG_SESSION_TYPE:-}"
if [ "$SESSION_TYPE" = "wayland" ]; then
  echo "⚠️  Sessão Wayland detectada: o binding de tecla usa GNOME X11 (custom-keybindings)."
  echo "    Em Wayland, configure a tecla manualmente ou use o instalador de tecla do seu ambiente."
  NO_KEYBINDING=1
fi

echo "==> 1/4 Copiando binários para $BIN_DIR"
mkdir -p "$BIN_DIR"
install -m 0755 "$SRC_DIR/bin/voice-dictate" "$BIN_DIR/"
install -m 0755 "$SRC_DIR/bin/voice-transcribe.py" "$BIN_DIR/"
install -m 0755 "$SRC_DIR/bin/check-audio-level.py" "$BIN_DIR/"

echo "==> 2/4 Verificando dependências"
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

# --- Detecta libcublas.so.12 (CUDA) em locais comuns ---
detect_cuda_lib() {
  local p lib
  for p in /usr/local/lib/ollama/cuda_v12 /usr/local/cuda/lib64 /usr/lib/wsl/lib /opt/cuda/lib64; do
    if [ -d "$p" ] && ls "$p"/libcublas.so.12* >/dev/null 2>&1; then
      echo "$p"; return 0
    fi
  done
  lib="$(ldconfig -p 2>/dev/null | grep -o '[^ ]*libcublas\.so\.12' | head -1)"
  if [ -n "$lib" ]; then
    dirname "$lib" 2>/dev/null || true
  fi
}

echo "==> 3/4 Configuração ($CONFIG_FILE)"
mkdir -p "$(dirname "$CONFIG_FILE")"
if [ ! -f "$CONFIG_FILE" ]; then
  if [ -f "$SRC_DIR/config.example" ]; then
    cp "$SRC_DIR/config.example" "$CONFIG_FILE"
  else
    cat > "$CONFIG_FILE" <<'EOF'
# voice-dictate — configuracao (gerado pelo install.sh)
KEY=<Super><Shift>XF86TouchpadOff
WHISPER_MODEL=small
WHISPER_LANG=
WHISPER_DEVICE=auto
WHISPER_CUDA_LIB=
MIC_SOURCE=default
ANTI_GHOST_DELAY=1.5
ANTI_GHOST_THRESHOLD=0.003
STOP_SETTLE=0.3
LOG_MAX_KB=200
TYPE_DELAY=5
BEEP=1
NOTIFY=1
EOF
  fi
  CUDA_LIB="$(detect_cuda_lib || true)"
  if [ -n "$CUDA_LIB" ]; then
    sed -i "s|^WHISPER_CUDA_LIB=$|WHISPER_CUDA_LIB=$CUDA_LIB|" "$CONFIG_FILE"
    echo "   ✅ CUDA detectado: $CUDA_LIB (WHISPER_CUDA_LIB preenchido)"
  else
    echo "   ℹ️  CUDA não detectado — transcrição usará CPU (pode ser lenta)."
  fi
else
  echo "   ✅ Config já existente (preservado)"
fi

# Tecla: config > env KEY > default
KEY="${KEY:-}"
if [ -z "$KEY" ] && [ -f "$CONFIG_FILE" ]; then
  KEY="$(grep -E '^KEY=' "$CONFIG_FILE" | head -1 | cut -d= -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
fi
KEY="${KEY:-<Super><Shift>XF86TouchpadOff}"

echo "==> 4/4 Preparando ambiente Python (faster-whisper)"
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
    if [ "$CURRENT" = "@as []" ]; then
      NEW="@as ['${BINDINGS_PATH}']"
    else
      # Remove os colchetes externos e faz append do novo caminho
      INNER="${CURRENT#[}"
      INNER="${INNER%]}"
      NEW="[${INNER}, '${BINDINGS_PATH}']"
    fi
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW"
  fi
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDINGS_PATH" name "Voice Dictate"
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDINGS_PATH" command "$BIN_DIR/voice-dictate"
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$BINDINGS_PATH" binding "$KEY"
else
  echo "==> (pulando registro de tecla)"
fi

echo ""
echo "✅ Instalado!"
echo ""
echo "   Configuração:  $CONFIG_FILE"
echo "   Edite com:     voice-dictate config   (ou qualquer editor)"
echo "   Diagnóstico:   voice-dictate doctor"
echo "   Teste:         voice-dictate status  → aperte a tecla para gravar/ditar"
echo ""
echo "Dicas:"
echo "  - Transcrição lenta? WHISPER_MODEL=tiny ou WHISPER_DEVICE=cpu no config."
echo "  - Mudou a tecla no config? Rode ./install.sh de novo para re-registrar."
echo "  - Se os atalhos pararem: systemctl --user start org.gnome.SettingsDaemon.MediaKeys.target"