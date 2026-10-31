#!/usr/bin/env python3
"""Converte uma folha de retratos (4 colunas x 3 linhas, com molduras) numa folha limpa.

Cada quadro é recortado por dentro da moldura e colocado numa grade perfeita,
com células do mesmo tamanho. No Godot basta usar Hframes = 4 e Vframes = 3.

Uso:
    python3 fatiar_retratos.py folha.jpg saida.png --cel 96x80

O retrato é encaixado pela largura e alinhado à base da célula (o busto sai
cortado embaixo, como na folha original). Sobra de altura é preenchida de preto.

Requer: pip install pillow numpy scipy
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage

COLUNAS, LINHAS = 4, 3


def so_blocos_grandes(preto, lado=61):
    """Abertura morfológica: some com linhas finas e ornamentos pretos da moldura e
    mantém só os blocos pretos grandes (o miolo do quadro)."""
    f = preto.astype("float32")
    erodido = ndimage.uniform_filter(f, size=lado) > 0.9999
    return ndimage.uniform_filter(erodido.astype("float32"), size=lado) > 0


def interior(blocos, cru, x0, y0, x1, y1):
    """Extensão do miolo preto do quadro dentro da janela, ignorando a moldura.

    O filtro de blocos acha o topo e as laterais com segurança, mas pode cortar a
    base (o busto largo deixa pouco preto nas laterais). A base é então estendida
    descendo pela borda esquerda enquanto ainda houver preto.
    """
    ys, xs = np.where(blocos[y0:y1, x0:x1])
    xa, ya, xb, yb = x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1
    colunas = slice(xa + 6, xa + 14)
    while yb < cru.shape[0] and cru[yb, colunas].any():
        yb += 1
    return xa, ya, xb, yb


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("entrada")
    p.add_argument("saida")
    p.add_argument("--cel", default="96x80", help="tamanho de cada célula, LARGURAxALTURA")
    p.add_argument("--inset", type=int, default=6, help="pixels cortados por dentro da moldura")
    a = p.parse_args()
    cw, ch = (int(v) for v in a.cel.lower().split("x"))

    img = Image.open(a.entrada).convert("RGB")
    arr = np.array(img).astype(int)
    cru = arr.sum(axis=2) < 45
    blocos = so_blocos_grandes(cru)
    h, w = cru.shape
    jw, jh = w / COLUNAS, h / LINHAS

    caixas = [[interior(blocos, cru, int(i * jw), int(j * jh), int((i + 1) * jw), int((j + 1) * jh))
               for i in range(COLUNAS)] for j in range(LINHAS)]
    # as molduras de uma mesma linha têm a mesma altura: topo e base iguais na linha
    for j in range(LINHAS):
        topo = min(c[1] for c in caixas[j])
        base = max(c[3] for c in caixas[j])
        caixas[j] = [(c[0], topo, c[2], base) for c in caixas[j]]

    folha = Image.new("RGB", (cw * COLUNAS, ch * LINHAS), (0, 0, 0))
    for j in range(LINHAS):
        for i in range(COLUNAS):
            x0, y0, x1, y1 = caixas[j][i]
            x0, y0, x1, y1 = x0 + a.inset, y0 + a.inset, x1 - a.inset, y1 - a.inset
            quadro = img.crop((x0, y0, x1, y1))
            alt = max(1, round(quadro.height * cw / quadro.width))
            quadro = quadro.resize((cw, alt), Image.BOX)
            if alt > ch:  # corta o excesso do topo, mantém a base
                quadro = quadro.crop((0, alt - ch, cw, alt))
                alt = ch
            folha.paste(quadro, (i * cw, j * ch + (ch - alt)))
            print(f"quadro {j * COLUNAS + i + 1:2d}: {x1 - x0}x{y1 - y0} em ({x0},{y0})")
    folha.save(a.saida)
    print(f"salvo: {a.saida} ({folha.width}x{folha.height})")


if __name__ == "__main__":
    main()
