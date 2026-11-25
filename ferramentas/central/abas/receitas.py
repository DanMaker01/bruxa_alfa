# receitas.py - aba Receitas (dados/receitas/*.tres, ReceitaData).
#   Esquerda: as receitas.
#   Meio:     nome, poção, descrição, duração, conhecida; ingredientes (item, quantidade, nota);
#             passos do texto (uma linha por passo); passos do livro (chama/ingrediente/segundos,
#             só para ver: edite na aba Balanceamento, botão "Abrir no Balanceamento").
#   Direita:  prévia em texto da página do livro (não é idêntica ao jogo).
# "Salvar" grava o .tres (pergunta se ele mudou fora daqui).
import glob
import html
import os

from PySide6 import QtGui, QtWidgets as W

from nucleo import motor, navegar

TITULO = "Receitas"
SCRIPT_ING = "res://src/dados/receita_ingrediente.gd"


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        _, self.T, _ = motor.eventos()
        self.proj = motor.projeto(raiz)
        self.sim, _ = motor.balanceamento()
        self.doc = None
        self.sujo = False
        self._carregando = False
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        for txt, fn in (("Recarregar", self.carregar), ("Salvar", self.salvar), ("Abrir no Balanceamento", self.balancear)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        h.addStretch(1)
        self.status = W.QLabel()
        h.addWidget(self.status)
        lay.addLayout(h)
        split = W.QSplitter()
        self.lista = W.QListWidget()
        self.lista.currentRowChanged.connect(self._escolhida)
        split.addWidget(self.lista)
        # formulário
        form_w = W.QWidget()
        v = W.QVBoxLayout(form_w)
        v.setContentsMargins(0, 0, 0, 0)
        f = W.QFormLayout()
        self.nome = W.QLineEdit()
        self.pocao = W.QComboBox()
        self.descricao = W.QPlainTextEdit()
        self.descricao.setMaximumHeight(70)
        self.duracao = W.QDoubleSpinBox(maximum=9999, decimals=1, suffix=" s")
        self.conhecida = W.QCheckBox("a bruxa já conhece")
        f.addRow("nome", self.nome)
        f.addRow("poção", self.pocao)
        f.addRow("descrição", self.descricao)
        f.addRow("duração", self.duracao)
        f.addRow("", self.conhecida)
        v.addLayout(f)
        for w_ in (self.nome,):
            w_.textChanged.connect(self._mudou)
        self.descricao.textChanged.connect(self._mudou)
        self.pocao.currentIndexChanged.connect(self._mudou)
        self.duracao.valueChanged.connect(self._mudou)
        self.conhecida.toggled.connect(self._mudou)
        v.addWidget(W.QLabel("Ingredientes:"))
        self.ing = W.QTableWidget(0, 3)
        self.ing.setHorizontalHeaderLabels(["item", "quantidade", "nota"])
        self.ing.verticalHeader().setVisible(False)
        self.ing.horizontalHeader().setStretchLastSection(True)
        self.ing.itemChanged.connect(self._mudou)
        self.ing.setMaximumHeight(150)
        v.addWidget(self.ing)
        h = W.QHBoxLayout()
        for txt, fn in (("+ ingrediente", self._mais_ing), ("− ingrediente", self._menos_ing)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        h.addStretch(1)
        v.addLayout(h)
        v.addWidget(W.QLabel("Passos (texto, um por linha):"))
        self.passos = W.QPlainTextEdit()
        self.passos.textChanged.connect(self._mudou)
        v.addWidget(self.passos, 1)
        v.addWidget(W.QLabel("Passos do livro (edite no Balanceamento):"))
        self.livro = W.QTableWidget(0, 4)
        self.livro.setHorizontalHeaderLabels(["tipo", "chama / item", "qtd", "segundos"])
        self.livro.verticalHeader().setVisible(False)
        self.livro.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.livro.setMaximumHeight(150)
        v.addWidget(self.livro)
        split.addWidget(form_w)
        self.previa = W.QTextBrowser()
        split.addWidget(self.previa)
        split.setSizes([200, 620, 460])
        lay.addWidget(split, 1)
        self.carregar()

    # ---------------------------------------------------------- dados
    def carregar(self, *_):
        if self.sujo and W.QMessageBox.question(self, "Recarregar", "Descartar as mudanças não salvas?") != W.QMessageBox.Yes:
            return
        self.itens = {}
        for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "itens", "*.tres"))):
            d = self.T.TresDoc.load(p)
            self.itens[self.proj.res(p)] = d.root.get("nome", "") or os.path.basename(p)
        self.pocoes = {}
        for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "pocoes", "**", "*.tres"), recursive=True)):
            if "PocaoReferencia" in open(p, encoding="utf-8").readline():
                self.pocoes[self.proj.res(p)] = self.T.TresDoc.load(p).root.get("nome", "") or os.path.basename(p)
        self.pocao.blockSignals(True)
        self.pocao.clear()
        self.pocao.addItem("(nenhuma)", None)
        for r, n in self.pocoes.items():
            self.pocao.addItem(n, r)
        self.pocao.blockSignals(False)
        atual = self.lista.currentRow()
        self.arqs = sorted(glob.glob(os.path.join(self.raiz, "dados", "receitas", "*.tres")))
        self.lista.blockSignals(True)
        self.lista.clear()
        for p in self.arqs:
            self.lista.addItem(os.path.splitext(os.path.basename(p))[0])
        self.lista.blockSignals(False)
        self.sujo = False
        self.lista.setCurrentRow(max(0, min(atual, len(self.arqs) - 1)))
        self._escolhida(self.lista.currentRow())

    def _escolhida(self, k):
        if not 0 <= k < len(self.arqs):
            return
        if self.sujo and self.doc and W.QMessageBox.question(self, "Trocar de receita", "Descartar as mudanças desta receita?") != W.QMessageBox.Yes:
            return
        self.arq = self.arqs[k]
        self.doc = self.T.TresDoc.load(self.arq)
        self.mtime = os.path.getmtime(self.arq)
        R = self.doc.root
        self._carregando = True
        self.nome.setText(R.get("nome", "") or "")
        po = R.get("pocao")
        self.pocao.setCurrentIndex(max(0, self.pocao.findData(po.path if isinstance(po, self.T.ExtRef) else None)))
        self.descricao.setPlainText(R.get("descricao", "") or "")
        self.duracao.setValue(float(R.get("duracao", 0) or 0))
        self.conhecida.setChecked(bool(R.get("conhecida", False)))
        ings = R.get("ingredientes")
        ings = ings.itens if isinstance(ings, self.T.TypedArray) else []
        self.ing.setRowCount(0)
        for g in ings:
            it = g.get("item")
            self._linha_ing(it.path if isinstance(it, self.T.ExtRef) else None, int(g.get("quantidade", 1) or 1), g.get("nota", "") or "")
        ps = R.get("passos")
        self.passos.setPlainText("\n".join(str(x) for x in (ps.args if isinstance(ps, self.T.Call) else (ps or []))))
        pl = R.get("passos_livro")
        self.pl = [x for x in (pl.itens if isinstance(pl, self.T.TypedArray) else []) if isinstance(x, dict)]
        self.livro.setRowCount(len(self.pl))
        for r, p in enumerate(self.pl):
            ing = p.get("tipo") == "ingrediente"
            e = self.sim.ESTADO.get(p.get("estado", ""))
            vals = [p.get("tipo", ""), p.get("item", "") if ing else (e["nome"] if e else p.get("estado", "")),
                    str(p.get("qtd", "")) if ing else "", "%g" % p.get("seg", 0) if ing else ""]
            for c, x in enumerate(vals):
                item = W.QTableWidgetItem(x)
                if e and not ing:
                    q = QtGui.QColor.fromRgbF(*e["cor"])
                    item.setBackground(q)
                    item.setForeground(QtGui.QColor("black" if q.lightness() > 140 else "white"))
                self.livro.setItem(r, c, item)
        self._carregando = False
        self.sujo = False
        self._previa()
        self._status()

    def _linha_ing(self, item_res, qtd, nota):
        r = self.ing.rowCount()
        self.ing.insertRow(r)
        c = W.QComboBox()
        for res, n in self.itens.items():
            c.addItem(n, res)
        c.setCurrentIndex(max(0, c.findData(item_res)))
        c.currentIndexChanged.connect(self._mudou)
        self.ing.setCellWidget(r, 0, c)
        self.ing.setItem(r, 1, W.QTableWidgetItem(str(qtd)))
        self.ing.setItem(r, 2, W.QTableWidgetItem(nota))

    def _mais_ing(self):
        self._linha_ing(None, 1, "")
        self._mudou()

    def _menos_ing(self):
        r = self.ing.currentRow()
        if r >= 0:
            self.ing.removeRow(r)
            self._mudou()

    def _mudou(self, *_):
        if self._carregando:
            return
        self.sujo = True
        self._previa()
        self._status()

    def _status(self):
        self.status.setText("não salvo" if self.sujo else "")
        it = self.lista.currentItem()
        if it:
            base = os.path.splitext(os.path.basename(self.arq))[0]
            it.setText(base + (" *" if self.sujo else ""))

    def _ingredientes(self):
        out = []
        for r in range(self.ing.rowCount()):
            c = self.ing.cellWidget(r, 0)
            try:
                q = max(1, int(float(self.ing.item(r, 1).text())))
            except (ValueError, AttributeError):
                q = 1
            out.append((c.currentData(), q, self.ing.item(r, 2).text() if self.ing.item(r, 2) else ""))
        return out

    # ---------------------------------------------------------- prévia
    def _previa(self):
        e = html.escape
        partes = ["<h2 style='margin-bottom:2px'>%s</h2>" % e(self.nome.text())]
        if self.pocao.currentData():
            partes.append("<i>%s</i>" % e(self.pocao.currentText()))
        partes.append("<p>%s</p>" % e(self.descricao.toPlainText()).replace("\n", "<br>"))
        partes.append("<h4>Ingredientes</h4><ul>")
        for res, q, nota in self._ingredientes():
            partes.append("<li><b>%d × %s</b>%s</li>" % (q, e(self.itens.get(res, "?")), (" <span style='color:#888'>(%s)</span>" % e(nota)) if nota else ""))
        partes.append("</ul><h4>Modo de preparo</h4><ol>")
        for linha in self.passos.toPlainText().splitlines():
            if linha.strip():
                partes.append("<li>%s</li>" % e(linha))
        partes.append("</ol>")
        if self.pl:
            partes.append("<h4>No livro</h4><p>")
            for p in self.pl:
                if p.get("tipo") == "chama":
                    est = self.sim.ESTADO.get(p.get("estado", ""))
                    q = QtGui.QColor.fromRgbF(*est["cor"]) if est else QtGui.QColor("#888")
                    partes.append("<span style='background:%s;color:%s'>&nbsp;%s&nbsp;</span> → " % (
                        q.name(), "black" if q.lightness() > 140 else "white", e(est["nome"] if est else p.get("estado", ""))))
                else:
                    partes.append("%s × %s por %g s → " % (p.get("qtd", 1), e(p.get("item", "")), p.get("seg", 0)))
            partes.append("pronto</p>")
        partes.append("<p style='color:#888'>duração ~%g s%s</p>" % (self.duracao.value(), " · conhecida" if self.conhecida.isChecked() else ""))
        self.previa.setHtml("".join(partes))

    # ---------------------------------------------------------- salvar / balancear
    def tem_mudancas(self):
        return self.sujo

    def salvar(self):
        if not self.doc:
            return
        if os.path.getmtime(self.arq) != self.mtime and W.QMessageBox.question(
                self, "Arquivo mudou", "A receita mudou fora daqui (Godot?). Gravar por cima?") != W.QMessageBox.Yes:
            return
        R = self.doc.root
        T = self.T
        R.props["nome"] = self.nome.text()
        R.props["descricao"] = self.descricao.toPlainText()
        R.props["duracao"] = T.GFloat(self.duracao.value())
        if self.conhecida.isChecked():
            R.props["conhecida"] = True
        else:
            R.props.pop("conhecida", None)      # falso é o padrão: o Godot não grava
        if self.pocao.currentData():
            R.props["pocao"] = self.proj.ext(self.pocao.currentData())
        else:
            R.props.pop("pocao", None)
        antigos = R.get("ingredientes")
        antigos = antigos.itens if isinstance(antigos, T.TypedArray) else []
        novos = []
        for k, (res, q, nota) in enumerate(self._ingredientes()):
            g = antigos[k] if k < len(antigos) else T.Res("Resource", {"script": self.proj.ext(SCRIPT_ING, "Script")})
            if res:
                g.props["item"] = self.proj.ext(res)
            g.props["quantidade"] = T.GInt(q)
            if nota:
                g.props["nota"] = nota
            else:
                g.props.pop("nota", None)
            novos.append(g)
        R.props["ingredientes"] = T.TypedArray(self.proj.ext(SCRIPT_ING, "Script"), novos)
        R.props["passos"] = T.Call("PackedStringArray", [l for l in self.passos.toPlainText().splitlines() if l.strip()])
        self.doc.save(self.arq)
        self.sujo = False
        self._escolhida(self.lista.currentRow())
        self.status.setText("salvo")

    def balancear(self):
        nome = os.path.splitext(os.path.basename(self.arq))[0] if self.doc else ""
        w = navegar.aba("balanceamento")
        if w is not None and hasattr(w, "combo"):
            if hasattr(w, "recarregar"):
                w.recarregar()
            i = w.combo.findText(nome)
            if i >= 0:
                w.combo.setCurrentIndex(i)


def criar(raiz):
    return Aba(raiz)
