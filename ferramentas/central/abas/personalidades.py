# personalidades.py - aba Personalidades.
# Uma tabela só, colunas de largura fixa: os 5 traços ANTES (editáveis) juntos e depois os 5
# DEPOIS da poção. O "depois" mostra o valor novo, ▲/▼ quanto mudou e a cor (verde sobe, vermelho
# desce, mais forte = maior). Escolha a poção/item, as doses e a borda (iguais ao jogo).
# "no banco" avisa se o jogo carrega o personagem; "Nova personalidade" cria e registra.
# Embaixo, o pentagrama do personagem escolhido (tracejado = antes).
import os

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import tres_simples as ts
from nucleo.tabela import pedir_id
from nucleo.visual import Pentagrama, cor_delta

TITULO = "Personalidades"
CAMPOS = ["abertura", "consciencia", "extroversao", "amabilidade", "neuroticismo"]
LARG_NOME, LARG_ANTES, LARG_DEPOIS, LARG_BANCO = 130, 52, 96, 70
COR_DEPOIS = QtGui.QColor(92, 141, 214)      # azul: marca as colunas O' C' E' A' N' (depois da poção)


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        self.linhas = []
        self._carregando = False
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        # barra
        h = W.QHBoxLayout()
        self.filtro = W.QLineEdit(placeholderText="filtrar...")
        self.filtro.textChanged.connect(self._filtrar)
        h.addWidget(self.filtro, 1)
        for txt, fn in (("Nova personalidade", self.nova), ("Recarregar", self.carregar), ("Salvar", self.salvar)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        lay.addLayout(h)
        h = W.QHBoxLayout()
        h.addWidget(W.QLabel("Depois de:"))
        self.combo = W.QComboBox()
        self.combo.setMinimumWidth(260)
        self.combo.currentIndexChanged.connect(self.atualizar)
        h.addWidget(self.combo)
        self.doses = W.QSpinBox(minimum=1, maximum=20, value=1, suffix=" dose(s)")
        self.doses.valueChanged.connect(self.atualizar)
        h.addWidget(self.doses)
        self.borda = W.QComboBox()
        self.borda.addItems(["borda: " + b for b in ts.BORDAS])
        self.borda.setToolTip("como o traço trata o limite de ±10 (o jogo tem o mesmo botão no debug)")
        self.borda.currentIndexChanged.connect(self.atualizar)
        h.addWidget(self.borda)
        self.so_mudou = W.QCheckBox("só quem muda")
        self.so_mudou.toggled.connect(lambda *_: self._filtrar(self.filtro.text()))
        h.addWidget(self.so_mudou)
        h.addStretch(1)
        lay.addLayout(h)
        self.desc = W.QLabel()
        self.desc.setStyleSheet("color:#9a9a9a")
        lay.addWidget(self.desc)
        # tabela
        split = W.QSplitter(QtCore.Qt.Vertical)
        self.tab = W.QTableWidget(0, 12)
        cab = ["personagem"] + list(ts.TRACOS) + [t + "'" for t in ts.TRACOS] + ["no banco"]
        self.tab.setColumnCount(len(cab))
        self.tab.setHorizontalHeaderLabels(cab)
        self.tab.verticalHeader().setVisible(False)
        self.tab.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.tab.setSelectionMode(W.QAbstractItemView.SingleSelection)
        hh = self.tab.horizontalHeader()
        hh.setSectionResizeMode(W.QHeaderView.Fixed)
        larguras = [LARG_NOME] + [LARG_ANTES] * 5 + [LARG_DEPOIS] * 5 + [LARG_BANCO]
        for c, w in enumerate(larguras):
            self.tab.setColumnWidth(c, w)
        for k, t in enumerate(ts.TRACOS):
            self.tab.horizontalHeaderItem(1 + k).setToolTip(ts.NOMES_TRACOS[t] + " antes (editável)")
            cab = self.tab.horizontalHeaderItem(6 + k)
            cab.setToolTip(ts.NOMES_TRACOS[t] + " depois da poção")
            cab.setForeground(COR_DEPOIS)
            cab.setBackground(QtGui.QColor(92, 141, 214, 60))
            f = cab.font()
            f.setBold(True)
            cab.setFont(f)
        self.tab.itemChanged.connect(self._mudou)
        self.tab.currentCellChanged.connect(lambda *_: self.atualizar_penta())
        split.addWidget(self.tab)
        self.penta = Pentagrama(200)
        split.addWidget(self.penta)
        split.setSizes([520, 220])
        lay.addWidget(split, 1)
        self.status = W.QLabel()
        lay.addWidget(self.status)
        self._carregar_matrizes()
        self.carregar()

    # ---------------------------------------------------------- dados
    def _carregar_matrizes(self):
        self.matrizes = []
        for pasta, rot, cl in (("dados/pocoes/**/*.tres", "poção", "PocaoReferencia"), ("dados/itens/*.tres", "item", "ItemData")):
            arqs = ts.listar(self.raiz, pasta, cl)
            arqs.sort(key=lambda pt: ("proibidas" in pt[0].replace("\\", "/"), pt[0]))
            for p, t in arqs:
                self.matrizes.append(("%s: %s" % (rot, ts.ler_campo(t, "nome", os.path.basename(p))), ts.ler_matriz(t)))
        self.combo.blockSignals(True)
        self.combo.clear()
        self.combo.addItems([m[0] for m in self.matrizes])
        self.combo.blockSignals(False)

    def carregar(self):
        try:
            banco = ts.ids_no_banco(self.raiz, "personalidades")
        except Exception:  # noqa: BLE001
            banco = set()
        self.linhas = []
        for p, t in ts.listar(self.raiz, "dados/personalidades/*.tres", "PersonalidadeData"):
            nid = os.path.splitext(os.path.basename(p))[0]
            v = [float(ts.ler_campo(t, c, 0.0) or 0.0) for c in CAMPOS]
            self.linhas.append({"arq": p, "id": nid, "texto": t, "v": v, "orig": list(v), "banco": nid in banco})
        self._carregando = True
        self.tab.setRowCount(len(self.linhas))
        for r, l in enumerate(self.linhas):
            it = W.QTableWidgetItem(l["id"])
            it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
            self.tab.setItem(r, 0, it)
            for k in range(5):
                it = W.QTableWidgetItem("%g" % l["v"][k])
                it.setTextAlignment(QtCore.Qt.AlignCenter)
                self.tab.setItem(r, 1 + k, it)
            it = W.QTableWidgetItem("sim" if l["banco"] else "NÃO")
            it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
            it.setTextAlignment(QtCore.Qt.AlignCenter)
            if not l["banco"]:
                it.setForeground(QtGui.QColor("#e53935"))
                it.setToolTip("não está em dados/banco.tres: o jogo não carrega")
            self.tab.setItem(r, 11, it)
        self._carregando = False
        self.atualizar()
        if self.linhas:
            self.tab.setCurrentCell(0, 0)

    def _M(self):
        return self.matrizes[max(0, self.combo.currentIndex())][1] if self.matrizes else ts.identidade()

    def _depois(self, l):
        return ts.aplicar(self._M(), l["v"], ts.BORDAS[self.borda.currentIndex()], self.doses.value())

    def atualizar(self, *_):
        if not hasattr(self, "tab"):
            return
        self.desc.setText("O que faz: " + "; ".join(ts.descrever_matriz(self._M())))
        self._carregando = True
        negrito = QtGui.QFont()
        negrito.setBold(True)
        for r, l in enumerate(self.linhas):
            q = self._depois(l)
            alguma = False
            for k in range(5):
                d = q[k] - l["v"][k]
                mudou = abs(d) >= 0.005
                it = W.QTableWidgetItem(("%.2f %s%.2f" % (q[k], "▲" if d > 0 else "▼", abs(d))) if mudou else "%.2f" % q[k])
                it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
                it.setTextAlignment(QtCore.Qt.AlignCenter)
                it.setToolTip("%s: %.2f → %.2f (%+.2f)" % (ts.NOMES_TRACOS[ts.TRACOS[k]], l["v"][k], q[k], d))
                cor = cor_delta(d)
                if cor:
                    it.setBackground(cor)
                    it.setForeground(QtGui.QColor("white" if cor.alpha() > 140 else "black"))
                    it.setFont(negrito)
                else:
                    fundo = QtGui.QColor(COR_DEPOIS)
                    fundo.setAlpha(35)
                    it.setBackground(fundo)
                    it.setForeground(QtGui.QColor("#888"))
                self.tab.setItem(r, 6 + k, it)
                alguma = alguma or mudou
            l["mudou"] = alguma
        self._carregando = False
        self._filtrar(self.filtro.text())
        self.atualizar_penta()
        self._status()

    def atualizar_penta(self):
        r = self.tab.currentRow()
        if 0 <= r < len(self.linhas):
            l = self.linhas[r]
            self.penta.definir(l["v"], self._depois(l), "%s  (tracejado = antes)" % l["id"])

    def _filtrar(self, txt):
        txt = txt.lower()
        for r, l in enumerate(self.linhas):
            esconder = (txt and txt not in l["id"].lower()) or (self.so_mudou.isChecked() and not l.get("mudou"))
            self.tab.setRowHidden(r, bool(esconder))

    def _mudou(self, it):
        if self._carregando or not 1 <= it.column() <= 5:
            return
        l = self.linhas[it.row()]
        k = it.column() - 1
        try:
            v = max(-10.0, min(10.0, float(it.text().replace(",", "."))))
        except ValueError:
            v = l["v"][k]
        l["v"][k] = v
        self._carregando = True
        it.setText("%g" % v)
        sujo = l["v"] != l["orig"]
        nome = self.tab.item(it.row(), 0)
        nome.setText(l["id"] + (" *" if sujo else ""))
        self._carregando = False
        self.atualizar()

    def tem_mudancas(self):
        return any(l["v"] != l["orig"] for l in self.linhas)

    def _status(self):
        n = sum(1 for l in self.linhas if l["v"] != l["orig"])
        self.status.setText("%d personagens%s" % (len(self.linhas), (" · %d não salvo(s)" % n) if n else ""))

    def salvar(self):
        n = 0
        for l in self.linhas:
            if l["v"] == l["orig"]:
                continue
            t = ts.ler(l["arq"])
            if t != l["texto"] and W.QMessageBox.question(
                    self, "Arquivo mudou", "%s mudou fora daqui (Godot?). Gravar por cima?" % l["id"]) != W.QMessageBox.Yes:
                continue
            for k, c in enumerate(CAMPOS):
                if l["v"][k] != l["orig"][k]:
                    t = ts.gravar_campo(t, c, l["v"][k])
            ts.escrever(l["arq"], t)
            n += 1
        r = self.tab.currentRow()
        self.carregar()
        self.tab.setCurrentCell(max(0, r), 0)
        self.status.setText(self.status.text() + " · salvo(s): %d" % n)

    def nova(self):
        nid = pedir_id(self, "Nova personalidade", "ferreiro")
        if not nid:
            return
        arq = os.path.join(self.raiz, "dados", "personalidades", nid + ".tres")
        if os.path.exists(arq):
            W.QMessageBox.warning(self, "Já existe", "%s.tres já existe." % nid)
            return
        ts.escrever(arq, '[gd_resource type="Resource" script_class="PersonalidadeData" format=3]\n\n'
                         '[ext_resource type="Script" path="res://src/dados/personalidade_data.gd" id="1_pers"]\n\n'
                         '[resource]\nscript = ExtResource("1_pers")\nid = "%s"\n' % nid + "".join("%s = 0.0\n" % c for c in CAMPOS))
        ts.registrar_no_banco(self.raiz, "res://dados/personalidades/%s.tres" % nid, "personalidades")
        self.carregar()


def criar(raiz):
    return Aba(raiz)
