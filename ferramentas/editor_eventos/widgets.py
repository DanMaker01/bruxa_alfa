# widgets.py - editores de campo, formulário genérico e diálogos do editor de eventos.

import os

from PySide6.QtCore import Qt, Signal, QTimer, QEvent
from PySide6.QtGui import QColor, QFont, QKeySequence, QShortcut, QSyntaxHighlighter, QTextCharFormat, QTextCursor
from PySide6.QtWidgets import (
    QAbstractItemView, QCheckBox, QColorDialog, QComboBox, QDialog, QDialogButtonBox, QDoubleSpinBox,
    QFormLayout, QFrame, QGroupBox, QHBoxLayout, QHeaderView, QLabel, QLineEdit, QListWidget,
    QListWidgetItem, QMessageBox, QPlainTextEdit, QPushButton, QScrollArea, QSizePolicy, QSpinBox,
    QTableWidget, QTableWidgetItem, QTreeWidget, QTreeWidgetItem, QVBoxLayout, QWidget, QCompleter,
)

import modelo
import tres
from tres import Res, ExtRef, GFloat, GInt, TypedArray

MISTO = object()   # valor diferente entre os itens selecionados

CORES = {
    "dialogo": "#2563c9", "fluxo": "#8b3fc0", "dados": "#1f8a4c", "cena": "#b85c00", "outros": "#555555",
}


def fonte_mono(tam=10):
    f = QFont("Consolas")
    f.setStyleHint(QFont.Monospace)
    f.setPointSize(tam)
    return f


# ---------------------------------------------------------------------------
# Pequenos widgets
# ---------------------------------------------------------------------------
class SemRoda:
    """Mixin: a roda do mouse só mexe no valor com o campo focado (não rouba a rolagem)."""

    def wheelEvent(self, e):
        if self.hasFocus():
            super().wheelEvent(e)
        else:
            e.ignore()


class SpinF(SemRoda, QDoubleSpinBox):
    def textFromValue(self, v):
        s = ("%%.%df" % self.decimals()) % v
        if "." in s:
            s = s.rstrip("0").rstrip(".")
        return s


class SpinI(SemRoda, QSpinBox):
    pass


class Combo(SemRoda, QComboBox):
    pass


def combo_editavel(opcoes, dicas=None):
    cb = Combo()
    cb.setEditable(True)
    cb.setInsertPolicy(QComboBox.NoInsert)
    cb.addItems(opcoes)
    if dicas:
        for i, o in enumerate(opcoes):
            if o in dicas and dicas[o]:
                cb.setItemData(i, dicas[o], Qt.ToolTipRole)
    comp = QCompleter(opcoes, cb)
    comp.setCaseSensitivity(Qt.CaseInsensitive)
    comp.setFilterMode(Qt.MatchContains)
    cb.setCompleter(comp)
    cb.setCurrentIndex(-1)
    cb.setEditText("")
    return cb


# ---------------------------------------------------------------------------
# Editores de campo
# ---------------------------------------------------------------------------
class Editor:
    """Envolve um widget: set(v), get(), misto(), e chama on_mudou() quando o usuário muda."""

    def __init__(self, campo, ctx):
        self.campo = campo
        self.ctx = ctx
        self.on_mudou = None
        self._bloq = False
        self.w = None

    def emitir(self):
        if not self._bloq and self.on_mudou:
            self.on_mudou(self)

    def set(self, v):
        self._bloq = True
        try:
            if v is MISTO:
                self._misto()
            else:
                self._set(v)
        finally:
            self._bloq = False

    def _misto(self):
        pass

    def _set(self, v):
        pass

    def get(self):
        return None


class EdBool(Editor):
    def __init__(self, campo, ctx):
        super().__init__(campo, ctx)
        self.w = QCheckBox()
        self.w.stateChanged.connect(lambda *_: self.emitir())

    def _misto(self):
        self.w.setTristate(True)
        self.w.setCheckState(Qt.PartiallyChecked)

    def _set(self, v):
        self.w.setTristate(False)
        self.w.setChecked(bool(v))

    def get(self):
        if self.w.checkState() == Qt.PartiallyChecked:
            return MISTO
        return self.w.isChecked()


def _range(campo):
    if campo.dica and campo.dica.startswith("range:"):
        partes = [p.strip() for p in campo.dica[6:].split(",")]
        nums = []
        for p in partes:
            try:
                nums.append(float(p))
            except ValueError:
                break
        if len(nums) >= 2:
            return nums[0], nums[1], (nums[2] if len(nums) > 2 else None), "or_greater" in campo.dica
    return None


class EdNum(Editor):
    def __init__(self, campo, ctx, inteiro=False):
        super().__init__(campo, ctx)
        self.inteiro = inteiro
        self.usa_padrao = None
        rg = _range(campo)
        if inteiro:
            self.spin = SpinI()
            self.spin.setRange(-10 ** 9, 10 ** 9)
        else:
            self.spin = SpinF()
            self.spin.setDecimals(4)
            self.spin.setRange(-1e9, 1e9)
            self.spin.setSingleStep(0.1)
            if rg:
                lo, hi, passo, livre = rg
                if not livre:
                    self.spin.setRange(lo, hi)
                if passo:
                    self.spin.setSingleStep(passo)
                # padrão fora do intervalo (ex.: posicao = -1): caixinha "(padrão)"
                if campo.padrao is not None and not (lo <= float(campo.padrao) <= hi):
                    self.usa_padrao = QCheckBox("(padrão)")
            elif campo.padrao is not None and float(campo.padrao) == int(float(campo.padrao)) and abs(float(campo.padrao)) >= 10:
                self.spin.setSingleStep(1.0)
        self.spin.setKeyboardTracking(False)
        self.spin.valueChanged.connect(lambda *_: self.emitir())
        if self.usa_padrao:
            box = QWidget()
            h = QHBoxLayout(box)
            h.setContentsMargins(0, 0, 0, 0)
            h.addWidget(self.usa_padrao)
            h.addWidget(self.spin, 1)
            self.usa_padrao.toggled.connect(self._toggle)
            self.w = box
        else:
            self.w = self.spin

    def _toggle(self, on):
        self.spin.setEnabled(not on)
        self.emitir()

    def _misto(self):
        self.spin.setSpecialValueText("(vários)")
        self.spin.setValue(self.spin.minimum())

    def _set(self, v):
        self.spin.setSpecialValueText("")
        try:
            f = float(v)
        except (TypeError, ValueError):
            f = 0.0
        if self.usa_padrao:
            lo = self.spin.minimum()
            fora = f < lo or f > self.spin.maximum()
            self.usa_padrao.setChecked(fora)
            self.spin.setEnabled(not fora)
            if fora:
                f = lo
        self.spin.setValue(int(f) if self.inteiro else f)

    def get(self):
        if self.spin.specialValueText() and self.spin.value() == self.spin.minimum():
            return MISTO
        if self.usa_padrao and self.usa_padrao.isChecked():
            return self.campo.padrao
        v = self.spin.value()
        return GInt(int(v)) if self.inteiro else GFloat(float(v))


class EdTexto(Editor):
    def __init__(self, campo, ctx, multilinha=False, opcoes=None, dicas=None):
        super().__init__(campo, ctx)
        self.multi = multilinha
        if multilinha:
            self.w = QPlainTextEdit()
            self.w.setMinimumHeight(110)
            self.w.setTabChangesFocus(True)
            self._timer = QTimer()
            self._timer.setSingleShot(True)
            self._timer.setInterval(400)
            self._timer.timeout.connect(self.emitir)
            self.w.textChanged.connect(self._timer.start)
            self.w.focusOutEvent = self._foco_saiu
        elif opcoes is not None:
            self.w = combo_editavel(opcoes, dicas)
            self.w.lineEdit().editingFinished.connect(self.emitir)
            self.w.activated.connect(lambda *_: self.emitir())
        else:
            self.w = QLineEdit()
            self.w.editingFinished.connect(self.emitir)

    def _foco_saiu(self, e):
        if self._timer.isActive():
            self._timer.stop()
            self.emitir()
        QPlainTextEdit.focusOutEvent(self.w, e)

    def _misto(self):
        if self.multi:
            self.w.setPlaceholderText("(vários)")
            self.w.setPlainText("")
        elif isinstance(self.w, QComboBox):
            self.w.setEditText("")
            self.w.lineEdit().setPlaceholderText("(vários)")
        else:
            self.w.setText("")
            self.w.setPlaceholderText("(vários)")
        self._misto_flag = True

    def _set(self, v):
        self._misto_flag = False
        s = "" if v is None else str(v)
        if self.multi:
            self.w.setPlainText(s)
        elif isinstance(self.w, QComboBox):
            self.w.setEditText(s)
        else:
            self.w.setText(s)

    def texto(self):
        if self.multi:
            return self.w.toPlainText()
        if isinstance(self.w, QComboBox):
            return self.w.currentText()
        return self.w.text()

    def get(self):
        s = self.texto()
        if getattr(self, "_misto_flag", False) and s == "":
            return MISTO
        return s

    def trocar_opcoes(self, opcoes):
        if isinstance(self.w, QComboBox):
            atual = self.w.currentText()
            self._bloq = True
            self.w.clear()
            self.w.addItems(opcoes)
            comp = QCompleter(opcoes, self.w)
            comp.setCaseSensitivity(Qt.CaseInsensitive)
            comp.setFilterMode(Qt.MatchContains)
            self.w.setCompleter(comp)
            self.w.setEditText(atual)
            self._bloq = False


class EdEnum(Editor):
    def __init__(self, campo, ctx):
        super().__init__(campo, ctx)
        self.w = Combo()
        for nome in (campo.enum or []):
            self.w.addItem(nome.lower().replace("_", " "))
        self.w.currentIndexChanged.connect(lambda *_: self.emitir())

    def _misto(self):
        self.w.setCurrentIndex(-1)
        self.w.setPlaceholderText("(vários)")

    def _set(self, v):
        try:
            self.w.setCurrentIndex(int(v))
        except (TypeError, ValueError):
            self.w.setCurrentIndex(0)

    def get(self):
        i = self.w.currentIndex()
        return MISTO if i < 0 else GInt(i)


class EdVec2(Editor):
    def __init__(self, campo, ctx):
        super().__init__(campo, ctx)
        self.w = QWidget()
        h = QHBoxLayout(self.w)
        h.setContentsMargins(0, 0, 0, 0)
        self.x = SpinF()
        self.y = SpinF()
        for s, n in ((self.x, "x"), (self.y, "y")):
            s.setRange(-1e7, 1e7)
            s.setDecimals(3)
            s.setKeyboardTracking(False)
            s.valueChanged.connect(lambda *_: self.emitir())
            h.addWidget(QLabel(n))
            h.addWidget(s, 1)
        self._m = False

    def _misto(self):
        self._m = True
        for s in (self.x, self.y):
            s.setSpecialValueText("(vários)")
            s.setValue(s.minimum())

    def _set(self, v):
        self._m = False
        x, y = tres.vec2_xy(v)
        for s in (self.x, self.y):
            s.setSpecialValueText("")
        self.x.setValue(x)
        self.y.setValue(y)

    def get(self):
        if self.x.specialValueText() and self.x.value() == self.x.minimum():
            return MISTO
        return tres.vec2(_numero(self.x.value()), _numero(self.y.value()))


def _numero(f):
    return GInt(int(f)) if float(f).is_integer() else GFloat(f)


class EdCor(Editor):
    def __init__(self, campo, ctx):
        super().__init__(campo, ctx)
        self.w = QPushButton()
        self.w.clicked.connect(self._escolher)
        self.v = None

    def _pinta(self):
        r, g, b, a = tres.color_rgba(self.v)
        c = QColor.fromRgbF(max(0, min(1, r)), max(0, min(1, g)), max(0, min(1, b)), max(0, min(1, a)))
        self.w.setText("%s  a=%.2f" % (c.name(), a))
        self.w.setStyleSheet("background:%s; color:%s" % (c.name(), "#000" if c.lightnessF() > 0.5 else "#fff"))

    def _misto(self):
        self.v = MISTO
        self.w.setText("(vários)")
        self.w.setStyleSheet("")

    def _set(self, v):
        self.v = v if v is not None else tres.Call("Color", [GInt(1), GInt(1), GInt(1), GInt(1)])
        self._pinta()

    def _escolher(self):
        r, g, b, a = tres.color_rgba(self.v if self.v is not MISTO else None)
        c = QColorDialog.getColor(QColor.fromRgbF(max(0, min(1, r)), max(0, min(1, g)), max(0, min(1, b)), max(0, min(1, a))),
                                  self.w, "Cor", QColorDialog.ShowAlphaChannel)
        if c.isValid():
            self.v = tres.Call("Color", [_numero(round(c.redF(), 4)), _numero(round(c.greenF(), 4)),
                                         _numero(round(c.blueF(), 4)), _numero(round(c.alphaF(), 4))])
            self._pinta()
            self.emitir()

    def get(self):
        return self.v


class EdRef(Editor):
    """Referência a arquivo (.tres): combo com os arquivos possíveis."""

    def __init__(self, campo, ctx, opcoes):
        super().__init__(campo, ctx)
        self.opcoes = opcoes    # [(rotulo, res_path)]
        self.w = Combo()
        self.w.addItem("(nenhum)", None)
        for rot, path in opcoes:
            self.w.addItem(rot, path)
        self.w.setEditable(True)
        self.w.setInsertPolicy(QComboBox.NoInsert)
        comp = QCompleter([o[0] for o in opcoes], self.w)
        comp.setCaseSensitivity(Qt.CaseInsensitive)
        comp.setFilterMode(Qt.MatchContains)
        self.w.setCompleter(comp)
        self.w.activated.connect(lambda *_: self.emitir())
        self.w.lineEdit().editingFinished.connect(self._digitou)

    def _digitou(self):
        i = self.w.findText(self.w.currentText(), Qt.MatchFixedString)
        if i >= 0 and i != self.w.currentIndex():
            self.w.setCurrentIndex(i)
        self.emitir()

    def _misto(self):
        self.w.setCurrentIndex(-1)
        self.w.setEditText("")
        self.w.lineEdit().setPlaceholderText("(vários)")

    def _set(self, v):
        if isinstance(v, ExtRef):
            i = self.w.findData(v.path)
            if i < 0:
                self.w.addItem(os.path.splitext(os.path.basename(v.path))[0], v.path)
                i = self.w.count() - 1
            self.w.setCurrentIndex(i)
        else:
            self.w.setCurrentIndex(0)

    def get(self):
        i = self.w.currentIndex()
        if i < 0:
            return MISTO
        path = self.w.itemData(i)
        if not path:
            return None
        return self.ctx["proj"].ext(path)


class EdOpcoes(Editor):
    """opcoes + labels do CmdMostrarOpcoes numa tabela de duas colunas."""

    def __init__(self, campo, ctx):
        super().__init__(campo, ctx)
        self.w = QWidget()
        v = QVBoxLayout(self.w)
        v.setContentsMargins(0, 0, 0, 0)
        self.tab = QTableWidget(0, 2)
        self.tab.setHorizontalHeaderLabels(["Opção (texto do botão)", "Label (para onde pula)"])
        self.tab.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.tab.setMinimumHeight(120)
        self.tab.itemChanged.connect(lambda *_: self.emitir())
        v.addWidget(self.tab)
        h = QHBoxLayout()
        b1 = QPushButton("+ opção")
        b2 = QPushButton("− remover")
        b1.clicked.connect(self._mais)
        b2.clicked.connect(self._menos)
        h.addWidget(b1)
        h.addWidget(b2)
        h.addStretch(1)
        v.addLayout(h)
        self.criar_labels = QCheckBox("Ao confirmar, criar no fim da página os labels que faltam")
        self.criar_labels.setToolTip("Cada label novo vem seguido de um \"ir para\" um label de saída comum, também criado.")
        v.addWidget(self.criar_labels)

    def _mais(self):
        r = self.tab.rowCount()
        self._bloq = True
        self.tab.insertRow(r)
        self.tab.setItem(r, 0, QTableWidgetItem("Opção %d" % (r + 1)))
        self.tab.setItem(r, 1, QTableWidgetItem("label_%d" % (r + 1)))
        self._bloq = False
        self.emitir()

    def _menos(self):
        r = self.tab.currentRow()
        if r >= 0:
            self.tab.removeRow(r)
            self.emitir()

    def _set(self, v):
        opcoes, labels = v
        self.tab.setRowCount(0)
        for i, o in enumerate(opcoes):
            self.tab.insertRow(i)
            self.tab.setItem(i, 0, QTableWidgetItem(str(o)))
            self.tab.setItem(i, 1, QTableWidgetItem(str(labels[i]) if i < len(labels) else ""))

    def get(self):
        ops, lbs = [], []
        for r in range(self.tab.rowCount()):
            a = self.tab.item(r, 0)
            b = self.tab.item(r, 1)
            ops.append(a.text() if a else "")
            lbs.append(b.text() if b else "")
        return ops, lbs


class EdListaTexto(Editor):
    """Array[String] genérico: uma linha por item."""

    def __init__(self, campo, ctx):
        super().__init__(campo, ctx)
        self.w = QPlainTextEdit()
        self.w.setMaximumHeight(90)
        self.w.textChanged.connect(self.emitir)

    def _set(self, v):
        self.w.setPlainText("\n".join(str(x) for x in (v.itens if isinstance(v, TypedArray) else (v or []))))

    def get(self):
        linhas = [l for l in self.w.toPlainText().split("\n")]
        while linhas and linhas[-1] == "":
            linhas.pop()
        return linhas


class EdSubRecurso(Editor):
    """Sub-recurso embutido (ex.: a condição do Se): formulário dentro de uma caixa."""

    def __init__(self, campo, ctx, cl):
        super().__init__(campo, ctx)
        self.cl = cl
        self.res = None
        self.w = QGroupBox()
        self.lay = QVBoxLayout(self.w)
        self.lay.setContentsMargins(6, 6, 6, 6)
        self.form = None

    def _set(self, v):
        proj = self.ctx["proj"]
        if not isinstance(v, Res):
            v = proj.novo(self.cl.caminho)
        self.res = v
        if self.form:
            self.form.setParent(None)
        self.form = FormRecurso(proj, self.cl, [self.res], self.ctx, self._mudou)
        self.lay.addWidget(self.form)

    def _mudou(self, nome, valor):
        modelo.definir(self.res, self.cl, nome, valor)
        self.form.atualizar_visiveis()
        self.emitir()

    def get(self):
        return self.res


class EdListaRes(Editor):
    """Array[Recurso] (condições, passos de rota...): lista com +, editar, remover, mover."""

    def __init__(self, campo, ctx, cl_elem, script_elem):
        super().__init__(campo, ctx)
        self.cl = cl_elem
        self.script_elem = script_elem
        self.itens = []
        self.w = QWidget()
        v = QVBoxLayout(self.w)
        v.setContentsMargins(0, 0, 0, 0)
        self.lista = QListWidget()
        self.lista.setMaximumHeight(130)
        self.lista.itemDoubleClicked.connect(lambda *_: self._editar())
        v.addWidget(self.lista)
        h = QHBoxLayout()
        for txt, fn in (("+", self._mais), ("editar", self._editar), ("−", self._menos), ("↑", lambda: self._mover(-1)), ("↓", lambda: self._mover(1))):
            b = QPushButton(txt)
            b.setMaximumWidth(70 if len(txt) > 1 else 30)
            b.clicked.connect(fn)
            h.addWidget(b)
        h.addStretch(1)
        v.addLayout(h)
        self.aviso = QLabel("")
        self.aviso.setStyleSheet("color:#b00")
        v.addWidget(self.aviso)

    def texto_item(self, r):
        proj = self.ctx["proj"]
        if self.cl and self.cl.nome == "Condicao":
            return modelo.texto_condicao(proj, r)
        return modelo.resumo(proj, r)[0]

    def _misto(self):
        self.aviso.setText("As páginas selecionadas têm listas diferentes. Editar aqui troca a lista de todas.")

    def _set(self, v):
        self.aviso.setText("")
        self.itens = list(v.itens if isinstance(v, TypedArray) else (v or []))
        self._redesenha()

    def _redesenha(self, sel=None):
        self.lista.clear()
        for r in self.itens:
            self.lista.addItem(self.texto_item(r))
        if sel is not None and 0 <= sel < self.lista.count():
            self.lista.setCurrentRow(sel)

    def _mais(self):
        proj = self.ctx["proj"]
        r = proj.novo(self.script_elem)
        if editar_recurso(self.w, proj, r, self.ctx, "Novo item"):
            i = self.lista.currentRow() + 1 if self.lista.currentRow() >= 0 else len(self.itens)
            self.itens.insert(i, r)
            self._redesenha(i)
            self.emitir()

    def _editar(self):
        i = self.lista.currentRow()
        if i < 0:
            return
        r = tres.copiar_mantendo_ids(self.itens[i])
        if editar_recurso(self.w, self.ctx["proj"], r, self.ctx, "Editar"):
            self.itens[i] = r
            self._redesenha(i)
            self.emitir()

    def _menos(self):
        i = self.lista.currentRow()
        if i >= 0:
            del self.itens[i]
            self._redesenha(min(i, len(self.itens) - 1))
            self.emitir()

    def _mover(self, d):
        i = self.lista.currentRow()
        j = i + d
        if i < 0 or j < 0 or j >= len(self.itens):
            return
        self.itens[i], self.itens[j] = self.itens[j], self.itens[i]
        self._redesenha(j)
        self.emitir()

    def get(self):
        return list(self.itens)


# ---------------------------------------------------------------------------
# Escolha do editor certo para cada campo
# ---------------------------------------------------------------------------
CAMPOS_EVENTO = ("evento", "ate_evento", "olhar_para", "evento_alvo")


def criar_editor(proj, cl, campo, ctx):
    n = campo.nome
    t = campo.tipo
    if t == "bool":
        return EdBool(campo, ctx)
    if t == "int":
        return EdNum(campo, ctx, inteiro=True)
    if t == "float":
        return EdNum(campo, ctx)
    if t == "enum":
        return EdEnum(campo, ctx)
    if t == "Vector2":
        return EdVec2(campo, ctx)
    if t == "Color":
        return EdCor(campo, ctx)
    if t in ("String", "StringName"):
        if campo.dica == "multiline":
            return EdTexto(campo, ctx, multilinha=True)
        if campo.dica and campo.dica.startswith("file:"):
            ext = campo.dica[5:]
            if ext.endswith(".mp3"):
                ops = proj.audio.get("se", []) + proj.audio.get("bgm", []) + proj.audio.get("bgs", [])
            elif ext.endswith(".tscn"):
                ops = proj.mapas
            else:
                ops = []
            return EdTexto(campo, ctx, opcoes=ops)
        if n == "variavel":
            return EdTexto(campo, ctx, opcoes=sorted(proj.variaveis), dicas=proj.variaveis)
        if n in CAMPOS_EVENTO:
            return EdTexto(campo, ctx, opcoes=list(proj.ids_evento))
        if n == "label":
            return EdTexto(campo, ctx, opcoes=list(ctx.get("labels", [])))
        if n == "personalidade":
            return EdTexto(campo, ctx, opcoes=sorted(i["id"] for i in proj.personalidades.values()))
        if n == "face":
            return EdTexto(campo, ctx, opcoes=[])
        if n == "animacao":
            return EdTexto(campo, ctx, opcoes=list(ctx.get("anims", [])))
        return EdTexto(campo, ctx)
    if t == "Res":
        c = campo.classe
        if c == "Personagem":
            ops = [("%s  (%s)" % (k, f["nome"]) if f["nome"] else k, f["res"]) for k, f in proj.falantes.items()]
            return EdRef(campo, ctx, ops)
        if c == "ItemData":
            return EdRef(campo, ctx, [("%s  (%s)" % (i["id"], i["nome"]) if i["nome"] else i["id"], p) for p, i in proj.itens.items()])
        if c == "PersonalidadeData":
            return EdRef(campo, ctx, [(i["id"], p) for p, i in proj.personalidades.items()])
        if c == "EventoData":
            return EdRef(campo, ctx, [(os.path.splitext(os.path.basename(p))[0], proj.res(p)) for p in proj.eventos])
        if c == "SpriteFrames":
            return EdRef(campo, ctx, [(os.path.splitext(os.path.basename(p))[0], p) for p in proj.animacoes])
        sub = proj.por_nome.get(c)
        if sub:
            return EdSubRecurso(campo, ctx, sub)
        return None
    if t == "Array":
        e = campo.elem
        if e == "String":
            return EdListaTexto(campo, ctx)
        sub = proj.por_nome.get(e)
        if sub and e != "Comando":
            return EdListaRes(campo, ctx, sub, sub.caminho)
        return None
    return None


# ---------------------------------------------------------------------------
# Formulário genérico
# ---------------------------------------------------------------------------
class FormRecurso(QWidget):
    """Mostra os campos de uma classe para um ou vários recursos (iguais = valor, diferentes = "(vários)").
    on_mudou(nome, valor) é chamado quando o usuário muda um campo."""

    def __init__(self, proj, cl, alvos, ctx, on_mudou, pular=("comandos",), mostrar_todos=False):
        super().__init__()
        self.proj = proj
        self.cl = cl
        self.alvos = alvos
        self.ctx = dict(ctx)
        self.ctx["proj"] = proj
        self.on_mudou = on_mudou
        self.mostrar_todos = mostrar_todos
        self.eds = {}
        self.linhas = {}
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        grupos = {}
        especial_opcoes = cl.nome == "CmdMostrarOpcoes"
        form_atual = None
        for campo in cl.campos:
            if campo.nome in pular:
                continue
            if especial_opcoes and campo.nome == "labels":
                continue
            if especial_opcoes and campo.nome == "opcoes":
                ed = EdOpcoes(campo, self.ctx)
            else:
                ed = criar_editor(proj, cl, campo, self.ctx)
            if ed is None:
                continue
            g = campo.grupo or ""
            if g not in grupos:
                if g:
                    box = QGroupBox(g)
                    fl = QFormLayout(box)
                    lay.addWidget(box)
                else:
                    box = QWidget()
                    fl = QFormLayout(box)
                    fl.setContentsMargins(0, 0, 0, 0)
                    lay.addWidget(box)
                fl.setFieldGrowthPolicy(QFormLayout.AllNonFixedFieldsGrow)
                grupos[g] = fl
            fl = grupos[g]
            rot = QLabel(campo.nome.replace("_", " "))
            if campo.doc:
                rot.setToolTip(campo.doc)
                ed.w.setToolTip(campo.doc)
                rot.setText(rot.text() + " ⓘ")
            fl.addRow(rot, ed.w)
            self.linhas[campo.nome] = (fl, rot, ed.w)
            ed.on_mudou = self._mudou
            self.eds[campo.nome] = ed
        lay.addStretch(1)
        self.carregar()

    def valor_comum(self, campo):
        if campo.nome == "opcoes" and self.cl.nome == "CmdMostrarOpcoes":
            r = self.alvos[0]
            return ([str(x) for x in modelo.itens(r, "opcoes")], [str(x) for x in modelo.itens(r, "labels")])
        vals = [modelo.valor_campo(r, campo) for r in self.alvos]
        v0 = vals[0]
        for v in vals[1:]:
            if not tres.valores_iguais(v, v0):
                return MISTO
        return v0

    def carregar(self):
        for nome, ed in self.eds.items():
            campo = ed.campo
            ed.set(self.valor_comum(campo))
        self._faces()
        self.atualizar_visiveis()

    def _faces(self):
        ed = self.eds.get("face")
        if ed and "personagem" in self.eds:
            per = self.eds["personagem"].get()
            faces = []
            if isinstance(per, ExtRef):
                stem = os.path.splitext(os.path.basename(per.path))[0]
                faces = self.proj.falantes.get(stem, {}).get("faces", [])
            ed.trocar_opcoes(faces)

    def atualizar_visiveis(self):
        import esquema
        for nome, (fl, rot, w) in self.linhas.items():
            campo = self.cl.campo(nome)
            vis = True
            if not self.mostrar_todos and campo is not None:
                vis = all(esquema.visivel(self.cl, campo, r) for r in self.alvos)
            rot.setVisible(vis)
            w.setVisible(vis)

    def _mudou(self, ed):
        v = ed.get()
        if v is MISTO:
            return
        self.on_mudou(ed.campo.nome, v)
        if ed.campo.nome == "personagem":
            self._faces()
        if ed.campo.tipo == "enum":
            self.atualizar_visiveis()

    def foco_inicial(self):
        for n in ("texto", "pergunta", "nome", "label", "variavel", "segundos"):
            if n in self.eds and self.eds[n].w.isVisible():
                self.eds[n].w.setFocus()
                return


# ---------------------------------------------------------------------------
# Diálogo de edição de um recurso (comando, condição, passo de rota)
# ---------------------------------------------------------------------------
class DialogoRecurso(QDialog):
    def __init__(self, parent, proj, res, ctx, titulo="", extra_check=None):
        super().__init__(parent)
        self.proj = proj
        self.res = res
        self.cl = proj.classe_de(res)
        self.setWindowTitle(titulo or (modelo.nome_bonito(self.cl) if self.cl else "Editar"))
        self.resize(620, 300)
        v = QVBoxLayout(self)
        if self.cl and self.cl.descricao:
            prim = self.cl.descricao.split("\n")[0]
            d = QLabel(prim + ("  ⓘ" if "\n" in self.cl.descricao else ""))
            d.setWordWrap(True)
            d.setToolTip(self.cl.descricao)
            d.setStyleSheet("color:#666; font-size:9pt")
            v.addWidget(d)
        self.extra = None
        if self.cl is None:
            v.addWidget(QLabel("Script desconhecido: %s" % res.script))
            self.form = None
        else:
            scroll = QScrollArea()
            scroll.setWidgetResizable(True)
            scroll.setFrameShape(QFrame.NoFrame)
            self.form = FormRecurso(proj, self.cl, [res], ctx, self._mudou)
            scroll.setWidget(self.form)
            v.addWidget(scroll, 1)
            todos = QCheckBox("mostrar todos os campos")
            todos.toggled.connect(self._todos)
            if extra_check:
                self.extra = QCheckBox(extra_check)
                v.addWidget(self.extra)
            v.addWidget(todos)
        bb = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        bb.accepted.connect(self._ok)
        bb.rejected.connect(self.reject)
        v.addWidget(bb)
        QShortcut(QKeySequence("Ctrl+Return"), self, activated=self._ok)
        QShortcut(QKeySequence("Ctrl+Enter"), self, activated=self._ok)
        if self.form:
            QTimer.singleShot(0, self.form.foco_inicial)
            h = self.form.sizeHint().height() + 160
            self.resize(640, max(220, min(h, 760)))

    def _todos(self, on):
        self.form.mostrar_todos = on
        self.form.atualizar_visiveis()

    def _mudou(self, nome, valor):
        if nome == "opcoes" and self.cl.nome == "CmdMostrarOpcoes":
            ops, lbs = valor
            modelo.definir_lista(self.proj, self.res, "opcoes", ops, tipo_basico="String")
            modelo.definir_lista(self.proj, self.res, "labels", lbs, tipo_basico="String")
            return
        campo = self.cl.campo(nome)
        if campo and campo.tipo == "Array":
            if campo.elem == "String":
                modelo.definir_lista(self.proj, self.res, nome, valor, tipo_basico="String")
            else:
                sub = self.proj.por_nome.get(campo.elem)
                modelo.definir_lista(self.proj, self.res, nome, valor, script_elem=sub.caminho if sub else None)
            return
        modelo.definir(self.res, self.cl, nome, valor)

    def _ok(self):
        # garante que o campo com foco grave (editingFinished)
        w = self.focusWidget()
        if w:
            w.clearFocus()
        if self.form:
            for ed in self.form.eds.values():
                if isinstance(ed, EdTexto) and ed.multi and ed._timer.isActive():
                    ed._timer.stop()
                    ed.emitir()
        self.accept()

    def criar_labels(self):
        if self.form and "opcoes" in self.form.eds and isinstance(self.form.eds["opcoes"], EdOpcoes):
            return self.form.eds["opcoes"].criar_labels.isChecked()
        return False


def editar_recurso(parent, proj, res, ctx, titulo=""):
    d = DialogoRecurso(parent, proj, res, ctx, titulo)
    return d.exec() == QDialog.Accepted


# ---------------------------------------------------------------------------
# Escolher o tipo de comando (com busca)
# ---------------------------------------------------------------------------
class SeletorComando(QDialog):
    def __init__(self, parent, proj):
        super().__init__(parent)
        self.setWindowTitle("Inserir comando")
        self.resize(460, 560)
        self.proj = proj
        self.escolhido = None
        v = QVBoxLayout(self)
        self.busca = QLineEdit()
        self.busca.setPlaceholderText("digite para filtrar (ex.: msg, var, mover)  ·  Enter insere")
        v.addWidget(self.busca)
        self.lista = QListWidget()
        v.addWidget(self.lista, 1)
        self.desc = QLabel("")
        self.desc.setWordWrap(True)
        self.desc.setStyleSheet("color:#555")
        self.desc.setMinimumHeight(60)
        v.addWidget(self.desc)
        self.busca.textChanged.connect(self._filtrar)
        self.lista.itemDoubleClicked.connect(lambda *_: self._ok())
        self.lista.currentItemChanged.connect(self._desc)
        self.busca.returnPressed.connect(self._ok)
        self.busca.installEventFilter(self)
        self._filtrar("")

    def eventFilter(self, obj, e):
        if obj is self.busca and e.type() == QEvent.Type.KeyPress and e.key() in (Qt.Key_Down, Qt.Key_Up):
            self.lista.setFocus()
            self.lista.keyPressEvent(e)
            return True
        return super().eventFilter(obj, e)

    def _filtrar(self, txt):
        txt = txt.lower().strip()
        self.lista.clear()
        cat_atual = None
        for cl in self.proj.comandos:
            nome = modelo.nome_bonito(cl)
            arq = os.path.basename(cl.arquivo)
            if txt and txt not in nome.lower() and txt not in arq.lower() and txt not in cl.descricao.lower():
                continue
            cat = modelo.categoria(cl.nome)
            if cat != cat_atual and not txt:
                cab = QListWidgetItem(modelo.NOME_CATEGORIA.get(cat, cat).upper())
                cab.setFlags(Qt.NoItemFlags)
                cab.setForeground(QColor(CORES.get(cat, "#555")))
                f = cab.font()
                f.setBold(True)
                cab.setFont(f)
                self.lista.addItem(cab)
                cat_atual = cat
            it = QListWidgetItem("   " + nome)
            it.setData(Qt.UserRole, cl.caminho)
            it.setForeground(QColor(CORES.get(cat, "#555")))
            self.lista.addItem(it)
        for i in range(self.lista.count()):
            if self.lista.item(i).data(Qt.UserRole):
                self.lista.setCurrentRow(i)
                break

    def _desc(self, it, *_):
        if it and it.data(Qt.UserRole):
            cl = self.proj.classes.get(it.data(Qt.UserRole))
            self.desc.setText(cl.descricao if cl else "")

    def _ok(self):
        it = self.lista.currentItem()
        if it and it.data(Qt.UserRole):
            self.escolhido = it.data(Qt.UserRole)
            self.accept()


# ---------------------------------------------------------------------------
# Diálogo como texto
# ---------------------------------------------------------------------------
class RealceDialogo(QSyntaxHighlighter):
    def __init__(self, doc):
        super().__init__(doc)
        self.f_cab = QTextCharFormat()
        self.f_cab.setForeground(QColor("#2563c9"))
        self.f_cab.setFontWeight(QFont.Bold)
        self.f_cmd = QTextCharFormat()
        self.f_cmd.setForeground(QColor("#999999"))
        self.f_cmd.setFontItalic(True)
        self.f_esc = QTextCharFormat()
        self.f_esc.setForeground(QColor("#b85c00"))
        self.f_tag = QTextCharFormat()
        self.f_tag.setForeground(QColor("#8b3fc0"))

    def highlightBlock(self, t):
        import re
        if t.startswith("@"):
            self.setFormat(0, len(t), self.f_cab)
        elif t.startswith("[["):
            self.setFormat(0, len(t), self.f_cmd)
        elif t.startswith("\\"):
            self.setFormat(0, 1, self.f_esc)
        else:
            for m in re.finditer(r"\[/?[a-z_]+(=[^\]]*)?\]", t):
                self.setFormat(m.start(), m.end() - m.start(), self.f_tag)


AJUDA_DIALOGO = (
    "<b>@falante</b> muda quem fala (arquivo em dados/falantes) · <b>@falante:face 100</b> com face e posição · "
    "<b>@-</b> sem nome.<br>Linha em branco separa as falas; linhas seguidas viram quebra de linha na mesma fala. "
    "Fala sem @ antes usa quem falou por último.<br><b>[[n]]</b> = comando que não é fala: pode mover ou apagar a linha, "
    "não edite o texto dela. Linha que começa com @ ou [[ no texto: ponha \\ antes. Linha só com \\ = linha vazia na fala."
)


class DialogoTexto(QDialog):
    def __init__(self, parent, proj, texto, titulo):
        super().__init__(parent)
        self.setWindowTitle(titulo)
        self.resize(820, 680)
        self.proj = proj
        v = QVBoxLayout(self)
        aj = QLabel(AJUDA_DIALOGO)
        aj.setWordWrap(True)
        aj.setStyleSheet("color:#555; font-size:9pt")
        v.addWidget(aj)
        h = QHBoxLayout()
        h.addWidget(QLabel("Inserir falante:"))
        self.cb = Combo()
        self.cb.addItem("-")
        for k, f in proj.falantes.items():
            self.cb.addItem(k)
        h.addWidget(self.cb)
        b = QPushButton("inserir @ na linha")
        b.clicked.connect(self._inserir)
        h.addWidget(b)
        h.addStretch(1)
        v.addLayout(h)
        self.ed = QPlainTextEdit()
        self.ed.setFont(fonte_mono(11))
        self.ed.setPlainText(texto)
        self.ed.setLineWrapMode(QPlainTextEdit.WidgetWidth)
        self.realce = RealceDialogo(self.ed.document())
        v.addWidget(self.ed, 1)
        self.erro = QLabel("")
        self.erro.setStyleSheet("color:#b00")
        v.addWidget(self.erro)
        bb = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        bb.accepted.connect(self.accept)
        bb.rejected.connect(self.reject)
        v.addWidget(bb)
        QShortcut(QKeySequence("Ctrl+Return"), self, activated=self.accept)
        QShortcut(QKeySequence("Ctrl+S"), self, activated=self.accept)

    def _inserir(self):
        c = self.ed.textCursor()
        c.movePosition(QTextCursor.StartOfBlock)
        c.insertText("@" + self.cb.currentText() + "\n")
        self.ed.setFocus()

    def texto(self):
        return self.ed.toPlainText()


# ---------------------------------------------------------------------------
# Busca em todos os eventos
# ---------------------------------------------------------------------------
class DialogoBusca(QDialog):
    ir_para = Signal(str, int, int)        # caminho, página, comando (-1 = só a página)

    def __init__(self, parent, janela):
        super().__init__(parent)
        self.janela = janela
        self.setWindowTitle("Buscar em todos os eventos")
        self.resize(900, 560)
        v = QVBoxLayout(self)
        h = QHBoxLayout()
        self.q = QLineEdit()
        self.q.setPlaceholderText("texto, variável, label, falante...")
        self.q.returnPressed.connect(self.buscar)
        h.addWidget(self.q, 1)
        self.maius = QCheckBox("Aa")
        self.maius.setToolTip("diferenciar maiúsculas")
        h.addWidget(self.maius)
        self.exato = QCheckBox("campo inteiro")
        self.exato.setToolTip("o campo tem que ser exatamente isso (bom para nome de variável/label)")
        h.addWidget(self.exato)
        b = QPushButton("Buscar")
        b.clicked.connect(self.buscar)
        h.addWidget(b)
        v.addLayout(h)
        h2 = QHBoxLayout()
        self.rep = QLineEdit()
        self.rep.setPlaceholderText("substituir por...")
        h2.addWidget(self.rep, 1)
        b2 = QPushButton("Substituir nos marcados")
        b2.clicked.connect(self.substituir)
        h2.addWidget(b2)
        v.addLayout(h2)
        self.res = QTreeWidget()
        self.res.setHeaderLabels(["evento", "pág.", "cmd", "campo", "texto"])
        self.res.setRootIsDecorated(False)
        self.res.header().setSectionResizeMode(4, QHeaderView.Stretch)
        self.res.itemDoubleClicked.connect(self._ir)
        v.addWidget(self.res, 1)
        self.info = QLabel("")
        v.addWidget(self.info)

    def _casa(self, s, q):
        if not self.maius.isChecked():
            s, q = s.lower(), q.lower()
        return s == q if self.exato.isChecked() else q in s

    def buscar(self):
        q = self.q.text()
        self.res.clear()
        if not q:
            return
        n = 0
        proj = self.janela.proj
        for caminho in proj.eventos:
            doc = self.janela.doc(caminho)
            if doc is None:
                continue
            for pi, pag in enumerate(doc.paginas):
                for campo, s in modelo.textos_de(pag):
                    if campo.startswith("comandos"):
                        continue
                    if self._casa(s, q):
                        self._add(doc, pi, -1, campo, s)
                        n += 1
                for ci, c in enumerate(modelo.itens(pag, "comandos")):
                    for campo, s in modelo.textos_de(c):
                        if self._casa(s, q):
                            self._add(doc, pi, ci, campo, s)
                            n += 1
        self.info.setText("%d resultado(s). Duplo clique abre. Marque para substituir." % n)

    def _add(self, doc, pi, ci, campo, s):
        it = QTreeWidgetItem([doc.nome, str(pi + 1), "" if ci < 0 else str(ci + 1), campo, s.replace("\n", " / ")])
        it.setData(0, Qt.UserRole, (doc.caminho, pi, ci, campo))
        it.setFlags(it.flags() | Qt.ItemIsUserCheckable)
        it.setCheckState(0, Qt.Unchecked)
        self.res.addTopLevelItem(it)

    def _ir(self, it, *_):
        caminho, pi, ci, _c = it.data(0, Qt.UserRole)
        self.ir_para.emit(caminho, pi, ci)

    def substituir(self):
        q, novo = self.q.text(), self.rep.text()
        marcados = [self.res.topLevelItem(i) for i in range(self.res.topLevelItemCount())
                    if self.res.topLevelItem(i).checkState(0) == Qt.Checked]
        if not q or not marcados:
            QMessageBox.information(self, "Substituir", "Busque e marque os resultados que quer trocar.")
            return
        por_doc = {}
        for it in marcados:
            caminho, pi, ci, campo = it.data(0, Qt.UserRole)
            por_doc.setdefault(caminho, []).append((pi, ci, campo))
        docs = [self.janela.doc(c) for c in por_doc]
        trocas = [0]

        def fazer():
            for caminho, lista in por_doc.items():
                doc = self.janela.doc(caminho)
                for pi, ci, campo in lista:
                    alvo = doc.paginas[pi] if ci < 0 else modelo.itens(doc.paginas[pi], "comandos")[ci]
                    trocas[0] += _substituir_campo(alvo, campo if ci >= 0 else campo, q, novo, self.maius.isChecked(), self.exato.isChecked())
        self.janela.mudar(docs, fazer)
        self.info.setText("%d campo(s) trocado(s). Ainda não salvo (Ctrl+S)." % trocas[0])
        self.buscar()


def _substituir_campo(res, caminho, q, novo, maius, exato):
    """caminho: "texto", "condicao.variavel", "opcoes[1]"..."""
    import re
    partes = re.findall(r"[^.\[\]]+|\[\d+\]", caminho)
    obj = res
    for p in partes[:-1]:
        if p.startswith("["):
            obj = (obj.itens if isinstance(obj, TypedArray) else obj)[int(p[1:-1])]
        else:
            obj = obj.props[p]
    ult = partes[-1]
    if ult.startswith("["):
        cont = obj.itens if isinstance(obj, TypedArray) else obj
        idx = int(ult[1:-1])
        atual = cont[idx]
    else:
        cont = obj.props
        idx = ult
        atual = cont[idx]
    if isinstance(atual, ExtRef) or not isinstance(atual, str):
        return 0
    if exato:
        ok = atual == q if maius else atual.lower() == q.lower()
        if not ok:
            return 0
        cont[idx] = type(atual)(novo) if type(atual) is not str else novo
        return 1
    flags = 0 if maius else re.IGNORECASE
    s2 = re.sub(re.escape(q), lambda m: novo, atual, flags=flags)
    if s2 != atual:
        cont[idx] = s2
        return 1
    return 0
