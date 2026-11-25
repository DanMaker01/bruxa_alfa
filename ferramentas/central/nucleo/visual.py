# visual.py - peças de interface usadas por várias abas (sem matplotlib: tudo com QPainter,
# para a ferramenta abrir rápido):
#   cor_delta(d)          cor de fundo para uma mudança (verde sobe, vermelho desce, mais forte = maior)
#   MatrizGrade           grade 5x5 da matriz A (compacta), editável ou só leitura, com cores
#   Pentagrama            O C E A N de −10 a 10: contorno cinza = antes, cor = depois
#   GraficoLinhas         linhas (ex.: temperatura no tempo) com faixas coloridas
#   Histograma            barras (ex.: aproveitamento de muitas jogadas)
import math

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo.tres_simples import TRACOS, identidade

VERDE = QtGui.QColor("#43a047")
VERMELHO = QtGui.QColor("#e53935")
DOURADO = QtGui.QColor("#f2c14e")
CINZA = QtGui.QColor("#8a8a8a")


def cor_delta(d, escala=5.0):
    """Fundo para uma diferença d: alfa cresce com |d| (|d| >= escala = cor cheia)."""
    if abs(d) < 0.005:
        return None
    c = QtGui.QColor(VERDE if d > 0 else VERMELHO)
    c.setAlpha(int(50 + 170 * min(1.0, abs(d) / escala)))
    return c


def cor_matriz(v, ref):
    if abs(v - ref) < 1e-9:
        return None
    return VERDE if v > ref else VERMELHO


class MatrizGrade(W.QWidget):
    """Matriz A 5x5. Linha = traço que muda (O'...), coluna = traço de origem."""
    mudou = QtCore.Signal()

    def __init__(self, editavel=True, largura=86):
        super().__init__()
        g = W.QGridLayout(self)
        g.setContentsMargins(4, 4, 4, 4)
        g.setHorizontalSpacing(4)
        g.setVerticalSpacing(3)
        self.caixas = []
        self._carregando = False
        for j, tr in enumerate(TRACOS):
            l = W.QLabel(tr, alignment=QtCore.Qt.AlignCenter)
            l.setStyleSheet("font-weight:bold")
            g.addWidget(l, 0, j + 1)
        for i, tr in enumerate(TRACOS):
            l = W.QLabel(tr + "'")
            l.setStyleSheet("font-weight:bold")
            g.addWidget(l, i + 1, 0)
            linha = []
            for j in range(5):
                c = W.QDoubleSpinBox()
                c.setRange(-10, 10)
                c.setDecimals(4)
                c.setSingleStep(0.01)
                c.setFixedWidth(largura)
                c.setButtonSymbols(W.QAbstractSpinBox.NoButtons)
                c.setAlignment(QtCore.Qt.AlignRight)
                c.setReadOnly(not editavel)
                c.valueChanged.connect(self._mudou)
                g.addWidget(c, i + 1, j + 1)
                linha.append(c)
            self.caixas.append(linha)
        g.setColumnStretch(6, 1)
        g.setRowStretch(6, 1)
        self.setSizePolicy(W.QSizePolicy.Maximum, W.QSizePolicy.Maximum)

    def _mudou(self):
        if not self._carregando:
            self._colorir()
            self.mudou.emit()

    def _colorir(self):
        for i in range(5):
            for j in range(5):
                cor = cor_matriz(self.caixas[i][j].value(), 1.0 if i == j else 0.0)
                self.caixas[i][j].setStyleSheet("color: %s; font-weight: bold;" % cor.name() if cor else "")

    def definir(self, M):
        self._carregando = True
        for i in range(5):
            for j in range(5):
                self.caixas[i][j].setValue(M[i][j])
        self._carregando = False
        self._colorir()

    def valor(self):
        return [[self.caixas[i][j].value() for j in range(5)] for i in range(5)]


class Pentagrama(W.QWidget):
    """antes (cinza) e depois (colorido), valores −10..10, raio linear (como no jogo)."""

    def __init__(self, tamanho=180):
        super().__init__()
        self.antes = None
        self.depois = None
        self.titulo = ""
        self.setMinimumSize(tamanho, tamanho)

    def definir(self, antes, depois=None, titulo=""):
        self.antes, self.depois, self.titulo = antes, depois, titulo
        self.update()

    def _pontos(self, v, c, r):
        out = []
        for i in range(5):
            f = 0.12 + 0.88 * max(0.0, min(1.0, (v[i] + 10) / 20))
            a = -math.pi / 2 + 2 * math.pi * i / 5
            out.append(QtCore.QPointF(c.x() + math.cos(a) * r * f, c.y() + math.sin(a) * r * f))
        return out

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.Antialiasing)
        w, h = self.width(), self.height()
        topo = 18 if self.titulo else 0
        r = min(w, h - topo) / 2 - 18
        c = QtCore.QPointF(w / 2, topo + (h - topo) / 2)
        if self.titulo:
            p.setPen(self.palette().text().color())
            p.drawText(QtCore.QRectF(0, 0, w, 16), QtCore.Qt.AlignCenter, self.titulo)
        p.setPen(QtGui.QPen(QtGui.QColor(128, 128, 128, 90), 1))
        for k in (0.25, 0.5, 0.75, 1.0):
            p.drawPolygon(QtGui.QPolygonF(self._pontos([-10 + 20 * k] * 5, c, r)))
        for i, tr in enumerate(TRACOS):
            a = -math.pi / 2 + 2 * math.pi * i / 5
            q = QtCore.QPointF(c.x() + math.cos(a) * (r + 10), c.y() + math.sin(a) * (r + 10))
            p.setPen(self.palette().text().color())
            p.drawText(QtCore.QRectF(q.x() - 8, q.y() - 8, 16, 16), QtCore.Qt.AlignCenter, tr)
        if self.antes:
            p.setPen(QtGui.QPen(CINZA, 2, QtCore.Qt.DashLine if self.depois else QtCore.Qt.SolidLine))
            p.setBrush(QtCore.Qt.NoBrush)
            p.drawPolygon(QtGui.QPolygonF(self._pontos(self.antes, c, r)))
        if self.depois:
            cor = QtGui.QColor(DOURADO)
            p.setPen(QtGui.QPen(cor, 2.5))
            cor.setAlpha(60)
            p.setBrush(cor)
            pts = self._pontos(self.depois, c, r)
            p.drawPolygon(QtGui.QPolygonF(pts))
            if self.antes:
                for i in range(5):
                    d = self.depois[i] - self.antes[i]
                    if abs(d) > 0.005:
                        p.setPen(QtCore.Qt.NoPen)
                        p.setBrush(VERDE if d > 0 else VERMELHO)
                        p.drawEllipse(pts[i], 4, 4)


class GraficoLinhas(W.QWidget):
    """series = [(pontos [(x, y)], QColor, rótulo)]; faixas = [(y0, y1, QColor)] no fundo;
    marcas = [(x, texto)] linhas verticais."""

    def __init__(self):
        super().__init__()
        self.series, self.faixas, self.marcas, self.faixas_x = [], [], [], []
        self.titulo_y = ""
        self.unidade_x = "s"
        self.faixa_y = None
        self.setMinimumHeight(180)

    def definir(self, series, faixas=None, marcas=None, titulo_y="", unidade_x="s", faixa_y=None, faixas_x=None):
        """faixa_y=(min, max) fixa o eixo y (ex.: (0, 1) para aproveitamento).
        faixas = bandas horizontais (em y); faixas_x = bandas verticais (em x), ex.: as chamas."""
        self.series, self.faixas, self.marcas, self.titulo_y = series, faixas or [], marcas or [], titulo_y
        self.faixas_x = faixas_x or []
        self.unidade_x, self.faixa_y = unidade_x, faixa_y
        self.update()

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.Antialiasing)
        texto = self.palette().text().color()
        m_esq, m_dir, m_cima, m_baixo = 44, 10, 10, 22
        w, h = self.width() - m_esq - m_dir, self.height() - m_cima - m_baixo
        pts_todos = [pt for s in self.series for pt in s[0]]
        if not pts_todos or w < 20 or h < 20:
            p.setPen(texto)
            p.drawText(self.rect(), QtCore.Qt.AlignCenter, "(rode uma simulação)")
            return
        x0, x1 = min(x for x, _ in pts_todos), max(x for x, _ in pts_todos)
        y0, y1 = min(y for _, y in pts_todos), max(y for _, y in pts_todos)
        if self.faixa_y:
            y0, y1 = self.faixa_y
        else:
            y0, y1 = min(y0, 0), y1 * 1.05 + 1
        x1 = x1 if x1 > x0 else x0 + 1
        X = lambda x: m_esq + (x - x0) / (x1 - x0) * w
        Y = lambda y: m_cima + h - (y - y0) / (y1 - y0) * h
        for a, b, cor in self.faixas_x:
            a, b = max(a, x0), min(b, x1)
            if b > a:
                p.fillRect(QtCore.QRectF(X(a), m_cima, X(b) - X(a), h), cor)
        for a, b, cor in self.faixas:
            a, b = max(a, y0), min(b, y1)
            if b > a:
                p.fillRect(QtCore.QRectF(m_esq, Y(b), w, Y(a) - Y(b)), cor)
        p.setPen(QtGui.QPen(QtGui.QColor(128, 128, 128, 120), 1))
        for k in range(5):
            yv = y0 + (y1 - y0) * k / 4
            p.drawLine(QtCore.QPointF(m_esq, Y(yv)), QtCore.QPointF(m_esq + w, Y(yv)))
            p.setPen(texto)
            p.drawText(QtCore.QRectF(0, Y(yv) - 8, m_esq - 4, 16), QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter,
                       ("%.0f%%" % (yv * 100)) if self.faixa_y == (0, 1) else "%.0f" % yv)
            p.setPen(QtGui.QPen(QtGui.QColor(128, 128, 128, 120), 1))
        for k in range(6):
            xv = x0 + (x1 - x0) * k / 5
            p.setPen(texto)
            p.drawText(QtCore.QRectF(X(xv) - 30, m_cima + h + 4, 60, 16), QtCore.Qt.AlignCenter, "%.0f%s" % (xv, self.unidade_x))
        for x, txt in self.marcas:
            p.setPen(QtGui.QPen(DOURADO, 1, QtCore.Qt.DashLine))
            p.drawLine(QtCore.QPointF(X(x), m_cima), QtCore.QPointF(X(x), m_cima + h))
            p.drawText(QtCore.QPointF(X(x) + 3, m_cima + 12), txt)
        for pts, cor, _ in self.series:
            if len(pts) < 2:
                continue
            p.setPen(QtGui.QPen(cor, 2))
            p.drawPolyline(QtGui.QPolygonF([QtCore.QPointF(X(x), Y(y)) for x, y in pts]))
        p.setPen(texto)
        p.drawText(QtCore.QPointF(4, m_cima + 10), self.titulo_y)
        # legenda (séries com nome), no canto direito
        nomes = [(cor, nome) for _, cor, nome in self.series if nome]
        if len(nomes) > 1:
            fm = p.fontMetrics()
            lw = max(fm.horizontalAdvance(n) for _, n in nomes) + 22
            y = m_cima + 2
            p.fillRect(QtCore.QRectF(m_esq + w - lw - 2, y - 1, lw + 2, 14 * len(nomes) + 2), QtGui.QColor(30, 30, 30, 170))
            for cor, nome in nomes:
                p.fillRect(QtCore.QRectF(m_esq + w - lw + 2, y + 3, 12, 8), cor)
                p.setPen(QtGui.QColor("white"))
                p.drawText(QtCore.QPointF(m_esq + w - lw + 18, y + 11), nome)
                y += 14


class Histograma(W.QWidget):
    """valores entre 0 e 1 em n faixas; linha dourada no limite."""

    def __init__(self, n=20, limite=0.95):
        super().__init__()
        self.valores, self.n, self.limite = [], n, limite
        self.setMinimumHeight(140)

    def definir(self, valores):
        self.valores = valores
        self.update()

    def paintEvent(self, _):
        p = QtGui.QPainter(self)
        texto = self.palette().text().color()
        if not self.valores:
            p.setPen(texto)
            p.drawText(self.rect(), QtCore.Qt.AlignCenter, "(rode o Monte Carlo)")
            return
        cont = [0] * self.n
        for v in self.valores:
            cont[min(self.n - 1, max(0, int(v * self.n)))] += 1
        m = max(cont) or 1
        w, h = self.width() - 20, self.height() - 24
        bw = w / self.n
        for k, c in enumerate(cont):
            bh = h * c / m
            cor = VERDE if (k + 1) / self.n > self.limite else QtGui.QColor("#5c8dd6")
            p.fillRect(QtCore.QRectF(10 + k * bw + 1, 4 + h - bh, bw - 2, bh), cor)
        p.setPen(QtGui.QPen(DOURADO, 1, QtCore.Qt.DashLine))
        xl = 10 + self.limite * w
        p.drawLine(QtCore.QPointF(xl, 4), QtCore.QPointF(xl, 4 + h))
        p.setPen(texto)
        for k in range(0, 101, 25):
            p.drawText(QtCore.QRectF(10 + k / 100 * w - 20, 4 + h + 2, 40, 16), QtCore.Qt.AlignCenter, "%d%%" % k)
