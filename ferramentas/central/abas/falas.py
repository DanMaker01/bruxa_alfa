# falas.py - aba Falas: todas as falas de um personagem juntas, na ordem dos eventos, para
# revisar o jeito de falar e as manias. Mostra também perguntas/opções e legendas.
# Marca em vermelho o que tem travessão (—), texto vazio ou espaço duplo.
# Duplo clique abre o evento na aba Eventos (no comando da fala).
from PySide6 import QtGui, QtWidgets as W

from nucleo import indice as ind
from nucleo import navegar

TITULO = "Falas"
TODOS = "(todos)"


def problemas(txt):
    p = []
    if "—" in txt:
        p.append("travessão")
    if not txt.strip():
        p.append("vazio")
    if "  " in txt:
        p.append("espaço duplo")
    return p


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        h.addWidget(W.QLabel("Personagem:"))
        self.quem = W.QComboBox()
        self.quem.setMinimumWidth(200)
        self.quem.currentIndexChanged.connect(self.mostrar)
        h.addWidget(self.quem)
        self.filtro = W.QLineEdit(placeholderText="procurar no texto...")
        self.filtro.textChanged.connect(self.mostrar)
        h.addWidget(self.filtro, 1)
        self.so_prob = W.QCheckBox("só com problema")
        self.so_prob.toggled.connect(self.mostrar)
        h.addWidget(self.so_prob)
        b = W.QPushButton("Recarregar")
        b.clicked.connect(lambda: self.carregar(True))
        h.addWidget(b)
        lay.addLayout(h)
        self.tab = W.QTableWidget(0, 5)
        self.tab.setHorizontalHeaderLabels(["personagem", "evento", "onde", "tipo", "texto"])
        self.tab.verticalHeader().setVisible(False)
        self.tab.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.tab.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.tab.setWordWrap(True)
        self.tab.horizontalHeader().setStretchLastSection(True)
        self.tab.cellDoubleClicked.connect(self._abrir)
        lay.addWidget(self.tab, 1)
        self.status = W.QLabel()
        lay.addWidget(self.status)
        self.carregar(False)

    def carregar(self, novo=True):
        self.I = ind.indice(self.raiz, novo=novo)
        self.todas = self.I.falas()
        atual = self.quem.currentData()
        nomes = {}
        for f in self.todas:
            st = f["falante"]
            if st not in nomes:
                fal = self.I.proj.falantes.get(st)
                nomes[st] = (fal["nome"] if fal and fal["nome"] else st) or "(sem personagem)"
        self.quem.blockSignals(True)
        self.quem.clear()
        self.quem.addItem(TODOS, TODOS)
        for st, nome in sorted(nomes.items(), key=lambda x: x[1].lower()):
            n = sum(1 for f in self.todas if f["falante"] == st)
            self.quem.addItem("%s (%d)" % (nome if nome == st else "%s · %s" % (nome, st), n), st)
        i = self.quem.findData(atual)
        self.quem.setCurrentIndex(max(0, i))
        self.quem.blockSignals(False)
        self.mostrar()

    def mostrar(self, *_):
        quem = self.quem.currentData()
        txt = self.filtro.text().lower()
        self.vis = [f for f in self.todas if (quem in (None, TODOS) or f["falante"] == quem)
                    and (not txt or txt in f["texto"].lower())
                    and (not self.so_prob.isChecked() or problemas(f["texto"]))]
        self.tab.setRowCount(len(self.vis))
        for r, f in enumerate(self.vis):
            d = f["d"]
            prob = problemas(f["texto"])
            for c, x in enumerate([f["falante"] or "-", d["ev"], self.I.onde(d), f["tipo"], f["texto"]]):
                it = W.QTableWidgetItem(x)
                if prob and c == 4:
                    it.setForeground(QtGui.QColor("#e53935"))
                    it.setToolTip(", ".join(prob))
                self.tab.setItem(r, c, it)
        self.tab.resizeColumnsToContents()
        self.tab.setColumnWidth(4, max(400, self.tab.width() - sum(self.tab.columnWidth(c) for c in range(4)) - 30))
        self.tab.resizeRowsToContents()
        palavras = sum(len(f["texto"].split()) for f in self.vis)
        self.status.setText("%d fala(s) · %d palavras · %d com problema" % (len(self.vis), palavras, sum(1 for f in self.vis if problemas(f["texto"]))))

    def _abrir(self, r, _c):
        if 0 <= r < len(self.vis):
            d = self.vis[r]["d"]
            navegar.abrir_evento(d["ev"], d["pag"], d["i"])


def criar(raiz):
    return Aba(raiz)
