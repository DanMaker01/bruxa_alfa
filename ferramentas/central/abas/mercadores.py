# mercadores.py - aba Mercadores: todas as lojas do jogo (comandos "loja" nos eventos).
#   Em cima: as lojas (evento, id da loja, personagem, ouro, margem).
#   Meio:    o estoque inicial da loja escolhida (item, quantidade) com o valor de cada item para
#            ele (valor_base · qtd_base / (qtd_base + estoque)); editável, "Salvar" grava no evento.
#   Embaixo: simulação da Balança / Pechincha com os valores de agora: o que a bruxa põe na mesa,
#            o que o mercador põe, ouro; mostra quanto cada lado vale, se ele aceita e quanto ouro falta.
#            Igual ao menu_loja.gd: o mesmo item dos dois lados se cancela.
import glob
import os

from PySide6 import QtCore, QtWidgets as W

from nucleo import indice as ind
from nucleo import motor, navegar
from nucleo import tres_simples as ts

TITULO = "Mercadores"


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        _, self.T, _ = motor.eventos()
        self.sujo = False
        self._carregando = False
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        for txt, fn in (("Recarregar", self.carregar), ("Salvar estoque", self.salvar), ("Abrir o evento", self.abrir_evento)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        h.addStretch(1)
        self.status = W.QLabel()
        h.addWidget(self.status)
        lay.addLayout(h)
        self.lojas_t = W.QTableWidget(0, 6)
        self.lojas_t.setHorizontalHeaderLabels(["evento", "onde", "id da loja", "personagem", "ouro dele", "margem"])
        self.lojas_t.verticalHeader().setVisible(False)
        self.lojas_t.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.lojas_t.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.lojas_t.setSelectionMode(W.QAbstractItemView.SingleSelection)
        self.lojas_t.setMaximumHeight(130)
        self.lojas_t.horizontalHeader().setStretchLastSection(True)
        self.lojas_t.currentCellChanged.connect(lambda r, *_: self._escolhida(r))
        lay.addWidget(self.lojas_t)
        split = W.QSplitter()
        # estoque
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        v.setContentsMargins(0, 0, 0, 0)
        f = W.QHBoxLayout()
        f.addWidget(W.QLabel("ouro dele:"))
        self.ouro = W.QSpinBox(maximum=100000)
        self.ouro.valueChanged.connect(self._mudou)
        f.addWidget(self.ouro)
        f.addWidget(W.QLabel("margem:"))
        self.margem = W.QDoubleSpinBox(maximum=2.0, singleStep=0.05, decimals=2)
        self.margem.valueChanged.connect(self._mudou)
        f.addWidget(self.margem)
        f.addStretch(1)
        v.addLayout(f)
        self.est = W.QTableWidget(0, 4)
        self.est.setHorizontalHeaderLabels(["item", "estoque", "valor de 1 para ele", "valor do estoque"])
        self.est.verticalHeader().setVisible(False)
        self.est.itemChanged.connect(self._mudou)
        v.addWidget(self.est, 1)
        f = W.QHBoxLayout()
        for txt, fn in (("+ item", self._mais), ("− item", self._menos)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            f.addWidget(b)
        f.addStretch(1)
        v.addLayout(f)
        split.addWidget(w)
        # simulação
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        v.setContentsMargins(0, 0, 0, 0)
        v.addWidget(W.QLabel("Simular uma troca (quantidades na mesa):"))
        self.mesa = W.QTableWidget(0, 3)
        self.mesa.setHorizontalHeaderLabels(["item", "a bruxa dá", "ele dá"])
        self.mesa.verticalHeader().setVisible(False)
        self.mesa.itemChanged.connect(lambda *_: self.simular())
        v.addWidget(self.mesa, 1)
        f = W.QHBoxLayout()
        f.addWidget(W.QLabel("ouro na mesa (+ a bruxa paga, − ele paga):"))
        self.ouro_mesa = W.QSpinBox(minimum=-100000, maximum=100000)
        self.ouro_mesa.valueChanged.connect(self.simular)
        f.addWidget(self.ouro_mesa)
        b = W.QPushButton("Zerar")
        b.clicked.connect(self._zerar_mesa)
        f.addWidget(b)
        f.addStretch(1)
        v.addLayout(f)
        self.balanca = W.QTextBrowser()
        fnt = self.balanca.font()
        fnt.setPointSize(fnt.pointSize() + 1)
        self.balanca.setFont(fnt)
        v.addWidget(self.balanca, 1)
        split.addWidget(w)
        split.setSizes([560, 560])
        lay.addWidget(split, 1)
        self.carregar()

    # ---------------------------------------------------------- dados
    def carregar(self, *_):
        self.itens = {}
        for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "itens", "*.tres"))):
            t = ts.ler(p)
            iid = ts.ler_campo(t, "id", os.path.splitext(os.path.basename(p))[0])
            self.itens[iid] = {"nome": ts.ler_campo(t, "nome", iid), "vb": float(ts.ler_campo(t, "valor_base", 10.0) or 10.0),
                               "qb": float(ts.ler_campo(t, "qtd_base", 5.0) or 5.0)}
        I = ind.indice(self.raiz, novo=True)
        self.lojas = [d for d in I.cmds if d["cl"] == "CmdLoja"]
        self.lojas_t.setRowCount(len(self.lojas))
        for r, d in enumerate(self.lojas):
            c = d["res"]
            pers = c.get("personagem")
            vals = [d["ev"], I.onde(d), c.get("id_loja", "mercador"), ind.stem(pers.path) if isinstance(pers, self.T.ExtRef) else "-",
                    str(int(c.get("ouro_mercador", 100))), "%g" % float(c.get("margem", 0.2))]
            for k, x in enumerate(vals):
                self.lojas_t.setItem(r, k, W.QTableWidgetItem(x))
        self.lojas_t.resizeColumnsToContents()
        self.sujo = False
        if self.lojas:
            self.lojas_t.setCurrentCell(0, 0)
            self._escolhida(0)
        self.status.setText("%d loja(s)" % len(self.lojas) if self.lojas else "nenhum comando loja nos eventos")

    def _escolhida(self, r):
        if not 0 <= r < len(self.lojas):
            return
        self.d = self.lojas[r]
        c = self.d["res"]
        est = c.get("estoque")
        est = dict(est.d) if isinstance(est, self.T.TypedDict) else dict(est or {})
        self._carregando = True
        self.ouro.setValue(int(c.get("ouro_mercador", 100)))
        self.margem.setValue(float(c.get("margem", 0.2)))
        self.est.setRowCount(0)
        for iid, q in est.items():
            self._linha(str(iid), int(q))
        self._carregando = False
        self.sujo = False
        self._valores()
        self._zerar_mesa()

    def _linha(self, iid, q):
        r = self.est.rowCount()
        self.est.insertRow(r)
        cb = W.QComboBox()
        for k, it in sorted(self.itens.items(), key=lambda x: x[1]["nome"]):
            cb.addItem(it["nome"], k)
        cb.setCurrentIndex(max(0, cb.findData(iid)))
        cb.currentIndexChanged.connect(self._mudou)
        self.est.setCellWidget(r, 0, cb)
        self.est.setItem(r, 1, W.QTableWidgetItem(str(q)))
        for c in (2, 3):
            it = W.QTableWidgetItem("")
            it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
            self.est.setItem(r, c, it)

    def _estoque(self):
        out = {}
        for r in range(self.est.rowCount()):
            iid = self.est.cellWidget(r, 0).currentData()
            try:
                q = max(0, int(float(self.est.item(r, 1).text())))
            except (ValueError, AttributeError):
                q = 0
            out[iid] = out.get(iid, 0) + q
        return out

    def valor(self, iid, q_merc):
        it = self.itens.get(iid)
        if not it:
            return 0.0
        qb = max(it["qb"], 0.01)
        return it["vb"] * qb / (qb + max(q_merc, 0))

    def _valores(self):
        est = self._estoque()
        self._carregando = True
        for r in range(self.est.rowCount()):
            iid = self.est.cellWidget(r, 0).currentData()
            q = est.get(iid, 0)
            self.est.item(r, 2).setText("%.1f" % self.valor(iid, q))
            self.est.item(r, 3).setText("%.1f" % (self.valor(iid, q) * q))
        self._carregando = False

    def _mais(self):
        livres = [k for k in self.itens if k not in self._estoque()]
        self._linha(livres[0] if livres else next(iter(self.itens), ""), 1)
        self._mudou()

    def _menos(self):
        r = self.est.currentRow()
        if r >= 0:
            self.est.removeRow(r)
            self._mudou()

    def _mudou(self, *_):
        if self._carregando:
            return
        self.sujo = True
        self.status.setText("não salvo")
        self._valores()
        self.simular()

    # ---------------------------------------------------------- simulação
    def _zerar_mesa(self):
        self.mesa.blockSignals(True)
        ids = sorted(self.itens, key=lambda k: self.itens[k]["nome"])
        self.mesa.setRowCount(len(ids))
        for r, k in enumerate(ids):
            it = W.QTableWidgetItem(self.itens[k]["nome"])
            it.setData(QtCore.Qt.UserRole, k)
            it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
            self.mesa.setItem(r, 0, it)
            self.mesa.setItem(r, 1, W.QTableWidgetItem("0"))
            self.mesa.setItem(r, 2, W.QTableWidgetItem("0"))
        self.mesa.blockSignals(False)
        self.ouro_mesa.blockSignals(True)
        self.ouro_mesa.setValue(0)
        self.ouro_mesa.blockSignals(False)
        self.simular()

    def simular(self, *_):
        est = self._estoque()
        margem = self.margem.value()
        recebe = da = 0.0
        linhas = []
        for r in range(self.mesa.rowCount()):
            k = self.mesa.item(r, 0).data(QtCore.Qt.UserRole)
            try:
                b = int(self.mesa.item(r, 1).text() or 0)
                m = int(self.mesa.item(r, 2).text() or 0)
            except (ValueError, AttributeError):
                continue
            liq = b - m
            v = self.valor(k, est.get(k, 0))
            if liq > 0:
                recebe += v * liq
                linhas.append("ele recebe %d %s (%.1f cada)" % (liq, self.itens[k]["nome"], v))
            elif liq < 0:
                da += v * -liq
                linhas.append("ele dá %d %s (%.1f cada)" % (-liq, self.itens[k]["nome"], v))
            if m > est.get(k, 0):
                linhas.append("<span style='color:#e53935'>ele só tem %d %s</span>" % (est.get(k, 0), self.itens[k]["nome"]))
        o = self.ouro_mesa.value()
        recebe += max(o, 0)
        da += max(-o, 0)
        precisa = (1 + margem) * da
        if not linhas and o == 0:
            self.balanca.setText("Mesa vazia. Ponha quantidades nas colunas.")
            return
        if recebe <= 0 and da <= 0:
            veredito = "<b>troca igual: ele não aceita</b> (os mesmos itens dos dois lados)"
        elif precisa <= 0 or recebe >= precisa:
            veredito = "<b style='color:#3a9d4a'>ele aceita</b>"
        else:
            import math
            veredito = "<b style='color:#e53935'>ele não aceita</b>: faltam %d de ouro" % math.ceil(precisa - recebe)
        pende = "para a bruxa" if da > recebe else ("para o mercador" if recebe > da else "reta")
        self.balanca.setText("<br>".join(linhas) + "<br><br>Balança (valor real, sem margem): ele recebe <b>%.1f</b>, ele dá <b>%.1f</b> → pende %s.<br>"
                             "Pechincha: ele quer receber ≥ (1 + %.2f) × %.1f = <b>%.1f</b>. %s" % (recebe, da, pende, margem, da, precisa, veredito))

    # ---------------------------------------------------------- salvar
    def tem_mudancas(self):
        return self.sujo

    def salvar(self):
        if not self.lojas or not self.sujo:
            return
        d = self.d
        doc = self.T.TresDoc.load(d["arq"])
        pags = doc.root.get("paginas").itens
        c = pags[d["pag"]].get("comandos").itens[d["i"]]
        est = c.get("estoque")
        tipos = est.tipos if isinstance(est, self.T.TypedDict) else ("String", "int")
        c.props["estoque"] = self.T.TypedDict(tipos, {k: self.T.GInt(q) for k, q in self._estoque().items()})
        c.props["ouro_mercador"] = self.T.GInt(self.ouro.value())
        c.props["margem"] = self.T.GFloat(self.margem.value())
        doc.save(d["arq"])
        r = self.lojas_t.currentRow()
        self.carregar()
        self.lojas_t.setCurrentCell(max(0, r), 0)
        self.status.setText("salvo em %s" % d["ev"])

    def abrir_evento(self):
        if self.lojas:
            navegar.abrir_evento(self.d["ev"], self.d["pag"], self.d["i"])


def criar(raiz):
    return Aba(raiz)
