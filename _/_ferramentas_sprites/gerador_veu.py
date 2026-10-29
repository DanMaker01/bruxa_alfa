"""
gerador_veu.py - gera os quadros de um "véu" com N folhas transparentes ondulando.

Todas as folhas ficam presas no mesmo topo, iguais e sobrepostas (cortina num varão).
Descendo, cada uma cai: abre um pouco, a base se desloca e ondula cada vez mais.
As folhas se revezam vindo para a frente (base desce/abre, mais opaca) e indo para trás.

Garantia: nada sai do quadro. Antes de desenhar, o gerador calcula o pior caso
(onda + deslocamento + abertura + profundidade). Se não couber, por padrão aumenta o
PNG (--ajuste png) e mantém o movimento; com --ajuste movimento mantém o PNG e reduz
esses valores na mesma proporção. Nos dois casos avisa. Depois confere os PNGs (borda sempre transparente).

Precisa de Python 3 com numpy e Pillow:   pip install numpy pillow
Exemplos (de qualquer pasta; os PNGs vão para assets/eventos/veu do projeto):
    python gerador_veu.py
    python gerador_veu.py --cores "#d7aaff" "#a0e6ff" "#ffd0e0" --nome veu3 --tres ../../animacoes/veu.tres
    python gerador_veu.py --fps 4 --voltas_onda 2 --voltas_alternancia 1 --amplitude 4
    python gerador_veu.py --png_largura 128 --png_altura 256   (folhas acompanham o tamanho)
    python gerador_veu.py -h        (lista tudo)

Por padrão também grava um GIF animado de prévia (<nome>.gif, na mesma pasta deste script),
na velocidade do --fps, sobre um fundo roxo escuro. --gif "" desliga.

Para o loop fechar sem pulo, voltas_onda e voltas_alternancia são inteiros:
são quantas vezes a onda e a troca frente/trás acontecem dentro de um ciclo.
"""
import argparse
import math
import os

import numpy as np
from PIL import Image

# pasta deste script e raiz do projeto (a pasta com project.godot, procurando para cima):
# assim os caminhos padrão funcionam de onde quer que o script seja rodado
PASTA_SCRIPT = os.path.dirname(os.path.abspath(__file__))


def raiz_projeto():
    d = PASTA_SCRIPT
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "project.godot")):
            return d
        d = os.path.dirname(d)
    return PASTA_SCRIPT


# =============================================================================
# DESENHO DE UMA FOLHA
# =============================================================================
def mascara(W, H, ss, cx, topo, w, h, p):
    """Cobertura (0..1) de uma folha presa no topo (de cx - w/2 a cx + w/2, em y = topo).
    p: dict com amp, ondas, fase, sentido, caimento, ox, oy, abre, assim.
    Supersampling ss x ss para bordas suaves."""
    Ws, Hs = W * ss, H * ss
    m = np.zeros((Hs, Ws))
    y0, y1 = topo * ss, (topo + h + p["oy"]) * ss
    xs = np.arange(Ws) + 0.5
    for ys in range(max(0, math.floor(y0)), min(Hs, math.ceil(y1))):
        yc = ys + 0.5
        if yc < y0 or yc > y1:
            continue
        u = (yc - y0) / (y1 - y0)                     # 0 no topo (preso), 1 na base (solta)
        solta = u ** p["caimento"]                    # quanto esta altura já "cai" (0 no topo)
        onda = math.sin(2 * math.pi * p["ondas"] * u * p["sentido"] - p["fase"])
        dx = p["amp"] * solta * onda + p["ox"] * solta
        meia = w / 2 * (1 + p["abre"] * solta)
        esq = cx - meia + dx
        dir_ = cx + meia + dx * (1 - p["assim"])      # lado direito acompanha um pouco menos
        m[ys] = (xs >= esq * ss) & (xs <= dir_ * ss)
    return m.reshape(H, ss, W, ss).mean(axis=(1, 3))


# =============================================================================
# GARANTIA: CABER NO QUADRO
# =============================================================================
def tamanho_minimo(a):
    """Menor PNG (largura, altura) em que a folha cabe com TODO o movimento pedido."""
    extra_x = a.largura / 2 * (a.abre + a.profundidade) + a.amplitude + abs(a.defasagem[0])
    pede_y = abs(a.defasagem[1]) + a.altura * a.profundidade
    w_min = a.largura + 2 * (a.margem + extra_x)
    if a.topo < 0:                                     # topo centralizado
        h_min = a.altura + 2 * (a.margem + pede_y)
    else:
        h_min = max(a.topo, a.margem) + a.altura + pede_y + a.margem
    par = lambda v: int(math.ceil(v / 2.0) * 2)        # arredonda para cima, número par
    return par(w_min), par(h_min)


def ajustar_para_caber(a, W, H, topo):
    """Pior caso de cada lado e da base. Se passar da margem, reduz os movimentos."""
    margem = a.margem
    # horizontal: meia largura na base + onda + deslocamento da base
    folga = W / 2 - margem - a.largura / 2            # o que sobra com a folha parada
    if folga < 0:
        raise SystemExit("A folha (largura %s) não cabe no quadro de %s px com margem %s."
                         % (a.largura, W, margem))
    extra = a.largura / 2 * (a.abre + a.profundidade) + a.amplitude + a.defasagem[0]
    if extra > folga:
        k = folga / extra
        a.amplitude *= k
        a.defasagem[0] *= k
        a.abre *= k
        a.profundidade *= k
        print("Aviso: movimento horizontal reduzido para %.0f%% para caber no quadro." % (k * 100))
    # vertical: base = topo + altura + defasagem_y + altura*profundidade
    limite = H - margem
    if topo < margem or topo + a.altura > limite:
        raise SystemExit("A folha (altura %s, topo %s) não cabe no quadro de %s px com margem %s."
                         % (a.altura, topo, H, margem))
    pede = abs(a.defasagem[1]) + a.altura * a.profundidade
    sobra = limite - (topo + a.altura)
    if pede > sobra:
        k = sobra / pede
        a.defasagem[1] *= k
        a.profundidade *= k
        print("Aviso: movimento vertical reduzido para %.0f%% para caber no quadro." % (k * 100))


# =============================================================================
# GERAÇÃO
# =============================================================================
def hex_para_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255.0


def salvar_gif(a, quadros):
    """GIF animado de prévia (GIF não tem transparência boa: vai sobre uma cor de fundo)."""
    fundo = tuple(int(c * 255) for c in hex_para_rgb(a.fundo_gif))
    imgs = []
    for q in quadros:
        base = Image.new("RGBA", (q.shape[1], q.shape[0]), fundo + (255,))
        base.alpha_composite(Image.fromarray(q, "RGBA"))
        if a.escala_gif != 1:
            base = base.resize((q.shape[1] * a.escala_gif, q.shape[0] * a.escala_gif), Image.NEAREST)
        imgs.append(base.convert("RGB"))
    caminho = a.gif if a.gif != "auto" else os.path.join(PASTA_SCRIPT, "%s.gif" % a.nome)
    imgs[0].save(caminho, save_all=True, append_images=imgs[1:], loop=0,
                 duration=int(round(1000 / a.fps)))
    print("GIF de prévia gravado em", caminho)


def gerar(a):
    cores = [hex_para_rgb(c) for c in a.cores]
    n = len(cores)
    W, H = a.png_largura, a.png_altura
    # folha sem tamanho escolhido: proporcional ao PNG (75% da largura, 85% da altura)
    if a.largura is None:
        a.largura = round(W * 0.75)
    if a.altura is None:
        a.altura = round(H * 0.85)
    # se não couber: "png" aumenta o PNG (mantém o movimento); "movimento" reduz o movimento
    if a.ajuste == "png":
        w_min, h_min = tamanho_minimo(a)
        if w_min > W or h_min > H:
            W, H = max(W, w_min), max(H, h_min)
            print("PNG aumentado para %dx%d para caber todo o movimento "
                  "(use --ajuste movimento para manter o tamanho e reduzir o movimento)." % (W, H))
    cx = W / 2
    topo = (H - a.altura) / 2 if a.topo < 0 else a.topo   # todas presas no mesmo topo
    ajustar_para_caber(a, W, H, topo)
    # defasagem entre as folhas: --fases em graus, ou espalhadas igualmente (360/N)
    fases = [math.radians(g) for g in a.fases] if a.fases else [2 * math.pi * k / n for k in range(n)]
    if len(fases) != n:
        raise SystemExit("--fases precisa de um valor por cor (%d)." % n)

    os.makedirs(a.saida, exist_ok=True)
    arquivos = []
    quadros_gif = []
    for f in range(a.quadros):
        t = f / a.quadros                                    # 0..1 dentro do ciclo
        folhas = []
        for k in range(n):
            fase_onda = 2 * math.pi * a.voltas_onda * t + fases[k]
            fase_alt = 2 * math.pi * a.voltas_alternancia * t + fases[k]
            prof = math.sin(fase_alt)                        # +1 = na frente, -1 = atrás
            p = {
                "amp": a.amplitude,
                "ondas": a.ondas,
                "fase": fase_onda,
                "sentido": -1 if (a.sentidos_alternados and k % 2) else 1,
                "caimento": a.caimento,
                "ox": a.defasagem[0] * math.cos(fase_alt),
                "oy": a.defasagem[1] * math.sin(fase_alt) + a.altura * a.profundidade * prof,
                "abre": a.abre + a.profundidade * prof,
                "assim": a.assimetria,
            }
            m = mascara(W, H, a.ss, cx, topo, a.largura, a.altura, p)
            alfa = np.clip(a.opacidade + a.var_opacidade * prof, 0, 1) * m
            folhas.append((prof, alfa, cores[k]))
        folhas.sort(key=lambda x: x[0])                      # de trás para a frente
        oa = np.zeros((H, W))
        oc = np.zeros((H, W, 3))
        for _, al, c in folhas:                              # composição "over"
            na = al + oa * (1 - al)
            oc = (c[None, None, :] * al[..., None] + oc * oa[..., None] * (1 - al[..., None])) \
                / np.maximum(na, 1e-9)[..., None]
            oa = na
        img = np.dstack([oc * 255, oa * 255]).clip(0, 255).round().astype(np.uint8)
        # conferência: a borda do quadro tem que ficar transparente
        if a.margem >= 1 and (img[0, :, 3].any() or img[-1, :, 3].any()
                              or img[:, 0, 3].any() or img[:, -1, 3].any()):
            raise SystemExit("Erro: o quadro %d encostou na borda." % (f + 1))
        nome = "%s_%d.png" % (a.nome, f + 1)
        Image.fromarray(img, "RGBA").save(os.path.join(a.saida, nome))
        arquivos.append(nome)
        quadros_gif.append(img)
    print("Gerados %d quadros em %s (%.1f s por ciclo a %s fps)"
          % (len(arquivos), a.saida, a.quadros / a.fps, a.fps))

    if a.gif:
        salvar_gif(a, quadros_gif)

    if a.tres:
        pasta_res = a.pasta_res.rstrip("/")
        ext = "".join('[ext_resource type="Texture2D" path="%s/%s" id="q%d"]\n' % (pasta_res, arq, i + 1)
                      for i, arq in enumerate(arquivos))
        fr = ",\n".join('{\n"duration": 1.0,\n"texture": ExtResource("q%d")\n}' % (i + 1)
                        for i in range(len(arquivos)))
        tres = ('[gd_resource type="SpriteFrames" format=3]\n\n' + ext +
                '\n[resource]\nanimations = [{\n"frames": [' + fr +
                '],\n"loop": true,\n"name": &"default",\n"speed": %s\n}]\n' % float(a.fps))
        with open(a.tres, "w", encoding="utf-8") as arq:
            arq.write(tres)
        print("SpriteFrames gravado em", a.tres)


# =============================================================================
# PARÂMETROS
# =============================================================================
if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Gera quadros de um véu com N folhas ondulando.")
    g = p.add_argument_group("folhas")
    g.add_argument("--cores", nargs="+", default=["#d7aaff", "#a0e6ff"],
                   help="uma cor (hex) por folha; o número de cores é o número de folhas")
    g.add_argument("--opacidade", type=float, default=0.30, help="opacidade média de cada folha (0..1)")
    g.add_argument("--largura", type=float, default=None,
                   help="largura de cada folha no topo, todas iguais (padrão: 75%% da largura do PNG)")
    g.add_argument("--altura", type=float, default=None,
                   help="altura de cada folha (padrão: 85%% da altura do PNG)")
    g.add_argument("--topo", type=float, default=-1, help="y do topo (-1 = centraliza a altura)")

    g = p.add_argument_group("tempo")
    g.add_argument("--quadros", type=int, default=16, help="quantos quadros no ciclo")
    g.add_argument("--fps", type=float, default=5.0, help="velocidade da animação (vai no .tres)")
    g.add_argument("--voltas_onda", type=int, default=1, help="quantas vezes a onda passa por ciclo")
    g.add_argument("--voltas_alternancia", type=int, default=1,
                   help="quantas vezes cada folha vai à frente e volta por ciclo")
    g.add_argument("--fases", type=float, nargs="+", default=None,
                   help="defasagem de cada folha em graus (padrão: 360/N espalhadas)")

    g = p.add_argument_group("oscilação")
    g.add_argument("--amplitude", type=float, default=2.5, help="quanto as laterais ondulam na base (px)")
    g.add_argument("--ondas", type=float, default=1.5, help="quantas ondas cabem na altura")
    g.add_argument("--caimento", type=float, default=1.2,
                   help="curva do caimento: 1 = cresce reto até a base, >1 = solta só embaixo, <1 = solta logo")
    g.add_argument("--abre", type=float, default=0.06, help="quanto a folha alarga até a base (0.06 = 6%%)")
    g.add_argument("--assimetria", type=float, default=0.15,
                   help="lado direito acompanha a onda um pouco menos (0 = igual ao esquerdo)")
    g.add_argument("--sentidos_alternados", type=int, default=1,
                   help="1 = folhas vizinhas ondulam em sentidos opostos, 0 = todas iguais")

    g = p.add_argument_group("alternância frente/trás")
    g.add_argument("--profundidade", type=float, default=0.035,
                   help="quanto a folha da frente desce/abre a mais (0.035 = 3,5%%)")
    g.add_argument("--var_opacidade", type=float, default=0.06,
                   help="quanto a opacidade sobe na frente e desce atrás")
    g.add_argument("--defasagem", type=float, nargs=2, default=[4, 3], metavar=("X", "Y"),
                   help="quanto a base de cada folha se desloca (px), cada uma na sua fase")

    g = p.add_argument_group("saída")
    g.add_argument("--png_largura", type=int, default=96, help="largura do PNG (px)")
    g.add_argument("--png_altura", type=int, default=192, help="altura do PNG (px)")
    g.add_argument("--ajuste", choices=["png", "movimento"], default="png",
                   help='se não couber: "png" aumenta o PNG e mantém o movimento (padrão); '
                        '"movimento" mantém o PNG e reduz o movimento')
    g.add_argument("--margem", type=float, default=2, help="px que ficam sempre vazios em volta")
    g.add_argument("--ss", type=int, default=4, help="supersampling (bordas suaves)")
    g.add_argument("--nome", default="veu2", help="prefixo dos arquivos (veu2 -> veu2_1.png...)")
    g.add_argument("--saida", default=os.path.join(raiz_projeto(), "assets", "eventos", "veu"),
                   help="pasta dos PNGs (padrão: assets/eventos/veu do projeto)")
    g.add_argument("--tres", default="", help="caminho do .tres para gravar (vazio = não grava)")
    g.add_argument("--pasta_res", default="res://assets/eventos/veu", help="pasta res:// dos PNGs, para o .tres")
    g.add_argument("--gif", default="auto",
                   help='GIF animado de prévia: "auto" = <nome>.gif aqui na pasta ferramentas; '
                        'outro caminho = grava lá; "" = não grava')
    g.add_argument("--fundo_gif", default="#3c2850", help="cor de fundo do GIF")
    g.add_argument("--escala_gif", type=int, default=2, help="ampliação do GIF (pixels inteiros)")
    gerar(p.parse_args())
