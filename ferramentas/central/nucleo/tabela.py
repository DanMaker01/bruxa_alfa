# tabela.py - TabelaTres: tabela genérica de .tres (um arquivo por linha) com campos
# editáveis, filtro, salvar só o que mudou, e um painel à direita (matriz A e o que a aba
# quiser acrescentar).
#   campos = [(nome, tipo, padrão, rótulo)]   tipo: 'num' | 'texto' | 'bool' | 'fixo'
#   ordem(caminho) -> chave de ordenação (ex.: proibidas no fim)
#   banco = nome da lista no dados/banco.tres (mostra a coluna "no banco")
import os

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import tres_simples as ts
from nucleo.visual import MatrizGrade


class TabelaTres(W.QWidget):
    linha_escolhida = QtCore.Signal(int)
    mudou = QtCore.Signal(int)

    def __init__(self, raiz, padrao, script_class, campos, com_matriz=False, coluna_id="arquivo",
                 ordem=None, banco=None, validar=None):
        super().__init__()
        self.raiz, self.padrao, self.script_class = raiz, padrao, script_class
        self.campos, self.com_matriz, self.coluna_id = campos, com_matriz, coluna_id
        self.ordem, self.banco, self._validar = ordem, banco, validar
        self.linhas = []
        self._carregando = False
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        self.barra = W.QHBoxLayout()
        self.filtro = W.QLineEdit(placeholderText="filtrar...")
        self.filtro.textChanged.connect(self._filtrar)
        self.barra.addWidget(self.filtro, 1)
        for txt, fn in (("Recarregar", self.carregar), ("Salvar", self.salvar)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            self.barra.addWidget(b)
        lay.addLayout(self.barra)
        self.split = W.QSplitter(QtCore.Qt.Horizontal)
        self.tab = W.QTableWidget(0, 0)
        self.tab.verticalHeader().setVisible(False)
        self.tab.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.tab.setSelectionMode(W.QAbstractItemView.SingleSelection)
        self.tab.itemChanged.connect(self._item_mudou)
        self.tab.currentCellChanged.connect(lambda r, *_: self._escolher(r))
        self.split.addWidget(self.tab)
        # painel da direita (rolável)
        self.painel = W.QWidget()
        self.painel_lay = W.QVBoxLayout(self.painel)
        self.painel_lay.setContentsMargins(4, 0, 4, 0)
        if com_matriz:
            caixa = W.QGroupBox("Matriz A  (linha = traço que muda · coluna = traço de origem)")
            v = W.QVBoxLayout(caixa)
            self.matriz = MatrizGrade()
            self.matriz.mudou.connect(self._matriz_mudou)
            v.addWidget(self.matriz)
            self.painel_lay.addWidget(caixa)
        rol = W.QScrollArea()
        rol.setWidgetResizable(True)
        rol.setWidget(self.painel)
        rol.setFrameShape(W.QFrame.NoFrame)
        self.split.addWidget(rol)
        self.split.setStretchFactor(0, 3)
        self.split.setStretchFactor(1, 2)
        lay.addWidget(self.split, 1)
        self.status = W.QLabel()
        lay.addWidget(self.status)
        self.carregar()

    def fim_do_painel(self):
        self.painel_lay.addStretch(1)

    # ---------------------------------------------------------- dados
    def carregar(self):
        arqs = ts.listar(self.raiz, self.padrao, self.script_class)
        if self.ordem:
            arqs.sort(key=lambda pt: self.ordem(pt[0]))
        self.linhas = []
        for p, t in arqs:
            vals = {c[0]: ts.ler_campo(t, c[0], c[2]) for c in self.campos}
            A = ts.ler_matriz(t) if self.com_matriz else None
            self.linhas.append({"arq": p, "id": os.path.splitext(os.path.basename(p))[0], "texto": t,
                                "valores": vals, "orig": dict(vals), "A": A,
                                "A_orig": [l[:] for l in A] if A else None, "sujo": False})
        self._preencher()

    def _cabecalho(self):
        cab = [self.coluna_id] + [c[3] for c in self.campos]
        if self.banco:
            cab.append("no banco")
        return cab

    def _preencher(self):
        self._carregando = True
        cab = self._cabecalho()
        self.tab.setColumnCount(len(cab))
        self.tab.setHorizontalHeaderLabels(cab)
        self.tab.setRowCount(len(self.linhas))
        try:
            banco = ts.ids_no_banco(self.raiz, self.banco) if self.banco else set()
        except Exception:
            banco = set()
        for r, l in enumerate(self.linhas):
            it = W.QTableWidgetItem(l["id"])
            it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
            it.setToolTip(os.path.relpath(l["arq"], self.raiz))
            if os.sep + "proibidas" + os.sep in l["arq"] or "/proibidas/" in l["arq"]:
                it.setForeground(QtGui.QColor("#c06060"))
            self.tab.setItem(r, 0, it)
            for c, (nome, tipo, padrao, _) in enumerate(self.campos):
                self.tab.setItem(r, c + 1, self._celula(l["valores"][nome], tipo))
            if self.banco:
                ok = l["id"] in banco
                it = W.QTableWidgetItem("sim" if ok else "NÃO")
                it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
                it.setToolTip("" if ok else "não está em dados/banco.tres: o jogo não carrega")
                if not ok:
                    it.setForeground(QtGui.QColor("#e53935"))
                self.tab.setItem(r, len(cab) - 1, it)
        self._carregando = False
        self.tab.resizeColumnsToContents()
        for c in range(self.tab.columnCount()):
            self.tab.setColumnWidth(c, min(self.tab.columnWidth(c), 320))
        self._filtrar(self.filtro.text())
        self._atualizar_status()
        if self.linhas:
            self.tab.setCurrentCell(0, 0)
            self._escolher(0)

    def _celula(self, v, tipo):
        if isinstance(v, float):
            txt = "%g" % v
        elif v is True:
            txt = "sim"
        elif v is False:
            txt = "não"
        else:
            txt = "" if v is None else str(v)
        it = W.QTableWidgetItem(txt)
        if tipo == "fixo":
            it.setFlags(it.flags() & ~QtCore.Qt.ItemIsEditable)
            it.setForeground(QtGui.QColor("#888"))
        if tipo == "num":
            it.setTextAlignment(QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)
        if tipo == "texto" and len(txt) > 40:
            it.setToolTip(txt)
        return it

    def _filtrar(self, txt):
        txt = txt.lower()
        for r in range(self.tab.rowCount()):
            vis = not txt or any(txt in (self.tab.item(r, c).text().lower() if self.tab.item(r, c) else "")
                                 for c in range(self.tab.columnCount()))
            self.tab.setRowHidden(r, not vis)

    def _item_mudou(self, it):
        if self._carregando or it.column() == 0 or it.column() > len(self.campos):
            return
        r = it.row()
        nome, tipo, padrao, _ = self.campos[it.column() - 1]
        l = self.linhas[r]
        txt = it.text().strip()
        if tipo == "num":
            try:
                v = float(txt.replace(",", "."))
            except ValueError:
                self._set_texto(it, "%g" % (l["valores"][nome] or 0))
                return
            if self._validar:
                v = self._validar(nome, v)
            self._set_texto(it, "%g" % v)
        elif tipo == "bool":
            v = txt.lower() in ("sim", "s", "true", "1", "x")
        else:
            v = txt
        if v != l["valores"][nome]:
            l["valores"][nome] = v
            self._marcar(r)
        self.mudou.emit(r)

    def _set_texto(self, it, txt):
        self._carregando = True
        it.setText(txt)
        self._carregando = False

    def _marcar(self, r):
        self.linhas[r]["sujo"] = True
        it = self.tab.item(r, 0)
        if it and not it.text().endswith(" *"):
            self._set_texto(it, it.text() + " *")
        self._atualizar_status()

    def _escolher(self, r):
        if not 0 <= r < len(self.linhas):
            return
        if self.com_matriz:
            self.matriz.definir(self.linhas[r]["A"])
        self.linha_escolhida.emit(r)

    def atual(self):
        r = self.tab.currentRow()
        return self.linhas[r] if 0 <= r < len(self.linhas) else None

    def _matriz_mudou(self):
        r = self.tab.currentRow()
        if 0 <= r < len(self.linhas):
            self.linhas[r]["A"] = self.matriz.valor()
            self._marcar(r)
            self.mudou.emit(r)

    def tem_mudancas(self):
        return any(l["sujo"] for l in self.linhas)

    def _atualizar_status(self):
        n = sum(1 for l in self.linhas if l["sujo"])
        self.status.setText("%d arquivo(s)%s" % (len(self.linhas), (" · %d não salvo(s)" % n) if n else ""))

    def salvar(self):
        n = 0
        for l in self.linhas:
            if not l["sujo"]:
                continue
            t = ts.ler(l["arq"])
            if t != l["texto"]:
                r = W.QMessageBox.question(self, "Arquivo mudou",
                                           "%s mudou fora daqui (Godot?) desde que foi lido. Gravar por cima?" % l["id"])
                if r != W.QMessageBox.Yes:
                    continue
            for nome, tipo, padrao, _ in self.campos:
                v = l["valores"][nome]
                if tipo != "fixo" and v is not None and v != l["orig"][nome]:
                    t = ts.gravar_campo(t, nome, v)
            if self.com_matriz and l["A"] != l["A_orig"]:
                t = ts.gravar_matriz(t, l["A"])
            ts.escrever(l["arq"], t)
            n += 1
        sel = self.tab.currentRow()
        self.carregar()
        if 0 <= sel < self.tab.rowCount():
            self.tab.setCurrentCell(sel, 0)
        self.status.setText(self.status.text() + " · salvo(s): %d" % n)

    def novo_arquivo(self, pasta_rel, nid, texto):
        """Cria dados/<pasta_rel>/<nid>.tres e registra no banco (se a tabela tiver banco)."""
        arq = os.path.join(self.raiz, *pasta_rel.split("/"), nid + ".tres")
        if os.path.exists(arq):
            W.QMessageBox.warning(self, "Já existe", "%s.tres já existe." % nid)
            return False
        ts.escrever(arq, texto)
        if self.banco:
            ts.registrar_no_banco(self.raiz, "res://%s/%s.tres" % (pasta_rel, nid), self.banco)
        self.carregar()
        for r, l in enumerate(self.linhas):
            if l["id"] == nid:
                self.tab.setCurrentCell(r, 0)
        return True


def pedir_id(parent, titulo, exemplo):
    nid, ok = W.QInputDialog.getText(parent, titulo, "id (letras minúsculas, sem espaço; ex.: %s):" % exemplo)
    nid = nid.strip().lower().replace(" ", "_")
    return nid if ok and nid else None
