#!/usr/bin/env python3
"""check_audio_level.py — mede o nível RMS de um arquivo WAV que ESTÁ CRESCENDO.

Lê o WAV parcial (header 44 bytes ignorado) e calcula o RMS normalizado das
amostras PCM s16le. Retorna 0-1.0 na stdout.

Uso: python3 check_audio_level.py /caminho/arquivo.wav
Saída: nível RMS (float). Ex: 0.0123
"""
import math
import struct
import sys

LIMIAR_SILENCIO = 0.003  # abaixo disso = microfone não está captando

def rms_level(wav_path: str) -> float:
    try:
        with open(wav_path, "rb") as f:
            data = f.read()
    except OSError:
        return 0.0

    if len(data) <= 44:
        return 0.0  # ainda sem dados PCM

    pcm = data[44:]
    n = len(pcm) // 2  # s16le = 2 bytes/amostra
    if n == 0:
        return 0.0

    samples = struct.unpack("<%dh" % n, pcm[: n * 2])
    soma = sum(s * s for s in samples)
    rms = math.sqrt(soma / n) / 32768.0
    return rms

def main() -> None:
    if len(sys.argv) < 2:
        print("uso: check_audio_level.py <wav> [limiar] [--limiar]")
        sys.exit(2)
    wav = sys.argv[1]
    limiar = LIMIAR_SILENCIO
    if len(sys.argv) > 2:
        try:
            limiar = float(sys.argv[2])
        except ValueError:
            pass  # se não é número, usa o padrão
    level = rms_level(wav)
    print(f"{level:.4f}")
    if "--limiar" in sys.argv:
        sys.exit(0 if level >= limiar else 1)

if __name__ == "__main__":
    main()
