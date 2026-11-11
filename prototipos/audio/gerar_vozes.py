#!/usr/bin/env python3
"""Gera os "blips" de voz dos personagens (estilo Undertale) e o bip do ECG, sem dependencias.

Cada personagem tem um timbre proprio (altura e forma de onda). No jogo o blip
toca a cada poucas letras do texto, com variacao aleatoria de tom, e basta para
indicar quem esta falando sem precisar de voz nitida.

Uso:  python3 prototipos/audio/gerar_vozes.py
Saida: assets/audio/sfx/voz_<id>.wav  (22050 Hz, mono, 16 bits)
"""
import math
import os
import random
import struct
import wave

TAXA = 22050
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SAIDA = os.path.join(RAIZ, "assets", "audio", "sfx")

# id: (frequencia Hz, forma, duracao s, vibrato Hz, volume)
VOZES = {
    "narrador":     (300, "quadrada", 0.050, 0.0, 0.22),
    "protagonista": (330, "triangulo", 0.050, 0.0, 0.30),
    "helena":       (520, "triangulo", 0.060, 7.0, 0.34),
    "euler":        (180, "serra", 0.065, 0.0, 0.22),
    "davi":         (440, "quadrada", 0.040, 11.0, 0.20),
    "rita":         (270, "triangulo", 0.070, 5.0, 0.34),
    "beatriz":      (390, "triangulo", 0.055, 6.0, 0.32),
}


def onda(forma, fase):
    t = fase % 1.0
    if forma == "quadrada":
        return 1.0 if t < 0.5 else -1.0
    if forma == "triangulo":
        return 4.0 * abs(t - 0.5) - 1.0
    if forma == "serra":
        return 2.0 * t - 1.0
    return math.sin(2 * math.pi * t)


def gerar(id_voz, freq, forma, dur, vibrato, volume):
    rnd = random.Random(id_voz)
    n = int(TAXA * dur)
    amostras = []
    fase = 0.0
    for i in range(n):
        t = i / TAXA
        f = freq * (1.0 + 0.03 * math.sin(2 * math.pi * vibrato * t)) if vibrato else freq
        fase += f / TAXA
        ataque = min(1.0, i / (TAXA * 0.004))
        queda = (1.0 - i / n) ** 1.6
        v = onda(forma, fase) * 0.8 + onda("seno", fase * 2) * 0.2
        amostras.append(int(32767 * volume * ataque * queda * v))
    caminho = os.path.join(SAIDA, f"voz_{id_voz}.wav")
    os.makedirs(SAIDA, exist_ok=True)
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(b"".join(struct.pack("<h", a) for a in amostras))
    return caminho


def gerar_bip_ecg():
    """"Pi" do monitor cardiaco: tom puro de ~1 kHz, ataque instantaneo e queda curta."""
    dur, freq = 0.16, 1000.0
    n = int(TAXA * dur)
    amostras = []
    for i in range(n):
        t = i / TAXA
        ataque = min(1.0, i / (TAXA * 0.002))
        queda = 1.0 if t < 0.07 else math.exp(-(t - 0.07) * 26.0)
        v = math.sin(2 * math.pi * freq * t) * 0.9 + math.sin(2 * math.pi * freq * 2 * t) * 0.1
        amostras.append(int(32767 * 0.5 * ataque * queda * v))
    caminho = os.path.join(SAIDA, "ecg_bip.wav")
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(b"".join(struct.pack("<h", a) for a in amostras))
    return caminho


if __name__ == "__main__":
    for nome, params in VOZES.items():
        print("OK ->", gerar(nome, *params))
    print("OK ->", gerar_bip_ecg())
