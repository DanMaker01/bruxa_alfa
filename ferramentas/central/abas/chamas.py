# chamas.py - aba Chamas: os estados da chama (src/livro/estados_chama.gd): nome no livro,
# faixa de temperatura do caldo (T mín, T máx) e cor. Mudou um valor, os gráficos mudam na hora:
#   faixas:       a régua de temperatura com as cores;
#   temperatura:  como o caldo esquenta até firmar em cada chama (simulador, jogadora perfeita);
#   item:         aproveitamento × segundos no caldo do item escolhido, uma linha por chama.
# As outras abas (Itens, Balanceamento) usam os mesmos valores enquanto a central estiver aberta.
# "Salvar" grava no estados_chama.gd (só a linha de cada estado que mudou).
import glob
import os
import re

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import chamas as chm
from nucleo import motor
from nucleo import tres_simples as ts
from nucleo.visual import GraficoLinhas

TITULO = "Chamas"
ARQ = os.path.join("src", "livro", "estados_chama.gd")
RE_LINHA = r'\{"id":\s*"%s",\s*"nome":\s*"[^"]*",\s*"T_min":\s*[-\d.]+,\s*"T_max":\s*[-\d.]+,\s*"cor":\s*Color\([^)]*\)\}'


class Faixas(W.QWidget):
    def __init__(self):
        super().__init__()
        self.estados = []
        self.setMinimumHeight(54)

    def definir(self, estados):
        self.estados = estados
        self.update()

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        w, h = self.width() - 20, 30
        X = lambda T: 10 + max(0.0, min(1.0, T / 250.0)) * w
        texto = self.palette().text().color()
        for e in self.estados:
            a, b = X(e["T_min"]), X(e["T_max"])
            p.fillRect(QtCore.QRectF(a, 4, b - a, h), QtGui.QColor.fromRgbF(*e["cor"]))
            if b - a > 26:
                q = QtGui.QColor.fromRgbF(*e["cor"])
                p.setPen(QtGui.QColor("black" if q.lightness() > 140 else "white"))
                p.drawText(QtCore.QRectF(a, 4, b - a, h), QtCore.Qt.AlignCenter, e["nome"][:8])
        p.setPen(texto)
        for T in range(0, 251, 25):
            p.drawText(QtCore.QRectF(X(T) - 20, h + 6, 40, 14), QtCore.Qt.AlignCenter, "%d°" % T)


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        self.sim, _ = motor.balanceamento()
        self._carregando = False
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        for txt, fn in (("Recarregar", self.carregar), ("Salvar", self.salvar)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        h.addWidget(W.QLabel("   Item para a curva:"))
        self.item = W.QComboBox()
        self.item.currentIndexChanged.connect(self.graficos)
        h.addWidget(self.item)
        h.addStretch(1)
        self.status = W.QLabel()
        h.addWidget(self.status)
        lay.addLayout(h)
        split = W.QSplitter()
        self.tab = W.QTableWidget(0, 5)
        self.tab.setHorizontalHeaderLabels(["id", "nome no livro", "T mín", "T máx", "cor"])
        self.tab.verticalHeader().setVisible(False)
        self.tab.itemChanged.connect(self._mudou)
        self.tab.cellDoubleClicked.connect(self._cor)
        split.addWidget(self.tab)
        d = W.QWidget()
        v = W.QVBoxLayout(d)
        v.setContentsMargins(0, 0, 0, 0)
        self.faixas = Faixas()
        v.addWidget(self.faixas)
        self.g_T, self.g_item = GraficoLinhas(), GraficoLinhas()
        v.addWidget(self.g_T, 1)
        v.addWidget(self.g_item, 1)
        split.addWidget(d)
        split.setSizes([430, 850])
        lay.addWidget(split, 1)
        lay.addWidget(W.QLabel("Duplo clique na cor para trocar. A ordem das faixas tem que ser crescente e sem buracos (T máx de uma = T mín da próxima)."))
        self.carregar()

    # ---------------------------------------------------------- dados
    def carregar(self, *_):
        txt = ts.ler(os.path.join(self.raiz, ARQ))
        self.orig = []
        for m in re.finditer(r'\{"id":\s*"(\w+)",\s*"nome":\s*"([^"]*)",\s*"T_min":\s*([-\d.]+),\s*"T_max":\s*([-\d.]+),\s*"cor":\s*Color\(([^)]*)\)\}', txt):
            self.orig.append({"id": m.group(1), "nome": m.group(2), "T_min": float(m.group(3)), "T_max": float(m.group(4)),
                              "cor": tuple(float(x) for x in m.group(5).split(",")[:3])})
        self.est = [dict(e) for e in self.orig]
        self._aplicar_no_simulador()
        self._carregando = True
        self.tab.setRowCount(len(self.est))
        for r, e in enumerate(self.est):
            vals = [e["id"], e["nome"], "%g" % e["T_min"], "%g" % e["T_max"], ""]
            for c, x in enumerate(vals):
                it = W.QTableWidgetItem(x)
                if c in (0, 4):
                    it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
                self.tab.setItem(r, c, it)
            self._pintar(r)
        self._carregando = False
        self.tab.resizeColumnsToContents()
        self.item.blockSignals(True)
        atual = self.item.currentData()
        self.item.clear()
        for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "itens", "*.tres"))):
            self.item.addItem(ts.ler_campo(ts.ler(p), "nome", os.path.basename(p)), p)
        self.item.setCurrentIndex(max(0, self.item.findData(atual)))
        self.item.blockSignals(False)
        self.graficos()

    def _pintar(self, r):
        q = QtGui.QColor.fromRgbF(*self.est[r]["cor"])
        it = self.tab.item(r, 4)
        it.setBackground(q)
        it.setText("%.2f, %.2f, %.2f" % self.est[r]["cor"])
        it.setForeground(QtGui.QColor("black" if q.lightness() > 140 else "white"))
        for c in (0, 1):
            self.tab.item(r, c).setBackground(QtGui.QColor(q.red(), q.green(), q.blue(), 70))

    def _aplicar_no_simulador(self):
        """Troca os estados do simulador em memória (as outras abas também veem)."""
        novos = {e["id"]: e for e in self.est}
        for e in self.sim.ESTADOS:
            if e["id"] in novos:
                e.update({k: novos[e["id"]][k] for k in ("nome", "T_min", "T_max", "cor")})
        chm._hist.clear()

    def _mudou(self, it):
        if self._carregando:
            return
        r, c = it.row(), it.column()
        e = self.est[r]
        try:
            if c == 1:
                e["nome"] = it.text().strip()
            elif c in (2, 3):
                e["T_min" if c == 2 else "T_max"] = float(it.text().replace(",", "."))
        except ValueError:
            pass
        self._carregando = True
        it.setText(e["nome"] if c == 1 else "%g" % e["T_min" if c == 2 else "T_max"])
        self._carregando = False
        self._aplicar_no_simulador()
        self.graficos()

    def _cor(self, r, c):
        if c != 4:
            return
        q = W.QColorDialog.getColor(QtGui.QColor.fromRgbF(*self.est[r]["cor"]), self, "Cor de " + self.est[r]["nome"])
        if q.isValid():
            self.est[r]["cor"] = (round(q.redF(), 2), round(q.greenF(), 2), round(q.blueF(), 2))
            self._pintar(r)
            self._aplicar_no_simulador()
            self.graficos()

    def tem_mudancas(self):
        return self.est != self.orig

    def salvar(self):
        arq = os.path.join(self.raiz, ARQ)
        txt = ts.ler(arq)
        n = 0
        for e, o in zip(self.est, self.orig):
            if e == o:
                continue
            nova = '{"id": "%s", "nome": "%s", "T_min": %s, "T_max": %s, "cor": Color(%s)}' % (
                e["id"], e["nome"], _f(e["T_min"]), _f(e["T_max"]), ", ".join("%g" % x for x in e["cor"]))
            txt, k = re.subn(RE_LINHA % re.escape(e["id"]), nova, txt, count=1)
            n += k
        ts.escrever(arq, txt)
        self.carregar()
        self.status.setText("salvo: %d estado(s)" % n)

    # ---------------------------------------------------------- gráficos
    def graficos(self, *_):
        self.faixas.definir([e for e in self.est if e["id"] != "apagado"])
        ordem = [e for e in self.est]
        buracos = [a["nome"] for a, b in zip(ordem, ordem[1:]) if abs(a["T_max"] - b["T_min"]) > 1e-6 or a["T_min"] >= a["T_max"]]
        self.status.setText(("faixas com buraco/sobreposição em: " + ", ".join(buracos)) if buracos else
                            ("não salvo" if self.tem_mudancas() else ""))
        series_T, series_a = [], []
        it = self._item()
        for e in chm.estados(self.sim):
            t0, h = chm.historico(self.sim, e["id"])
            c = chm.cor(self.sim, e["id"])
            series_T.append(([(t, T) for t, T in h if t <= t0 + 60], c, e["nome"]))
            if it:
                pts = chm.curva_item(self.sim, it, e["id"], 60)
                if max(a for _, a in pts) > 0.001:
                    series_a.append(([(t0 + s, a) for s, a in pts], c, e["nome"]))
        self.g_T.definir(series_T, titulo_y="temperatura do caldo (°C) até firmar em cada chama", unidade_x="s")
        self.g_item.definir(series_a, faixa_y=(0, 1), unidade_x="s",
                            titulo_y="aproveitamento de 1 %s jogado quando a chama firma" % (self.item.currentText() or "item"))

    def _item(self):
        p = self.item.currentData()
        if not p:
            return None
        t = ts.ler(p)
        f = lambda k, d: float(ts.ler_campo(t, k, d) or d)
        it = {k: f(k, d) for k, d in (("m", 0), ("s_menos", 1000), ("s_mais", 1000), ("T_min", 0), ("k_min", 0.25),
                                       ("T_max", 0), ("k_max", 0.25), ("t_min", 0), ("h_min", 0.25), ("t_max", 0), ("h_max", 0.25))}
        it["id"] = "_chamas"
        return it


def _f(x):
    s = "%g" % x
    return s if "." in s or "e" in s else s + ".0"


def criar(raiz):
    return Aba(raiz)
