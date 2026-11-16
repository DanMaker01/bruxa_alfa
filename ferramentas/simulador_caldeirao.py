#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
simulador_caldeirao.py
Simula o caldeirão do jogo fora do Godot, para experimentos automáticos com receitas.

Lê direto do projeto (então acompanha as mudanças):
  src/preparo/sistema_termico.gd   constantes do fogo e do caldo (K, HF, C, CONST_A...)
  src/livro/estados_chama.gd       faixas de temperatura de cada cor de chama
  dados/itens/*.tres               ingredientes (matriz A, m, s-, s+, T_min, T_max, t_min, t_max...)
  dados/receitas/*.tres            receitas (passos_livro)
  dados/pocoes/**/*.tres           catálogo de poções (nome, A, efeito, aproveitamento mínimo)

Mesmas contas do jogo: SistemaTermico.step (DT 0,01), histórico a cada 0,05 s,
CalculadoraPocao (Q, T_max, T_min, duração → aproveitamento; A = B_n···B_1) e o
reconhecimento pelo catálogo (distância de Frobenius <= distancia_max).

Uma "jogadora" simulada segue a receita: acende o fogo, controla a chama (cliques no +Fogo
e segurando o −Fogo) para ficar na cor pedida, espera a cor ficar estável 1 s (como a guia),
joga os itens segurando (um a cada 0,4 s, caem 0,35 s depois) e passa ao passo seguinte
depois dos segundos do passo (contados da entrada do 1º item). Erros e ruído da jogadora
são parâmetros (para distribuições).

USO (na pasta do projeto ou em ferramentas/):
  python simulador_caldeirao.py receitas
  python simulador_caldeirao.py rodar retorno
  python simulador_caldeirao.py rodar calma_profunda --seg 1=+5 --chama 2=amarelo
  python simulador_caldeirao.py tempo retorno --passo 1 --de -20 --ate 20
  python simulador_caldeirao.py chama retorno --passo 0
  python simulador_caldeirao.py mapa retorno --passo-tempo 1 --passo-chama 0
  python simulador_caldeirao.py monte retorno --n 300 --sigma-seg 2 --ruido 0.08
  python simulador_caldeirao.py janelas
  python simulador_caldeirao.py quantidade retorno --item po_retorno --de 1 --ate 6
  python simulador_caldeirao.py otimizar calma_profunda
  python simulador_caldeirao.py relatorio            (tudo para todas as receitas)

Saída: tabelas no terminal + CSV e PNG em ferramentas/sim_saida/ (PNG precisa de matplotlib).
Passos são numerados como em passos_livro (0, 1, 2...).
"""
import argparse
import csv
import glob
import json
import math
import os
import random
import re
import sys

# =============================================================================
# PROJETO
# =============================================================================
AQUI = os.path.dirname(os.path.abspath(__file__))


def achar_projeto():
    d = AQUI
    for _ in range(4):
        if os.path.exists(os.path.join(d, "project.godot")):
            return d
        d = os.path.dirname(d)
    return os.path.dirname(AQUI)


PROJ = achar_projeto()
SAIDA = os.path.join(AQUI, "sim_saida")


def ler(caminho):
    with open(caminho, encoding="utf-8") as f:
        return f.read()


def const_gd(texto, nome, padrao):
    m = re.search(r"const\s+%s\s*(?::\s*\w+)?\s*=\s*([-\d.eE]+)" % nome, texto)
    return float(m.group(1)) if m else padrao


# =============================================================================
# CONSTANTES DO JOGO (lidas dos .gd)
# =============================================================================
_st = ler(os.path.join(PROJ, "src/preparo/sistema_termico.gd"))
T_AMB = const_gd(_st, "T_AMB", 20.0)
F_EQ = const_gd(_st, "F_EQ", 800.0)
T_EQ = const_gd(_st, "T_EQ", 100.0)
K = const_gd(_st, "K", 0.3)
HF = const_gd(_st, "HF", 0.01)
C = const_gd(_st, "C", 2.0)
C_F = const_gd(_st, "C_F", 2.0)
CONST_A = const_gd(_st, "CONST_A", 30.0)
CONST_C = const_gd(_st, "CONST_C", 20.0)
F_LIMIT_MIN = const_gd(_st, "F_LIMIT_MIN", 400.0)
DT = const_gd(_st, "DT", 0.01)
H = K * (F_EQ - T_EQ) / (T_EQ - T_AMB)
P_COMB = K * (F_EQ - T_EQ) + HF * (F_EQ - T_AMB)

K_LOGISTICA = const_gd(ler(os.path.join(PROJ, "src/preparo/calculadora_pocao.gd")), "K_LOGISTICA", 9.189587)
INTERVALO_HISTORICO = 0.05      # cena_preparo.gd
ESPERA_SEGURAR = 0.35           # jogar_varios.gd: segurando, o 1º sai depois disto
INTERVALO_ITEM = 0.4            # jogar_varios.gd: um item a cada 0,4 s
VOO_ITEM = 0.35                 # lancador_item.gd: o item cai no caldeirão depois do voo
TEMPO_CHAMA = 1.0               # guia_receita.gd: chama estável por 1 s
INTERVALO_ABAFAR = 0.3          # cena_preparo.gd: segurando o −Fogo, −CONST_C a cada 0,3 s

ESTADOS = []                    # [{"id","nome","T_min","T_max"}]
for m in re.finditer(r'\{"id":\s*"(\w+)",\s*"nome":\s*"([^"]+)",\s*"T_min":\s*([-\d.]+),\s*"T_max":\s*([-\d.]+),\s*"cor":\s*Color\(([^)]*)\)',
                     ler(os.path.join(PROJ, "src/livro/estados_chama.gd"))):
    cor = tuple(float(x) for x in m.group(5).split(",")[:3])
    ESTADOS.append({"id": m.group(1), "nome": m.group(2), "T_min": float(m.group(3)), "T_max": float(m.group(4)),
                    "cor": cor})
ESTADO = {e["id"]: e for e in ESTADOS}


def estado_de_T(T, ligado=True):
    if not ligado:
        return "apagado"
    for e in ESTADOS:
        if e["T_min"] <= T < e["T_max"]:
            return e["id"]
    return "negro"


def T_alvo_estado(eid):
    e = ESTADO[eid]
    lo = max(e["T_min"], T_AMB + 5)
    hi = min(e["T_max"], 220.0)
    return (lo + hi) / 2.0


# =============================================================================
# LEITURA DOS .tres
# =============================================================================
def matriz_tres(txt):
    m = re.search(r"^A = Array\[PackedFloat32Array\]\(\[(.*)\]\)\s*$", txt, re.M)
    if not m:
        return identidade()
    linhas = re.findall(r"PackedFloat32Array\(([^)]*)\)", m.group(1))
    return [[float(x) for x in l.split(",")] for l in linhas]


def campo(txt, nome, padrao=None, tipo=float):
    m = re.search(r"^%s = (.*)$" % nome, txt, re.M)
    if not m:
        return padrao
    v = m.group(1).strip()
    if tipo is str:
        return json.loads(v) if v.startswith('"') else v
    return tipo(v)


def carregar_itens():
    itens = {}
    for p in glob.glob(os.path.join(PROJ, "dados/itens/*.tres")):
        t = ler(p)
        iid = campo(t, "id", None, str)
        if not iid:
            continue
        itens[iid] = {
            "id": iid, "nome": campo(t, "nome", iid, str), "A": matriz_tres(t),
            "m": campo(t, "m", 0.0), "s_menos": campo(t, "s_menos", 0.0), "s_mais": campo(t, "s_mais", 0.0),
            "T_min": campo(t, "T_min", 0.0), "k_min": campo(t, "k_min", 0.0),
            "T_max": campo(t, "T_max", 0.0), "k_max": campo(t, "k_max", 0.0),
            "t_min": campo(t, "t_min", 0.0), "h_min": campo(t, "h_min", 0.0),
            "t_max": campo(t, "t_max", 0.0), "h_max": campo(t, "h_max", 0.0),
        }
    return itens


def carregar_receitas():
    rec = {}
    for p in glob.glob(os.path.join(PROJ, "dados/receitas/*.tres")):
        t = ler(p)
        m = re.search(r"^passos_livro = Array\[Dictionary\]\((\[.*\])\)\s*$", t, re.M)
        if not m:
            continue
        chave = os.path.splitext(os.path.basename(p))[0]
        # poção da receita (ext_resource id="p_pocao" → nome no .tres da poção)
        pocao = ""
        mp = re.search(r'path="res://([^"]+)" id="p_pocao"', t)
        if mp and os.path.exists(os.path.join(PROJ, mp.group(1))):
            pocao = campo(ler(os.path.join(PROJ, mp.group(1))), "nome", "", str)
        rec[chave] = {"chave": chave, "nome": campo(t, "nome", chave, str), "passos": json.loads(m.group(1)),
                      "pocao": pocao, "arquivo": p}
    return rec


def carregar_catalogo():
    cat = []
    dist_max = 0.05
    for p in glob.glob(os.path.join(PROJ, "dados/pocoes/**/*.tres"), recursive=True):
        t = ler(p)
        if 'script_class="CatalogoPocoes"' in t:
            dist_max = campo(t, "distancia_max", dist_max)
            continue
        if 'script_class="PocaoReferencia"' not in t:
            continue
        cat.append({"nome": campo(t, "nome", os.path.basename(p), str), "A": matriz_tres(t),
                    "efeito": bool(re.search(r"^efeito = .*SubResource", t, re.M)),
                    "a_min": campo(t, "aproveitamento_min_efeito", 0.0),
                    "tol": campo(t, "distancia_max", 0.0)})
    return cat, dist_max


# =============================================================================
# MATRIZES
# =============================================================================
def identidade(n=5):
    return [[1.0 if i == j else 0.0 for j in range(n)] for i in range(n)]


def mult(X, Y):
    n = len(X)
    return [[sum(X[i][k] * Y[k][j] for k in range(n)) for j in range(n)] for i in range(n)]


def interpolar(A, a):
    return [[a * A[i][j] + (1 - a) * (1.0 if i == j else 0.0) for j in range(5)] for i in range(5)]


def distancia(A, B):
    return math.sqrt(sum((A[i][j] - B[i][j]) ** 2 for i in range(5) for j in range(5)))


# =============================================================================
# APROVEITAMENTO (CalculadoraPocao)
# =============================================================================
def a_cozimento(Q, m, s_menos, s_mais):
    if m <= 0:
        return 1.0
    s = s_menos if Q < m else s_mais
    if s <= 0:
        return 1.0 if abs(Q - m) < 1e-6 else 0.0
    z = (Q - m) / s
    return math.exp(-0.5 * z * z)


def curva_max(x, x0, h):
    if x0 <= 0 or x <= x0:
        return 1.0
    if h <= 0:
        return 0.0
    x_m = (1 + h * 0.5) * x0
    R = K_LOGISTICA / (h * x0)
    return 1.0 / (1.0 + math.exp(min(60, R * (x - x_m))))


def curva_min(x, x0, h):
    if x0 <= 0 or x >= x0:
        return 1.0
    if h <= 0:
        return 0.0
    x_m = (1 - h * 0.5) * x0
    R = K_LOGISTICA / (h * x0)
    return 1.0 / (1.0 + math.exp(min(60, -R * (x - x_m))))


def diagnostico(item, t0, hist, t_final):
    Q = 0.0
    Tmax, Tmin, n = -1e9, 1e9, 0
    ant = None
    for (t, T) in hist:
        if t > t_final:
            break
        if t < t0:
            continue
        Tmax, Tmin, n = max(Tmax, T), min(Tmin, T), n + 1
        if ant:
            Q += (ant[1] + T) * 0.5 * (t - ant[0])
        ant = (t, T)
    d = {"item": item["id"], "t0": t0, "dur": t_final - t0, "Q": Q,
         "T_max": Tmax if n else 0.0, "T_min": Tmin if n else 0.0}
    d["a_Q"] = a_cozimento(Q, item["m"], item["s_menos"], item["s_mais"])
    d["a_Tmax"] = curva_max(d["T_max"], item["T_max"], item["k_max"]) if n else 1.0
    d["a_Tmin"] = curva_min(d["T_min"], item["T_min"], item["k_min"]) if n else 1.0
    d["a_tmin"] = curva_min(d["dur"], item["t_min"], item["h_min"])
    d["a_tmax"] = curva_max(d["dur"], item["t_max"], item["h_max"])
    d["a"] = d["a_Q"] * d["a_Tmax"] * d["a_Tmin"] * d["a_tmin"] * d["a_tmax"]
    return d


# =============================================================================
# JOGADORA SIMULADA
# =============================================================================
class Jogadora:
    """Como a jogadora mexe no fogo e no tempo.
    cliques_s:   cliques máximos por segundo no +Fogo
    reacao:      atraso (s) entre olhar a chama e agir
    ruido:       erro de leitura da chama (fração do F; 0.05 = ±5%)
    folga:       quanto (°C) ela deixa o caldo passar do meio da faixa antes de corrigir
    sigma_seg:   desvio (s) no tempo de cada passo (antecipa/atrasa a troca de passo)
    erro_seg:    {passo: +s} erro fixo (ex.: tirar 5 s antes)
    chama:       {passo: estado} trocar a cor pedida num passo de chama
    """

    def __init__(self, cliques_s=3.0, reacao=0.25, ruido=0.0, folga=4.0, sigma_seg=0.0,
                 erro_seg=None, chama=None, seed=None, vies_seg=0.0):
        self.cliques_s, self.reacao, self.ruido, self.folga = cliques_s, reacao, ruido, folga
        self.sigma_seg = sigma_seg
        self.vies_seg = vies_seg        # erro médio (s) em todo passo (ex.: −2 = sempre tira cedo)
        self.erro_seg = erro_seg or {}
        self.chama = chama or {}
        self.rng = random.Random(seed)


def F_para_T(T):
    """F que segura o caldo em T (equilíbrio: K(F−T) = h(T−T_AMB))."""
    return ((K + H) * T - H * T_AMB) / K


def simular(receita, itens, jog=None, catalogo=None, guardar_hist=True):
    """Roda a receita com a jogadora. Devolve o resultado completo."""
    jog = jog or Jogadora()
    T, F, t = T_AMB, T_AMB, 0.0
    ligado = True                       # acende logo no início
    hist = []
    prox_hist = 0.0
    entradas = []                       # (t0, item_id)
    passos = receita["passos"]
    alvo = None
    i_passo = 0
    fase = "chama"                      # "chama" (esperando estabilizar) / "jogando" / "cozinhando"
    t_estavel = 0.0
    t_prox_item = None
    restantes = 0
    t_primeiro = None
    t_fim_passo = None
    t_final = None
    prox_acao = 0.0
    t_abafar = 0.0
    eventos = []
    segs_reais = {}

    def chama_do_passo(k):
        return jog.chama.get(k, passos[k].get("estado"))

    # avança passos de chama até achar o próximo de ingrediente
    def comecar_passo():
        nonlocal i_passo, alvo, fase, t_estavel, restantes, t_prox_item, t_primeiro
        while i_passo < len(passos) and passos[i_passo]["tipo"] == "chama":
            alvo = chama_do_passo(i_passo)
            eventos.append((t, "chama %s" % alvo))
            i_passo += 1
            fase = "chama"
            t_estavel = 0.0
        if i_passo >= len(passos):
            return False
        p = passos[i_passo]
        restantes = int(p.get("qtd", 1))
        t_prox_item = None
        t_primeiro = None
        if fase != "chama":
            fase = "jogando"
        return True

    comecar_passo()
    LIMITE = 600.0
    while t < LIMITE:
        # ---- decisões da jogadora (a cada "reação") ----
        if t >= prox_acao:
            prox_acao = t + max(1.0 / jog.cliques_s, jog.reacao * (0.7 + 0.6 * jog.rng.random()))
            if alvo and ligado:
                T_meio = T_alvo_estado(alvo)
                F_visto = F * (1 + jog.rng.gauss(0, jog.ruido)) if jog.ruido > 0 else F
                F_quero = F_para_T(T_meio)
                if T < T_meio - jog.folga or F_visto < F_quero - 25:
                    if T < T_meio + jog.folga:
                        F += CONST_A                    # clique no +Fogo
                elif T > T_meio + jog.folga and F_visto > F_quero + 25:
                    if t >= t_abafar:                   # segurando o −Fogo
                        F = max(F - CONST_C, T_AMB)
                        t_abafar = t + INTERVALO_ABAFAR
                        if F < F_LIMIT_MIN:
                            ligado = False
                            eventos.append((t, "apagou"))
            elif alvo and not ligado and estado_de_T(T) != "apagado":
                ligado = True
        # ---- passo da receita ----
        if fase == "chama":
            if alvo and estado_de_T(T, ligado) == alvo:
                t_estavel += DT
                if t_estavel >= TEMPO_CHAMA:
                    fase = "jogando"
            else:
                t_estavel = 0.0
        if fase == "jogando" and i_passo < len(passos):
            if t_prox_item is None:
                t_prox_item = t + ESPERA_SEGURAR
            if t >= t_prox_item and restantes > 0:
                p = passos[i_passo]
                t0 = t + VOO_ITEM
                entradas.append((t0, p["item"]))
                if t_primeiro is None:
                    t_primeiro = t0
                restantes -= 1
                t_prox_item = t + INTERVALO_ITEM
            if restantes == 0 and t_primeiro is not None:
                seg = float(passos[i_passo].get("seg", 0.0)) + jog.erro_seg.get(i_passo, 0.0) + jog.vies_seg
                if jog.sigma_seg > 0:
                    seg += jog.rng.gauss(0, jog.sigma_seg)
                seg = max(0.0, seg)
                segs_reais[i_passo] = seg
                t_fim_passo = t_primeiro + seg
                fase = "cozinhando"
        if fase == "cozinhando" and t >= t_fim_passo:
            i_passo += 1
            if i_passo >= len(passos):
                t_final = t
                break
            fase = "jogando"
            comecar_passo()
        # ---- física (SistemaTermico.step) ----
        dT = (K * (F - T) - H * (T - T_AMB)) / C
        dF = ((-K * (F - T) - HF * (F - T_AMB) + (P_COMB if ligado else 0.0)) / C_F)
        T += dT * DT
        F += dF * DT
        t += DT
        if t >= prox_hist:
            hist.append((t, T, F))
            prox_hist = t + INTERVALO_HISTORICO
    if t_final is None:
        t_final = t
    # ---- resultado (CalculadoraPocao) ----
    hTT = [(h[0], h[1]) for h in hist]
    diags = []
    A = identidade()
    for (t0, iid) in entradas:
        it = itens[iid]
        d = diagnostico(it, t0, hTT, t_final)
        diags.append(d)
        A = mult(interpolar(it["A"], d["a"]), A)
    a_med = sum(d["a"] for d in diags) / len(diags) if diags else 0.0
    res = {"receita": receita["chave"], "t_final": t_final, "diags": diags, "A": A, "a": a_med,
           "a_min_item": min((d["a"] for d in diags), default=0.0), "eventos": eventos,
           "segs": segs_reais}
    if catalogo:
        res.update(reconhecer(A, a_med, catalogo))
    if guardar_hist:
        res["hist"] = hist
        res["entradas"] = entradas
    return res


def avaliar(entradas, hist_tt, t_final, itens, catalogo=None):
    """Resultado (CalculadoraPocao) de uma jogada já feita: entradas [(t0, id)], hist [(t, T)].
    Serve para reavaliar jogadas reais com os parâmetros atuais dos itens."""
    diags = []
    A = identidade()
    for (t0, iid) in entradas:
        it = itens.get(iid)
        if it is None:
            continue
        d = diagnostico(it, t0, hist_tt, t_final)
        diags.append(d)
        A = mult(interpolar(it["A"], d["a"]), A)
    a_med = sum(d["a"] for d in diags) / len(diags) if diags else 0.0
    res = {"t_final": t_final, "diags": diags, "A": A, "a": a_med,
           "a_min_item": min((d["a"] for d in diags), default=0.0)}
    if catalogo:
        res.update(reconhecer(A, a_med, catalogo))
    return res


def reconhecer(A, a_med, catalogo):
    """Como CatalogoPocoes.procurar / efeito_pela_matriz: cada poção tem a sua tolerância
    (distancia_max no .tres; 0 = a do catálogo)."""
    cat, dist_max = catalogo
    melhor, dmin, perto = "", 1e9, False
    efeito = False
    d_ef = 1e9
    for r in cat:
        tol = r["tol"] if r["tol"] > 0 else dist_max
        d = distancia(A, r["A"])
        dentro = d <= tol
        if (dentro and (not perto or d < dmin)) or (not perto and d < dmin):
            melhor, dmin, perto = r["nome"], d, dentro
        if r["efeito"] and a_med >= r["a_min"] and dentro and d < d_ef:
            efeito, d_ef = True, d
    return {"pocao": melhor if perto else "(desconhecida)", "dist": dmin, "perto": perto, "efeito": efeito}


# =============================================================================
# SAÍDA
# =============================================================================
def garantir_saida():
    os.makedirs(SAIDA, exist_ok=True)


def plt_ou_none():
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        return plt
    except Exception:
        print("(sem matplotlib: só CSV. Instale com: pip install matplotlib)")
        return None


def salvar_csv(nome, cab, linhas):
    garantir_saida()
    p = os.path.join(SAIDA, nome)
    with open(p, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(cab)
        w.writerows(linhas)
    print("  CSV:", os.path.relpath(p, PROJ))


def salvar_fig(plt, fig, nome):
    garantir_saida()
    p = os.path.join(SAIDA, nome)
    fig.savefig(p, dpi=110, bbox_inches="tight")
    plt.close(fig)
    print("  PNG:", os.path.relpath(p, PROJ))


def pct(x):
    return "%5.1f%%" % (100 * x)


def imprimir_resultado(r, itens):
    print("\nReceita %s   tempo total %.1f s   aproveitamento médio %s   pior item %s"
          % (r["receita"], r["t_final"], pct(r["a"]), pct(r["a_min_item"])))
    if "pocao" in r:
        print("  poção: %s  (dist %.3f)  efeito: %s" % (r["pocao"], r["dist"], "SIM" if r["efeito"] else "não"))
    print("  %-20s %6s %6s %7s %6s %6s %6s %6s %6s %6s %6s" %
          ("item", "t0", "dur", "Q", "Tmin", "Tmax", "a_Q", "aTmn", "aTmx", "atmn", "a"))
    for d in r["diags"]:
        print("  %-20s %6.1f %6.1f %7.0f %6.1f %6.1f %6s %6s %6s %6s %6s" %
              (itens[d["item"]]["nome"][:20], d["t0"], d["dur"], d["Q"], d["T_min"], d["T_max"],
               pct(d["a_Q"]), pct(d["a_Tmin"]), pct(d["a_Tmax"]), pct(d["a_tmin"] * d["a_tmax"]), pct(d["a"])))


def grafico_corrida(r, itens, nome_png):
    plt = plt_ou_none()
    if not plt or "hist" not in r:
        return
    fig, ax = plt.subplots(figsize=(10, 4.5))
    for e in ESTADOS:
        lo, hi = max(e["T_min"], 20), min(e["T_max"], 220)
        if hi > lo:
            ax.axhspan(lo, hi, alpha=0.22, color=e["cor"], lw=0)
            ax.text(0.5, (lo + hi) / 2, e["nome"], fontsize=7, va="center", alpha=0.6)
    ts = [h[0] for h in r["hist"]]
    ax.plot(ts, [h[1] for h in r["hist"]], label="T caldo (°C)")
    ax2 = ax.twinx()
    ax2.plot(ts, [h[2] for h in r["hist"]], color="orange", alpha=0.35, label="F fogo")
    ax2.set_ylabel("F")
    for (t0, iid) in r["entradas"]:
        ax.axvline(t0, color="green", alpha=0.25, lw=1)
    ax.axvline(r["t_final"], color="red", ls="--", label="finalizar")
    ax.set_xlabel("t (s)")
    ax.set_ylabel("T (°C)")
    ax.set_ylim(15, 200)
    ax.set_title("%s: a médio %s, %s%s" % (r["receita"], pct(r["a"]), r.get("pocao", ""),
                                          " (EFEITO)" if r.get("efeito") else ""))
    ax.legend(loc="upper left")
    salvar_fig(plt, fig, nome_png)


# =============================================================================
# EXPERIMENTOS
# =============================================================================
def parse_mapa(lista, conv):
    out = {}
    for s in lista or []:
        k, v = s.split("=")
        out[int(k)] = conv(v)
    return out


def exp_rodar(rc, itens, cat, args):
    jog = Jogadora(erro_seg=parse_mapa(args.seg, float), chama=parse_mapa(args.chama, str),
                   ruido=args.ruido, sigma_seg=args.sigma_seg, seed=args.seed)
    r = simular(rc, itens, jog, cat)
    imprimir_resultado(r, itens)
    for (t, e) in r["eventos"]:
        print("   %6.1f s  %s" % (t, e))
    grafico_corrida(r, itens, "rodar_%s.png" % rc["chave"])
    return r


def passos_ingrediente(rc):
    return [k for k, p in enumerate(rc["passos"]) if p["tipo"] == "ingrediente"]


def passos_chama(rc):
    return [k for k, p in enumerate(rc["passos"]) if p["tipo"] == "chama"]


def exp_tempo(rc, itens, cat, args):
    passo = args.passo if args.passo is not None else passos_ingrediente(rc)[-1]
    print("\nVariando os segundos do passo %d (%s) de %+g a %+g s"
          % (passo, rc["passos"][passo].get("item"), args.de, args.ate))
    linhas = []
    x = args.de
    while x <= args.ate + 1e-9:
        r = simular(rc, itens, Jogadora(erro_seg={passo: x}), cat, guardar_hist=False)
        linhas.append([round(x, 2), round(r["a"], 4), round(r["a_min_item"], 4), r.get("pocao", ""),
                       round(r.get("dist", 0), 4), int(r.get("efeito", False))])
        print("  %+6.1f s   a %s   pior %s   %s%s" % (x, pct(r["a"]), pct(r["a_min_item"]), r.get("pocao", ""),
                                                   "  EFEITO" if r.get("efeito") else ""))
        x += args.passo_x
    salvar_csv("tempo_%s_p%d.csv" % (rc["chave"], passo), ["erro_s", "a", "pior_item", "pocao", "dist", "efeito"], linhas)
    janela = [l[0] for l in linhas if l[1] >= 0.95]
    if janela:
        print("  janela para 95%%: de %+g a %+g s (largura %g s)" % (min(janela), max(janela), max(janela) - min(janela)))
    plt = plt_ou_none()
    if plt:
        fig, ax = plt.subplots(figsize=(8, 4))
        ax.plot([l[0] for l in linhas], [l[1] for l in linhas], label="a médio")
        ax.plot([l[0] for l in linhas], [l[2] for l in linhas], label="pior item", alpha=0.6)
        ax.axhline(0.95, color="red", ls="--", label="95% (efeito)")
        ax.axhline(0.80, color="gray", ls=":", label="80%")
        ax.set_xlabel("erro nos segundos do passo %d (s)" % passo)
        ax.set_ylabel("aproveitamento")
        ax.set_ylim(0, 1.02)
        ax.legend()
        ax.set_title("%s: sensibilidade ao tempo" % rc["nome"])
        salvar_fig(plt, fig, "tempo_%s_p%d.png" % (rc["chave"], passo))


def exp_chama(rc, itens, cat, args):
    passo = args.passo if args.passo is not None else passos_chama(rc)[0]
    print("\nTrocando a chama do passo %d (pedida: %s)" % (passo, rc["passos"][passo].get("estado")))
    linhas = []
    for e in ESTADOS:
        if e["id"] in ("apagado", "negro"):
            continue
        r = simular(rc, itens, Jogadora(chama={passo: e["id"]}), cat, guardar_hist=False)
        linhas.append([e["id"], round(r["a"], 4), round(r["a_min_item"], 4), r.get("pocao", ""), int(r.get("efeito", False))])
        print("  %-20s a %s   pior %s   %s%s" % (e["nome"], pct(r["a"]), pct(r["a_min_item"]), r.get("pocao", ""),
                                               "  EFEITO" if r.get("efeito") else ""))
    salvar_csv("chama_%s_p%d.csv" % (rc["chave"], passo), ["chama", "a", "pior_item", "pocao", "efeito"], linhas)


def exp_mapa(rc, itens, cat, args):
    pt = args.passo_tempo if args.passo_tempo is not None else passos_ingrediente(rc)[-1]
    pc = args.passo_chama if args.passo_chama is not None else passos_chama(rc)[0]
    estados = [e for e in ESTADOS if e["id"] not in ("apagado", "negro")]
    xs = []
    x = args.de
    while x <= args.ate + 1e-9:
        xs.append(round(x, 2))
        x += args.passo_x
    grade = []
    print("\nMapa: chama do passo %d × segundos do passo %d" % (pc, pt))
    for e in estados:
        linha = []
        for x in xs:
            r = simular(rc, itens, Jogadora(erro_seg={pt: x}, chama={pc: e["id"]}), cat, guardar_hist=False)
            linha.append(r["a"])
        grade.append(linha)
        print("  %-20s melhor %s" % (e["nome"], pct(max(linha))))
    salvar_csv("mapa_%s.csv" % rc["chave"], ["chama"] + xs, [[e["id"]] + [round(v, 4) for v in l] for e, l in zip(estados, grade)])
    plt = plt_ou_none()
    if plt:
        fig, ax = plt.subplots(figsize=(9, 4.5))
        im = ax.imshow(grade, aspect="auto", vmin=0, vmax=1, cmap="viridis", origin="lower",
                       extent=[xs[0], xs[-1], -0.5, len(estados) - 0.5])
        ax.contour(xs, list(range(len(estados))), grade, levels=[0.8, 0.95], colors=["white", "red"], linewidths=1)
        ax.set_yticks(range(len(estados)))
        ax.set_yticklabels([e["nome"] for e in estados])
        ax.set_xlabel("erro nos segundos do passo %d (s)" % pt)
        ax.set_title("%s: aproveitamento (linha vermelha = 95%%)" % rc["nome"])
        fig.colorbar(im)
        salvar_fig(plt, fig, "mapa_%s.png" % rc["chave"])


def exp_monte(rc, itens, cat, args):
    print("\nMonte Carlo: %d jogadas, sigma do tempo %g s, ruído na leitura da chama %g, folga %g °C"
          % (args.n, args.sigma_seg, args.ruido, args.folga))
    linhas = []
    vals = []
    efeitos = 0
    for k in range(args.n):
        jog = Jogadora(sigma_seg=args.sigma_seg, ruido=args.ruido, folga=args.folga,
                       reacao=args.reacao, seed=(args.seed or 0) * 100000 + k)
        r = simular(rc, itens, jog, cat, guardar_hist=False)
        vals.append(r["a"])
        efeitos += int(r.get("efeito", False))
        linhas.append([k, round(r["a"], 4), round(r["a_min_item"], 4), r.get("pocao", ""), int(r.get("efeito", False)),
                       round(r["t_final"], 2)])
    vals.sort()
    def q(p):
        return vals[min(len(vals) - 1, int(p * len(vals)))]
    print("  média %s   mediana %s   p10 %s   p90 %s" % (pct(sum(vals) / len(vals)), pct(q(0.5)), pct(q(0.1)), pct(q(0.9))))
    for lim in (0.95, 0.90, 0.80):
        print("  >= %d%%: %s das jogadas" % (int(lim * 100), pct(sum(1 for v in vals if v >= lim) / len(vals))))
    print("  com efeito: %s" % pct(efeitos / len(vals)))
    salvar_csv("monte_%s.csv" % rc["chave"], ["jogada", "a", "pior_item", "pocao", "efeito", "t_final"], linhas)
    plt = plt_ou_none()
    if plt:
        fig, ax = plt.subplots(figsize=(8, 4))
        ax.hist(vals, bins=30, range=(0, 1))
        ax.axvline(0.95, color="red", ls="--", label="95%")
        ax.set_xlabel("aproveitamento médio")
        ax.set_ylabel("jogadas")
        ax.set_title("%s: σ tempo %g s, ruído %g → %s com efeito" % (rc["nome"], args.sigma_seg, args.ruido, pct(efeitos / len(vals))))
        ax.legend()
        salvar_fig(plt, fig, "monte_%s.png" % rc["chave"])


def janela_item(it, T, alvo=0.95):
    """Segundos de cozimento a T constante em que o item fica >= alvo."""
    ok = []
    for s10 in range(0, 3000):
        s = s10 / 10.0
        d = {"Q": T * s}
        a = (a_cozimento(T * s, it["m"], it["s_menos"], it["s_mais"]) * curva_max(T, it["T_max"], it["k_max"]) *
             curva_min(T, it["T_min"], it["k_min"]) * curva_min(s, it["t_min"], it["h_min"]) *
             curva_max(s, it["t_max"], it["h_max"]))
        if a >= alvo:
            ok.append(s)
    return (min(ok), max(ok)) if ok else None


def exp_janelas(itens, args):
    print("\nJanela de tempo (s) para cada item ficar >= 95% / 80%, a temperatura constante")
    linhas = []
    for e in ESTADOS:
        if e["id"] in ("apagado", "negro"):
            continue
        T = T_alvo_estado(e["id"])
        for it in sorted(itens.values(), key=lambda x: x["id"]):
            j95 = janela_item(it, T, 0.95)
            j80 = janela_item(it, T, 0.80)
            linhas.append([e["id"], round(T, 1), it["id"], j95[0] if j95 else "", j95[1] if j95 else "",
                           j80[0] if j80 else "", j80[1] if j80 else ""])
    for it in sorted(itens.values(), key=lambda x: x["id"]):
        print("\n  %s" % it["nome"])
        for l in linhas:
            if l[2] == it["id"] and l[3] != "":
                print("    %-20s %5.0f °C   95%%: %5.1f–%5.1f s (±%.1f)   80%%: %5.1f–%5.1f s"
                      % (ESTADO[l[0]]["nome"], l[1], l[3], l[4], (l[4] - l[3]) / 2, l[5], l[6]))
    salvar_csv("janelas_itens.csv", ["chama", "T", "item", "95_de", "95_ate", "80_de", "80_ate"], linhas)


def exp_quantidade(rc, itens, cat, args):
    """Muda a quantidade de um item e o aproveitamento: mostra a distância ao catálogo
    (o problema '4 mal cozidos ≈ 3 bem cozidos')."""
    item = args.item or next(p["item"] for p in rc["passos"] if p["tipo"] == "ingrediente")
    it = itens[item]
    print("\nQuantidade × aproveitamento de %s (matriz da poção vs. catálogo)" % it["nome"])
    linhas = []
    nomes = []
    cab = "  qtd " + "".join("%11s" % ("a=%d%%" % int(a * 100)) for a in (1.0, 0.95, 0.9, 0.8, 0.7, 0.6))
    print(cab)
    for n in range(args.de_q, args.ate_q + 1):
        txt = "  %3d " % n
        for a in (1.0, 0.95, 0.9, 0.8, 0.7, 0.6):
            A = identidade()
            for _ in range(n):
                A = mult(interpolar(it["A"], a), A)
            r = reconhecer(A, a, cat)
            efeito = r["efeito"]
            marca = "    "
            if r["perto"]:
                if r["pocao"] not in nomes:
                    nomes.append(r["pocao"])
                marca = "[%d%s]" % (nomes.index(r["pocao"]) + 1, "E" if efeito else "")
                marca = marca.ljust(4)
            txt += "  %.3f%s" % (r["dist"], marca)
            linhas.append([n, a, round(r["dist"], 4), r["pocao"], int(efeito)])
        print(txt)
    print("  (distância à poção do catálogo mais perto; [n] = recebe o nome n abaixo; [nE] = nome e efeito)")
    for k, n in enumerate(nomes):
        print("    %d = %s" % (k + 1, n))
    salvar_csv("quantidade_%s.csv" % item, ["qtd", "a", "dist", "pocao", "efeito"], linhas)


def exp_otimizar(rc, itens, cat, args):
    """Procura os segundos de cada passo de ingrediente que dão o melhor aproveitamento (e a
    largura da janela de 95%), um passo de cada vez (coordenada)."""
    ps = passos_ingrediente(rc)
    erro = {p: 0.0 for p in ps}
    print("\nOtimizando os segundos dos passos %s de %s" % (ps, rc["nome"]))
    for volta in range(2):
        for p in ps:
            melhor, mx = erro[p], -1
            x = -30.0
            while x <= 30.0:
                e2 = dict(erro)
                e2[p] = x
                r = simular(rc, itens, Jogadora(erro_seg=e2), cat, guardar_hist=False)
                if r["a"] > mx + 1e-6:
                    mx, melhor = r["a"], x
                x += 1.0
            erro[p] = melhor
    r = simular(rc, itens, Jogadora(erro_seg=erro), cat, guardar_hist=False)
    for p in ps:
        base = float(rc["passos"][p].get("seg", 0))
        print("  passo %d (%s): %g s na receita → melhor %g s" % (p, rc["passos"][p]["item"], base, base + erro[p]))
    print("  aproveitamento: receita %s → otimizada %s"
          % (pct(simular(rc, itens, Jogadora(), cat, guardar_hist=False)["a"]), pct(r["a"])))


def exp_receitas(rcs, itens, cat):
    print("\nReceitas lidas de dados/receitas:")
    for rc in rcs.values():
        r = simular(rc, itens, Jogadora(), cat, guardar_hist=False)
        print("  %-16s %-40s a %s  %s%s" % (rc["chave"], " → ".join(
            (p["estado"] if p["tipo"] == "chama" else "%s×%d %gs" % (p["item"], p.get("qtd", 1), p.get("seg", 0)))
            for p in rc["passos"])[:40], pct(r["a"]), r.get("pocao", ""), "  EFEITO" if r.get("efeito") else ""))


def exp_relatorio(rcs, itens, cat, args):
    exp_receitas(rcs, itens, cat)
    exp_janelas(itens, args)
    for rc in rcs.values():
        a = argparse.Namespace(**vars(args))
        a.seg, a.chama, a.passo = None, None, None
        exp_rodar(rc, itens, cat, a)
        exp_tempo(rc, itens, cat, a)
        if passos_chama(rc):
            exp_chama(rc, itens, cat, a)
        exp_monte(rc, itens, cat, a)


# =============================================================================
# MAIN
# =============================================================================
def main():
    ap = argparse.ArgumentParser(description="Simulador do caldeirão (mesmas contas do jogo).")
    ap.add_argument("experimento", choices=["receitas", "rodar", "tempo", "chama", "mapa", "monte", "janelas",
                                            "quantidade", "otimizar", "relatorio"])
    ap.add_argument("receita", nargs="?", help="nome do arquivo em dados/receitas (sem .tres)")
    ap.add_argument("--seg", action="append", help="erro nos segundos: PASSO=+s (ex.: 1=+5)")
    ap.add_argument("--chama", action="append", help="trocar a chama: PASSO=estado (ex.: 0=amarelo)")
    ap.add_argument("--passo", type=int, help="passo variado (tempo/chama)")
    ap.add_argument("--passo-tempo", type=int)
    ap.add_argument("--passo-chama", type=int)
    ap.add_argument("--de", type=float, default=-20.0)
    ap.add_argument("--ate", type=float, default=20.0)
    ap.add_argument("--passo-x", type=float, default=1.0, help="incremento da varredura de tempo")
    ap.add_argument("--n", type=int, default=300, help="jogadas no Monte Carlo")
    ap.add_argument("--sigma-seg", type=float, default=2.0, help="desvio (s) no tempo de cada passo")
    ap.add_argument("--ruido", type=float, default=0.05, help="erro de leitura da chama (fração de F)")
    ap.add_argument("--folga", type=float, default=4.0, help="°C que a jogadora tolera antes de corrigir")
    ap.add_argument("--reacao", type=float, default=0.25, help="s entre olhar e agir")
    ap.add_argument("--item", help="item para o experimento de quantidade")
    ap.add_argument("--de-q", type=int, default=1)
    ap.add_argument("--ate-q", type=int, default=6)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()

    itens = carregar_itens()
    rcs = carregar_receitas()
    cat = carregar_catalogo()
    print("Projeto: %s  (%d itens, %d receitas, %d poções no catálogo, distância máx. %g)"
          % (PROJ, len(itens), len(rcs), len(cat[0]), cat[1]))

    if args.experimento == "receitas":
        return exp_receitas(rcs, itens, cat)
    if args.experimento == "janelas":
        return exp_janelas(itens, args)
    if args.experimento == "relatorio":
        if args.receita:
            rcs = {args.receita: rcs[args.receita]}
        return exp_relatorio(rcs, itens, cat, args)
    if not args.receita or args.receita not in rcs:
        print("Escolha a receita:", ", ".join(sorted(rcs)))
        sys.exit(1)
    rc = rcs[args.receita]
    {"rodar": exp_rodar, "tempo": exp_tempo, "chama": exp_chama, "mapa": exp_mapa, "monte": exp_monte,
     "quantidade": exp_quantidade, "otimizar": exp_otimizar}[args.experimento](rc, itens, cat, args)


if __name__ == "__main__":
    main()
