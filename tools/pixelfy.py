#!/usr/bin/env python3
"""Converte uma imagem gerada por IA em pixel art no padrão do Veet.

Passos: remove o fundo (opcional), reduz para o tamanho final sem suavizar
e trava as cores na paleta do projeto.

Uso:
    python3 pixelfy.py entrada.png saida.png --size 128x128
    python3 pixelfy.py entrada.png saida.png --size 128x128 --remove-bg --fit

Requer: pip install pillow
"""
import argparse
import sys

from PIL import Image

# Paleta base do projeto (docs/Lista-de-Assets.docx, seção 2)
PALETA = [
    "F4EBD9", "E3CDA4", "B98B5E", "A8D5BA", "6FA287", "9EC5E0", "4A5F85",
    "E8B4B8", "E39A5B", "8D93A0", "8C6A4A", "4B3A2E", "D96C6C", "F2D675",
    "FFFDF7", "2A2420",
]


def hex_para_rgb(valor):
    return tuple(int(valor[i:i + 2], 16) for i in (0, 2, 4))


def remover_fundo(img, tolerancia):
    """Torna transparente a cor dos cantos (fundo chapado)."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    cantos = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    fundo = tuple(sum(c[i] for c in cantos) // 4 for i in range(3))
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if abs(r - fundo[0]) + abs(g - fundo[1]) + abs(b - fundo[2]) <= tolerancia:
                px[x, y] = (0, 0, 0, 0)
    return img


def encaixar(img, largura, altura):
    """Corta a área vazia e encaixa o sprite no quadro, centro-inferior."""
    caixa = img.getbbox()
    if caixa:
        img = img.crop(caixa)
    escala = min(largura / img.width, altura / img.height)
    novo = (max(1, round(img.width * escala)), max(1, round(img.height * escala)))
    img = img.resize(novo, Image.NEAREST)
    quadro = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
    quadro.paste(img, ((largura - novo[0]) // 2, altura - novo[1]), img)
    return quadro


def travar_paleta(img, paleta):
    cores = [hex_para_rgb(c) for c in paleta]
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            melhor = min(cores, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)
            px[x, y] = melhor + (255,)
    return img


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("entrada")
    p.add_argument("saida")
    p.add_argument("--size", required=True, help="tamanho final, ex.: 128x128")
    p.add_argument("--remove-bg", action="store_true", help="remove o fundo chapado")
    p.add_argument("--bg-tolerance", type=int, default=60, help="tolerância do fundo (padrão 60)")
    p.add_argument("--fit", action="store_true", help="corta o vazio e encaixa no quadro (sprites)")
    p.add_argument("--no-palette", action="store_true", help="não trava na paleta do projeto")
    a = p.parse_args()

    try:
        largura, altura = (int(v) for v in a.size.lower().split("x"))
    except ValueError:
        sys.exit("--size deve ser LARGURAxALTURA, ex.: 128x128")

    img = Image.open(a.entrada).convert("RGBA")
    if a.remove_bg:
        img = remover_fundo(img, a.bg_tolerance)
    if a.fit:
        img = encaixar(img, largura, altura)
    else:
        img = img.resize((largura, altura), Image.NEAREST)
    if not a.no_palette:
        img = travar_paleta(img, PALETA)
    img.save(a.saida)
    print(f"ok: {a.saida} ({largura}x{altura})")


if __name__ == "__main__":
    main()
