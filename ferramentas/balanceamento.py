#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
balanceamento.py — ferramenta de balanceamento das receitas (interface).

Usa o motor do simulador_caldeirao.py (mesmas contas do jogo, lidas dos .gd/.tres).

Abas:
  Receita         edita os passos (chama, quantidade, segundos), roda, compara com a anterior
  Sensibilidade   erro de tempo de um passo, cor da chama, mapa chama × tempo
  Monte Carlo     muitas jogadas com a jogadora (calibrada ou não), histograma, comparar
  Itens           mexe nos parâmetros de um item e vê as janelas na hora; salva no .tres
  Testes          testes automáticos (receitas chegam a 95%, quantidade errada sem efeito,
                  catálogo sem sobreposição, dados válidos)
  Dificuldade     nota de dificuldade por receita (janela de tempo, faixa de chama, chance)
  Jogadas reais   jogadas gravadas pelo jogo (debug: user://jogadas/), reavaliadas com os
                  parâmetros atuais; calibra a jogadora simulada para jogar como você

Linha de comando (sem interface):
  python ferramentas/balanceamento.py --testes        (código de saída 1 se algum teste falhar)
  python ferramentas/balanceamento.py --dificuldade
  python ferramentas/balanceamento.py --calibrar [pasta_das_jogadas]

Precisa de: PySide6 e matplotlib  (pip install PySide6 matplotlib)
"""
import copy
import glob
import json
import math
import os
import re
import statistics
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import simulador_caldeirao as sim  # noqa: E402

ARQ_CALIBRACAO = os.path.join(AQUI, "calibracao.json")
PADRAO_JOGADORA = {"cliques_s": 3.0, "reacao": 0.25, "ruido": 0.05, "folga": 4.0, "sigma_seg": 2.0, "vies_seg": 0.0}
CAMPOS_ITEM = ["m", "s_menos", "s_mais", "T_min", "k_min", "T_max", "k_max", "t_min", "h_min", "t_max", "h_max"]
NOTAS = [(0.90, 1, "muito fácil"), (0.70, 2, "fácil"), (0.45, 3, "média"), (0.20, 4, "difícil"), (0.0, 5, "muito difícil")]


# =============================================================================
# DADOS
# =============================================================================
class Dados:
    def __init__(self):
        self.recarregar()

    def recarregar(self):
        self.itens = sim.carregar_itens()
        self.receitas = sim.carregar_receitas()
        self.catalogo = sim.carregar_catalogo()
        sim.ajustar_catalogo_ao_ruido(self.itens, self.receitas, self.catalogo)

    def ref_da_pocao(self, nome):
        for r in self.catalogo[0]:
            if r["nome"] == nome:
                return r
        return None


def ler_calibracao():
    try:
        with open(ARQ_CALIBRACAO, encoding="utf-8") as f:
            c = json.load(f)
        return {k: float(c.get(k, v)) for k, v in PADRAO_JOGADORA.items()}
    except Exception:
        return dict(PADRAO_JOGADORA)


def jogadora(params, seed=None, erro_seg=None, chama=None, perfeita=False):
    if perfeita:
        return sim.Jogadora(erro_seg=erro_seg, chama=chama)
    return sim.Jogadora(cliques_s=params["cliques_s"], reacao=params["reacao"], ruido=params["ruido"],
                        folga=params["folga"], sigma_seg=params["sigma_seg"], vies_seg=params["vies_seg"],
                        erro_seg=erro_seg, chama=chama, seed=seed)


def receita_com_qtd(rc, passo, delta):
    r = copy.deepcopy(rc)
    p = r["passos"][passo]
    p["qtd"] = max(1, int(p.get("qtd", 1)) + delta)
    return r


def passos_ing(rc):
    return [k for k, p in enumerate(rc["passos"]) if p["tipo"] == "ingrediente"]


def passos_chama(rc):
    return [k for k, p in enumerate(rc["passos"]) if p["tipo"] == "chama"]


def nota_da_chance(ch):
    for lim, n, txt in NOTAS:
        if ch >= lim:
            return n, txt
    return 5, "muito difícil"


NOVA_RECEITA = "(receita nova)"
NOME_AGUA = "Água de Caldeirão"
NOME_DESCONHECIDO = "Poção desconhecida"
ADJETIVOS = [(0.95, "Concentrada"), (0.80, "Refinada"), (0.60, ""), (0.40, "Rala"), (0.20, "Aguada"), (0.0, "Estragada")]
SEMELHANCA_MAX = 0.3


def adjetivo(a):
    for lim, txt in ADJETIVOS:
        if a >= lim:
            return txt
    return ADJETIVOS[-1][1]


def proximas(dados, A, n=3):
    """[(nome, distância, tolerância)] das poções do catálogo mais perto da matriz."""
    cat, dmax = dados.catalogo
    out = [(r["nome"], sim.distancia(A, r["A"]), r["tol"] if r["tol"] > 0 else dmax) for r in cat]
    return sorted(out, key=lambda x: x[1])[:n]


def nome_como_jogo(dados, r):
    """O nome que a janela do resultado daria (JanelaResultado: água, catálogo, um item só,
    parecida com um ingrediente, desconhecida). Devolve (nome, por quê)."""
    A = r["A"]
    if sim.distancia(A, sim.identidade()) <= 0.0001:
        return NOME_AGUA, "a matriz não mudou nada (identidade)"
    rec = sim.reconhecer(A, r["a"], dados.catalogo)
    if rec["perto"]:
        return rec["pocao"], "perto de uma poção do catálogo (dist %.3f)" % rec["dist"]
    ids = {d["item"] for d in r["diags"]}
    if len(ids) == 1:
        it = dados.itens[next(iter(ids))]
        adj = adjetivo(r["a"])
        nome = ("Poção de %s %s" % (it["nome"], adj)) if adj else "Poção de %s" % it["nome"]
        if any(c["nome"] == nome for c in dados.catalogo[0]):
            nome = "Poção de %s" % it["nome"]
        return nome, "um item só (qualidade pelo aproveitamento médio %s)" % pct_txt(r["a"])
    melhor, rel_min = "", 1e9
    for it in dados.itens.values():
        ef = sim.distancia(it["A"], sim.identidade())
        if ef < 0.001:
            continue
        rel = sim.distancia(A, it["A"]) / ef
        if rel < rel_min:
            melhor, rel_min = it["nome"], rel
    if rel_min <= SEMELHANCA_MAX:
        return "Poção de " + melhor, "matriz parecida com a de um ingrediente puro"
    return NOME_DESCONHECIDO, "poção nova: a bruxa dá o nome no livro"


def pct_txt(x):
    return "%.1f%%" % (100 * x)


# =============================================================================
# ANÁLISES
# =============================================================================
def janela_tempo(dados, rc, passo, alvo=0.95, passo_x=0.5, faixa=30.0):
    """Largura (s) do erro de tempo no passo que mantém a >= alvo (contínuo em volta do 0)."""
    ok = {}
    x = -faixa
    while x <= faixa + 1e-9:
        r = sim.simular(rc, dados.itens, sim.Jogadora(erro_seg={passo: x}), dados.catalogo, guardar_hist=False)
        ok[round(x, 2)] = r["a"] >= alvo
        x += passo_x
    if not ok.get(0.0):
        return 0.0, 0.0, 0.0
    lo = hi = 0.0
    while ok.get(round(lo - passo_x, 2)):
        lo = round(lo - passo_x, 2)
    while ok.get(round(hi + passo_x, 2)):
        hi = round(hi + passo_x, 2)
    return hi - lo, lo, hi


def chamas_ok(dados, rc, passo, alvo=0.95):
    out = []
    for e in sim.ESTADOS:
        if e["id"] in ("apagado", "negro"):
            continue
        r = sim.simular(rc, dados.itens, sim.Jogadora(chama={passo: e["id"]}), dados.catalogo, guardar_hist=False)
        if r["a"] >= alvo:
            out.append(e["id"])
    return out


def monte_carlo(dados, rc, params, n=200, seed=1):
    res = []
    for k in range(n):
        res.append(sim.simular(rc, dados.itens, jogadora(params, seed=seed * 100000 + k), dados.catalogo,
                               guardar_hist=False))
    return res


def dificuldade(dados, rc, params, n=150):
    jan = {p: janela_tempo(dados, rc, p)[0] for p in passos_ing(rc)}
    cham = {p: chamas_ok(dados, rc, p) for p in passos_chama(rc)}
    mc = monte_carlo(dados, rc, params, n)
    ref = dados.ref_da_pocao(rc.get("pocao", ""))
    if ref and ref["efeito"]:
        chance = sum(1 for r in mc if r.get("efeito")) / len(mc)
        criterio = "efeito"
    else:
        chance = sum(1 for r in mc if r["a"] >= 0.95) / len(mc)
        criterio = ">=95%"
    nota, txt = nota_da_chance(chance)
    return {"receita": rc["chave"], "janelas": jan, "chamas": cham, "chance": chance, "criterio": criterio,
            "nota": nota, "nota_txt": txt, "a_medio": statistics.mean(r["a"] for r in mc),
            "passos": len(rc["passos"])}


def testes(dados, params=None):
    """[(nivel, texto)]  nivel: ok / aviso / falha."""
    out = []
    params = params or ler_calibracao()
    ids_estados = {e["id"] for e in sim.ESTADOS}
    for rc in dados.receitas.values():
        nome = rc["chave"]
        # dados válidos
        ruim = False
        for k, p in enumerate(rc["passos"]):
            if p["tipo"] == "chama" and p.get("estado") not in ids_estados:
                out.append(("falha", "%s: passo %d tem chama desconhecida '%s'" % (nome, k, p.get("estado"))))
                ruim = True
            if p["tipo"] == "ingrediente" and p.get("item") not in dados.itens:
                out.append(("falha", "%s: passo %d usa item desconhecido '%s'" % (nome, k, p.get("item"))))
                ruim = True
        if ruim:
            continue
        # receita ideal chega a 95% e dá a poção certa (e o efeito, se tiver)
        r = sim.simular(rc, dados.itens, sim.Jogadora(), dados.catalogo, guardar_hist=False)
        ref = dados.ref_da_pocao(rc.get("pocao", ""))
        if r["a"] >= 0.95:
            out.append(("ok", "%s: feita certinho chega a %.1f%%" % (nome, 100 * r["a"])))
        else:
            out.append(("falha", "%s: feita certinho só chega a %.1f%% (precisa 95%%)" % (nome, 100 * r["a"])))
        if rc.get("pocao"):
            if r.get("pocao") == rc["pocao"]:
                out.append(("ok", "%s: vira '%s'" % (nome, rc["pocao"])))
            else:
                out.append(("falha", "%s: deveria virar '%s', virou '%s' (dist %.3f)" % (nome, rc["pocao"], r.get("pocao"), r.get("dist", 0))))
        if ref and ref["efeito"]:
            out.append(("ok" if r.get("efeito") else "falha", "%s: %s o efeito" % (nome, "ganha" if r.get("efeito") else "NÃO ganha")))
        # quantidade errada (±1 de cada ingrediente) não ganha o efeito da poção
        if ref and ref["efeito"]:
            for p in passos_ing(rc):
                for dlt in (-1, +1):
                    if int(rc["passos"][p].get("qtd", 1)) + dlt < 1:
                        continue
                    r2 = sim.simular(receita_com_qtd(rc, p, dlt), dados.itens, sim.Jogadora(), dados.catalogo, guardar_hist=False)
                    q = int(rc["passos"][p].get("qtd", 1)) + dlt
                    if r2.get("efeito"):
                        out.append(("falha", "%s: com %d× %s também ganha o efeito" % (nome, q, rc["passos"][p]["item"])))
                    elif r2.get("pocao") == rc.get("pocao"):
                        out.append(("aviso", "%s: com %d× %s ainda se chama '%s' (sem efeito)" % (nome, q, rc["passos"][p]["item"], rc["pocao"])))
                    else:
                        out.append(("ok", "%s: com %d× %s não ganha o efeito" % (nome, q, rc["passos"][p]["item"])))
        # chance com a jogadora calibrada
        mc = monte_carlo(dados, rc, params, 80)
        ch = sum(1 for x in mc if (x.get("efeito") if (ref and ref["efeito"]) else x["a"] >= 0.95)) / len(mc)
        nivel = "aviso" if ch < 0.10 else "ok"
        out.append((nivel, "%s: chance de acertar com a jogadora calibrada: %.0f%%" % (nome, 100 * ch)))
    # catálogo: poções que se sobrepõem (uma matriz poderia valer pelas duas)
    cat, dmax = dados.catalogo
    for i in range(len(cat)):
        for j in range(i + 1, len(cat)):
            a, b = cat[i], cat[j]
            ta = a["tol"] if a["tol"] > 0 else dmax
            tb = b["tol"] if b["tol"] > 0 else dmax
            d = sim.distancia(a["A"], b["A"])
            if d < ta + tb:
                out.append(("aviso", "catálogo: '%s' e '%s' se sobrepõem (dist %.3f < %.3f + %.3f)" % (a["nome"], b["nome"], d, ta, tb)))
    if not any(n == "aviso" and t.startswith("catálogo") for n, t in out):
        out.append(("ok", "catálogo: nenhuma poção se sobrepõe"))
    return out


# =============================================================================
# JOGADAS REAIS E CALIBRAÇÃO
# =============================================================================
def pasta_jogadas_padrao():
    appdata = os.environ.get("APPDATA")
    cands = []
    if appdata:
        cands.append(os.path.join(appdata, "Godot", "app_userdata", "bruxa_alfa", "jogadas"))
    cands.append(os.path.expanduser("~/.local/share/godot/app_userdata/bruxa_alfa/jogadas"))
    cands.append(os.path.expanduser("~/Library/Application Support/Godot/app_userdata/bruxa_alfa/jogadas"))
    for c in cands:
        if os.path.isdir(c):
            return c
    return cands[0]


def ler_jogadas(pasta):
    out = []
    for p in sorted(glob.glob(os.path.join(pasta, "*.json"))):
        try:
            with open(p, encoding="utf-8") as f:
                j = json.load(f)
            j["arquivo"] = p
            out.append(j)
        except Exception:
            pass
    return out


def hist_de(j):
    return [(h[0], h[1]) for h in j.get("historico", [])]


def entradas_de(j):
    return [(e[1], e[0]) for e in j.get("entradas", [])]


def reavaliar(dados, j):
    return sim.avaliar(entradas_de(j), hist_de(j), float(j.get("t_final", 0)), dados.itens, dados.catalogo)


def metricas(passos, entradas, hist, t_final):
    """Medidas do jeito de jogar (iguais para jogada real e simulada):
    erros de tempo dos passos (s) e controle do fogo (fração fora da faixa, desvio médio)."""
    if not passos or not entradas:
        return None
    grupos = []           # (k_passo, t do 1º item)
    ents = sorted(entradas)
    i = 0
    for k, p in enumerate(passos):
        if p["tipo"] != "ingrediente":
            continue
        q = int(p.get("qtd", 1))
        while i < len(ents) and ents[i][1] != p["item"]:
            i += 1
        if i >= len(ents):
            break
        grupos.append((k, ents[i][0]))
        i += q
    erros = []
    for n, (k, t1) in enumerate(grupos):
        seg = float(passos[k].get("seg", 0))
        if n == len(grupos) - 1:
            erros.append(t_final - t1 - seg)
        elif grupos[n + 1][0] == k + 1:     # próximo passo é ingrediente direto
            erros.append(grupos[n + 1][1] - sim.VOO_ITEM - sim.ESPERA_SEGURAR - t1 - seg)
    # faixa pedida em cada instante (a chama do último passo de chama antes do grupo ativo)
    if not grupos:
        return None
    t_ini = grupos[0][1]
    fora = 0
    desv = []
    total = 0
    for (t, T) in hist:
        if t < t_ini or t > t_final:
            continue
        k_ativo = grupos[0][0]
        for (k, t1) in grupos:
            if t >= t1:
                k_ativo = k
        estado = None
        for k in range(k_ativo, -1, -1):
            if passos[k]["tipo"] == "chama":
                estado = passos[k]["estado"]
                break
        if not estado or estado not in sim.ESTADO:
            continue
        e = sim.ESTADO[estado]
        total += 1
        if not (e["T_min"] <= T < e["T_max"]):
            fora += 1
        desv.append(abs(T - sim.T_alvo_estado(estado)))
    return {"erros": erros, "fora": fora / total if total else 0.0, "desvio": statistics.mean(desv) if desv else 0.0}


def metricas_reais(jogs):
    erros, fora, desv = [], [], []
    for j in jogs:
        rec = j.get("receita") or {}
        m = metricas(rec.get("passos", []), entradas_de(j), hist_de(j), float(j.get("t_final", 0)))
        if not m:
            continue
        erros += m["erros"]
        fora.append(m["fora"])
        desv.append(m["desvio"])
    return erros, fora, desv


def receita_da_jogada(j):
    rec = j.get("receita") or {}
    if not rec.get("passos"):
        return None
    return {"chave": rec.get("nome", "jogada"), "nome": rec.get("nome", "jogada"), "passos": rec["passos"], "pocao": ""}


def calibrar(dados, jogs, progresso=None):
    """Ajusta a jogadora simulada às jogadas reais (com receita memorizada)."""
    com_receita = [j for j in jogs if receita_da_jogada(j)]
    if not com_receita:
        return None, "nenhuma jogada com receita memorizada"
    erros, fora_r, desv_r = metricas_reais(com_receita)
    params = dict(PADRAO_JOGADORA)
    if erros:
        params["vies_seg"] = statistics.mean(erros)
        params["sigma_seg"] = statistics.pstdev(erros) if len(erros) > 1 else 1.0
    alvo_fora = statistics.mean(fora_r) if fora_r else 0.0
    alvo_desv = statistics.mean(desv_r) if desv_r else 0.0
    # cliques por segundo: o ritmo mais rápido que você chegou a clicar
    ritmos = []
    for j in com_receita:
        ts = [a[0] for a in j.get("acoes", []) if a[1] == "+fogo"]
        for k in range(len(ts) - 3):
            dt = ts[k + 3] - ts[k]
            if dt > 0:
                ritmos.append(3.0 / dt)
    if ritmos:
        ritmos.sort()
        params["cliques_s"] = max(1.0, min(8.0, ritmos[int(0.9 * (len(ritmos) - 1))]))
    melhor, melhor_err = None, 1e9
    grade = [(f, r) for f in (2, 3, 4, 6, 8, 11, 15) for r in (0.0, 0.03, 0.06, 0.1, 0.15)]
    for n, (folga, ruido) in enumerate(grade):
        if progresso:
            progresso(n, len(grade))
        fs, ds = [], []
        for j in com_receita[:12]:
            rc = receita_da_jogada(j)
            for s in range(3):
                p2 = dict(params, folga=folga, ruido=ruido)
                r = sim.simular(rc, dados.itens, jogadora(p2, seed=s + 7), None)
                m = metricas(rc["passos"], [(t0, iid) for (t0, iid) in r["entradas"]], [(h[0], h[1]) for h in r["hist"]], r["t_final"])
                if m:
                    fs.append(m["fora"])
                    ds.append(m["desvio"])
        if not fs:
            continue
        err = ((statistics.mean(fs) - alvo_fora) / 0.1) ** 2 + ((statistics.mean(ds) - alvo_desv) / 3.0) ** 2
        if err < melhor_err:
            melhor, melhor_err = (folga, ruido), err
    if melhor:
        params["folga"], params["ruido"] = melhor
    params["n_jogadas"] = len(com_receita)
    with open(ARQ_CALIBRACAO, "w", encoding="utf-8") as f:
        json.dump(params, f, indent=2)
    resumo = ("%d jogadas | erro de tempo: média %+.1f s, desvio %.1f s | fora da faixa: %.0f%% | desvio da chama %.1f °C | "
              "cliques até %.1f/s → folga %g °C, ruído %g" % (len(com_receita), params["vies_seg"], params["sigma_seg"],
                                                              100 * alvo_fora, alvo_desv, params["cliques_s"],
                                                              params["folga"], params["ruido"]))
    return params, resumo


# =============================================================================
# .tres DOS ITENS
# =============================================================================
def salvar_item(item_id, valores):
    p = os.path.join(sim.PROJ, "dados", "itens", item_id + ".tres")
    with open(p, encoding="utf-8", newline="") as f:
        t = f.read()
    for k, v in valores.items():
        linha = "%s = %s" % (k, repr(float(v)))
        if re.search(r"^%s = .*$" % k, t, re.M):
            t = re.sub(r"^%s = .*$" % k, linha, t, count=1, flags=re.M)
        else:
            t = t.rstrip("\n") + "\n" + linha + "\n"
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(t)
    return p


# =============================================================================
# LINHA DE COMANDO
# =============================================================================
def cli(argv):
    dados = Dados()
    if "--testes" in argv:
        res = testes(dados)
        for n, t in res:
            print({"ok": "  ok   ", "aviso": "  AVISO", "falha": "  FALHA"}[n], t)
        falhas = sum(1 for n, _ in res if n == "falha")
        print("\n%d falha(s), %d aviso(s)" % (falhas, sum(1 for n, _ in res if n == "aviso")))
        return 1 if falhas else 0
    if "--dificuldade" in argv:
        params = ler_calibracao()
        for rc in dados.receitas.values():
            d = dificuldade(dados, rc, params)
            print("%-16s nota %d (%s)  chance %3.0f%% [%s]  janelas %s  chamas ok %s" % (
                rc["chave"], d["nota"], d["nota_txt"], 100 * d["chance"], d["criterio"],
                {k: "%.1fs" % v for k, v in d["janelas"].items()}, d["chamas"]))
        return 0
    if "--calibrar" in argv:
        i = argv.index("--calibrar")
        pasta = argv[i + 1] if len(argv) > i + 1 else pasta_jogadas_padrao()
        params, resumo = calibrar(dados, ler_jogadas(pasta))
        print(resumo)
        return 0
    return None


# =============================================================================
# INTERFACE
# =============================================================================
def interface(so_janela=False):
    """Abre a janela. so_janela=True: só cria e devolve a Janela (a ferramenta central usa numa aba)."""
    from PySide6 import QtCore, QtGui, QtWidgets as W
    import matplotlib
    matplotlib.use("QtAgg")
    from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg
    from matplotlib.figure import Figure

    class Grafico(FigureCanvasQTAgg):
        def __init__(self):
            self.fig = Figure(figsize=(7, 4), tight_layout=True)
            super().__init__(self.fig)

        def novo(self, n=1):
            self.fig.clear()
            axs = [self.fig.add_subplot(n, 1, k + 1) for k in range(n)]
            return axs if n > 1 else axs[0]

    def faixas_chama(ax):
        for e in sim.ESTADOS:
            lo, hi = max(e["T_min"], 20), min(e["T_max"], 220)
            if hi > lo:
                ax.axhspan(lo, hi, alpha=0.18, color=e["cor"], lw=0)

    def ocupado(f):
        def w(*a, **k):
            W.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
            try:
                return f(*a, **k)
            finally:
                W.QApplication.restoreOverrideCursor()
        return w

    def tabela(cabecalho):
        t = W.QTableWidget(0, len(cabecalho))
        t.setHorizontalHeaderLabels(cabecalho)
        t.horizontalHeader().setSectionResizeMode(W.QHeaderView.ResizeToContents)
        t.verticalHeader().setVisible(False)
        t.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        return t

    def preencher(t, linhas, cores=None):
        t.setRowCount(len(linhas))
        for i, l in enumerate(linhas):
            for j, v in enumerate(l):
                it = W.QTableWidgetItem(str(v))
                if cores and cores[i]:
                    it.setBackground(QtGui.QColor(cores[i]))
                t.setItem(i, j, it)

    def pct(x):
        return "%.1f%%" % (100 * x)

    class Janela(W.QMainWindow):
        def __init__(self):
            super().__init__()
            self.setWindowTitle("Balanceamento — Jogo da Bruxa")
            self.resize(1280, 820)
            self.dados = Dados()
            self.params = ler_calibracao()
            self.anterior = None          # última corrida (para comparar)
            self.mc_anterior = None
            self.tabs = W.QTabWidget()
            self.setCentralWidget(self.tabs)
            barra = self.addToolBar("principal")
            barra.addAction("Recarregar dados do projeto", self.recarregar)
            self.acao_quad = barra.addAction("Dose quadrática (a²)")
            self.acao_quad.setCheckable(True)
            self.acao_quad.setToolTip("Teste: cada ingrediente conta como a² em vez de a (mal cozido pesa bem menos). "
                                      "Só aqui no balanceamento; o jogo continua linear.")
            self.acao_quad.toggled.connect(self.trocar_dose)
            barra.addWidget(W.QLabel("  Cisalhamento: "))
            self.combo_cis = W.QComboBox()
            # (texto, σ, corte): ruído fixo por item fora da diagonal (teste do problema do zero)
            self.niveis_cis = [("desligado", 0.0, 0.0), ("±1% (σ 0,005)", 0.005, 0.01),
                               ("±2% (σ 0,01)", 0.01, 0.02), ("±4% (σ 0,02)", 0.02, 0.04)]
            self.combo_cis.addItems([n[0] for n in self.niveis_cis])
            self.combo_cis.setToolTip("Teste do problema do zero: ruído fixo por item fora da diagonal (normal, cortado), "
                                      "sorteado pelo nome do item. O catálogo segue o ruído. Só aqui; o jogo não muda.")
            self.combo_cis.setCurrentIndex(1)   # padrão: ±1%
            self.combo_cis.currentIndexChanged.connect(self.trocar_cisalhamento)
            barra.addWidget(self.combo_cis)
            self.status = W.QLabel()
            self.statusBar().addWidget(self.status)
            self.aba_receita()
            self.aba_sensibilidade()
            self.aba_monte()
            self.aba_itens()
            self.aba_testes()
            self.aba_dificuldade()
            self.aba_jogadas()
            self.atualizar_status()

        def atualizar_status(self):
            p = self.params
            self.status.setText("Projeto: %s | %d itens, %d receitas, %d poções | jogadora: cliques %.1f/s, reação %.2f s, "
                                "ruído %.2f, folga %.0f °C, tempo %+.1f±%.1f s" % (
                                    sim.PROJ, len(self.dados.itens), len(self.dados.receitas), len(self.dados.catalogo[0]),
                                    p["cliques_s"], p["reacao"], p["ruido"], p["folga"], p["vies_seg"], p["sigma_seg"]) + (" | dose: a² (teste)" if sim.EXPOENTE_DOSE == 2.0 else " | dose: a (linear)")
                                + (" | cisalhamento σ %.3f" % sim.CISALHAMENTO_SIGMA if sim.CISALHAMENTO else ""))

        def trocar_cisalhamento(self, idx):
            _, sigma, corte = self.niveis_cis[idx]
            sim.CISALHAMENTO = sigma > 0
            sim.CISALHAMENTO_SIGMA = sigma
            sim.CISALHAMENTO_MAX = corte
            sim.ajustar_catalogo_ao_ruido(self.dados.itens, self.dados.receitas, self.dados.catalogo)
            self.atualizar_status()
            try:
                self.rodar_receita()
            except Exception as e:  # noqa: BLE001
                print("[balanceamento] rodar depois de trocar o cisalhamento:", e)

        def trocar_dose(self, ligado):
            sim.EXPOENTE_DOSE = 2.0 if ligado else 1.0
            self.atualizar_status()
            try:
                self.rodar_receita()
            except Exception as e:  # noqa: BLE001
                print("[balanceamento] rodar depois de trocar a dose:", e)

        def recarregar(self):
            self.dados.recarregar()
            self.params = ler_calibracao()
            self.carregar_receita()
            self.carregar_item()
            self.atualizar_status()

        def combo_receitas(self):
            c = W.QComboBox()
            c.addItems(sorted(self.dados.receitas))
            return c

        # ---------------- Receita ----------------
        def aba_receita(self):
            w = W.QWidget()
            lay = W.QHBoxLayout(w)
            esq = W.QVBoxLayout()
            linha = W.QHBoxLayout()
            linha.addWidget(W.QLabel("Receita"))
            self.r_combo = W.QComboBox()
            self.r_combo.addItems(sorted(self.dados.receitas) + [NOVA_RECEITA])
            self.r_combo.currentTextChanged.connect(self.carregar_receita)
            linha.addWidget(self.r_combo, 1)
            esq.addLayout(linha)
            self.r_passos = W.QTableWidget(0, 4)
            self.r_passos.setHorizontalHeaderLabels(["passo", "chama / item", "qtd", "segundos"])
            self.r_passos.verticalHeader().setVisible(False)
            self.r_passos.setSelectionBehavior(W.QAbstractItemView.SelectRows)
            self.r_passos.setSelectionMode(W.QAbstractItemView.SingleSelection)
            self.r_passos.setMinimumWidth(470)
            esq.addWidget(self.r_passos)
            # mexer nos passos
            bts = W.QGridLayout()
            for k, (txt, f) in enumerate([("+ chama", lambda: self.novo_passo("chama")),
                                          ("+ ingrediente", lambda: self.novo_passo("ingrediente")),
                                          ("remover passo", self.remover_passo),
                                          ("subir", lambda: self.mover_passo(-1)),
                                          ("descer", lambda: self.mover_passo(1))]):
                b = W.QPushButton(txt)
                b.clicked.connect(f)
                bts.addWidget(b, k // 3, k % 3)
            esq.addLayout(bts)
            self.r_perfeita = W.QCheckBox("jogadora perfeita (sem erro)")
            self.r_perfeita.setChecked(True)
            self.r_perfeita.toggled.connect(self.mudou_receita)
            esq.addWidget(self.r_perfeita)
            self.r_auto = W.QCheckBox("rodar sozinho a cada mudança")
            self.r_auto.setChecked(True)
            esq.addWidget(self.r_auto)
            bt = W.QPushButton("Rodar")
            bt.clicked.connect(self.rodar_receita)
            esq.addWidget(bt)
            bt2 = W.QPushButton("Restaurar receita do arquivo")
            bt2.clicked.connect(self.carregar_receita)
            esq.addWidget(bt2)
            self.r_comparar = W.QCheckBox("mostrar a corrida anterior por cima")
            self.r_comparar.setChecked(True)
            esq.addWidget(self.r_comparar)
            self.r_resumo = W.QLabel()
            self.r_resumo.setWordWrap(True)
            self.r_resumo.setTextFormat(QtCore.Qt.RichText)
            esq.addWidget(self.r_resumo, 1)
            lay.addLayout(esq, 0)
            dir_ = W.QVBoxLayout()
            self.r_graf = Grafico()
            dir_.addWidget(self.r_graf, 3)
            self.r_tab = tabela(["item", "entrou (s)", "duração", "Q", "T mín", "T máx", "a_Q", "a T", "a tempo", "a"])
            dir_.addWidget(self.r_tab, 2)
            lay.addLayout(dir_, 1)
            self.tabs.addTab(w, "Receita")
            self._timer_auto = QtCore.QTimer(self)
            self._timer_auto.setSingleShot(True)
            self._timer_auto.setInterval(250)
            self._timer_auto.timeout.connect(self.rodar_receita)
            self.carregar_receita()

        def mudou_receita(self, *_):
            if getattr(self, "_montando", False):
                return
            if self.r_auto.isChecked():
                self._timer_auto.start()

        def carregar_receita(self, *_):
            nome = self.r_combo.currentText()
            if nome == NOVA_RECEITA:
                item0 = sorted(self.dados.itens)[0] if self.dados.itens else ""
                self.r_lista = [{"tipo": "chama", "estado": "normal"}, {"tipo": "ingrediente", "item": item0, "qtd": 1, "seg": 20.0}]
            else:
                rc = self.dados.receitas.get(nome)
                if not rc:
                    return
                self.r_lista = copy.deepcopy(rc["passos"])
            self.montar_passos()
            self.mudou_receita()

        def montar_passos(self, selecionar=-1):
            self._montando = True
            t = self.r_passos
            t.setRowCount(0)
            t.setRowCount(len(self.r_lista))
            estados = [e["id"] for e in sim.ESTADOS]
            for k, p in enumerate(self.r_lista):
                t.setItem(k, 0, W.QTableWidgetItem(str(k)))
                c = W.QComboBox()
                if p["tipo"] == "chama":
                    c.addItems(estados)
                    c.setCurrentText(p.get("estado", "normal"))
                    c.currentTextChanged.connect(self.mudou_receita)
                    t.setCellWidget(k, 1, c)
                    t.setCellWidget(k, 2, W.QLabel(""))
                    t.setCellWidget(k, 3, W.QLabel(""))
                else:
                    for iid in sorted(self.dados.itens):
                        c.addItem("%s (%s)" % (self.dados.itens[iid]["nome"], iid), iid)
                    c.setCurrentIndex(max(0, c.findData(p.get("item"))))
                    c.currentIndexChanged.connect(self.mudou_receita)
                    t.setCellWidget(k, 1, c)
                    q = W.QSpinBox()
                    q.setRange(1, 30)
                    q.setValue(int(p.get("qtd", 1)))
                    q.valueChanged.connect(self.mudou_receita)
                    t.setCellWidget(k, 2, q)
                    s = W.QDoubleSpinBox()
                    s.setRange(0, 600)
                    s.setSingleStep(1)
                    s.setDecimals(1)
                    s.setValue(float(p.get("seg", 0)))
                    s.valueChanged.connect(self.mudou_receita)
                    t.setCellWidget(k, 3, s)
            t.resizeColumnsToContents()
            if 0 <= selecionar < len(self.r_lista):
                t.selectRow(selecionar)
            self._montando = False

        def ler_passos(self):
            """Passos como estão na tabela."""
            t = self.r_passos
            out = []
            for k, p in enumerate(self.r_lista):
                if p["tipo"] == "chama":
                    out.append({"tipo": "chama", "estado": t.cellWidget(k, 1).currentText()})
                else:
                    out.append({"tipo": "ingrediente", "item": t.cellWidget(k, 1).currentData(),
                                "qtd": t.cellWidget(k, 2).value(), "seg": t.cellWidget(k, 3).value()})
            return out

        def _linha_sel(self):
            r = self.r_passos.currentRow()
            return r if 0 <= r < len(self.r_lista) else -1

        def novo_passo(self, tipo):
            self.r_lista = self.ler_passos()
            k = self._linha_sel()
            k = len(self.r_lista) if k < 0 else k + 1
            if tipo == "chama":
                p = {"tipo": "chama", "estado": "normal"}
            else:
                item0 = sorted(self.dados.itens)[0] if self.dados.itens else ""
                p = {"tipo": "ingrediente", "item": item0, "qtd": 1, "seg": 20.0}
            self.r_lista.insert(k, p)
            self.montar_passos(k)
            self.mudou_receita()

        def remover_passo(self):
            k = self._linha_sel()
            if k < 0:
                return
            self.r_lista = self.ler_passos()
            del self.r_lista[k]
            self.montar_passos(min(k, len(self.r_lista) - 1))
            self.mudou_receita()

        def mover_passo(self, d):
            k = self._linha_sel()
            j = k + d
            if k < 0 or not (0 <= j < len(self.r_lista)):
                return
            self.r_lista = self.ler_passos()
            self.r_lista[k], self.r_lista[j] = self.r_lista[j], self.r_lista[k]
            self.montar_passos(j)
            self.mudou_receita()

        def receita_editada(self):
            nome = self.r_combo.currentText()
            base = self.dados.receitas.get(nome, {"chave": "nova", "nome": "Receita nova", "pocao": ""})
            rc = {k: v for k, v in base.items() if k != "passos"}
            rc["passos"] = self.ler_passos()
            return rc

        @ocupado
        def rodar_receita(self, *_):
            rc = self.receita_editada()
            if not any(p["tipo"] == "ingrediente" for p in rc["passos"]):
                self.r_resumo.setText("Sem ingrediente: nada para cozinhar.")
                return
            r = sim.simular(rc, self.dados.itens, jogadora(self.params, seed=1, perfeita=self.r_perfeita.isChecked()),
                            self.dados.catalogo)
            ax = self.r_graf.novo()
            faixas_chama(ax)
            if self.anterior and self.r_comparar.isChecked():
                a = self.anterior
                ax.plot([h[0] for h in a["hist"]], [h[1] for h in a["hist"]], color="gray", alpha=0.6,
                        label="anterior (%s)" % pct(a["a"]))
            ax.plot([h[0] for h in r["hist"]], [h[1] for h in r["hist"]], label="agora (%s)" % pct(r["a"]))
            for (t0, _iid) in r["entradas"]:
                ax.axvline(t0, color="green", alpha=0.25, lw=1)
            ax.axvline(r["t_final"], color="red", ls="--")
            ax.set_ylim(15, 200)
            ax.set_xlabel("t (s)")
            ax.set_ylabel("T caldo (°C)")
            ax.legend(loc="upper left")
            self.r_graf.draw()
            linhas = []
            for d in r["diags"]:
                linhas.append([self.dados.itens[d["item"]]["nome"], "%.1f" % d["t0"], "%.1f" % d["dur"], "%.0f" % d["Q"],
                               "%.1f" % d["T_min"], "%.1f" % d["T_max"], pct(d["a_Q"]), pct(d["a_Tmin"] * d["a_Tmax"]),
                               pct(d["a_tmin"] * d["a_tmax"]), pct(d["a"])])
            preencher(self.r_tab, linhas, ["#ffd6d6" if d["a"] < 0.95 else "" for d in r["diags"]])
            nome, motivo = nome_como_jogo(self.dados, r)
            perto = proximas(self.dados, r["A"], 3)
            diag = "  ".join("%s ×%.3f" % (tr, r["A"][k][k]) for k, tr in enumerate("OCEAN"))
            fora = sum(abs(r["A"][i][j]) for i in range(5) for j in range(5) if i != j)
            self.r_resumo.setText(
                "<span style='font-size:15pt'>Resultado: <b>%s</b></span><br><i>%s</i><br>"
                "efeito: <b>%s</b><br><br>"
                "aproveitamento médio <b>%s</b> (pior item %s)<br>tempo total %.1f s<br><br>"
                "<b>Matriz</b>: %s%s<br><br><b>Poções mais perto</b> (distância / tolerância):<br>%s"
                % (nome, motivo, "SIM" if r.get("efeito") else "não", pct(r["a"]), pct(r["a_min_item"]), r["t_final"],
                   diag, ("<br>fora da diagonal: %.3f" % fora) if fora > 1e-4 else "",
                   "<br>".join("%s%s: %.3f / %.3f" % ("✔ " if d <= tol else "· ", n, d, tol) for n, d, tol in perto)))
            self.anterior = r

        # ---------------- Sensibilidade ----------------
        def aba_sensibilidade(self):
            w = W.QWidget()
            lay = W.QVBoxLayout(w)
            linha = W.QHBoxLayout()
            self.s_combo = self.combo_receitas()
            linha.addWidget(W.QLabel("Receita"))
            linha.addWidget(self.s_combo)
            self.s_passo = W.QSpinBox()
            linha.addWidget(W.QLabel("passo"))
            linha.addWidget(self.s_passo)
            self.s_faixa = W.QDoubleSpinBox()
            self.s_faixa.setRange(2, 60)
            self.s_faixa.setValue(15)
            linha.addWidget(W.QLabel("± segundos"))
            linha.addWidget(self.s_faixa)
            for txt, f in (("Erro de tempo", self.sens_tempo), ("Cor da chama", self.sens_chama), ("Mapa chama × tempo", self.sens_mapa)):
                b = W.QPushButton(txt)
                b.clicked.connect(f)
                linha.addWidget(b)
            linha.addStretch()
            lay.addLayout(linha)
            self.s_info = W.QLabel("Tempo: escolha um passo de ingrediente. Chama/mapa: o passo de chama é o anterior ao passo escolhido.")
            lay.addWidget(self.s_info)
            self.s_graf = Grafico()
            lay.addWidget(self.s_graf)
            self.tabs.addTab(w, "Sensibilidade")

        def _rc_s(self):
            rc = self.dados.receitas[self.s_combo.currentText()]
            p = min(self.s_passo.value(), len(rc["passos"]) - 1)
            return rc, p

        @ocupado
        def sens_tempo(self, *_):
            rc, p = self._rc_s()
            if rc["passos"][p]["tipo"] != "ingrediente":
                p = passos_ing(rc)[-1]
            f = self.s_faixa.value()
            xs, a, pior, ef = [], [], [], []
            x = -f
            while x <= f + 1e-9:
                r = sim.simular(rc, self.dados.itens, sim.Jogadora(erro_seg={p: x}), self.dados.catalogo, guardar_hist=False)
                xs.append(x)
                a.append(r["a"])
                pior.append(r["a_min_item"])
                ef.append(1 if r.get("efeito") else 0)
                x += 0.5
            ax = self.s_graf.novo()
            ax.plot(xs, a, label="a médio")
            ax.plot(xs, pior, alpha=0.6, label="pior item")
            ax.fill_between(xs, 0, 1, where=[e == 1 for e in ef], color="gold", alpha=0.15, label="com efeito")
            ax.axhline(0.95, color="red", ls="--")
            ax.set_ylim(0, 1.02)
            ax.set_xlabel("erro nos segundos do passo %d (%s)" % (p, rc["passos"][p]["item"]))
            ax.legend()
            larg, lo, hi = janela_tempo(self.dados, rc, p)
            ax.set_title("%s: janela para 95%%: %+.1f a %+.1f s (%.1f s)" % (rc["nome"], lo, hi, larg))
            self.s_graf.draw()

        def _passo_chama(self, rc, p):
            for k in range(p, -1, -1):
                if rc["passos"][k]["tipo"] == "chama":
                    return k
            return passos_chama(rc)[0] if passos_chama(rc) else None

        @ocupado
        def sens_chama(self, *_):
            rc, p = self._rc_s()
            pc = self._passo_chama(rc, p)
            if pc is None:
                return
            nomes, vals, cores = [], [], []
            for e in sim.ESTADOS:
                if e["id"] in ("apagado", "negro"):
                    continue
                r = sim.simular(rc, self.dados.itens, sim.Jogadora(chama={pc: e["id"]}), self.dados.catalogo, guardar_hist=False)
                nomes.append(e["nome"])
                vals.append(r["a"])
                cores.append(e["cor"])
            ax = self.s_graf.novo()
            ax.bar(nomes, vals, color=cores, edgecolor="k")
            ax.axhline(0.95, color="red", ls="--")
            ax.set_ylim(0, 1.02)
            ax.set_title("%s: chama do passo %d (pedida: %s)" % (rc["nome"], pc, rc["passos"][pc]["estado"]))
            self.s_graf.draw()

        @ocupado
        def sens_mapa(self, *_):
            rc, p = self._rc_s()
            if rc["passos"][p]["tipo"] != "ingrediente":
                p = passos_ing(rc)[-1]
            pc = self._passo_chama(rc, p)
            if pc is None:
                return
            f = self.s_faixa.value()
            estados = [e for e in sim.ESTADOS if e["id"] not in ("apagado", "negro")]
            xs = []
            x = -f
            while x <= f + 1e-9:
                xs.append(x)
                x += 1.0
            grade = [[sim.simular(rc, self.dados.itens, sim.Jogadora(erro_seg={p: x}, chama={pc: e["id"]}), self.dados.catalogo,
                                  guardar_hist=False)["a"] for x in xs] for e in estados]
            ax = self.s_graf.novo()
            im = ax.imshow(grade, aspect="auto", vmin=0, vmax=1, origin="lower", extent=[xs[0], xs[-1], -0.5, len(estados) - 0.5])
            ax.contour(xs, list(range(len(estados))), grade, levels=[0.8, 0.95], colors=["white", "red"])
            ax.set_yticks(range(len(estados)))
            ax.set_yticklabels([e["nome"] for e in estados])
            ax.set_xlabel("erro nos segundos do passo %d (s)" % p)
            ax.set_title("%s: chama do passo %d × tempo do passo %d (vermelho = 95%%)" % (rc["nome"], pc, p))
            self.s_graf.fig.colorbar(im, ax=ax)
            self.s_graf.draw()

        # ---------------- Monte Carlo ----------------
        def aba_monte(self):
            w = W.QWidget()
            lay = W.QHBoxLayout(w)
            esq = W.QFormLayout()
            self.m_combo = self.combo_receitas()
            esq.addRow("Receita", self.m_combo)
            self.m_campos = {}
            for k, (mn, mx, st, txt) in {"cliques_s": (0.5, 10, 0.5, "cliques/s máx"), "reacao": (0.05, 1.5, 0.05, "reação (s)"),
                                         "ruido": (0, 0.5, 0.01, "erro ao ler a chama"), "folga": (0, 30, 1, "folga (°C)"),
                                         "sigma_seg": (0, 20, 0.5, "desvio no tempo (s)"), "vies_seg": (-20, 20, 0.5, "erro médio no tempo (s)")}.items():
                s = W.QDoubleSpinBox()
                s.setRange(mn, mx)
                s.setSingleStep(st)
                s.setDecimals(2)
                self.m_campos[k] = s
                esq.addRow(txt, s)
            self.m_n = W.QSpinBox()
            self.m_n.setRange(20, 3000)
            self.m_n.setValue(300)
            esq.addRow("jogadas", self.m_n)
            b0 = W.QPushButton("Usar a jogadora calibrada")
            b0.clicked.connect(self.mc_calibrada)
            esq.addRow(b0)
            b = W.QPushButton("Rodar")
            b.clicked.connect(self.rodar_monte)
            esq.addRow(b)
            self.m_comparar = W.QCheckBox("comparar com a rodada anterior")
            self.m_comparar.setChecked(True)
            esq.addRow(self.m_comparar)
            self.m_info = W.QLabel()
            self.m_info.setWordWrap(True)
            esq.addRow(self.m_info)
            caixa = W.QWidget()
            caixa.setLayout(esq)
            caixa.setMaximumWidth(380)
            lay.addWidget(caixa)
            self.m_graf = Grafico()
            lay.addWidget(self.m_graf, 1)
            self.tabs.addTab(w, "Monte Carlo")
            self.mc_calibrada()

        def mc_calibrada(self, *_):
            for k, s in self.m_campos.items():
                s.setValue(self.params[k])

        @ocupado
        def rodar_monte(self, *_):
            rc = self.dados.receitas[self.m_combo.currentText()]
            params = {k: s.value() for k, s in self.m_campos.items()}
            res = monte_carlo(self.dados, rc, params, self.m_n.value())
            vals = [r["a"] for r in res]
            ef = sum(1 for r in res if r.get("efeito")) / len(res)
            ax = self.m_graf.novo()
            if self.mc_anterior and self.m_comparar.isChecked():
                ax.hist(self.mc_anterior["vals"], bins=40, range=(0, 1), alpha=0.4, color="gray", label="anterior: " + self.mc_anterior["rot"])
            rot = "%s, ≥95%% %s, efeito %s" % (rc["chave"], pct(sum(1 for v in vals if v >= 0.95) / len(vals)), pct(ef))
            ax.hist(vals, bins=40, range=(0, 1), alpha=0.7, label="agora: " + rot)
            ax.axvline(0.95, color="red", ls="--")
            ax.set_xlabel("aproveitamento médio")
            ax.set_ylabel("jogadas")
            ax.legend(loc="upper left", fontsize=8)
            self.m_graf.draw()
            vs = sorted(vals)
            self.m_info.setText("média %s · mediana %s · p10 %s · p90 %s<br>≥95%%: <b>%s</b> · ≥90%%: %s · ≥80%%: %s<br>com efeito: <b>%s</b>" % (
                pct(statistics.mean(vals)), pct(vs[len(vs) // 2]), pct(vs[len(vs) // 10]), pct(vs[9 * len(vs) // 10]),
                pct(sum(1 for v in vals if v >= 0.95) / len(vals)), pct(sum(1 for v in vals if v >= 0.9) / len(vals)),
                pct(sum(1 for v in vals if v >= 0.8) / len(vals)), pct(ef)))
            self.mc_anterior = {"vals": vals, "rot": rot}

        # ---------------- Itens ----------------
        def aba_itens(self):
            w = W.QWidget()
            lay = W.QHBoxLayout(w)
            esq = W.QFormLayout()
            self.i_combo = W.QComboBox()
            self.i_combo.addItems(sorted(self.dados.itens))
            self.i_combo.currentTextChanged.connect(self.carregar_item)
            esq.addRow("Item", self.i_combo)
            self.i_campos = {}
            for k in CAMPOS_ITEM:
                s = W.QDoubleSpinBox()
                s.setRange(0, 100000)
                s.setDecimals(3)
                s.setSingleStep(10 if k in ("m", "s_menos", "s_mais") else (1 if k in ("T_min", "T_max", "t_min", "t_max") else 0.05))
                s.valueChanged.connect(self.item_mudou)
                self.i_campos[k] = s
                esq.addRow(k, s)
            b1 = W.QPushButton("Salvar no .tres do item")
            b1.clicked.connect(self.salvar_item)
            esq.addRow(b1)
            b2 = W.QPushButton("Desfazer (ler do arquivo)")
            b2.clicked.connect(self.desfazer_item)
            esq.addRow(b2)
            self.i_info = W.QLabel("As mudanças valem na hora para todas as abas (sem salvar).")
            self.i_info.setWordWrap(True)
            esq.addRow(self.i_info)
            caixa = W.QWidget()
            caixa.setLayout(esq)
            caixa.setMaximumWidth(340)
            lay.addWidget(caixa)
            dir_ = W.QVBoxLayout()
            self.i_tab = tabela(["chama", "T (°C)", "95%: de", "até", "±", "80%: de", "até"])
            dir_.addWidget(self.i_tab, 1)
            self.i_graf = Grafico()
            dir_.addWidget(self.i_graf, 1)
            lay.addLayout(dir_, 1)
            self.tabs.addTab(w, "Itens")
            self.carregar_item()

        def carregar_item(self, *_):
            it = self.dados.itens.get(self.i_combo.currentText())
            if not it:
                return
            self._carregando = True
            for k, s in self.i_campos.items():
                s.setValue(float(it.get(k, 0.0)))
            self._carregando = False
            self.mostrar_item()

        def item_mudou(self, *_):
            if getattr(self, "_carregando", False):
                return
            it = self.dados.itens.get(self.i_combo.currentText())
            for k, s in self.i_campos.items():
                it[k] = s.value()
            self.mostrar_item()

        def mostrar_item(self):
            it = self.dados.itens.get(self.i_combo.currentText())
            linhas = []
            for e in sim.ESTADOS:
                if e["id"] in ("apagado", "negro"):
                    continue
                T = sim.T_alvo_estado(e["id"])
                j95 = sim.janela_item(it, T, 0.95)
                j80 = sim.janela_item(it, T, 0.80)
                linhas.append([e["nome"], "%.0f" % T, "%.1f" % j95[0] if j95 else "-", "%.1f" % j95[1] if j95 else "-",
                               "%.1f" % ((j95[1] - j95[0]) / 2) if j95 else "-", "%.1f" % j80[0] if j80 else "-",
                               "%.1f" % j80[1] if j80 else "-"])
            preencher(self.i_tab, linhas)
            ax = self.i_graf.novo()
            for e in sim.ESTADOS:
                if e["id"] in ("apagado", "negro"):
                    continue
                T = sim.T_alvo_estado(e["id"])
                xs = [s / 2 for s in range(0, 240)]
                ys = []
                for s in xs:
                    ys.append(sim.a_cozimento(T * s, it["m"], it["s_menos"], it["s_mais"]) * sim.curva_max(T, it["T_max"], it["k_max"]) *
                              sim.curva_min(T, it["T_min"], it["k_min"]) * sim.curva_min(s, it["t_min"], it["h_min"]) *
                              sim.curva_max(s, it["t_max"], it["h_max"]))
                if max(ys) > 0.05:
                    ax.plot(xs, ys, color=e["cor"], label=e["nome"], lw=2)
            ax.axhline(0.95, color="red", ls="--")
            ax.set_xlabel("segundos cozinhando (T constante)")
            ax.set_ylabel("aproveitamento")
            ax.set_ylim(0, 1.02)
            ax.legend(fontsize=8)
            ax.set_title(it["nome"])
            self.i_graf.draw()

        def salvar_item(self, *_):
            iid = self.i_combo.currentText()
            vals = {k: s.value() for k, s in self.i_campos.items()}
            if W.QMessageBox.question(self, "Salvar", "Gravar estes valores em dados/itens/%s.tres?\n(feche o .tres no Godot antes)" % iid) != W.QMessageBox.Yes:
                return
            p = salvar_item(iid, vals)
            self.i_info.setText("Salvo em %s" % os.path.relpath(p, sim.PROJ))

        def desfazer_item(self, *_):
            novos = sim.carregar_itens()
            iid = self.i_combo.currentText()
            if iid in novos:
                self.dados.itens[iid] = novos[iid]
            self.carregar_item()

        # ---------------- Testes ----------------
        def aba_testes(self):
            w = W.QWidget()
            lay = W.QVBoxLayout(w)
            b = W.QPushButton("Rodar os testes")
            b.clicked.connect(self.rodar_testes)
            lay.addWidget(b)
            self.t_resumo = W.QLabel()
            lay.addWidget(self.t_resumo)
            self.t_lista = W.QListWidget()
            lay.addWidget(self.t_lista)
            self.tabs.addTab(w, "Testes")

        @ocupado
        def rodar_testes(self, *_):
            res = testes(self.dados, self.params)
            self.t_lista.clear()
            cor = {"ok": "#dff5df", "aviso": "#fff2c2", "falha": "#ffd0d0"}
            ordem = {"falha": 0, "aviso": 1, "ok": 2}
            for n, t in sorted(res, key=lambda x: ordem[x[0]]):
                it = W.QListWidgetItem({"ok": "✔ ", "aviso": "⚠ ", "falha": "✘ "}[n] + t)
                it.setBackground(QtGui.QColor(cor[n]))
                self.t_lista.addItem(it)
            self.t_resumo.setText("%d ok · %d avisos · %d falhas" % tuple(sum(1 for n, _ in res if n == k) for k in ("ok", "aviso", "falha")))

        # ---------------- Dificuldade ----------------
        def aba_dificuldade(self):
            w = W.QWidget()
            lay = W.QVBoxLayout(w)
            b = W.QPushButton("Calcular (usa a jogadora calibrada)")
            b.clicked.connect(self.rodar_dificuldade)
            lay.addWidget(b)
            lay.addWidget(W.QLabel("Nota 1–5 pela chance de acertar (efeito, ou ≥95% se a poção não tem efeito). "
                                   "Janela = quantos segundos de erro cada passo aguenta mantendo 95%. "
                                   "Chamas = cores que também dão 95%."))
            self.d_tab = tabela(["receita", "nota", "chance", "critério", "a médio", "passos", "janelas de tempo (95%)", "chamas que servem"])
            lay.addWidget(self.d_tab, 1)
            self.d_graf = Grafico()
            lay.addWidget(self.d_graf, 1)
            self.tabs.addTab(w, "Dificuldade")

        @ocupado
        def rodar_dificuldade(self, *_):
            ds = [dificuldade(self.dados, rc, self.params) for rc in self.dados.receitas.values()]
            ds.sort(key=lambda d: d["chance"], reverse=True)
            linhas = [[d["receita"], "%d (%s)" % (d["nota"], d["nota_txt"]), pct(d["chance"]), d["criterio"], pct(d["a_medio"]),
                       d["passos"], "  ".join("p%d: %.1f s" % (k, v) for k, v in d["janelas"].items()),
                       "  ".join("p%d: %s" % (k, ", ".join(v) or "nenhuma") for k, v in d["chamas"].items())] for d in ds]
            cores = {1: "#dff5df", 2: "#eef8d8", 3: "#fff2c2", 4: "#ffe0c0", 5: "#ffd0d0"}
            preencher(self.d_tab, linhas, [cores[d["nota"]] for d in ds])
            ax = self.d_graf.novo()
            ax.barh([d["receita"] for d in ds], [d["chance"] for d in ds], color=[cores[d["nota"]] for d in ds], edgecolor="k")
            ax.set_xlim(0, 1)
            ax.set_xlabel("chance de acertar com a jogadora calibrada")
            self.d_graf.draw()

        # ---------------- Jogadas reais ----------------
        def aba_jogadas(self):
            w = W.QWidget()
            lay = W.QHBoxLayout(w)
            esq = W.QVBoxLayout()
            linha = W.QHBoxLayout()
            self.j_pasta = W.QLineEdit(pasta_jogadas_padrao())
            linha.addWidget(self.j_pasta)
            b = W.QPushButton("…")
            b.clicked.connect(self.escolher_pasta)
            linha.addWidget(b)
            esq.addWidget(W.QLabel("Pasta das jogadas (o jogo grava em debug: user://jogadas)"))
            esq.addLayout(linha)
            b2 = W.QPushButton("Ler jogadas")
            b2.clicked.connect(self.ler_jogadas)
            esq.addWidget(b2)
            self.j_lista = W.QListWidget()
            self.j_lista.currentRowChanged.connect(self.mostrar_jogada)
            esq.addWidget(self.j_lista, 1)
            b3 = W.QPushButton("Calibrar a jogadora com estas jogadas")
            b3.clicked.connect(self.calibrar)
            esq.addWidget(b3)
            self.j_info = W.QLabel()
            self.j_info.setWordWrap(True)
            esq.addWidget(self.j_info)
            caixa = W.QWidget()
            caixa.setLayout(esq)
            caixa.setMaximumWidth(420)
            lay.addWidget(caixa)
            dir_ = W.QVBoxLayout()
            self.j_graf = Grafico()
            dir_.addWidget(self.j_graf, 3)
            self.j_tab = tabela(["item", "entrou (s)", "a gravado", "a com os itens de agora"])
            dir_.addWidget(self.j_tab, 1)
            lay.addLayout(dir_, 1)
            self.tabs.addTab(w, "Jogadas reais")
            self.jogadas = []

        def escolher_pasta(self, *_):
            d = W.QFileDialog.getExistingDirectory(self, "Pasta das jogadas", self.j_pasta.text())
            if d:
                self.j_pasta.setText(d)
                self.ler_jogadas()

        def ler_jogadas(self, *_):
            self.jogadas = ler_jogadas(self.j_pasta.text())
            self.j_lista.clear()
            for j in self.jogadas:
                rec = (j.get("receita") or {}).get("nome", "") or "sem receita"
                a = j.get("aproveitamento", [])
                self.j_lista.addItem("%s  ·  %s  ·  %s" % (j.get("quando", "?"), rec, pct(sum(a) / len(a)) if a else "-"))
            self.j_info.setText("%d jogadas (%d com receita memorizada)" % (len(self.jogadas), sum(1 for j in self.jogadas if receita_da_jogada(j))))
            self.mostrar_resumo_real()

        def mostrar_resumo_real(self):
            if not self.jogadas:
                return
            ax1, ax2 = self.j_graf.novo(2)
            erros, fora, desv = metricas_reais(self.jogadas)
            reais = [sum(j["aproveitamento"]) / len(j["aproveitamento"]) for j in self.jogadas if j.get("aproveitamento")]
            ax1.hist(reais, bins=20, range=(0, 1), alpha=0.7, label="suas jogadas")
            sims = []
            for j in self.jogadas[:20]:
                rc = receita_da_jogada(j)
                if rc:
                    for r in monte_carlo(self.dados, rc, self.params, 10):
                        sims.append(r["a"])
            if sims:
                ax1.hist(sims, bins=20, range=(0, 1), alpha=0.4, color="gray", label="jogadora simulada")
            ax1.axvline(0.95, color="red", ls="--")
            ax1.set_title("aproveitamento: você × simulada")
            ax1.legend(fontsize=8)
            if erros:
                ax2.hist(erros, bins=20, alpha=0.7)
                ax2.set_title("seus erros de tempo nos passos (s): média %+.1f, desvio %.1f" % (statistics.mean(erros), statistics.pstdev(erros)))
            self.j_graf.draw()

        def mostrar_jogada(self, i):
            if i < 0 or i >= len(self.jogadas):
                return
            j = self.jogadas[i]
            ax = self.j_graf.novo()
            faixas_chama(ax)
            h = j.get("historico", [])
            ax.plot([x[0] for x in h], [x[1] for x in h], label="sua jogada")
            rc = receita_da_jogada(j)
            if rc:
                r = sim.simular(rc, self.dados.itens, sim.Jogadora(), self.dados.catalogo)
                ax.plot([x[0] for x in r["hist"]], [x[1] for x in r["hist"]], color="gray", alpha=0.7, label="jogadora perfeita")
            for e in j.get("entradas", []):
                ax.axvline(e[1], color="green", alpha=0.25, lw=1)
            for a in j.get("acoes", []):
                if a[1] in ("+fogo", "-fogo"):
                    ax.plot([a[0]], [18], marker="|", color="orange" if a[1] == "+fogo" else "blue", ms=8)
            ax.axvline(float(j.get("t_final", 0)), color="red", ls="--")
            ax.set_ylim(15, 200)
            ax.legend(loc="upper left")
            ax.set_title("%s — %s" % (j.get("quando", ""), (j.get("receita") or {}).get("nome", "sem receita")))
            self.j_graf.draw()
            r2 = reavaliar(self.dados, j)
            gravado = j.get("aproveitamento", [])
            linhas = []
            for k, d in enumerate(r2["diags"]):
                linhas.append([self.dados.itens[d["item"]]["nome"], "%.1f" % d["t0"], pct(gravado[k]) if k < len(gravado) else "-", pct(d["a"])])
            preencher(self.j_tab, linhas)

        @ocupado
        def calibrar(self, *_):
            if not self.jogadas:
                self.ler_jogadas()
            params, resumo = calibrar(self.dados, self.jogadas)
            if params:
                self.params = ler_calibracao()
                self.mc_calibrada()
                self.atualizar_status()
            self.j_info.setText(resumo)
            self.mostrar_resumo_real()

    app = W.QApplication.instance() or W.QApplication(sys.argv)
    j = Janela()
    if so_janela:
        return j
    j.show()
    return app.exec()


if __name__ == "__main__":
    r = cli(sys.argv[1:])
    if r is not None:
        sys.exit(r)
    sys.exit(interface())
