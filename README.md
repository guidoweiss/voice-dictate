# 🎙️ Voice Dictate

**Dite seus prompts no terminal (e em qualquer app) por voz — 100% local, sem enviar áudio para lugar nenhum.**

Grava o microfone, transcreve com [faster-whisper](https://github.com/SYSTRAN/faster-whisper) (local) e injeta o texto no campo selecionado via teclado. Pressione a tecla para gravar, fale, pressione de novo — o texto aparece.

> Feito para o [OpenCode](https://github.com/sst/opencode) TUI, mas funciona em **qualquer aplicação** (terminal, editor, navegador, formulários).

---

## ✨ Como funciona

```
tecla (1º aperto)  →  ffmpeg grava o microfone (buffer temporário)
tecla (2º aperto)  →  faster-whisper transcreve localmente (GPU se disponível)
                   →  texto vai para o clipboard → injetado com Ctrl+Shift+V
```

**Nada é salvo no computador.** O áudio temporário fica em `/tmp` e é **apagado automaticamente** assim que o texto é injetado (ou em qualquer erro). Não há arquivos persistentes.

**Feedback ao usuário** (para você nunca ficar no escuro):
- 🔊 **2 beeps agudos** = gravando
- 🔊 **1 beep médio** = transcrevendo
- 🔊 **1 beep agudo longo** = texto injetado
- 🔊 **3 beeps graves** = erro
- 🔔 Notificação persistente "🎙 Gravando..." na tela
- 🛡️ **Anti-fantasma**: 1,5s após começar, o sistema mede o nível do microfone. Se estiver mudo/morto, aborta na hora com aviso — você não perde tempo falando um prompt gigante.

---

## 📋 Pré-requisitos

| Dependência | Necessária para | Instalação (Debian/Ubuntu) |
|---|---|---|
| X11 (sessão Xorg) | injeção de teclado + tecla | — |
| `ffmpeg` (+ `ffplay`) | gravação + beeps | `sudo apt install ffmpeg` |
| `xdotool` | injetar texto no app ativo | `sudo apt install xdotool` |
| `xclip` | clipboard (opcional) | `sudo apt install xclip` |
| `notify-send` | notificações (opcional) | `sudo apt install libnotify-bin` |
| `python3` + `venv` | transcrição | `sudo apt install python3-venv` |
| NVIDIA GPU (opcional) | transcrição rápida | driver proprietário + CUDA 12 |

> ⚠️ **Wayland**: o script de instalação registra a tecla via custom-keybindings do GNOME (X11). Em Wayland, configure a tecla no seu ambiente ou use o `install.sh` sem binding (`NO_KEYBINDING=1`).

---

## 🚀 Instalação

```bash
git clone https://github.com/guidoweiss/voice-dictate.git
cd voice-dictate
./install.sh
```

O instalador:
1. Copia os binários para `~/.local/bin/`
2. Cria um venv isolado com `faster-whisper` em `~/.local/share/voice-dictate/venv`
3. Registra a tecla padrão no GNOME (custom-keybinding "Voice Dictate")

### Tecla padrão e personalização

O padrão é `<Super><Shift>XF86TouchpadOff` (a tecla ASUS única do TUF F16 emite esse chord). Para usar outra tecla:

```bash
KEY="XF86AudioMicMute" ./install.sh
# ou sem registrar tecla nenhuma:
NO_KEYBINDING=1 ./install.sh
```

**Variáveis de ambiente** (também úteis no seu shell):

| Variável | Default | Descrição |
|---|---|---|
| `WHISPER_MODEL` | `small` | `tiny`, `base`, `small`, `medium`, `large-v3` |
| `WHISPER_LANG` | auto | `pt`, `en`, etc. |
| `WHISPER_DEVICE` | `auto` | `cuda`, `cpu` ou `auto` (tenta GPU, cai para CPU) |
| `WHISPER_CUDA_LIB` | — | caminho da `libcublas.so.12` (ex: `/usr/local/lib/ollama/cuda_v12`) |
| `MIC_SOURCE` | `default` | fonte PulseAudio/PipeWire |

Exemplo: `WHISPER_MODEL=tiny WHISPER_DEVICE=cpu voice-dictate stop`

---

## 🎮 Uso

| Comando | Efeito |
|---|---|
| `voice-dictate` | alterna gravar/parar+transcrever |
| `voice-dictate start` | começa a gravar |
| `voice-dictate stop` | para e transcreve |
| `voice-dictate status` | mostra se está gravando |

**Fluxo de uso:**
1. Foque o app onde quer o texto (ex: OpenCode)
2. Aperte a tecla → 2 beeps + "🎙 Gravando..."
3. Fale seu prompt
4. Aperte a tecla de novo → beep médio → ~5-8s → beep agudo + "✅ Texto injetado"

---

## 🔒 Privacidade

- **100% local**: nenhum áudio ou texto sai da máquina.
- **Nada persistente**: o WAV temporário é apagado após a transcrição (sucesso ou erro).
- O modelo do whisper fica em `~/.cache/huggingface` (reutilizável, não é lixo).

---

## 🛠️ Solução de problemas

| Problema | Solução |
|---|---|
| A tecla não faz nada | `systemctl --user start org.gnome.SettingsDaemon.MediaKeys.target` |
| "Microfone não está captando áudio!" | Verifique o mic no PulseAudio/PipeWire |
| Transcrição lenta | Use `WHISPER_MODEL=tiny` ou `WHISPER_DEVICE=cpu` |
| Erro de CUDA | Configure `WHISPER_CUDA_LIB` ou use `WHISPER_DEVICE=cpu` |
| ffmpeg órfão rodando | `pkill -f voice-dictate.wav` |
| Log/diagnóstico | `tail -50 /tmp/voice-dictate.log` |

---

## 🧹 Desinstalar

```bash
./uninstall.sh
```

## 📄 Licença

[MIT](LICENSE) — use, modifique e compartilhe à vontade.