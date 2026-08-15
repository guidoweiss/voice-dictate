#!/usr/bin/env python3
"""voice-transcribe.py — transcreve um WAV com faster-whisper (GPU se disponível).

Uso: voice-transcribe.py <arquivo.wav>
Saída: texto transcrito em stdout.

Env (todos opcionais):
  WHISPER_MODEL     (default: small)   ex: tiny, base, small, medium, large-v3
  WHISPER_LANG      (default: auto)    ex: pt, en — vazio = auto-detect
  WHISPER_DEVICE    (default: auto)    cuda | cpu | auto (tenta GPU, cai para CPU)
  WHISPER_CUDA_LIB  (opcional)         caminho da libcublas.so.12, ex: /usr/local/lib/ollama/cuda_v12
"""
import os
import sys

# Configura LD_LIBRARY_PATH para CUDA ANTES do import do faster_whisper
_cuda_lib = os.environ.get("WHISPER_CUDA_LIB", "").strip()
if _cuda_lib:
    os.environ["LD_LIBRARY_PATH"] = (
        _cuda_lib + os.pathsep + os.environ.get("LD_LIBRARY_PATH", "")
    )

MODEL = os.environ.get("WHISPER_MODEL", "small").strip() or "small"
LANG = os.environ.get("WHISPER_LANG", "").strip() or None
DEVICE = os.environ.get("WHISPER_DEVICE", "auto").strip() or "auto"

from faster_whisper import WhisperModel  # noqa: E402


def _device_available(device: str) -> bool:
    if device != "cuda":
        return device == "cpu"
    try:
        import ctypes
        ctypes.CDLL("libcublas.so.12")
        return True
    except OSError:
        return False


def _transcribe(wav: str, device: str) -> str:
    compute = "float16" if device == "cuda" else "int8"
    model = WhisperModel(MODEL, device=device, compute_type=compute)
    segments, _info = model.transcribe(wav, beam_size=1, language=LANG)
    return "".join(s.text for s in segments).strip()


def main() -> int:
    if len(sys.argv) < 2:
        print("uso: voice-transcribe.py <arquivo.wav>", file=sys.stderr)
        return 1
    wav = sys.argv[1]

    candidates = []
    if DEVICE == "auto":
        candidates = ["cuda", "cpu"] if _device_available("cuda") else ["cpu"]
    elif DEVICE in ("cuda", "cpu"):
        candidates = [DEVICE, "cpu"] if DEVICE == "cuda" else ["cpu"]
    else:
        print(f"erro: WHISPER_DEVICE inválido: {DEVICE}", file=sys.stderr)
        return 1

    last_err: Exception | None = None
    for device in candidates:
        try:
            text = _transcribe(wav, device)
            print(text)
            return 0
        except Exception as e:  # noqa: BLE001
            last_err = e
            print(f"aviso: falha em {device}: {e}", file=sys.stderr)

    print(f"erro: transcrição falhou: {last_err}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())