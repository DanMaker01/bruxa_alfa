# calibracao.py - aba Calibração: as jogadas reais gravadas pelo jogo (build de debug grava em
# user://jogadas/) comparadas com as jogadoras simuladas, e a calibração da jogadora calibrada.
#   Jogadas:     cada preparo gravado: quando, receita, aproveitamento que deu no jogo e o que daria
#                hoje com os itens atuais (reavaliado).
#   Jogadoras:   os parâmetros da perfeita, da calibrada (ferramentas/calibracao.json) e da ruim.
#                "Calibrar com as jogadas" ajusta a calibrada às jogadas com receita memorizada e grava
#                o calibracao.json (o mesmo do balanceamento.py --calibrar).
#   Comparação:  por receita, a média real e a média das jogadoras simuladas (Monte Carlo), e a
#                distribuição do aproveitamento (real × calibrada × ruim) no gráfico.
import os
import statistics

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import motor
from nucleo.visual import GraficoLinhas

TITULO = "Calibração"
CHAVES = ["cliques_s", "reacao", "ruido", "folga", "sigma_seg", "vies_seg"]
ROTULOS = {"cliques_s": "cliques por segundo", "reacao": "reação (s)", "ruido": "erro ao ler a chama (fração)",
           "folga": "folga da chama (°C)", "sigma_seg": "erro no tempo (desvio, s)", "vies_seg": "atraso médio (s)"}


def _ruim():
    try:
        from abas.balanceamento import JOGADORA_RUIM
        return dict(JOGADORA_RUIM)
    except Exception:  # noqa: BLE001
        return {"cliques_s": 2.0, "reacao": 0.5, "ruido": 0.12, "folga": 5.0, "sigma_seg": 6.0, "vies_seg": 2.0}


def media_a(j):
    a = j.get("aproveitamento") or []
    return sum(a) / len(a) if a else None


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        self.sim, self.bal = motor.balanceamento()
        self.dados = self.bal.Dados()
        self.jogadas = []
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        h.addWidget(W.QLabel("Pasta das jogadas:"))
        self.pasta = W.QLineEdit(self.bal.pasta_jogadas_padrao())
        h.addWidget(self.pasta, 1)
        b = W.QPushButton("...")
        b.clicked.connect(self._escolher_pasta)
        h.addWidget(b)
        for txt, fn in (("Ler jogadas", self.ler), ("Calibrar com as jogadas", self.calibrar), ("Comparar", self.comparar)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        self.n_mc = W.QSpinBox(minimum=10, maximum=500, value=60, suffix=" jogadas sim.")
        h.addWidget(self.n_mc)
        lay.addLayout(h)
        self.info = W.QLabel()
        self.info.setWordWrap(True)
        lay.addWidget(self.info)
        split = W.QSplitter(QtCore.Qt.Vertical)
        cima = W.QSplitter()
        self.tab = W.QTableWidget(0, 4)
        self.tab.setHorizontalHeaderLabels(["quando", "receita", "no jogo", "hoje"])
        self.tab.verticalHeader().setVisible(False)
        self.tab.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.tab.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.tab.setToolTip("hoje = a mesma jogada (tempos e temperatura) avaliada com os itens atuais")
        cima.addWidget(self.tab)
        self.params = W.QTableWidget(len(CHAVES), 3)
        self.params.setHorizontalHeaderLabels(["perfeita", "calibrada", "ruim"])
        self.params.setVerticalHeaderLabels([ROTULOS[k] for k in CHAVES])
        self.params.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        cima.addWidget(self.params)
        cima.setSizes([620, 520])
        split.addWidget(cima)
        baixo = W.QSplitter()
        self.comp = W.QTableWidget(0, 5)
        self.comp.setHorizontalHeaderLabels(["receita", "real (n)", "perfeita", "calibrada", "ruim"])
        self.comp.verticalHeader().setVisible(False)
        self.comp.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        baixo.addWidget(self.comp)
        self.graf = GraficoLinhas()
        baixo.addWidget(self.graf)
        baixo.setSizes([520, 620])
        split.addWidget(baixo)
        lay.addWidget(split, 1)
        self._mostrar_params()
        self.ler()

    def _escolher_pasta(self):
        p = W.QFileDialog.getExistingDirectory(self, "Pasta das jogadas", self.pasta.text())
        if p:
            self.pasta.setText(p)
            self.ler()

    def _mostrar_params(self):
        cal = self.bal.ler_calibracao()
        perf = {"cliques_s": "∞", "reacao": 0, "ruido": 0, "folga": "-", "sigma_seg": 0, "vies_seg": 0}
        for r, k in enumerate(CHAVES):
            for c, v in enumerate([perf[k], cal.get(k), _ruim().get(k)]):
                self.params.setItem(r, c, W.QTableWidgetItem(v if isinstance(v, str) else "%.3g" % float(v)))
        existe = os.path.exists(self.bal.ARQ_CALIBRACAO)
        self.params.setToolTip("calibrada: " + (self.bal.ARQ_CALIBRACAO if existe else "sem calibracao.json, usando o padrão"))

    def ler(self, *_):
        pasta = self.pasta.text()
        self.jogadas = self.bal.ler_jogadas(pasta) if os.path.isdir(pasta) else []
        self.tab.setRowCount(len(self.jogadas))
        for r, j in enumerate(self.jogadas):
            rec = (j.get("receita") or {}).get("nome", "") or "sem receita"
            a = media_a(j)
            try:
                hoje = self.bal.reavaliar(self.dados, j)["a"]
            except Exception:  # noqa: BLE001
                hoje = None
            for c, x in enumerate([j.get("quando", "?"), rec, "%.0f%%" % (100 * a) if a is not None else "-",
                                   "%.0f%%" % (100 * hoje) if hoje is not None else "-"]):
                self.tab.setItem(r, c, W.QTableWidgetItem(x))
        self.tab.resizeColumnsToContents()
        com = sum(1 for j in self.jogadas if self.bal.receita_da_jogada(j))
        self.info.setText(("%d jogadas (%d com receita memorizada) em %s" % (len(self.jogadas), com, pasta)) if self.jogadas else
                          "Nenhuma jogada em %s. O jogo grava os preparos ali quando roda em modo debug." % pasta)

    def calibrar(self):
        if not self.jogadas:
            self.info.setText("Leia as jogadas antes.")
            return
        W.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
        try:
            params, resumo = self.bal.calibrar(self.dados, self.jogadas)
        finally:
            W.QApplication.restoreOverrideCursor()
        self.info.setText(("Calibrado e gravado em calibracao.json: " + resumo) if params else resumo)
        self._mostrar_params()

    def comparar(self):
        W.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
        try:
            self._comparar()
        finally:
            W.QApplication.restoreOverrideCursor()

    def _comparar(self):
        n = self.n_mc.value()
        cal, ruim = self.bal.ler_calibracao(), _ruim()
        reais = {}
        for j in self.jogadas:
            rec = (j.get("receita") or {}).get("nome", "")
            a = media_a(j)
            if a is not None:
                reais.setdefault(rec or "sem receita", []).append(a)
        linhas = []
        dist = {"real": [a for v in reais.values() for a in v], "calibrada": [], "ruim": []}
        for chave, rc in sorted(self.dados.receitas.items()):
            perf = self.sim.simular(rc, self.dados.itens, self.sim.Jogadora(), self.dados.catalogo, guardar_hist=False)["a"]
            mc_c = [r["a"] for r in self.bal.monte_carlo(self.dados, rc, cal, n)]
            mc_r = [r["a"] for r in self.bal.monte_carlo(self.dados, rc, ruim, n)]
            dist["calibrada"] += mc_c
            dist["ruim"] += mc_r
            nome = rc.get("nome", chave)
            real = reais.get(nome) or reais.get(chave) or []
            linhas.append([chave, ("%.0f%% (%d)" % (100 * statistics.mean(real), len(real))) if real else "-",
                           "%.0f%%" % (100 * perf), "%.0f%%" % (100 * statistics.mean(mc_c)), "%.0f%%" % (100 * statistics.mean(mc_r))])
        self.comp.setRowCount(len(linhas))
        for r, l in enumerate(linhas):
            for c, x in enumerate(l):
                self.comp.setItem(r, c, W.QTableWidgetItem(x))
        self.comp.resizeColumnsToContents()
        cores = {"real": QtGui.QColor("#f2c14e"), "calibrada": QtGui.QColor("#5c8dd6"), "ruim": QtGui.QColor("#e53935")}
        series = []
        for nome, vals in dist.items():
            if not vals:
                continue
            nb = 20
            cont = [0] * nb
            for v in vals:
                cont[min(nb - 1, max(0, int(v * nb)))] += 1
            series.append(([(100 * (k + 0.5) / nb, 100.0 * c / len(vals)) for k, c in enumerate(cont)], cores[nome], "%s (%d)" % (nome, len(vals))))
        self.graf.definir(series, titulo_y="% das jogadas × aproveitamento (todas as receitas)", unidade_x="%")


def criar(raiz):
    return Aba(raiz)
