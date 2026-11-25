# onde_usado.py - aba Onde é usado: escolha (ou digite) um item, evento, personagem, poção,
# receita, falante, variável ou mapa e veja todos os eventos, mapas, dados e scripts que o citam.
# Bom antes de renomear ou apagar. Duplo clique abre o evento na aba Eventos.
from PySide6 import QtWidgets as W

from nucleo import indice as ind
from nucleo.usos import TabelaUsos

TITULO = "Onde é usado"


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        h.addWidget(W.QLabel("Procurar:"))
        self.alvo = W.QComboBox(editable=True)
        self.alvo.setMinimumWidth(320)
        self.alvo.setInsertPolicy(W.QComboBox.NoInsert)
        self.alvo.activated.connect(lambda *_: self.procurar())
        self.alvo.lineEdit().returnPressed.connect(self.procurar)
        h.addWidget(self.alvo)
        self.textos = W.QCheckBox("também dentro de falas e textos")
        h.addWidget(self.textos)
        for txt, fn in (("Procurar", self.procurar), ("Recarregar", self.recarregar)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        h.addStretch(1)
        lay.addLayout(h)
        self.info = W.QLabel()
        lay.addWidget(self.info)
        self.tab = TabelaUsos(raiz)
        lay.addWidget(self.tab, 1)
        self.recarregar(novo=False)

    def recarregar(self, *_, novo=True):
        self.I = ind.indice(self.raiz, novo=novo)
        atual = self.alvo.currentText()
        self.alvo.clear()
        for rot, ident in self.I.alvos_conhecidos():
            self.alvo.addItem("%s  (%s)" % (ident, rot), ident)
        self.alvo.setEditText(atual)

    def procurar(self):
        txt = self.alvo.currentText().strip()
        i = self.alvo.findText(txt)
        alvo = self.alvo.itemData(i) if i >= 0 else txt.split("  (")[0].strip()
        us = self.I.usos(alvo, self.textos.isChecked())
        self.tab.definir(us)
        self.info.setText("%d lugar(es) citam \"%s\"" % (len(us), alvo) if us else "ninguém cita \"%s\"" % alvo)


def criar(raiz):
    return Aba(raiz)
