#!/usr/bin/env python3
"""Processa em lote os sprites de corpo inteiro de um animal.

Para cada imagem: remove o fundo (a partir das bordas), usa UMA escala comum a
todas as imagens (o animal mantém o mesmo tamanho em todos os estados), alinha
as patas na base, reduz para o quadro final e trava as cores numa paleta única
gerada a partir do próprio conjunto (as cores ficam iguais entre os estados).

Uso:
    python3 processar_animal.py PASTA_ENTRADA PASTA_SAIDA \
        --map "Fibonacci - Neutro.jpg=fibonacci_neutro" \
        --map "Fibonacci - Dor.jpg=fibonacci_dor" \
        --size 128 --cores 24 --folha folha.png

    --bolso ARQUIVO:X,Y   marca um ponto de fundo cercado pelo desenho (ex.: dentro
                          da curva do rabo), em pixels da imagem original.

Requer: pip install pillow numpy scipy
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

CONTORNO = (30, 25, 40)  # cor das bordas semitransparentes (parece contorno)

# Cores de destaque da paleta do projeto (rosa, vermelho-aviso, amarelo-luz, azul, branco)
DESTAQUES = ["E8B4B8", "D96C6C", "F2D675", "9EC5E0", "FFFDF7"]


def hex_para_rgb(valor):
    return tuple(int(valor[i:i + 2], 16) for i in (0, 2, 4))


def reduzir(img, novo):
    """Reduz uma imagem RGBA levando a transparência em conta (alfa pré-multiplicado).

    Sem isso, detalhes pequenos (corações, brilho, gota) se misturam com a cor do
    fundo removido e perdem a cor.
    """
    dados = np.array(img).astype("float32")
    alfa = dados[:, :, 3:4] / 255.0
    canais = np.concatenate([dados[:, :, :3] * alfa, alfa * 255.0], axis=2)
    peq = np.stack([np.array(Image.fromarray(canais[:, :, i], "F").resize(novo, Image.BOX))
                    for i in range(4)], axis=2)
    a = peq[:, :, 3:4] / 255.0
    rgb = np.where(a > 0, peq[:, :, :3] / np.maximum(a, 1e-6), 0)
    return Image.fromarray(np.clip(np.dstack([rgb, peq[:, :, 3]]), 0, 255).astype("uint8"), "RGBA")


def cor_do_fundo(arr):
    borda = np.concatenate([arr[:8].reshape(-1, 3), arr[-8:].reshape(-1, 3),
                            arr[:, :8].reshape(-1, 3), arr[:, -8:].reshape(-1, 3)])
    return np.median(borda, axis=0)


def mascara_fundo(arr, bolsos, tol, auto_bolsos=0):
    """True onde é fundo: região parecida com o fundo ligada às bordas (e bolsos marcados).

    Com auto_bolsos > 0, toda região de cor de fundo com pelo menos essa área (em
    pixels) também é removida, mesmo cercada pelo desenho (ex.: dentro da curva do
    rabo). Só é seguro quando o animal não tem partes da cor do fundo (o peito claro
    do Fibonacci seria apagado).
    """
    bg = cor_do_fundo(arr)
    parecido = (np.abs(arr.astype(int) - bg).sum(axis=2) <= tol)
    rotulos, n = ndimage.label(parecido)  # regiões conectadas de "cor de fundo"
    h, w = parecido.shape
    fundo = np.zeros_like(parecido)
    if auto_bolsos:
        areas = ndimage.sum(parecido, rotulos, range(1, n + 1))
        grandes = np.where(areas >= auto_bolsos)[0] + 1
        fundo |= np.isin(rotulos, grandes)
    for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)] + bolsos:
        r = rotulos[y, x]
        if r:
            fundo |= rotulos == r
        elif (x, y) in bolsos:
            print(f"  aviso: o ponto {(x, y)} não é fundo, ignorado", file=sys.stderr)
    # engole o halo (pixels de transição entre o fundo e o contorno)
    for _ in range(2):
        vizinho = np.zeros_like(fundo)
        vizinho[1:] |= fundo[:-1]; vizinho[:-1] |= fundo[1:]
        vizinho[:, 1:] |= fundo[:, :-1]; vizinho[:, :-1] |= fundo[:, 1:]
        halo = vizinho & ~fundo & (np.abs(arr.astype(int) - bg).sum(axis=2) <= tol * 2.2)
        fundo |= halo
    return fundo


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("entrada")
    p.add_argument("saida")
    p.add_argument("--map", action="append", default=[], help='"arquivo.jpg=nome_saida"')
    p.add_argument("--bolso", action="append", default=[], help="ARQUIVO:X,Y")
    p.add_argument("--size", type=int, default=128)
    p.add_argument("--margem", type=int, default=4)
    p.add_argument("--cores", type=int, default=0, help="reduz a uma paleta de N cores; 0 (padrão) mantém as cores fiéis")
    p.add_argument("--tol", type=int, default=34, help="tolerância do fundo (soma RGB)")
    p.add_argument("--auto-bolsos", type=int, default=0, metavar="AREA",
                   help="remove sozinho o fundo cercado pelo desenho, em regiões de pelo menos AREA pixels "
                        "(ex.: 600). Não use se o animal tiver partes da cor do fundo")
    p.add_argument("--folha", help="salva uma folha de contato (conferência visual)")
    a = p.parse_args()

    pares = [m.split("=", 1) for m in a.map]
    bolsos = {}
    for b in a.bolso:
        arq, xy = b.rsplit(":", 1)
        x, y = (int(v) for v in xy.split(","))
        bolsos.setdefault(arq, []).append((x, y))

    recortes = []  # (nome, imagem RGBA recortada)
    for arq, nome in pares:
        origem = Image.open(os.path.join(a.entrada, arq)).convert("RGB")
        arr = np.array(origem)
        fundo = mascara_fundo(arr, bolsos.get(arq, []), a.tol, a.auto_bolsos)
        arr = arr.copy()
        arr[fundo] = CONTORNO  # franja escura em vez de cinza claro
        alfa = (~fundo * 255).astype("uint8")
        img = Image.fromarray(np.dstack([arr, alfa]), "RGBA")
        caixa = img.getbbox()
        recortes.append((nome, img.crop(caixa)))
        print(f"{nome}: recorte {caixa[2]-caixa[0]}x{caixa[3]-caixa[1]}")

    util = a.size - 2 * a.margem
    escala = util / max(max(r.width, r.height) for _, r in recortes)
    print(f"escala comum: {escala:.4f}")

    quadros = []
    for nome, rec in recortes:
        novo = (max(1, round(rec.width * escala)), max(1, round(rec.height * escala)))
        peq = reduzir(rec, novo)
        quadro = Image.new("RGBA", (a.size, a.size), (0, 0, 0, 0))
        quadro.paste(peq, ((a.size - novo[0]) // 2, a.size - a.margem - novo[1]), peq)
        quadros.append((nome, quadro))

    # paleta única a partir de todos os estados. Usa cada cor distinta UMA vez (sem
    # pesar pela frequência), senão as cores raras (rosa da orelha, olhos, língua)
    # somem e só o cinza predominante sobrevive.
    pixels = np.concatenate([np.array(q)[np.array(q)[:, :, 3] >= 128][:, :3] for _, q in quadros])
    pixels = np.unique(pixels, axis=0)
    lado = int(np.ceil(np.sqrt(len(pixels))))
    base = np.zeros((lado * lado, 3), dtype="uint8")
    base[:len(pixels)] = pixels
    base[len(pixels):] = pixels[-1]
    paleta = Image.fromarray(base.reshape(lado, lado, 3), "RGB").quantize(
        colors=max(a.cores, 1), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)

    # paleta final = cores do animal + cores de destaque fixas (efeitos pequenos como
    # corações, brilho e gota de suor, que a paleta automática ignoraria)
    cores_animal = np.array(paleta.getpalette()[:3 * a.cores], dtype=int).reshape(-1, 3)
    destaques = np.array([hex_para_rgb(h) for h in DESTAQUES], dtype=int)
    cores_finais = np.concatenate([cores_animal, destaques])

    os.makedirs(a.saida, exist_ok=True)
    finais = []
    for nome, q in quadros:
        dados = np.array(q)
        alfa = dados[:, :, 3]
        rgb_in = dados[:, :, :3].astype(int)
        if a.cores == 0:  # sem paleta: mantém as cores reais da redução
            rgb = rgb_in.astype("uint8")
        else:
            dist = ((rgb_in[:, :, None, :] - cores_finais[None, None, :, :]) ** 2).sum(axis=3)
            rgb = cores_finais[dist.argmin(axis=2)].astype("uint8")
        saida = np.dstack([rgb, np.where(alfa >= 128, 255, 0).astype("uint8")])
        out = Image.fromarray(saida, "RGBA")
        out.save(os.path.join(a.saida, nome + ".png"))
        finais.append((nome, out))
        print(f"salvo: {nome}.png")

    if a.folha:
        z = 2
        cols = 4
        linhas = (len(finais) + cols - 1) // cols
        cel = a.size * z
        folha = Image.new("RGBA", (cols * cel, linhas * cel), (255, 0, 255, 255))
        for i, (_, f) in enumerate(finais):
            folha.paste(f.resize((cel, cel), Image.NEAREST), ((i % cols) * cel, (i // cols) * cel),
                        f.resize((cel, cel), Image.NEAREST))
        folha.save(a.folha)
        print(f"folha de contato: {a.folha}")


if __name__ == "__main__":
    main()
