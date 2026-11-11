#!/usr/bin/env python3
"""Gera os sprites dos personagens humanos do Veet (pixel art, sem dependencias).

Personagens: Protagonista (residente), Dra. Helena (preceptora/guia) e
Prof. Euler (tutor do Fibonacci). Segue docs/Lista-de-Assets: contorno limpo,
sem anti-aliasing, paleta pastel, luz no canto superior esquerdo.

Saida (relativa a raiz do projeto):
  assets/personagens/<id>/<id>_sheet.png      4 linhas x 4 quadros de 64x96
  assets/personagens/<id>/frames/<anim>_<n>.png
  assets/personagens/<id>/<id>_retratos.png   3 retratos de 64x64
  assets/personagens/elenco.png               os tres lado a lado
  assets/personagens/personagens.json         metadados para o Godot/visualizador

Uso:  python3 prototipos/personagens/gerar_personagens.py
"""
import json
import os
import struct
import zlib

W, H = 64, 96
EXPRESSOES = ["fecha", "abre1", "sorri", "preocupa", "surpresa"]  # neutro, falando, sorrindo, preocupado, surpreso
FPS = {"idle": 6, "falar": 8, "andar": 8, "acenar": 6}
ANIMS = ["idle", "falar", "andar", "acenar"]  # ordem das linhas na folha
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SAIDA = os.path.join(RAIZ, "assets", "personagens")

# --- paleta base (docs/Lista-de-Assets) + extras de personagem humano -------
def hexa(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

OUT = hexa("#2A2420")
CREME, AREIA, MADEIRA = hexa("#F4EBD9"), hexa("#E3CDA4"), hexa("#B98B5E")
MENTA, FOLHA = hexa("#A8D5BA"), hexa("#6FA287")
AZUL_P, AZUL_N = hexa("#9EC5E0"), hexa("#4A5F85")
ROSA, VERMELHO, AMARELO = hexa("#E8B4B8"), hexa("#D96C6C"), hexa("#F2D675")
CINZA_G, MARROM_E, BRANCO = hexa("#8D93A0"), hexa("#4B3A2E"), hexa("#FFFDF7")


VERDE_CRACHA = (111, 162, 135, 255)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)

def sombra(c):
    return mix(c, AZUL_N, 0.38)

def luz(c):
    return mix(c, BRANCO, 0.45)


# --- primitivas: mascaras (conjuntos de pixels) ------------------------------
def m_elipse(cx, cy, rx, ry):
    s = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0:
                s.add((x, y))
    return s

def m_rect(x0, y0, x1, y1):  # x1/y1 exclusivos
    return {(x, y) for y in range(y0, y1) for x in range(x0, x1)}

def m_poly(pts):
    ys = [p[1] for p in pts]
    s = set()
    for y in range(min(ys), max(ys) + 1):
        xs = []
        for i in range(len(pts)):
            (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % len(pts)]
            if (ya <= y + .5 < yb) or (yb <= y + .5 < ya):
                xs.append(xa + (y + .5 - ya) * (xb - xa) / (yb - ya))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            for x in range(round(xs[i]), round(xs[i + 1])):
                s.add((x, y))
    return s

def m_capsula(x0, y0, x1, y1, r):
    s = set()
    passos = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
    for i in range(passos + 1):
        t = i / passos
        s |= m_elipse(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r, r)
    return s


class Quadro:
    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.p = [[None] * w for _ in range(h)]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y][x] = c

    def parte(self, m, cor, contorno="auto", sombrear=True):
        """Pinta uma parte: contorno de 1px (escurecido da propria cor) e
        sombreado com volume (luz em cima/esquerda, sombra embaixo/direita)."""
        if not m:
            return
        if contorno == "auto":
            contorno = mix(cor, OUT, 0.9)
        if contorno is not None:
            for (x, y) in m:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if (x + dx, y + dy) not in m:
                        self.put(x + dx, y + dy, contorno)
        xs = [p[0] for p in m]
        ys = [p[1] for p in m]
        x0, y0, w, h = min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
        grande = w >= 7 and h >= 7
        for (x, y) in m:
            c = cor
            if sombrear:
                t = ((x - x0) / w + (y - y0) / h) / 2
                borda_b = (x, y + 1) not in m or (x + 1, y) not in m
                borda_a = (x - 1, y) not in m or (x, y - 1) not in m
                if borda_b:
                    c = sombra(cor)
                elif grande and t > 0.70:
                    c = mix(cor, sombra(cor), 0.55)
                elif borda_a:
                    c = luz(cor)
                elif grande and t < 0.2:
                    c = mix(cor, luz(cor), 0.6)
            self.put(x, y, c)

    def pontos(self, pts, cor):
        for x, y in pts:
            self.put(x, y, cor)

    def retangulo(self, x0, y0, x1, y1, cor):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.put(x, y, cor)


# --- definicao dos personagens ----------------------------------------------
PERSONAGENS = {
    "protagonista": dict(
        nome="Residente (Protagonista)", arquetipo="Protagonista", pele=hexa("#D9A27A"), cabelo=hexa("#5A4232"),
        traje="jaleco", jaleco=BRANCO, manga=BRANCO, roupa=MENTA, calca=FOLHA, sapato=BRANCO, estilo="curto",
        iris=hexa("#6B4A2E"), pets=(),
    ),
    "helena": dict(
        nome="Dra. Helena (Preceptora)", arquetipo="Preceptora", pele=hexa("#EBC3A0"), cabelo=hexa("#B8B2C4"),
        traje="jaleco", jaleco=BRANCO, manga=BRANCO, roupa=AZUL_P, calca=AZUL_N, sapato=MARROM_E, estilo="coque",
        iris=hexa("#4F7F99"), pets=(),
    ),
    "euler": dict(
        nome="Prof. Euler (Tutor)", arquetipo="O Professor de Exatas", pele=hexa("#E8BC98"), cabelo=hexa("#C9C4BA"),
        traje="paleto", jaleco=hexa("#7B9BB8"), manga=hexa("#7B9BB8"), roupa=CREME, calca=MADEIRA, sapato=MARROM_E, estilo="careca",
        iris=hexa("#5E8C61"), pets=("fibonacci", "sultao"),
    ),
    "davi": dict(
        nome="Davi (Calouro)", arquetipo="O Calouro Aflito", pele=hexa("#C98E66"), cabelo=hexa("#2E2A3A"),
        traje="moletom", jaleco=hexa("#5D7FB0"), manga=hexa("#5D7FB0"), roupa=CREME, calca=hexa("#3E4A66"), sapato=BRANCO, estilo="cacheado",
        iris=hexa("#4A3A2E"), pets=("pipoca", "nutella"),
    ),
    "rita": dict(
        nome="Dona Rita (Funcionaria do Bloco)", arquetipo="A Funcionaria do Bloco", pele=hexa("#A8704C"), cabelo=hexa("#8A8494"),
        traje="colete", jaleco=hexa("#E39A5B"), manga=CREME, roupa=CREME, calca=hexa("#4F6B8A"), sapato=MARROM_E, estilo="lenco",
        iris=hexa("#3E2E24"), pets=("tigre", "racao"),
    ),
    "beatriz": dict(
        nome="Beatriz (Veterana)", arquetipo="Calouro Aflito (veterana do TCC)", pele=hexa("#F0C8A8"), cabelo=hexa("#7A4A38"),
        traje="cardiga", jaleco=FOLHA, manga=FOLHA, roupa=CREME, calca=hexa("#5B5F73"), sapato=hexa("#C86060"), estilo="rabo",
        iris=hexa("#5A3E2E"), pets=("schrodinger", "luna"),
    ),
}

# gatos nas caixas de transporte
GATOS = {
    "fibonacci":   dict(pelo="#B9BECD", orelha="#9096A8", olhos="#6FA287", rx=5, ry=3.8, extra=None, adesivo=VERMELHO),
    "sultao":      dict(pelo="#7C8394", orelha="#5E6475", olhos="#E3B455", rx=6, ry=4.5, extra="sono", adesivo=AMARELO),
    "pipoca":      dict(pelo="#F4EBD9", orelha="#E39A5B", olhos="#A8C46A", rx=5, ry=3.8, extra="tricolor", adesivo=ROSA),
    "nutella":     dict(pelo="#8C6A4A", orelha="#6B4E36", olhos="#E3B455", rx=5, ry=3.8, extra="timido", adesivo=MENTA),
    "tigre":       dict(pelo="#E39A5B", orelha="#C9743A", olhos="#6FA287", rx=5, ry=3.8, extra="bravo", adesivo=AZUL_P),
    "schrodinger": dict(pelo="#4A4858", orelha="#34323F", olhos="#F2D675", rx=5, ry=3.8, extra=None, adesivo=AMARELO),
    "luna":        dict(pelo="#F7F3EC", orelha="#E8B4B8", olhos="#9EC5E0", rx=5, ry=3.8, extra=None, adesivo=AZUL_P),
}

# poses de braco: (cotovelo, mao) relativos ao ombro, para o braco da ESQUERDA
# da imagem; o da direita espelha o eixo x.
BRACO = {
    "baixo":   ((-2, 10), (-2, 19)),
    "balanca": ((-3, 10), (-3, 20)),
    "tras":    ((-1, 9), (0, 17)),
    "gesto1":  ((-6, 8), (-10, 2)),
    "gesto2":  ((-5, 7), (-9, 5)),
    "tchau1":  ((-8, 4), (-10, -7)),
    "tchau2":  ((-8, 4), (-5, -8)),
    "prancha": ((-3, 10), (-1, 15)),
}

# quadros de cada animacao: bob (torso/cabeca), boca, pernas (elevacao esq,dir),
# braco esquerdo/direito da IMAGEM, piscar
QUADROS = {
    "idle": [
        dict(bob=0, boca="fecha", pern=(0, 0), be="baixo", bd="baixo", pisca=False),
        dict(bob=0, boca="fecha", pern=(0, 0), be="balanca", bd="balanca", pisca=False),
        dict(bob=1, boca="fecha", pern=(0, 0), be="balanca", bd="baixo", pisca=True),
        dict(bob=1, boca="fecha", pern=(0, 0), be="baixo", bd="balanca", pisca=False),
    ],
    "falar": [
        dict(bob=0, boca="abre1", pern=(0, 0), be="baixo", bd="gesto1", pisca=False),
        dict(bob=-1, boca="abre2", pern=(0, 0), be="baixo", bd="gesto2", pisca=False),
        dict(bob=0, boca="abre1", pern=(0, 0), be="baixo", bd="gesto1", pisca=False),
        dict(bob=-1, boca="fecha", pern=(0, 0), be="baixo", bd="baixo", pisca=True),
    ],
    "andar": [
        dict(bob=1, boca="fecha", pern=(3, 0), be="tras", bd="balanca", pisca=False),
        dict(bob=0, boca="fecha", pern=(0, 0), be="baixo", bd="baixo", pisca=False),
        dict(bob=1, boca="fecha", pern=(0, 3), be="balanca", bd="tras", pisca=False),
        dict(bob=0, boca="fecha", pern=(0, 0), be="baixo", bd="baixo", pisca=False),
    ],
    "acenar": [
        dict(bob=0, boca="sorri", pern=(0, 0), be="baixo", bd="tchau1", pisca=False),
        dict(bob=-1, boca="sorri", pern=(0, 0), be="baixo", bd="tchau2", pisca=False),
        dict(bob=0, boca="sorri", pern=(0, 0), be="baixo", bd="tchau1", pisca=True),
        dict(bob=-1, boca="sorri", pern=(0, 0), be="baixo", bd="tchau2", pisca=False),
    ],
}


def olho(f, ex, ey, iris, cilios=False, fechado=False, pele=None):
    """Olho 4x4: palpebra, esclera, iris, pupila e brilho."""
    if fechado:
        f.pontos([(ex, ey + 1), (ex + 1, ey + 2), (ex + 2, ey + 2), (ex + 3, ey + 1)], OUT)
        f.pontos([(ex + 1, ey + 1), (ex + 2, ey + 1)], sombra(pele))
    else:
        f.pontos([(ex, ey - 1), (ex + 1, ey - 1), (ex + 2, ey - 1), (ex + 3, ey - 1)], OUT)
        f.retangulo(ex, ey, ex + 4, ey + 3, BRANCO)
        f.retangulo(ex + 1, ey, ex + 3, ey + 3, iris)
        f.put(ex + 2, ey + 1, OUT)
        f.put(ex + 2, ey + 2, OUT)
        f.put(ex + 1, ey, BRANCO)
        f.pontos([(ex, ey + 3), (ex + 1, ey + 3), (ex + 2, ey + 3), (ex + 3, ey + 3)], sombra(pele))
    if cilios:
        f.pontos([(ex - 1, ey - 1), (ex - 1, ey)] if ex < 32 else [(ex + 4, ey - 1), (ex + 4, ey)], OUT)


def caixa_gato(f, cx0, cy0, nome):
    """Caixa de transporte com o gato espiando."""
    g = GATOS[nome]
    pelo, orelha, olhos = hexa(g["pelo"]), hexa(g["orelha"]), hexa(g["olhos"])
    f.parte(m_rect(cx0, cy0, cx0 + 17, cy0 + 15), AZUL_P)
    f.parte(m_rect(cx0 + 2, cy0 + 3, cx0 + 15, cy0 + 13), hexa("#566784"), sombrear=False)
    f.parte(m_poly([(cx0 + 4, cy0 + 8), (cx0 + 5, cy0 + 2), (cx0 + 8, cy0 + 6)]), orelha, contorno=None)
    f.parte(m_poly([(cx0 + 13, cy0 + 8), (cx0 + 12, cy0 + 2), (cx0 + 9, cy0 + 6)]), orelha, contorno=None)
    f.parte(m_elipse(cx0 + 8.5, cy0 + 9, g["rx"], g["ry"]), pelo, sombrear=False)
    ex = g["extra"]
    if ex == "tricolor":    # manchas laranja e preta
        f.parte(m_elipse(cx0 + 6, cy0 + 8, 2.2, 2), hexa("#E39A5B"), contorno=None, sombrear=False)
        f.parte(m_elipse(cx0 + 12, cy0 + 7, 1.8, 1.8), hexa("#4A4858"), contorno=None, sombrear=False)
    if ex == "bravo":       # listras e sobrancelhas zangadas
        f.pontos([(cx0 + 8, cy0 + 5), (cx0 + 9, cy0 + 5), (cx0 + 8, cy0 + 6)], hexa("#C9743A"))
        f.pontos([(cx0 + 5, cy0 + 7), (cx0 + 6, cy0 + 8), (cx0 + 12, cy0 + 8), (cx0 + 13, cy0 + 7)], OUT)
    f.pontos([(cx0 + 6, cy0 + 8), (cx0 + 11, cy0 + 8)], olhos)
    if ex == "sono":        # palpebras pesadas (estoico)
        f.pontos([(cx0 + 5, cy0 + 7), (cx0 + 6, cy0 + 7), (cx0 + 11, cy0 + 7), (cx0 + 12, cy0 + 7)], orelha)
    if ex == "timido":      # orelhas baixas / olhar para baixo
        f.pontos([(cx0 + 6, cy0 + 9), (cx0 + 11, cy0 + 9)], olhos)
    f.pontos([(cx0 + 6, cy0 + 9), (cx0 + 11, cy0 + 9)], OUT)
    f.pontos([(cx0 + 8, cy0 + 10), (cx0 + 9, cy0 + 10)], ROSA)
    f.pontos([(cx0 + 3, cy0 + 10), (cx0 + 4, cy0 + 11), (cx0 + 14, cy0 + 11), (cx0 + 15, cy0 + 10)], CREME)
    for gx in (cx0 + 5, cx0 + 8, cx0 + 11):
        for gy in range(cy0 + 3, cy0 + 13):
            if gy not in (cy0 + 8, cy0 + 9, cy0 + 10):
                f.put(gx, gy, AREIA)
    f.pontos([(cx0 + 1, cy0 + 14), (cx0 + 2, cy0 + 14)], AZUL_N)
    f.parte(m_rect(cx0 + 5, cy0 - 3, cx0 + 12, cy0), AZUL_N)
    f.parte(m_rect(cx0 + 13, cy0 + 1, cx0 + 16, cy0 + 4), g["adesivo"])
    f.put(cx0 + 14, cy0 + 2, BRANCO)


def saco_racao(f, cx0, cy0):
    """Saco de racao da Dona Rita."""
    f.parte(m_poly([(cx0 + 1, cy0 + 2), (cx0 + 15, cy0 + 2), (cx0 + 17, cy0 + 16), (cx0, cy0 + 16)]), hexa("#C9A24A"))
    f.parte(m_rect(cx0 + 2, cy0, cx0 + 14, cy0 + 3), hexa("#B58A33"))
    f.parte(m_rect(cx0 + 4, cy0 + 6, cx0 + 13, cy0 + 12), CREME, sombrear=False)
    f.pontos([(cx0 + 6, cy0 + 8), (cx0 + 8, cy0 + 8), (cx0 + 10, cy0 + 8), (cx0 + 11, cy0 + 8)], MARROM_E)
    f.pontos([(cx0 + 6, cy0 + 10), (cx0 + 7, cy0 + 10), (cx0 + 9, cy0 + 10), (cx0 + 12, cy0 + 10)], MARROM_E)
    f.pontos([(cx0 + 7, cy0 + 12), (cx0 + 9, cy0 + 12)], VERMELHO)
    f.pontos([(cx0 + 2, cy0 + 5), (cx0 + 3, cy0 + 6)], luz(hexa("#C9A24A")))


def desenhar(pid, q, largura=W, altura=H):
    """Desenha um quadro (visao frontal) do personagem `pid` com a pose `q`."""
    d = PERSONAGENS[pid]
    f = Quadro(largura, altura)
    cx = 32
    bob = q["bob"]
    pele, cab = d["pele"], d["cabelo"]
    jaleco = d["jaleco"]
    traje = d["traje"]
    estilo = d["estilo"]
    contorno_j = mix(jaleco, OUT, 0.8)
    bocao = q["boca"]
    sobr = q.get("sobr", "n")
    ansioso = pid in ("davi", "beatriz")

    # --- sombra macia no chao
    for (x, y) in m_elipse(cx, 92, 16, 3.2):
        f.put(x, y, (42, 36, 32, 70))
    for (x, y) in m_elipse(cx, 92, 11, 2):
        f.put(x, y, (42, 36, 32, 110))

    # --- elementos atras do corpo
    if traje == "moletom":   # mochila + capuz
        f.parte(m_rect(17, 42, 47, 67), hexa("#C86060"))
        f.parte(m_rect(19, 56, 27, 66), hexa("#A84A4A"))
        f.parte(m_elipse(cx, 37 + bob, 11, 5), jaleco)
    if estilo == "coque":
        f.parte(m_elipse(cx, 8 + bob, 5.5, 5), cab)
        f.parte(m_elipse(cx, 21 + bob, 11.5, 10.5), mix(cab, sombra(cab), 0.4))
    elif estilo == "careca":
        for sx in (-1, 1):
            f.parte(m_elipse(cx + sx * 10.5, 21 + bob, 4, 4.5), cab)
            f.parte(m_elipse(cx + sx * 11.5, 17 + bob, 3, 3), cab)
            f.pontos([(cx + sx * 12, 16 + bob), (cx + sx * 11, 15 + bob)], luz(cab))
    elif estilo == "cacheado":
        f.parte(m_elipse(cx, 19 + bob, 13, 12), cab)
    elif estilo == "rabo":
        f.parte(m_elipse(cx + 1, 21 + bob, 11.5, 10.5), mix(cab, sombra(cab), 0.35))
        f.parte(m_capsula(44, 14 + bob, 49, 28 + bob, 3.2), cab)           # rabo de cavalo
        f.parte(m_elipse(49, 31 + bob, 3, 4), cab)
        f.pontos([(46, 18 + bob), (47, 22 + bob)], luz(cab))

    # --- pernas, calca com vinco e sapatos
    el, er = q["pern"]
    for x0, elev in ((24, el), (33, er)):
        f.parte(m_rect(x0, 68, x0 + 7, 88 - elev), d["calca"])
        f.pontos([(x0 + 3, yy) for yy in range(72, 86 - elev)], luz(d["calca"]))
        f.pontos([(x0 + x, 86 - elev) for x in range(0, 7)], sombra(d["calca"]))
        sap = d["sapato"]
        f.parte(m_poly([(x0 - 2, 88 - elev), (x0 + 8, 88 - elev), (x0 + 9, 92 - elev), (x0 - 3, 92 - elev)]), sap)
        f.pontos([(x0 - 2 + k, 92 - elev) for k in range(0, 11)], mix(sap, MARROM_E, 0.7))
        f.pontos([(x0, 89 - elev), (x0 + 1, 89 - elev), (x0 + 2, 89 - elev)], luz(sap))
        if pid in ("protagonista", "davi"):
            f.pontos([(x0 + k, 90 - elev) for k in range(-1, 8)], MENTA if pid == "protagonista" else AZUL_P)
        if pid == "euler":
            f.pontos([(x0 + 2, 88 - elev), (x0 + 4, 88 - elev)], CREME)

    # --- tronco conforme o traje
    if traje in ("jaleco", "paleto", "cardiga"):
        f.parte(m_poly([(22, 38 + bob), (42, 38 + bob), (45, 70), (19, 70)]), jaleco, contorno=contorno_j)
        f.parte(m_poly([(28, 38 + bob), (36, 38 + bob), (35, 70), (29, 70)]), d["roupa"])
        if pid == "euler":
            f.pontos([(32, 60), (32, 65)], AREIA)
        f.pontos([(24, yy) for yy in range(50, 68)], sombra(jaleco))
        f.pontos([(40, yy) for yy in range(50, 68)], sombra(jaleco))
        f.pontos([(x, 69) for x in range(20, 45)], sombra(jaleco))
        f.pontos([(27, 66), (28, 66), (36, 66), (37, 66)], sombra(jaleco))
        if traje != "cardiga":
            f.parte(m_poly([(25, 37 + bob), (32, 37 + bob), (32, 47 + bob), (27, 42 + bob)]), jaleco, contorno=contorno_j)
            f.parte(m_poly([(39, 37 + bob), (32, 37 + bob), (32, 47 + bob), (37, 42 + bob)]), jaleco, contorno=contorno_j)
        f.pontos([(32, 62), (32, 66)], MENTA if pid != "euler" else AMARELO)
        if traje != "cardiga":
            f.parte(m_rect(36, 56 + bob // 2, 43, 63 + bob // 2), jaleco, contorno=contorno_j)
            f.pontos([(39, 54 + bob // 2), (39, 55 + bob // 2)], AZUL_N)
            f.pontos([(40, 54 + bob // 2), (40, 55 + bob // 2)], VERMELHO)
        else:  # cardiga: botoes grandes e gola em V
            for yy in (50, 56, 62):
                f.pontos([(31, yy), (33, yy)], CREME)
            f.parte(m_poly([(28, 38 + bob), (36, 38 + bob), (32, 46 + bob)]), d["roupa"], contorno=None)
        if pid == "euler":
            f.pontos([(37, 55), (38, 55), (37, 56)], ROSA)
    elif traje == "moletom":
        f.parte(m_poly([(22, 38 + bob), (42, 38 + bob), (45, 70), (19, 70)]), jaleco, contorno=contorno_j)
        f.pontos([(x, 69) for x in range(20, 45)], sombra(jaleco))
        f.pontos([(24, yy) for yy in range(48, 66)], sombra(jaleco))
        f.pontos([(40, yy) for yy in range(48, 66)], sombra(jaleco))
        f.parte(m_poly([(26, 57), (38, 57), (40, 67), (24, 67)]), jaleco, contorno=contorno_j)   # bolso canguru
        f.pontos([(32, yy) for yy in range(40 + bob, 52)], sombra(jaleco))                      # zipper
        f.pontos([(30, 41 + bob), (30, 45 + bob), (34, 41 + bob), (34, 45 + bob)], BRANCO)       # cordoes
        f.parte(m_rect(24, 44, 27, 60), hexa("#A84A4A"), sombrear=False)                         # alca da mochila
        f.parte(m_rect(37, 44, 40, 60), hexa("#A84A4A"), sombrear=False)
        f.parte(m_poly([(27, 38 + bob), (37, 38 + bob), (32, 44 + bob)]), d["roupa"], contorno=None)
    elif traje == "colete":
        f.parte(m_poly([(22, 38 + bob), (42, 38 + bob), (45, 70), (19, 70)]), d["roupa"])           # camisa
        f.parte(m_poly([(22, 40 + bob), (42, 40 + bob), (44, 70), (20, 70)]), jaleco, contorno=contorno_j)  # colete
        f.pontos([(32, yy) for yy in range(42 + bob, 70)], sombra(jaleco))
        f.pontos([(x, 60) for x in range(21, 44)], sombra(jaleco))
        f.pontos([(x, 61) for x in range(21, 44)], hexa("#F2D675"))                              # faixa refletiva
        f.pontos([(x, 66) for x in range(20, 44)], hexa("#F2D675"))
        f.parte(m_poly([(26, 38 + bob), (32, 38 + bob), (32, 46 + bob)]), d["roupa"], contorno=None)
        f.parte(m_poly([(38, 38 + bob), (32, 38 + bob), (32, 46 + bob)]), d["roupa"], contorno=None)
        f.parte(m_rect(23, 50 + bob // 2, 30, 57 + bob // 2), jaleco, contorno=contorno_j)
        f.parte(m_rect(34, 50 + bob // 2, 41, 57 + bob // 2), jaleco, contorno=contorno_j)
        f.pontos([(x, 69) for x in range(20, 44)], sombra(jaleco))
        # chaveiro no cinto
        f.pontos([(41, 67), (42, 68), (41, 69)], hexa("#C9A24A"))
        for kx in (40, 42, 44):
            f.pontos([(kx, 70), (kx, 71)], hexa("#E3CDA4"))

    # --- pescoco + cabeca
    f.parte(m_rect(29, 32 + bob, 36, 38 + bob), pele)
    f.pontos([(x, 34 + bob) for x in range(29, 36)], sombra(pele))
    f.pontos([(x, 35 + bob) for x in range(29, 36)], sombra(pele))
    for sx in (-1, 1):
        f.parte(m_elipse(cx + sx * 10, 24 + bob, 2.2, 3.2), pele)
        f.put(cx + sx * 10, 24 + bob, sombra(pele))
        f.put(cx + sx * 10, 25 + bob, sombra(pele))
    f.parte(m_elipse(cx, 23 + bob, 10.5, 11.5), pele)
    f.pontos([(26, 15 + bob), (27, 14 + bob), (28, 14 + bob)], luz(pele))

    # --- cabelo da frente
    if estilo == "curto":
        f.parte(m_poly([(20, 25 + bob), (20, 15 + bob), (24, 9 + bob), (31, 6 + bob), (39, 7 + bob), (43, 12 + bob), (44, 25 + bob),
                        (42, 19 + bob), (38, 14 + bob), (33, 17 + bob), (27, 15 + bob), (23, 21 + bob)]), cab)
        f.parte(m_elipse(37, 5 + bob, 3, 2.5), cab)
        f.parte(m_poly([(24, 14 + bob), (33, 12 + bob), (35, 16 + bob), (27, 18 + bob)]), cab)
        for (x, y) in [(25, 10), (26, 9), (28, 8), (30, 8), (23, 13), (24, 12), (29, 13), (31, 13)]:
            f.put(x, y + bob, luz(cab))
        for (x, y) in [(36, 12), (38, 13), (40, 14), (33, 15)]:
            f.put(x, y + bob, sombra(cab))
    elif estilo == "coque":
        f.parte(m_poly([(20, 27 + bob), (20, 15 + bob), (26, 9 + bob), (38, 9 + bob), (44, 15 + bob), (44, 27 + bob),
                        (41, 19 + bob), (33, 14 + bob), (26, 16 + bob), (23, 21 + bob)]), cab)
        f.parte(m_poly([(24, 12 + bob), (34, 11 + bob), (30, 17 + bob)]), cab)
        for (x, y) in [(24, 11), (26, 10), (28, 10), (22, 15), (23, 14), (21, 19), (30, 12)]:
            f.put(x, y + bob, luz(cab))
        for (x, y) in [(40, 13), (42, 16), (43, 20), (36, 12)]:
            f.put(x, y + bob, sombra(cab))
        f.pontos([(31, 6 + bob), (32, 5 + bob), (33, 6 + bob)], luz(cab))
        f.parte(m_rect(30, 11 + bob, 35, 13 + bob), AMARELO)
    elif estilo == "careca":
        f.pontos([(26, 11 + bob), (27, 10 + bob), (28, 10 + bob), (27, 12 + bob)], BRANCO)
        f.pontos([(28, 10 + bob), (29, 10 + bob)], luz(pele))
    elif estilo == "cacheado":   # cachos volumosos
        for (ccx, ccy, r) in [(24, 12, 4.5), (32, 9, 5), (40, 12, 4.5), (21, 18, 3.5), (43, 18, 3.5), (28, 14, 3), (36, 14, 3)]:
            f.parte(m_elipse(ccx, ccy + bob, r, r), cab)
        f.parte(m_poly([(22, 17 + bob), (30, 13 + bob), (34, 14 + bob), (42, 17 + bob), (40, 14 + bob), (32, 11 + bob), (24, 14 + bob)]), cab, contorno=None)
        for (x, y) in [(23, 10), (24, 9), (31, 6), (32, 6), (38, 9), (39, 9), (20, 16), (43, 16), (27, 12), (36, 12)]:
            f.put(x, y + bob, luz(cab))
        for (x, y) in [(26, 15), (30, 15), (34, 15), (38, 15)]:
            f.put(x, y + bob, sombra(cab))
    elif estilo == "lenco":      # cabelo curto grisalho + lenco amarelo com bolinhas
        f.parte(m_poly([(20, 27 + bob), (20, 16 + bob), (25, 10 + bob), (39, 10 + bob), (44, 16 + bob), (44, 27 + bob),
                        (41, 20 + bob), (32, 17 + bob), (23, 20 + bob)]), cab)
        f.parte(m_poly([(20, 17 + bob), (25, 9 + bob), (39, 9 + bob), (44, 17 + bob), (40, 14 + bob), (32, 12 + bob), (24, 14 + bob)]), AMARELO)
        for (x, y) in [(25, 11), (28, 10), (31, 12), (34, 10), (38, 11), (42, 15), (22, 15)]:
            f.put(x, y + bob, VERMELHO)
        f.parte(m_poly([(41, 11 + bob), (47, 7 + bob), (47, 13 + bob)]), AMARELO)           # no do lenco
        f.parte(m_poly([(41, 11 + bob), (46, 15 + bob), (44, 17 + bob)]), AMARELO)
        for (x, y) in [(22, 21), (21, 24), (43, 22)]:
            f.put(x, y + bob, luz(cab))
    elif estilo == "rabo":       # franja bagunçada + presilha/lapis
        f.parte(m_poly([(20, 25 + bob), (20, 15 + bob), (25, 9 + bob), (39, 9 + bob), (44, 15 + bob), (43, 24 + bob),
                        (40, 17 + bob), (36, 16 + bob), (30, 15 + bob), (25, 18 + bob), (23, 22 + bob)]), cab)
        f.parte(m_poly([(25, 12 + bob), (35, 11 + bob), (28, 18 + bob)]), cab)
        f.pontos([(21, 20 + bob), (21, 22 + bob), (43, 19 + bob), (42, 17 + bob), (20, 18 + bob)], cab)  # fios soltos
        for (x, y) in [(25, 10), (27, 9), (30, 9), (33, 9), (23, 13), (24, 12)]:
            f.put(x, y + bob, luz(cab))
        for (x, y) in [(38, 13), (40, 15), (34, 14)]:
            f.put(x, y + bob, sombra(cab))
        f.parte(m_rect(41, 12 + bob, 46, 15 + bob), VERMELHO)                                 # xuxinha
        f.pontos([(38 + k, 8 + bob - k // 2) for k in range(0, 8)], AMARELO)                  # lapis no cabelo
        f.put(45, 5 + bob, ROSA)
        f.put(37, 8 + bob, MARROM_E)

    # --- rosto
    ey = 23 + bob
    iris = d["iris"]
    fecha = q["pisca"]
    cilios = pid in ("helena", "beatriz")
    olho(f, 26, ey, iris, cilios=cilios, fechado=fecha, pele=pele)
    olho(f, 35, ey, iris, cilios=cilios, fechado=fecha, pele=pele)
    if pid == "beatriz":      # olheiras
        for ex in (26, 35):
            f.pontos([(ex, ey + 4), (ex + 1, ey + 4), (ex + 2, ey + 4), (ex + 3, ey + 4)], mix(pele, hexa("#9A7AA8"), 0.55))
    # sobrancelhas
    alt = 1 if (bocao == "abre2" or sobr == "alto") else 0
    if pid == "euler":
        cor_sobr = mix(CINZA_G, BRANCO, 0.3)
        for ex in (25, 35):
            f.pontos([(ex + k, ey - 5 - alt) for k in range(0, 5)], cor_sobr)
            f.pontos([(ex + k, ey - 4 - alt) for k in range(1, 4)], cor_sobr)
    else:
        cor_sobr = sombra(cab) if pid != "rita" else mix(cab, OUT, 0.5)
        b0 = ey - 4 - alt
        if sobr == "inclina" or (ansioso and bocao == "fecha" and not fecha):
            f.pontos([(26, b0 + 1), (27, b0 + 1), (28, b0), (29, b0 - 1)], cor_sobr)
            f.pontos([(35, b0 - 1), (36, b0), (37, b0 + 1), (38, b0 + 1)], cor_sobr)
        else:
            f.pontos([(26, b0 + 1), (27, b0), (28, b0), (29, b0)], cor_sobr)
            f.pontos([(35, b0), (36, b0), (37, b0), (38, b0 + 1)], cor_sobr)
    # nariz e bochechas
    f.pontos([(32, ey + 3), (33, ey + 3)], sombra(pele))
    f.put(32, ey + 4, sombra(pele))
    f.put(33, ey + 4, mix(pele, luz(pele), 0.5))
    rubor = mix(pele, ROSA, 0.75)
    for bx in (23, 40):
        f.pontos([(bx, ey + 5), (bx + 1, ey + 5), (bx + 1, ey + 6)], rubor)
    if pid in ("protagonista", "davi"):
        for (x, y) in [(27, ey + 4), (29, ey + 5), (36, ey + 5), (38, ey + 4)]:
            f.put(x, y, sombra(pele))
    # oculos (Helena, Euler)
    if pid in ("helena", "euler"):
        arm = AZUL_N if pid == "helena" else hexa("#C9A24A")
        for ex in (24, 34):
            for x in range(ex, ex + 7):
                f.put(x, ey - 2, arm)
                f.put(x, ey + 4, arm)
            for y in range(ey - 2, ey + 5):
                f.put(ex, y, arm)
                f.put(ex + 6, y, arm)
            f.put(ex + 1, ey - 1, mix(BRANCO, AZUL_P, 0.5))
            f.put(ex + 2, ey - 1, mix(BRANCO, AZUL_P, 0.5))
        f.pontos([(30, ey), (31, ey), (32, ey), (33, ey)], arm)
        f.put(23, ey - 1, arm)
        f.put(41, ey - 1, arm)
    if pid == "euler":
        f.parte(m_poly([(27, 28 + bob), (37, 28 + bob), (40, 32 + bob), (36, 31 + bob), (32, 29 + bob), (28, 31 + bob), (25, 32 + bob)]),
                mix(cab, BRANCO, 0.2), contorno=None)
        f.pontos([(31, 28 + bob), (32, 28 + bob)], sombra(pele))
        f.put(32, ey + 4, mix(pele, ROSA, 0.6))
    if pid == "rita":         # rugas de expressao
        f.pontos([(24, ey + 3), (23, ey + 4), (40, ey + 3), (41, ey + 4)], sombra(pele))
    # boca
    my = 29 + bob if pid != "euler" else 32 + bob
    labio = mix(ROSA, VERMELHO, 0.55)
    if pid == "rita":
        labio = mix(VERMELHO, MARROM_E, 0.2)
    if bocao == "fecha":
        f.pontos([(30, my), (31, my), (32, my), (33, my)], labio)
        f.pontos([(30, my + 1), (31, my + 1), (32, my + 1), (33, my + 1)], mix(labio, sombra(pele), 0.5))
    elif bocao == "sorri":
        f.pontos([(29, my - 1), (30, my), (31, my + 1), (32, my + 1), (33, my + 1), (34, my), (35, my - 1)], labio)
        f.pontos([(31, my), (32, my), (33, my)], BRANCO)
    elif bocao == "abre1":
        f.retangulo(30, my, 35, my + 3, mix(OUT, VERMELHO, 0.25))
        f.pontos([(31, my), (32, my), (33, my), (34, my)], BRANCO)
        f.retangulo(31, my + 2, 34, my + 3, VERMELHO)
    elif bocao == "abre2":
        f.retangulo(29, my, 36, my + 5, mix(OUT, VERMELHO, 0.25))
        f.pontos([(30 + k, my) for k in range(5)], BRANCO)
        f.retangulo(31, my + 3, 35, my + 5, VERMELHO)
    elif bocao == "preocupa":
        f.pontos([(30, my + 1), (31, my), (32, my), (33, my), (34, my + 1)], labio)
        f.pontos([(29, my + 2), (35, my + 2)], mix(labio, sombra(pele), 0.5))
    elif bocao == "surpresa":
        f.retangulo(31, my - 1, 34, my + 3, mix(OUT, VERMELHO, 0.25))
        f.retangulo(32, my + 1, 33, my + 3, VERMELHO)
    if (ansioso and (q["bob"] == 1 or bocao == "preocupa")) or bocao == "surpresa" and ansioso:
        f.pontos([(44, 16 + bob), (43, 17 + bob), (44, 17 + bob), (45, 17 + bob), (44, 18 + bob)], AZUL_P)   # gota de suor
        f.put(44, 16 + bob, BRANCO)

    # --- acessorios por personagem
    if pid == "protagonista":
        for (x, y) in [(27, 38), (26, 40), (26, 43), (27, 46), (29, 48), (31, 49), (33, 49), (35, 48), (37, 46), (38, 43), (38, 40), (37, 38)]:
            f.put(x, y + bob, CINZA_G)
            f.put(x + 1 if x < 32 else x - 1, y + bob, luz(CINZA_G))
        f.parte(m_elipse(32, 52 + bob, 2.8, 2.8), CINZA_G)
        f.put(31, 51 + bob, BRANCO)
        f.pontos([(23, 40 + bob), (24, 44 + bob), (25, 48 + bob), (25, 52 + bob)], AZUL_P)
        f.parte(m_rect(22, 55 + bob // 2, 28, 61 + bob // 2), BRANCO)
        f.pontos([(23, 56 + bob // 2), (24, 56 + bob // 2), (25, 56 + bob // 2), (26, 56 + bob // 2)], AZUL_P)
        f.pontos([(24, 58 + bob // 2), (26, 58 + bob // 2), (25, 59 + bob // 2)], MARROM_E)
    if pid == "helena":
        for (x, y) in [(27, 38), (28, 40), (30, 41), (32, 42), (34, 41), (36, 40), (37, 38)]:
            f.put(x, y + bob, BRANCO)
            f.put(x, y + 1 + bob, mix(ROSA, BRANCO, 0.5))
        f.parte(m_elipse(32, 45 + bob, 2.5, 2.5), MENTA)
        f.pontos([(31, 45 + bob), (33, 45 + bob), (32, 46 + bob)], FOLHA)
        f.put(cx - 10, 28 + bob, AMARELO)
        f.put(cx + 10, 28 + bob, AMARELO)
    if pid == "davi":      # fones de ouvido no pescoco
        f.parte(m_capsula(24, 36 + bob, 40, 36 + bob, 1.6), hexa("#2A2420"), contorno=None, sombrear=False)
        for ex in (22, 42):
            f.parte(m_elipse(ex, 38 + bob, 3.2, 3.8), hexa("#D96C6C"))
            f.put(ex - 1, 37 + bob, luz(hexa("#D96C6C")))
    if pid == "rita":      # cracha com cordao e broche de patinha
        f.pontos([(26, 40 + bob), (27, 44 + bob), (28, 48 + bob)], VERMELHO)
        f.pontos([(38, 40 + bob), (37, 44 + bob), (36, 48 + bob)], VERMELHO)
        f.parte(m_rect(29, 49 + bob // 2, 36, 57 + bob // 2), BRANCO)
        f.pontos([(30, 50 + bob // 2), (31, 50 + bob // 2), (32, 50 + bob // 2), (33, 50 + bob // 2), (34, 50 + bob // 2)], VERDE_CRACHA)
        f.pontos([(31, 53 + bob // 2), (33, 53 + bob // 2), (32, 54 + bob // 2)], MARROM_E)
        f.put(cx - 10, 28 + bob, hexa("#C9A24A"))
        f.put(cx + 10, 28 + bob, hexa("#C9A24A"))
    if pid == "beatriz":   # colar fino + cracha da biblioteca
        f.pontos([(28, 38 + bob), (30, 41 + bob), (32, 42 + bob), (34, 41 + bob), (36, 38 + bob)], AMARELO)
        f.pontos([(24, 56 + bob // 2), (25, 56 + bob // 2), (24, 57 + bob // 2)], CINZA_G)

    # --- bracos da frente
    be, bd = q["be"], q["bd"]
    manga = d["manga"]

    def braco(lado, pose):
        ombro = (21 if lado == 0 else 43, 41 + bob)
        (ex, ey2), (mx, my2) = BRACO[pose]
        if lado == 1:
            e = (ombro[0] - ex, ombro[1] + ey2)
            m = (ombro[0] - mx, ombro[1] + my2)
        else:
            e = (ombro[0] + ex, ombro[1] + ey2)
            m = (ombro[0] + mx, ombro[1] + my2)
        cm = mix(manga, OUT, 0.8)
        f.parte(m_capsula(ombro[0], ombro[1], e[0], e[1], 3.4), manga, contorno=cm)
        f.parte(m_capsula(e[0], e[1], m[0], m[1], 3.2), manga, contorno=cm)
        if pid == "euler":
            f.parte(m_elipse(e[0], e[1], 2.2, 2.2), MADEIRA, contorno=None)
        pun = (m[0] + (e[0] - m[0]) * 0.28, m[1] + (e[1] - m[1]) * 0.28)
        f.parte(m_elipse(pun[0], pun[1], 3.4, 3.2), mix(manga, sombra(manga), 0.4), contorno=cm)
        f.parte(m_elipse(m[0], m[1], 3, 3), pele)
        f.put(int(m[0]), int(m[1]) + 2, sombra(pele))
        f.put(int(m[0]) + (2 if lado == 0 else -2), int(m[1]) - 1, luz(pele))
        if pid == "protagonista" and lado == 0:
            f.pontos([(int(pun[0]) - 1, int(pun[1]) + 1), (int(pun[0]), int(pun[1]) + 1)], CINZA_G)
        if pid == "beatriz" and lado == 0:   # pulseira
            f.pontos([(int(pun[0]) - 1, int(pun[1]) + 1), (int(pun[0]), int(pun[1]) + 1)], VERMELHO)
        return m

    if pid == "helena":
        mx, my2 = 21 + BRACO["prancha"][1][0], 41 + bob + BRACO["prancha"][1][1]
        f.parte(m_rect(mx - 6, my2 - 11, mx + 4, my2 + 4), CREME)
        f.parte(m_rect(mx - 3, my2 - 13, mx + 1, my2 - 10), CINZA_G)
        for yy in (my2 - 7, my2 - 4, my2 - 1):
            f.pontos([(mx - 4 + x, yy) for x in range(0, 6)], AZUL_N)
        f.pontos([(mx + 1, my2 + 1), (mx + 2, my2 + 1), (mx + 1, my2)], VERMELHO)
        m = braco(0, "prancha")
    else:
        m = braco(0, be)
    braco(1, bd)

    # --- caixas de transporte / itens dos tutores
    if d["pets"]:
        gesto = bd in ("gesto1", "gesto2", "tchau1", "tchau2")
        hx, hy = m
        pet_a, pet_b = d["pets"]
        caixa_gato(f, hx - 7, hy + 3, pet_a)
        f.parte(m_elipse(hx, hy, 3, 3), pele)
        if gesto:   # item da mao direita vai ao chao para liberar o braco
            if pet_b == "racao":
                saco_racao(f, 45, 76)
            else:
                caixa_gato(f, 45, 76, pet_b)
        else:
            (_, (mx2, my2)) = BRACO[bd]
            hx2, hy2 = 43 - mx2, 41 + bob + my2
            if pet_b == "racao":
                saco_racao(f, hx2 - 8, hy2 + 3)
            else:
                caixa_gato(f, hx2 - 8, hy2 + 3, pet_b)
            f.parte(m_elipse(hx2, hy2, 3, 3), pele)
    if pid == "euler":
        f.parte(m_poly([(31, 40 + bob), (34, 40 + bob), (35, 52 + bob), (32, 57 + bob), (30, 52 + bob)]), VERMELHO)
        for yy in (44, 48, 52):
            f.pontos([(31, yy + bob), (32, yy + bob), (33, yy + bob)], mix(VERMELHO, BRANCO, 0.4))
        f.pontos([(38, 56), (39, 57), (40, 58), (41, 59)], AMARELO)
    return f


# --- PNG sem dependencias ----------------------------------------------------
def salvar_png(quadro, caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    linhas = []
    for y in range(quadro.h):
        linha = bytearray([0])
        for x in range(quadro.w):
            c = quadro.p[y][x]
            linha += bytes(c) if c else b"\x00\x00\x00\x00"
        linhas.append(bytes(linha))
    bruto = b"".join(linhas)

    def chunk(tag, dados):
        corpo = tag + dados
        return struct.pack(">I", len(dados)) + corpo + struct.pack(">I", zlib.crc32(corpo) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", quadro.w, quadro.h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bruto, 9)) + chunk(b"IEND", b"")
    with open(caminho, "wb") as fh:
        fh.write(png)


def colar(destino, origem, ox, oy):
    for y in range(origem.h):
        for x in range(origem.w):
            c = origem.p[y][x]
            if c:
                destino.put(ox + x, oy + y, c)


def retrato(pid, expressao):
    pose = dict(bob=0, boca=expressao, pern=(0, 0), be="baixo", bd="baixo", pisca=False)
    if expressao == "preocupa":
        pose["sobr"] = "inclina"
    if expressao == "surpresa":
        pose["sobr"] = "alto"
    quadro = desenhar(pid, pose)
    r = Quadro(64, 64)
    for y in range(32):
        for x in range(32):
            c = quadro.p[2 + y][16 + x]
            if c:
                for dy in (0, 1):
                    for dx in (0, 1):
                        r.put(x * 2 + dx, y * 2 + dy, c)
    return r


def main():
    meta = {"quadro": [W, H], "ancora": "centro-inferior", "linhas": ANIMS, "colunas": 4, "personagens": {}}
    elenco = Quadro((W + 8) * len(PERSONAGENS), H)
    for i, (pid, d) in enumerate(PERSONAGENS.items()):
        pasta = os.path.join(SAIDA, pid)
        folha = Quadro(W * 4, H * len(ANIMS))
        for linha, anim in enumerate(ANIMS):
            for col, q in enumerate(QUADROS[anim]):
                fr = desenhar(pid, q)
                colar(folha, fr, col * W, linha * H)
                salvar_png(fr, os.path.join(pasta, "frames", f"{anim}_{col}.png"))
        salvar_png(folha, os.path.join(pasta, f"{pid}_sheet.png"))

        ret = Quadro(64 * len(EXPRESSOES), 64)
        for k, expr in enumerate(EXPRESSOES):
            colar(ret, retrato(pid, expr), k * 64, 0)
        salvar_png(ret, os.path.join(pasta, f"{pid}_retratos.png"))

        colar(elenco, desenhar(pid, QUADROS["idle"][0]), i * (W + 8), 0)
        meta["personagens"][pid] = dict(nome=d["nome"], arquetipo=d["arquetipo"], pets=list(d["pets"]), folha=f"{pid}/{pid}_sheet.png", retratos=f"{pid}/{pid}_retratos.png")
    salvar_png(elenco, os.path.join(SAIDA, "elenco.png"))
    meta["fps"] = FPS
    meta["retratos"] = ["neutro", "falando", "sorrindo", "preocupado", "surpreso"]
    with open(os.path.join(SAIDA, "personagens.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    print("OK ->", SAIDA)


if __name__ == "__main__":
    main()
