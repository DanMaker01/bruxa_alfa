# usos.py - tabela de "onde aparece" (lista de indice.Uso). Duplo clique abre o evento na aba Eventos.
import os

from PySide6 import QtGui, QtWidgets as W

from nucleo import navegar

CORES = {"muda": "#3a7d44", "testa": "#3567a8", "código": "#8a6d1f", "mapa": "#7a4a9a", "dados": "#666"}


class TabelaUsos(W.QTableWidget):
    def __init__(self, raiz):
        super().__init__(0, 4)
        self.raiz = raiz
        self.usos = []
        self.setHorizontalHeaderLabels(["tipo", "arquivo", "onde", "o quê"])
        self.verticalHeader().setVisible(False)
        self.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.horizontalHeader().setStretchLastSection(True)
        self.setToolTip("duplo clique: abre o evento na aba Eventos")
        self.cellDoubleClicked.connect(lambda r, _c: navegar.abrir_uso(self.usos[r]) if 0 <= r < len(self.usos) else None)

    def definir(self, usos):
        self.usos = list(usos)
        self.setRowCount(len(self.usos))
        for r, u in enumerate(self.usos):
            arq = u.evento or os.path.relpath(u.arquivo, self.raiz).replace("\\", "/")
            for c, txt in enumerate([u.tipo, arq, u.onde, u.texto]):
                it = W.QTableWidgetItem(txt)
                if c == 0 and u.tipo in CORES:
                    it.setForeground(QtGui.QColor(CORES[u.tipo]))
                if c == 1 and u.evento:
                    f = it.font()
                    f.setUnderline(True)
                    it.setFont(f)
                self.setItem(r, c, it)
        self.resizeColumnsToContents()
        self.setColumnWidth(3, max(self.columnWidth(3), 300))
