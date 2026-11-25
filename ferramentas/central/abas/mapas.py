# mapas.py - aba Mapas: os mapas (mapas/*.tscn), o que tem em cada um e como se ligam.
#   Esquerda: lista dos mapas e o desenho das ligações (seta = algum evento do mapa teleporta para o outro).
#   Direita:  os eventos colocados no mapa (nó, evento, posição), áreas de spawn (item, quantidade,
#             largura, cooldown) e, para cada passagem, para onde leva e a que distância a bruxa chega
#             da passagem mais perto no mapa de destino.
# Duplo clique numa linha abre o evento na aba Eventos. Só leitura.
import math
import os

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import indice as ind
from nucleo import navegar

TITULO = "Mapas"


def _n(x):
    try:
        return "%g" % round(float(x), 2)
    except ValueError:
        return str(x)


def nome_mapa(res):
    return ind.stem(res).replace("mapa_", "")


class Ligacoes(W.QWidget):
    """Mapas num círculo, setas para onde cada um teleporta. Clique escolhe o mapa."""
    escolhido = QtCore.Signal(str)

    def __init__(self):
        super().__init__()
        self.mapas, self.arestas, self.atual, self.pos = [], set(), "", {}
        self.setMinimumSize(320, 320)

    def definir(self, mapas, arestas, atual):
        self.mapas, self.arestas, self.atual = mapas, arestas, atual
        self.update()

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.Antialiasing)
        n = len(self.mapas)
        if not n:
            return
        cx, cy = self.width() / 2, self.height() / 2
        R = min(cx, cy) - 40
        self.pos = {m: (cx + R * math.cos(2 * math.pi * k / n - math.pi / 2), cy + R * math.sin(2 * math.pi * k / n - math.pi / 2))
                    for k, m in enumerate(self.mapas)}
        texto = self.palette().text().color()
        for a, b in self.arestas:
            if a not in self.pos or b not in self.pos:
                continue
            liga = self.atual in (a, b)
            cor = QtGui.QColor("#f2c14e") if liga else QtGui.QColor(128, 128, 128, 110)
            p.setPen(QtGui.QPen(cor, 2 if liga else 1))
            (x1, y1), (x2, y2) = self.pos[a], self.pos[b]
            dx, dy = x2 - x1, y2 - y1
            L = math.hypot(dx, dy) or 1
            x2b, y2b = x2 - dx / L * 14, y2 - dy / L * 14
            p.drawLine(QtCore.QPointF(x1, y1), QtCore.QPointF(x2b, y2b))
            ang = math.atan2(dy, dx)
            for s in (-0.4, 0.4):
                p.drawLine(QtCore.QPointF(x2b, y2b), QtCore.QPointF(x2b - 8 * math.cos(ang + s), y2b - 8 * math.sin(ang + s)))
        for m, (x, y) in self.pos.items():
            sel = m == self.atual
            p.setBrush(QtGui.QColor("#f2c14e") if sel else QtGui.QColor("#5c8dd6"))
            p.setPen(QtCore.Qt.NoPen)
            p.drawEllipse(QtCore.QPointF(x, y), 6, 6)
            p.setPen(texto)
            f = p.font()
            f.setBold(sel)
            p.setFont(f)
            p.drawText(QtCore.QRectF(x - 70, y + 6, 140, 16), QtCore.Qt.AlignCenter, nome_mapa(m))

    def mousePressEvent(self, e):
        for m, (x, y) in self.pos.items():
            if math.hypot(e.position().x() - x, e.position().y() - y) < 14:
                self.escolhido.emit(m)
                return


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        lay = W.QHBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        split = W.QSplitter()
        esq = W.QWidget()
        v = W.QVBoxLayout(esq)
        v.setContentsMargins(0, 0, 0, 0)
        self.lista = W.QListWidget()
        self.lista.currentRowChanged.connect(self._escolhido)
        v.addWidget(self.lista, 1)
        self.graf = Ligacoes()
        self.graf.escolhido.connect(self._por_nome)
        v.addWidget(self.graf, 2)
        b = W.QPushButton("Recarregar")
        b.clicked.connect(lambda: self.carregar(True))
        v.addWidget(b)
        split.addWidget(esq)
        dir_ = W.QWidget()
        v = W.QVBoxLayout(dir_)
        v.setContentsMargins(0, 0, 0, 0)
        self.titulo = W.QLabel()
        f = self.titulo.font()
        f.setBold(True)
        f.setPointSize(f.pointSize() + 2)
        self.titulo.setFont(f)
        v.addWidget(self.titulo)
        self.tab = W.QTableWidget(0, 6)
        self.tab.setHorizontalHeaderLabels(["nó", "evento", "posição", "tipo", "leva para / detalhes", "chega a"])
        self.tab.verticalHeader().setVisible(False)
        self.tab.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.tab.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.tab.horizontalHeader().setStretchLastSection(True)
        self.tab.cellDoubleClicked.connect(self._abrir)
        v.addWidget(self.tab, 1)
        self.chegam = W.QLabel(wordWrap=True)
        v.addWidget(self.chegam)
        split.addWidget(dir_)
        split.setSizes([380, 900])
        lay.addWidget(split)
        self.carregar(False)

    def carregar(self, novo=True):
        I = self.I = ind.indice(self.raiz, novo=novo)
        self.arestas = set()
        for m, d in I.mapas.items():
            for n in d["nos"]:
                for dest, _ in I.teleportes(n["evento"]):
                    if dest:
                        self.arestas.add((m, dest))
        atual = self.lista.currentItem().data(QtCore.Qt.UserRole) if self.lista.currentItem() else None
        self.lista.blockSignals(True)
        self.lista.clear()
        for m in sorted(I.mapas):
            it = W.QListWidgetItem("%s  (%d eventos)" % (nome_mapa(m), len(I.mapas[m]["nos"])))
            it.setData(QtCore.Qt.UserRole, m)
            self.lista.addItem(it)
        self.lista.blockSignals(False)
        self._por_nome(atual or (sorted(I.mapas)[0] if I.mapas else ""))

    def _por_nome(self, m):
        for k in range(self.lista.count()):
            if self.lista.item(k).data(QtCore.Qt.UserRole) == m:
                self.lista.setCurrentRow(k)
                self._escolhido(k)
                return

    def _escolhido(self, k):
        it = self.lista.item(k)
        if not it:
            return
        m = it.data(QtCore.Qt.UserRole)
        I = self.I
        self.graf.definir(sorted(I.mapas), self.arestas, m)
        self.titulo.setText(nome_mapa(m) + "   (" + os.path.relpath(I.mapas[m]["arq"], self.raiz).replace("\\", "/") + ")")
        nos = sorted(I.mapas[m]["nos"], key=lambda n: (n["pos"] or (0, 0))[0])
        self.linhas = []
        for n in nos:
            tele = I.teleportes(n["evento"])
            if n["script"] == "area_spawn":
                pr = n["props"]
                det = "spawn: quantidade %s · largura %s · cooldown %s s" % (_n(pr.get("quantidade", "?")), _n(pr.get("largura", "?")), _n(pr.get("cooldown", "?")))
                self.linhas.append((n, "área de spawn", det, ""))
            elif tele:
                for dest, xy in tele:
                    self.linhas.append((n, "passagem", "%s em %s" % (nome_mapa(dest), "%d, %d" % xy if xy else "?"), self._chegada(dest, xy)))
            else:
                self.linhas.append((n, "evento", "", ""))
        self.tab.setRowCount(len(self.linhas))
        for r, (n, tipo, det, cheg) in enumerate(self.linhas):
            pos = "%d, %d" % n["pos"] if n["pos"] else "-"
            for c, x in enumerate([n["nome"], n["evento"], pos, tipo, det, cheg]):
                it = W.QTableWidgetItem(x)
                if c == 3 and tipo == "passagem":
                    it.setForeground(QtGui.QColor("#f2c14e"))
                self.tab.setItem(r, c, it)
        self.tab.resizeColumnsToContents()
        de = sorted({nome_mapa(a) for a, b in self.arestas if b == m})
        self.chegam.setText("Chegam aqui de: " + (", ".join(de) if de else "(nenhum teleporte aponta para este mapa)"))

    def _chegada(self, dest, xy):
        """Distância do ponto de chegada até a passagem mais perto no mapa de destino."""
        d = self.I.mapas.get(dest)
        if not d or not xy:
            return "mapa não existe" if not d else ""
        melhor = None
        for n in d["nos"]:
            if n["pos"] and self.I.teleportes(n["evento"]):
                dist = math.hypot(n["pos"][0] - xy[0], n["pos"][1] - xy[1])
                if melhor is None or dist < melhor[0]:
                    melhor = (dist, n["nome"])
        return "%.0f px de %s" % melhor if melhor else "sem passagem lá"

    def _abrir(self, r, _c):
        if 0 <= r < len(self.linhas):
            navegar.abrir_evento(self.linhas[r][0]["evento"])


def criar(raiz):
    return Aba(raiz)
