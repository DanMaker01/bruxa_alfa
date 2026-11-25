# itens.py - aba Itens: todos os itens (dados/itens/*.tres) com os campos principais,
# "no banco" (se o jogo carrega) e, à direita, a matriz A, o que ela faz e o valor de troca.
# "Novo item" cria o .tres com os padrões e registra em dados/banco.tres (o ícone se escolhe
# depois no Godot, no Inspector do item).
from PySide6 import QtGui, QtWidgets as W

from nucleo import chamas, motor
from nucleo import tres_simples as ts
from nucleo.tabela import TabelaTres, pedir_id
from nucleo.visual import GraficoLinhas

TITULO = "Itens"
CAMPOS = [("nome", "texto", "", "nome"),
          ("valor_base", "num", 10.0, "valor base"), ("qtd_base", "num", 5.0, "qtd base"),
          ("m", "num", 0.0, "Q ideal (m)"), ("s_menos", "num", 1000.0, "s−"), ("s_mais", "num", 1000.0, "s+"),
          ("T_min", "num", 0.0, "T mín"), ("k_min", "num", 0.25, "k mín"),
          ("T_max", "num", 0.0, "T máx"), ("k_max", "num", 0.25, "k máx"),
          ("t_min", "num", 0.0, "t mín (s)"), ("t_max", "num", 0.0, "t máx (s)"),
          ("h_min", "num", 0.25, "h mín"), ("h_max", "num", 0.25, "h máx"),
          ("descricao", "texto", "", "descrição")]


class Aba(TabelaTres):
    def __init__(self, raiz):
        super().__init__(raiz, "dados/itens/*.tres", "ItemData", CAMPOS, com_matriz=True, coluna_id="item", banco="itens")
        b = W.QPushButton("Novo item")
        b.clicked.connect(self.novo)
        self.barra.insertWidget(1, b)
        caixa = W.QGroupBox("O que faz")
        v = W.QVBoxLayout(caixa)
        self.desc = W.QLabel(wordWrap=True)
        v.addWidget(self.desc)
        self.painel_lay.addWidget(caixa)
        caixa = W.QGroupBox("Valor para um mercador (valor base · qtd base / (qtd base + estoque dele))")
        v = W.QVBoxLayout(caixa)
        self.valor = W.QLabel()
        v.addWidget(self.valor)
        self.painel_lay.addWidget(caixa)
        caixa = W.QGroupBox("Curvas de aproveitamento (as mesmas do jogo)")
        v = W.QVBoxLayout(caixa)
        self.g_coz, self.g_temp, self.g_tempo = GraficoLinhas(), GraficoLinhas(), GraficoLinhas()
        for g in (self.g_coz, self.g_temp, self.g_tempo):
            g.setMinimumHeight(150)
            v.addWidget(g)
        self.painel_lay.addWidget(caixa)
        caixa = W.QGroupBox("Aproveitamento por cor da chama (1 item jogado com a chama já firme)")
        v = W.QVBoxLayout(caixa)
        self.g_chama = GraficoLinhas()
        self.g_chama.setMinimumHeight(240)
        v.addWidget(self.g_chama)
        self.painel_lay.addWidget(caixa)
        self.fim_do_painel()
        self.linha_escolhida.connect(self.atualizar)
        self.mudou.connect(self.atualizar)
        self.atualizar()

    def atualizar(self, *_):
        l = self.atual()
        if not l or not hasattr(self, "desc"):
            return
        self.desc.setText("\n".join(ts.descrever_matriz(l["A"])))
        vb, qb = float(l["valores"]["valor_base"] or 0), max(float(l["valores"]["qtd_base"] or 0.1), 0.1)
        self.valor.setText("   ".join("estoque %d: %.1f" % (e, vb * qb / (qb + e)) for e in (0, 5, 10, 20)))
        self._curvas(l["valores"])

    def _curvas(self, v):
        try:
            sim, _ = motor.balanceamento()
        except Exception as e:  # noqa: BLE001
            self.g_coz.definir([], titulo_y="sem o simulador: %s" % e)
            return
        f = lambda k, p=0.0: float(v.get(k) if v.get(k) is not None else p)
        amar = QtGui.QColor("#f2c14e")
        # cozimento: a_Q(Q)
        m = f("m")
        qmax = max(2 * m + 3 * f("s_mais", 1000), 6000) if m > 0 else 6000
        pts = [(q, sim.a_cozimento(q, m, f("s_menos", 1000), f("s_mais", 1000))) for q in [qmax * i / 200 for i in range(201)]]
        self.g_coz.definir([(pts, amar, "")], marcas=[(m, "ideal")] if m > 0 else [], faixa_y=(0, 1),
                           titulo_y="cozimento (Q = ∫T dt)", unidade_x="")
        # temperatura: a(T) com as faixas das chamas
        faixas = []
        for e in sim.ESTADOS:
            c = QtGui.QColor.fromRgbF(*e["cor"][:3])
            c.setAlpha(40)
            faixas.append((e["T_min"], e["T_max"], c))
        pts = [(T, sim.curva_min(T, f("T_min"), f("k_min", 0.25)) * sim.curva_max(T, f("T_max"), f("k_max", 0.25)))
               for T in [250 * i / 250 for i in range(251)]]
        self.g_temp.definir([(pts, amar, "")], marcas=[(x, n) for x, n in ((f("T_min"), "mín"), (f("T_max"), "máx")) if 0 < x < 999],
                            faixa_y=(0, 1), titulo_y="temperatura do caldo (faixas = chamas)", unidade_x="°", faixas_x=faixas)
        # tempo no caldeirão
        tmax = f("t_max")
        lim = max(1.5 * (tmax if 0 < tmax < 999 else f("t_min") * 2 or 60), 30)
        pts = [(t, sim.curva_min(t, f("t_min"), f("h_min", 0.25)) * sim.curva_max(t, tmax, f("h_max", 0.25)))
               for t in [lim * i / 200 for i in range(201)]]
        self.g_tempo.definir([(pts, amar, "")], marcas=[(x, n) for x, n in ((f("t_min"), "mín"), (tmax, "máx")) if 0 < x < 999],
                             faixa_y=(0, 1), titulo_y="tempo no caldeirão", unidade_x="s")
        # por cor da chama: simula a temperatura de cada chama e avalia o item nela
        item = {k: f(k, p) for k, p in (("m", 0), ("s_menos", 1000), ("s_mais", 1000), ("T_min", 0), ("k_min", 0.25),
                                         ("T_max", 0), ("k_max", 0.25), ("t_min", 0), ("h_min", 0.25), ("t_max", 0), ("h_max", 0.25))}
        item["id"] = "_aba"
        series = []
        for e in chamas.estados(sim):
            pts = chamas.curva_item(sim, item, e["id"], lim)
            if max(a for _, a in pts) > 0.001:
                series.append((pts, chamas.cor(sim, e["id"]), e["nome"]))
        self.g_chama.definir(series, marcas=[(x, n) for x, n in ((f("t_min"), "mín"), (tmax, "máx")) if 0 < x < 999],
                             faixa_y=(0, 1), titulo_y="aproveitamento × segundos no caldo (chamas que dão > 0)", unidade_x="s")

    def novo(self):
        nid = pedir_id(self, "Novo item", "pena_coruja")
        if not nid:
            return
        nome = nid.replace("_", " ").capitalize()
        self.novo_arquivo("dados/itens", nid,
                          '[gd_resource type="Resource" script_class="ItemData" format=3]\n\n'
                          '[ext_resource type="Script" path="res://src/dados/item_data.gd" id="1_item"]\n\n'
                          '[resource]\nscript = ExtResource("1_item")\nid = "%s"\nnome = "%s"\n' % (nid, nome))


def criar(raiz):
    return Aba(raiz)
