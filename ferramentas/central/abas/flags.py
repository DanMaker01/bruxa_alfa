# flags.py - aba Flags: todas as variáveis do jogo (dados/variaveis e as usadas nos eventos),
# valor inicial, descrição, quantos lugares MUDAM e quantos TESTAM cada uma, e avisos:
# ninguém muda, ninguém testa, não declarada em dados/variaveis. "código" = algum script do jogo
# cita o nome (ex.: ouro, missao01_pocao_feita), o que pode explicar quem muda ou testa.
# Escolha uma variável para ver os lugares embaixo (duplo clique abre o evento).
from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import indice as ind
from nucleo.usos import TabelaUsos

TITULO = "Flags"


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        self.filtro = W.QLineEdit(placeholderText="filtrar...")
        self.filtro.textChanged.connect(self._filtrar)
        h.addWidget(self.filtro, 1)
        self.so_aviso = W.QCheckBox("só com aviso")
        self.so_aviso.toggled.connect(lambda *_: self._filtrar())
        h.addWidget(self.so_aviso)
        b = W.QPushButton("Recarregar")
        b.clicked.connect(lambda: self.carregar(True))
        h.addWidget(b)
        lay.addLayout(h)
        split = W.QSplitter(QtCore.Qt.Vertical)
        self.tab = W.QTableWidget(0, 7)
        self.tab.setHorizontalHeaderLabels(["variável", "inicial", "muda", "testa", "código", "aviso", "descrição"])
        self.tab.verticalHeader().setVisible(False)
        self.tab.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.tab.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.tab.setSelectionMode(W.QAbstractItemView.SingleSelection)
        self.tab.horizontalHeader().setStretchLastSection(True)
        self.tab.setSortingEnabled(True)
        self.tab.currentCellChanged.connect(lambda *_: self._mostrar())
        split.addWidget(self.tab)
        self.usos = TabelaUsos(raiz)
        split.addWidget(self.usos)
        split.setSizes([450, 300])
        lay.addWidget(split, 1)
        self.status = W.QLabel()
        lay.addWidget(self.status)
        self.carregar(False)

    def carregar(self, novo=True):
        I = self.I = ind.indice(self.raiz, novo=novo)
        nomes = sorted(set(I.vars) | set(I.muda) | set(I.testa))
        self.tab.setSortingEnabled(False)
        self.tab.setRowCount(len(nomes))
        avisos = 0
        for r, n in enumerate(nomes):
            v = I.vars.get(n)
            m, t, c = len(I.muda.get(n, [])), len(I.testa.get(n, [])), len(I.codigo.get(n, []))
            av = []
            if v is None:
                av.append("não declarada")
            if not m and not c:
                av.append("ninguém muda")
            if not t and not c:
                av.append("ninguém testa")
            avisos += bool(av)
            vals = [n, "%g" % v["inicial"] if v else "", m, t, c, ", ".join(av), (v["descricao"] if v else "").replace("\n", " ")]
            for col, x in enumerate(vals):
                it = W.QTableWidgetItem()
                it.setData(QtCore.Qt.DisplayRole, x)
                if col == 5 and av:
                    it.setForeground(QtGui.QColor("#e53935"))
                if col == 6:
                    it.setToolTip(v["descricao"] if v else "")
                self.tab.setItem(r, col, it)
        self.tab.setSortingEnabled(True)
        self.tab.resizeColumnsToContents()
        self.tab.setColumnWidth(6, 400)
        self.status.setText("%d variáveis · %d com aviso" % (len(nomes), avisos))
        self._filtrar()

    def _filtrar(self, *_):
        txt = self.filtro.text().lower()
        for r in range(self.tab.rowCount()):
            n = self.tab.item(r, 0).text()
            esc = (txt and txt not in n.lower()) or (self.so_aviso.isChecked() and not self.tab.item(r, 5).text())
            self.tab.setRowHidden(r, bool(esc))

    def _mostrar(self):
        r = self.tab.currentRow()
        if r < 0 or not self.tab.item(r, 0):
            return
        n = self.tab.item(r, 0).text()
        self.usos.definir(self.I.muda.get(n, []) + self.I.testa.get(n, []) + self.I.codigo.get(n, []))


def criar(raiz):
    return Aba(raiz)
