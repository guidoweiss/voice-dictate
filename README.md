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
3. **Gera o arquivo de configuração** `~/.config/voice-dictate.conf` (se não existir) e **detecta CUDA automaticamente**
4. Registra a tecla padrão no GNOME (custom-keybinding "Voice Dictate")

---

## ⚙️ Configuração

Tudo fica em **um arquivo**: `~/.config/voice-dictate.conf` (gerado no install, editável à vontade).

```bash
voice-dictate config    # abre o arquivo no seu editor
voice-dictate doctor    # mostra a configuração efetiva em uso + diagnóstico
```

**Precedência:** `defaults < arquivo de config < variáveis de ambiente`
(um `export WHISPER_MODEL=...` no shell sobrepõe o config — útil para testes pontuais).

| Opção | Default | Descrição |
|---|---|---|
| `KEY` | `<Super><Shift>XF86TouchpadOff` | tecla de acionamento (usada pelo install.sh) |
| `WHISPER_MODEL` | `small` | `tiny`, `base`, `small`, `medium`, `large-v3` |
| `WHISPER_LANG` | vazio (auto) | `pt`, `en`, etc. |
| `WHISPER_DEVICE` | `auto` | `cuda`, `cpu` ou `auto` (tenta GPU, cai para CPU) |
| `WHISPER_CUDA_LIB` | detectado | caminho da `libcublas.so.12` |
| `MIC_SOURCE` | `default` | fonte PulseAudio/PipeWire |
| `ANTI_GHOST_DELAY` | `1.5` | segundos até checar se o mic capta |
| `ANTI_GHOST_THRESHOLD` | `0.003` | nível RMS mínimo (aborta se menor) |
| `STOP_SETTLE` | `0.3` | espera após parar o ffmpeg |
| `LOG_MAX_KB` | `200` | teto do log de diagnóstico |
| `TYPE_DELAY` | `5` | delay do `xdotool type` (fallback sem xclip) |
| `BEEP` | `1` | `0` desliga os beeps |
| `NOTIFY` | `1` | `0` desliga as notificações |

**Mudou a tecla no config?** Rode `./install.sh` de novo — ele relê o `KEY` do arquivo e re-registra o binding.

Para usar outra tecla na primeira instalação:
```bash
KEY="XF86AudioMicMute" ./install.sh
# ou sem registrar tecla nenhuma:
NO_KEYBINDING=1 ./install.sh
```

---

## 🎮 Uso

| Comando | Efeito |
|---|---|
| `voice-dictate` | alterna gravar/parar+transcrever |
| `voice-dictate start` | começa a gravar |
| `voice-dictate stop` | para e transcreve |
| `voice-dictate status` | mostra se está gravando |
| `voice-dictate config` | abre o arquivo de configuração |
| `voice-dictate doctor` | mostra a config efetiva + diagnóstico |

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

**Primeiro diagnóstico:** `voice-dictate doctor` mostra a config efetiva, o python usado, o CUDA e se as dependências existem.

| Problema | Solução |
|---|---|
| A tecla não faz nada | 1) `systemctl --user restart org.gnome.SettingsDaemon.MediaKeys.target` (reinicia o serviço de atalhos) 2) Confira que o binding está na lista: `gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings` |
| Binding registrado mas a tecla não dispara | Se o journal mostrar `Failed to grab accelerator ... voice-dictate`, o serviço não conseguiu capturar a tecla. Troque a tecla no config (ex: `<Super><Alt>d`), rode `./install.sh` de novo e reinicie o MediaKeys |
| "Microfone não está captando áudio!" | Verifique o volume do mic: `pactl get-source-volume @DEFAULT_SOURCE@` — se estiver baixo, aumente: `pactl set-source-volume @DEFAULT_SOURCE@ 80%` |
| Transcrição sai vazia / não reconhece | Microfone com volume baixo (veja acima) ou ambiente ruidoso. Aumente o mic e fale mais próximo |
| Transcrição lenta | Use `WHISPER_MODEL=tiny` ou `WHISPER_DEVICE=cpu` no config |
| Erro de CUDA | Configure `WHISPER_CUDA_LIB` no config (o install.sh detecta) ou use `WHISPER_DEVICE=cpu` |
| ffmpeg órfão rodando | `pkill -f 'voice-dictate[.]wav'` (o `[.]` evita o pkill se auto-matar) |
| Log/diagnóstico | `tail -50 /tmp/voice-dictate.log` (teto 200KB, não cresce para sempre) |
| Os atalhos todos pararam | `systemctl --user start org.gnome.SettingsDaemon.MediaKeys.target` |

---

## ❓ FAQ

**O áudio sai da minha máquina?**
Não. Gravação e transcrição são 100% locais (ffmpeg + faster-whisper). Nada é enviado para servidores.

**Fica algum arquivo de áudio salvo?**
Não. O WAV temporário (`/tmp/voice-dictate.wav`) é apagado após a transcrição — em sucesso e em erro. Só o log de texto fica (teto de 200KB).

**Funciona no Wayland?**
A transcrição e a injeção funcionam (via XWayland). O registro da tecla usa custom-keybindings do GNOME X11; em Wayland use `NO_KEYBINDING=1 ./install.sh` e configure a tecla no seu ambiente.

**Qual o melhor modelo?**
`small` (padrão) é um bom equilíbrio. Em CPU fraco use `tiny`/`base`. Em GPU use `medium`/`large-v3` para mais precisão.

**Preciso de GPU?**
Não. Sem CUDA o install.sh deixa `WHISPER_DEVICE=auto` e o script cai para CPU automaticamente (mais lento). Com GPU NVIDIA, o install.sh detecta a `libcublas` e usa `float16`.

**Posso usar outra tecla que não seja a do notebook?**
Sim. Edite `KEY` no config e rode `./install.sh` de novo — ele relê e re-registra o binding. Formato GNOME: `<Super><Shift>XF86TouchpadOff`, `<Ctrl><Alt>d`, `XF86AudioMicMute`, etc.

**Por que 2 beeps / 3 beeps?**
2 agudos = gravando · 1 médio = transcrevendo · 1 agudo longo = texto injetado · 3 graves = erro. Pode desligar com `BEEP=0` no config.

---

## 🧹 Desinstalar

```bash
./uninstall.sh
```

Remove binários, venv, binding GNOME, config e o estado temporário.

## 📄 Licença

[MIT](LICENSE) — use, modifique e compartilhe à vontade.