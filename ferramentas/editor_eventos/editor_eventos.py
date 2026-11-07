#!/usr/bin/env python3
# editor_eventos.py - editor visual dos eventos (dados/eventos/*.tres) do bruxa_alfa.
#
#   python editor_eventos.py            (precisa de: pip install PySide6)
#
# Lê os scripts do jogo (src/dados/...) para saber os comandos e campos, então um
# comando novo no jogo aparece aqui sozinho. Salva os .tres no formato do Godot,
# com backup em backup/ (nesta pasta) a cada vez que salva.

import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

try:
    from PySide6.QtCore import Qt, QTimer, QEvent, QSize, QItemSelectionModel
    from PySide6.QtGui import QAction, QColor, QBrush, QKeySequence, QFont, QShortcut, QGuiApplication
    from PySide6.QtWidgets import (
        QAbstractItemView, QApplication, QFileDialog, QHBoxLayout, QInputDialog, QLabel, QLineEdit,
        QListWidget, QListWidgetItem, QMainWindow, QMenu, QMessageBox, QPushButton, QScrollArea,
        QSplitter, QStyleFactory, QToolButton, QVBoxLayout, QWidget, QFrame, QDialog,
    )
except ImportError:
    print("Este editor precisa do PySide6.  Instale com:\n\n    pip install PySide6\n")
    input("Enter para sair...")
    sys.exit(1)

import modelo
import tres
import widgets
from modelo import itens
from tres import Res, ExtRef
from widgets import CORES, fonte_mono

CLIP = {"tipo": None, "itens": []}
TITULO = "Editor de eventos"


def achar_projeto():
    p = AQUI
    for _ in range(6):
        if os.path.exists(os.path.join(p, "project.godot")):
            return p
        p = os.path.dirname(p)
    return None


# ---------------------------------------------------------------------------
# Lista de comandos (arrastar para reordenar)
# ---------------------------------------------------------------------------
class ListaComandos(QListWidget):
    def __init__(self, janela):
        super().__init__()
        self.janela = janela
        self.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.setDragDropMode(QAbstractItemView.InternalMove)
        self.setDefaultDropAction(Qt.MoveAction)
        self.setFont(fonte_mono(10))
        self.setUniformItemSizes(True)
        self.setAlternatingRowColors(True)

    def dropEvent(self, e):
        alvo = self.indexAt(e.position().toPoint()).row()
        pos = self.dropIndicatorPosition()
        if alvo < 0:
            alvo = self.count() - 1
        elif pos == QAbstractItemView.BelowItem:
            alvo += 1
        e.ignore()
        e.setDropAction(Qt.IgnoreAction)
        self.janela.arrastar_comandos(alvo)

    def keyPressEvent(self, e):
        if self.janela.tecla_comandos(e):
            return
        super().keyPressEvent(e)


class ListaPaginas(QListWidget):
    def __init__(self, janela):
        super().__init__()
        self.janela = janela
        self.setSelectionMode(QAbstractItemView.ExtendedSelection)

    def keyPressEvent(self, e):
        if self.janela.tecla_paginas(e):
            return
        super().keyPressEvent(e)


def botao(txt, dica, fn, largura=None):
    b = QToolButton()
    b.setText(txt)
    b.setToolTip(dica)
    b.setAutoRaise(True)
    b.clicked.connect(fn)
    if largura:
        b.setMinimumWidth(largura)
    return b


# ---------------------------------------------------------------------------
# Janela principal
# ---------------------------------------------------------------------------
class Janela(QMainWindow):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        self.proj = modelo.Projeto(raiz)
        self.docs = {}                 # caminho -> EventoDoc
        self.hist = []                 # [[docs]] ações para desfazer
        self.hist_refazer = []
        self.cfg = self._ler_cfg()
        self._montar()
        self.atualizar_eventos()
        ult = self.cfg.get("ultimo_evento")
        if ult:
            self.selecionar_evento(os.path.join(self.raiz, *ult.split("/")))
        self._restaurar_layout()
        self.atualizar_titulo()

    # ------------------------------------------------------------ config
    def _ler_cfg(self):
        try:
            with open(os.path.join(AQUI, "config.json"), encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}

    def _gravar_cfg(self):
        self.cfg["geometria"] = bytes(self.saveGeometry().toHex()).decode()
        self.cfg["split"] = self.split.sizes()
        self.cfg["split_meio"] = self.split_meio.sizes()
        cam = self.evento_atual()
        if cam:
            self.cfg["ultimo_evento"] = os.path.relpath(cam, self.raiz).replace(os.sep, "/")
        try:
            with open(os.path.join(AQUI, "config.json"), "w", encoding="utf-8") as f:
                json.dump(self.cfg, f, indent=1)
        except Exception:
            pass

    def _restaurar_layout(self):
        from PySide6.QtCore import QByteArray
        if self.cfg.get("geometria"):
            self.restoreGeometry(QByteArray.fromHex(self.cfg["geometria"].encode()))
        else:
            self.resize(1500, 900)
        if self.cfg.get("split"):
            self.split.setSizes(self.cfg["split"])
        if self.cfg.get("split_meio"):
            self.split_meio.setSizes(self.cfg["split_meio"])

    # ------------------------------------------------------------ montagem
    def _montar(self):
        self.split = QSplitter(Qt.Horizontal)
        self.setCentralWidget(self.split)

        # --- eventos
        w = QWidget()
        v = QVBoxLayout(w)
        v.setContentsMargins(4, 4, 4, 4)
        v.addWidget(QLabel("<b>Eventos</b>"))
        self.filtro = QLineEdit()
        self.filtro.setPlaceholderText("filtrar...")
        self.filtro.textChanged.connect(self.atualizar_eventos)
        v.addWidget(self.filtro)
        self.lista_ev = QListWidget()
        self.lista_ev.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.lista_ev.itemSelectionChanged.connect(self._ev_sel)
        self.lista_ev.setToolTip("Ctrl/Shift + clique: várias. As páginas de todos aparecem juntas (edição em lote).")
        v.addWidget(self.lista_ev, 1)
        h = QHBoxLayout()
        h.addWidget(botao("+ novo", "Novo evento", self.novo_evento))
        h.addWidget(botao("duplicar", "Duplicar evento (arquivo novo)", self.duplicar_evento))
        h.addStretch(1)
        v.addLayout(h)
        self.split.addWidget(w)

        # --- páginas + formulário
        self.split_meio = QSplitter(Qt.Vertical)
        w = QWidget()
        v = QVBoxLayout(w)
        v.setContentsMargins(4, 4, 4, 4)
        h = QHBoxLayout()
        self.rot_pag = QLabel("<b>Páginas</b>")
        h.addWidget(self.rot_pag)
        h.addStretch(1)
        h.addWidget(botao("+", "Nova página (no fim)", self.nova_pagina))
        h.addWidget(botao("⧉", "Duplicar páginas (Ctrl+D)", self.duplicar_paginas))
        h.addWidget(botao("✕", "Apagar páginas (Del)", self.apagar_paginas))
        h.addWidget(botao("↑", "Subir (Alt+↑)", lambda: self.mover_paginas(-1)))
        h.addWidget(botao("↓", "Descer (Alt+↓)", lambda: self.mover_paginas(1)))
        v.addLayout(h)
        self.lista_pag = ListaPaginas(self)
        self.lista_pag.itemSelectionChanged.connect(self._pag_sel)
        self.lista_pag.setToolTip("Vale a ÚLTIMA página com todas as condições verdadeiras.\n"
                                  "Selecione várias para mudar um campo em todas.\nCtrl+C / Ctrl+V copiam páginas entre eventos.")
        v.addWidget(self.lista_pag, 1)
        self.split_meio.addWidget(w)
        self.scroll_form = QScrollArea()
        self.scroll_form.setWidgetResizable(True)
        self.scroll_form.setFrameShape(QFrame.NoFrame)
        self.split_meio.addWidget(self.scroll_form)
        self.split_meio.setSizes([260, 600])
        self.split.addWidget(self.split_meio)

        # --- comandos
        w = QWidget()
        v = QVBoxLayout(w)
        v.setContentsMargins(4, 4, 4, 4)
        h = QHBoxLayout()
        self.rot_cmd = QLabel("<b>Comandos</b>")
        h.addWidget(self.rot_cmd)
        h.addStretch(1)
        h.addWidget(botao("+ inserir", "Inserir comando (Insert ou Enter na última linha)", self.inserir))
        h.addWidget(botao("+ fala", "Nova fala com o mesmo falante da anterior (Ctrl+M)", self.nova_fala))
        h.addWidget(botao("editar", "Editar (Enter / duplo clique)", self.editar))
        h.addWidget(botao("✕", "Apagar (Del)", self.apagar))
        h.addWidget(botao("↑", "Subir (Alt+↑)", lambda: self.mover(-1)))
        h.addWidget(botao("↓", "Descer (Alt+↓)", lambda: self.mover(1)))
        h.addWidget(botao("bloco", "Selecionar o bloco inteiro (Se ... Fim) (Ctrl+B)", self.selecionar_bloco))
        h.addWidget(botao("→ label", "Ir para o label do 'ir para'/opções, ou achar quem usa o label (F12)", self.ir_label))
        h.addWidget(botao("diálogo em texto", "Editar as falas selecionadas (ou a página toda) como texto (Ctrl+T)", self.dialogo_texto))
        v.addLayout(h)
        self.lista_cmd = ListaComandos(self)
        self.lista_cmd.itemDoubleClicked.connect(lambda *_: self.editar())
        self.lista_cmd.currentRowChanged.connect(self._realcar_bloco)
        self.lista_cmd.setContextMenuPolicy(Qt.CustomContextMenu)
        self.lista_cmd.customContextMenuRequested.connect(self._menu_cmd)
        v.addWidget(self.lista_cmd, 1)
        self.info_cmd = QLabel("")
        self.info_cmd.setStyleSheet("color:#666")
        v.addWidget(self.info_cmd)
        self.split.addWidget(w)
        self.split.setSizes([240, 520, 900])

        # --- menus e atalhos
        mb = self.menuBar()
        m = mb.addMenu("&Arquivo")
        self._acao(m, "Salvar tudo", "Ctrl+S", self.salvar)
        self._acao(m, "Recarregar (scripts e arquivos)", "F5", self.recarregar)
        m.addSeparator()
        self._acao(m, "Abrir pasta de backups", None, lambda: self._abrir_pasta(os.path.join(AQUI, "backup")))
        self._acao(m, "Trocar projeto...", None, self.trocar_projeto)
        m = mb.addMenu("&Editar")
        self._acao(m, "Desfazer", "Ctrl+Z", self.desfazer)
        self._acao(m, "Refazer", "Ctrl+Y", self.refazer)
        self._acao(m, "Refazer", "Ctrl+Shift+Z", self.refazer, no_menu=True)
        m.addSeparator()
        self._acao(m, "Buscar / substituir em todos os eventos", "Ctrl+Shift+F", self.buscar)
        m = mb.addMenu("A&juda")
        self._acao(m, "Atalhos", "F1", self.ajuda)
        self.statusBar().showMessage("F1 = atalhos")

    def _acao(self, menu, txt, atalho, fn, no_menu=False):
        a = QAction(txt, self)
        if atalho:
            a.setShortcut(QKeySequence(atalho))
        a.triggered.connect(fn)
        self.addAction(a)
        if not no_menu:
            menu.addAction(a)
        return a

    def _abrir_pasta(self, p):
        os.makedirs(p, exist_ok=True)
        from PySide6.QtGui import QDesktopServices
        from PySide6.QtCore import QUrl
        QDesktopServices.openUrl(QUrl.fromLocalFile(p))

    # ------------------------------------------------------------ documentos
    def doc(self, caminho):
        d = self.docs.get(caminho)
        if d is None:
            try:
                d = modelo.EventoDoc(self.proj, caminho)
            except Exception as e:
                self.statusBar().showMessage("Erro lendo %s: %s" % (os.path.basename(caminho), e))
                return None
            self.docs[caminho] = d
        return d

    def mudar(self, docs, fn):
        """Toda mudança passa por aqui (desfazer em grupo)."""
        docs = [d for d in docs if d is not None]
        docs = list({id(d): d for d in docs}.values())
        for d in docs:
            d.antes_de_mudar()
        try:
            fn()
        except Exception as e:
            for d in docs:
                d.desfazer()
                d.refazer_pilha.clear()
            QMessageBox.warning(self, "Erro", "Não deu para fazer isso:\n%s" % e)
            return False
        self.hist.append(docs)
        self.hist_refazer.clear()
        self.atualizar_titulo()
        return True

    def desfazer(self):
        if self._foco_em_texto():
            return
        while self.hist:
            docs = self.hist.pop()
            ok = [d for d in docs if d.desfazer()]
            if ok:
                self.hist_refazer.append(ok)
                self.atualizar_tudo()
                self.statusBar().showMessage("Desfeito", 2000)
                return

    def refazer(self):
        if self._foco_em_texto():
            return
        while self.hist_refazer:
            docs = self.hist_refazer.pop()
            ok = [d for d in docs if d.refazer()]
            if ok:
                self.hist.append(ok)
                self.atualizar_tudo()
                self.statusBar().showMessage("Refeito", 2000)
                return

    def _foco_em_texto(self):
        w = QApplication.focusWidget()
        from PySide6.QtWidgets import QPlainTextEdit, QLineEdit as QL, QAbstractSpinBox
        if isinstance(w, (QPlainTextEdit, QL, QAbstractSpinBox)) and w.window() is self:
            return True    # o Ctrl+Z é do próprio campo
        return False

    def atualizar_titulo(self):
        n = sum(1 for d in self.docs.values() if d.modificado)
        self.setWindowTitle("%s  ·  %s%s" % (TITULO, os.path.basename(self.raiz), ("  ·  %d não salvo(s)" % n) if n else ""))
        for i in range(self.lista_ev.count()):
            it = self.lista_ev.item(i)
            cam = it.data(Qt.UserRole)
            d = self.docs.get(cam)
            nome = os.path.splitext(os.path.relpath(cam, os.path.join(self.raiz, "dados", "eventos")))[0].replace(os.sep, "/")
            it.setText(("● " if d and d.modificado else "   ") + nome)

    # ------------------------------------------------------------ seleção
    def eventos_sel(self):
        return [it.data(Qt.UserRole) for it in self.lista_ev.selectedItems()]

    def evento_atual(self):
        s = self.eventos_sel()
        return s[0] if len(s) == 1 else None

    def paginas_sel(self):
        """[(doc, índice)] na ordem da lista."""
        out = []
        for it in sorted(self.lista_pag.selectedItems(), key=lambda it: self.lista_pag.row(it)):
            cam, i = it.data(Qt.UserRole)
            d = self.doc(cam)
            if d and i < len(d.paginas):
                out.append((d, i))
        return out

    def pag_atual(self):
        s = self.paginas_sel()
        if len(s) != 1:
            return None
        d, i = s[0]
        return d, i, d.paginas[i]

    def cmds_atuais(self):
        p = self.pag_atual()
        if not p:
            return None, None, None
        d, i, pag = p
        v = pag.props.get("comandos")
        if not isinstance(v, tres.TypedArray):
            v = self.proj.array_tipado(modelo.SCRIPT_COMANDO, list(v) if isinstance(v, list) else [])
            pag.props["comandos"] = v
        return d, pag, v.itens

    def linhas_sel(self):
        n = self.lista_cmd.count() - 1
        return sorted(r for r in (self.lista_cmd.row(it) for it in self.lista_cmd.selectedItems()) if 0 <= r < n)

    # ------------------------------------------------------------ eventos
    def atualizar_eventos(self):
        sel = set(self.eventos_sel())
        f = self.filtro.text().lower()
        self.lista_ev.blockSignals(True)
        self.lista_ev.clear()
        base = os.path.join(self.raiz, "dados", "eventos")
        for cam in self.proj.eventos:
            nome = os.path.splitext(os.path.relpath(cam, base))[0].replace(os.sep, "/")
            if f and f not in nome.lower():
                continue
            it = QListWidgetItem(nome)
            it.setData(Qt.UserRole, cam)
            self.lista_ev.addItem(it)
            if cam in sel:
                it.setSelected(True)
        self.lista_ev.blockSignals(False)
        self.atualizar_titulo()

    def selecionar_evento(self, cam, pag=None, cmd=None):
        if self.filtro.text() and not any(self.lista_ev.item(i).data(Qt.UserRole) == cam for i in range(self.lista_ev.count())):
            self.filtro.setText("")
        for i in range(self.lista_ev.count()):
            it = self.lista_ev.item(i)
            if it.data(Qt.UserRole) == cam:
                self.lista_ev.setCurrentItem(it)
                self.lista_ev.scrollToItem(it)
                break
        if pag is not None and 0 <= pag < self.lista_pag.count():
            self.lista_pag.setCurrentRow(pag, QItemSelectionModel.ClearAndSelect)
            if cmd is not None and cmd >= 0 and cmd < self.lista_cmd.count():
                self.lista_cmd.setCurrentRow(cmd, QItemSelectionModel.ClearAndSelect)
                self.lista_cmd.scrollToItem(self.lista_cmd.item(cmd), QAbstractItemView.PositionAtCenter)
                self.lista_cmd.setFocus()

    def _ev_sel(self):
        self.atualizar_paginas(sel=[0])

    def novo_evento(self):
        nome, ok = QInputDialog.getText(self, "Novo evento", "Nome do arquivo (sem .tres), ex.: cidadeA_npc4:")
        nome = nome.strip()
        if not ok or not nome:
            return
        cam = os.path.join(self.raiz, "dados", "eventos", nome + ".tres")
        if os.path.exists(cam):
            QMessageBox.warning(self, "Novo evento", "Já existe.")
            return
        modelo.EventoDoc.criar(self.proj, cam, nome)
        self.proj.indexar()
        self.atualizar_eventos()
        self.selecionar_evento(cam)
        self.statusBar().showMessage("Criado %s. Ponha no mapa com um nó EventoBase apontando para ele." % nome, 8000)

    def duplicar_evento(self):
        cam = self.evento_atual()
        if not cam:
            return
        d = self.doc(cam)
        nome, ok = QInputDialog.getText(self, "Duplicar evento", "Nome do novo arquivo:", text=d.nome + "_copia")
        nome = nome.strip()
        if not ok or not nome:
            return
        novo = os.path.join(os.path.dirname(cam), nome + ".tres")
        if os.path.exists(novo):
            QMessageBox.warning(self, "Duplicar", "Já existe.")
            return
        doc = tres.TresDoc.loads(d.doc.dumps())
        doc.cab.pop("uid", None)          # o Godot dá um uid novo
        doc.root.props["id"] = nome
        doc.save(novo)
        self.proj.indexar()
        self.atualizar_eventos()
        self.selecionar_evento(novo)

    # ------------------------------------------------------------ páginas
    def atualizar_paginas(self, sel=None):
        """sel: índices (um evento) ou [(cam, i)]."""
        evs = self.eventos_sel()
        varios = len(evs) > 1
        if sel is None:
            sel = [(d.caminho, i) for d, i in self.paginas_sel()]
        self.lista_pag.blockSignals(True)
        self.lista_pag.clear()
        for cam in evs:
            d = self.doc(cam)
            if d is None:
                continue
            for i, pag in enumerate(d.paginas):
                txt = modelo.resumo_pagina(self.proj, pag, i)
                it = QListWidgetItem((d.nome + ":  " if varios else "") + txt)
                it.setData(Qt.UserRole, (cam, i))
                it.setToolTip("\n".join(["Condições:"] + ["  " + modelo.texto_condicao(self.proj, c) for c in itens(pag, "condicoes")] or ["sempre"]))
                self.lista_pag.addItem(it)
                if (cam, i) in sel or (not varios and i in sel and isinstance(i, int)):
                    it.setSelected(True)
                    self.lista_pag.setCurrentItem(it, QItemSelectionModel.NoUpdate)
        self.lista_pag.blockSignals(False)
        self.rot_pag.setText("<b>Páginas</b>" + (" de %d eventos (lote)" % len(evs) if varios else ""))
        self._pag_sel()

    def atualizar_textos_paginas(self):
        varios = len(self.eventos_sel()) > 1
        for r in range(self.lista_pag.count()):
            it = self.lista_pag.item(r)
            cam, i = it.data(Qt.UserRole)
            d = self.doc(cam)
            if d and i < len(d.paginas):
                it.setText((d.nome + ":  " if varios else "") + modelo.resumo_pagina(self.proj, d.paginas[i], i))

    def _pag_sel(self):
        self.montar_form()
        self.atualizar_comandos(sel=[])

    def montar_form(self):
        sel = self.paginas_sel()
        old = self.scroll_form.takeWidget()
        if old:
            old.deleteLater()
        if not sel:
            self.scroll_form.setWidget(QLabel("  (selecione uma ou mais páginas)"))
            return
        cl = self.proj.classes.get(modelo.SCRIPT_PAGINA)
        alvos = [d.paginas[i] for d, i in sel]
        anims = []
        spr = alvos[0].get("sprite_frames")
        if isinstance(spr, ExtRef):
            anims = self.proj.animacoes.get(spr.path, [])
        ctx = {"anims": anims, "labels": []}
        w = QWidget()
        v = QVBoxLayout(w)
        v.setContentsMargins(4, 4, 4, 4)
        tit = QLabel("<b>%s</b>" % ("Página %d" % (sel[0][1] + 1) if len(sel) == 1 else "%d páginas (mudança vale para todas)" % len(sel)))
        v.addWidget(tit)
        self.form_pag = widgets.FormRecurso(self.proj, cl, alvos, ctx, self._pagina_mudou)
        v.addWidget(self.form_pag)
        self.scroll_form.setWidget(w)

    def _pagina_mudou(self, nome, valor):
        sel = self.paginas_sel()
        cl = self.proj.classes.get(modelo.SCRIPT_PAGINA)
        campo = cl.campo(nome)

        def fazer():
            for k, (d, i) in enumerate(sel):
                pag = d.paginas[i]
                v = valor
                if campo and campo.tipo == "Array":
                    lista = list(valor) if k == 0 else [tres.copiar_profundo(x) for x in valor]
                    sub = self.proj.por_nome.get(campo.elem)
                    modelo.definir_lista(self.proj, pag, nome, lista, script_elem=sub.caminho if sub else None,
                                         tipo_basico="String" if campo.elem == "String" else None)
                else:
                    modelo.definir(pag, cl, nome, v)
        self.mudar([d for d, _ in sel], fazer)
        self.atualizar_textos_paginas()
        if nome == "sprite_frames":
            QTimer.singleShot(0, self.montar_form)

    def tecla_paginas(self, e):
        k, m = e.key(), e.modifiers()
        if k == Qt.Key_Delete:
            self.apagar_paginas()
        elif m & Qt.ControlModifier and k == Qt.Key_C:
            self.copiar_paginas()
        elif m & Qt.ControlModifier and k == Qt.Key_V:
            self.colar_paginas()
        elif m & Qt.ControlModifier and k == Qt.Key_D:
            self.duplicar_paginas()
        elif m & Qt.AltModifier and k in (Qt.Key_Up, Qt.Key_Down):
            self.mover_paginas(-1 if k == Qt.Key_Up else 1)
        elif k in (Qt.Key_Return, Qt.Key_Enter, Qt.Key_Right):
            self.lista_cmd.setFocus()
            if self.lista_cmd.currentRow() < 0:
                self.lista_cmd.setCurrentRow(0)
        else:
            return False
        return True

    def _um_evento(self):
        cam = self.evento_atual()
        if not cam:
            self.statusBar().showMessage("Selecione só um evento para isso.", 4000)
        return self.doc(cam) if cam else None

    def nova_pagina(self):
        d = self._um_evento()
        if not d:
            return
        self.mudar([d], lambda: d.paginas.append(self.proj.nova_pagina()))
        self.atualizar_paginas(sel=[len(d.paginas) - 1])

    def duplicar_paginas(self):
        sel = self.paginas_sel()
        if not sel or len({id(d) for d, _ in sel}) != 1:
            return
        d = sel[0][0]
        idxs = [i for _, i in sel]

        def fazer():
            copias = [tres.copiar_profundo(d.paginas[i]) for i in idxs]
            pos = max(idxs) + 1
            d.paginas[pos:pos] = copias
        self.mudar([d], fazer)
        self.atualizar_paginas(sel=list(range(max(idxs) + 1, max(idxs) + 1 + len(idxs))))

    def apagar_paginas(self):
        sel = self.paginas_sel()
        if not sel:
            return
        if QMessageBox.question(self, "Apagar páginas", "Apagar %d página(s)?" % len(sel)) != QMessageBox.Yes:
            return
        docs = [d for d, _ in sel]

        def fazer():
            por_doc = {}
            for d, i in sel:
                por_doc.setdefault(id(d), (d, []))[1].append(i)
            for d, idxs in por_doc.values():
                for i in sorted(idxs, reverse=True):
                    del d.paginas[i]
        self.mudar(docs, fazer)
        self.atualizar_paginas(sel=[])

    def mover_paginas(self, delta):
        sel = self.paginas_sel()
        if not sel or len({id(d) for d, _ in sel}) != 1:
            return
        d = sel[0][0]
        idxs = sorted(i for _, i in sel)
        n = len(d.paginas)
        if (delta < 0 and idxs[0] == 0) or (delta > 0 and idxs[-1] == n - 1):
            return

        def fazer():
            for i in (idxs if delta < 0 else reversed(idxs)):
                d.paginas[i], d.paginas[i + delta] = d.paginas[i + delta], d.paginas[i]
        self.mudar([d], fazer)
        self.atualizar_paginas(sel=[i + delta for i in idxs])

    def copiar_paginas(self):
        sel = self.paginas_sel()
        if sel:
            CLIP["tipo"] = "paginas"
            CLIP["itens"] = [tres.copiar_profundo(d.paginas[i]) for d, i in sel]
            self.statusBar().showMessage("%d página(s) copiada(s)" % len(sel), 3000)

    def colar_paginas(self):
        if CLIP["tipo"] != "paginas":
            return
        d = self._um_evento()
        if not d:
            return
        sel = self.paginas_sel()
        pos = (max(i for _, i in sel) + 1) if sel else len(d.paginas)
        novas = [tres.copiar_profundo(p) for p in CLIP["itens"]]

        def fazer():
            d.paginas[pos:pos] = novas
        self.mudar([d], fazer)
        self.atualizar_paginas(sel=list(range(pos, pos + len(novas))))

    # ------------------------------------------------------------ comandos
    def atualizar_comandos(self, sel=None, atual=None):
        d, pag, cmds = self.cmds_atuais()
        if sel is None:
            sel = self.linhas_sel()
        if atual is None:
            atual = self.lista_cmd.currentRow()
        self.lista_cmd.blockSignals(True)
        self.lista_cmd.clear()
        if cmds is None:
            self.rot_cmd.setText("<b>Comandos</b>  (selecione uma página)")
            self.lista_cmd.blockSignals(False)
            self.info_cmd.setText("")
            return
        p = self.pag_atual()
        self.rot_cmd.setText("<b>Comandos</b>  ·  %s  ·  página %d" % (d.nome, p[1] + 1))
        prof, par = modelo.estrutura(self.proj, cmds)
        labels = set(modelo.labels_da_lista(self.proj, cmds))
        refs = {}
        for c in cmds:
            for l in modelo.alvos_de_label(self.proj, c):
                refs[l] = refs.get(l, 0) + 1
        problemas = 0
        for i, c in enumerate(cmds):
            txt, cat = modelo.resumo(self.proj, c)
            it = QListWidgetItem("%3d  %s%s" % (i + 1, "    " * prof[i], txt))
            it.setForeground(QColor(CORES.get(cat, "#555")))
            cl = self.proj.classe_de(c)
            nome = cl.nome if cl else ""
            if nome in ("CmdLabel",):
                f = it.font()
                f.setBold(True)
                it.setFont(f)
                if not refs.get(c.get("nome", "")):
                    it.setToolTip("label sem ninguém que pule para ele")
            faltam = [l for l in modelo.alvos_de_label(self.proj, c) if l not in labels]
            if faltam:
                it.setBackground(QColor("#ffd6d6"))
                it.setToolTip("label que não existe nesta página: " + ", ".join(faltam))
                problemas += 1
            if nome in modelo.ABRE + ("CmdElse", "CmdEnd") and par[i] is None and nome != "CmdElse":
                it.setBackground(QColor("#ffd6d6"))
                it.setToolTip("bloco sem par (Se/Enquanto sem Fim, ou Fim sobrando)")
                problemas += 1
            if nome == "CmdMostrarMsg":
                it.setToolTip(c.get("texto", ""))
            self.lista_cmd.addItem(it)
        fim = QListWidgetItem("      ◇  (fim da lista: Enter ou duplo clique insere aqui)")
        fim.setForeground(QColor("#aaa"))
        fim.setFlags(fim.flags() & ~Qt.ItemIsDragEnabled)
        self.lista_cmd.addItem(fim)
        for r in sel:
            if 0 <= r < self.lista_cmd.count():
                self.lista_cmd.item(r).setSelected(True)
        if 0 <= atual < self.lista_cmd.count():
            self.lista_cmd.setCurrentRow(atual, QItemSelectionModel.NoUpdate if sel else QItemSelectionModel.ClearAndSelect)
        self.lista_cmd.blockSignals(False)
        self._realcar_bloco(self.lista_cmd.currentRow())
        self.info_cmd.setText("%d comandos%s" % (len(cmds), ("  ·  %d problema(s) em vermelho" % problemas) if problemas else ""))

    def _realcar_bloco(self, row):
        d, pag, cmds = self.cmds_atuais()
        if cmds is None:
            return
        prof, par = modelo.estrutura(self.proj, cmds)
        for i in range(len(cmds)):
            it = self.lista_cmd.item(i)
            if it.background().color() == QColor("#e6ecff"):
                it.setBackground(QBrush())
        if 0 <= row < len(cmds) and par[row] is not None:
            a, b = sorted((row, par[row]))
            # if -> else -> end
            for i in range(a, b + 1):
                cl = self.proj.classe_de(cmds[i])
                if i in (a, b) or (cl and cl.nome == "CmdElse" and prof[i] == prof[a]):
                    it = self.lista_cmd.item(i)
                    if it.background().color() != QColor("#ffd6d6"):
                        it.setBackground(QColor("#e6ecff"))

    def _ctx(self, pag, cmds):
        anims = []
        spr = pag.get("sprite_frames")
        if isinstance(spr, ExtRef):
            anims = self.proj.animacoes.get(spr.path, [])
        return {"labels": modelo.labels_da_lista(self.proj, cmds), "anims": anims}

    def _pos_inserir(self):
        rows = self.linhas_sel()
        cur = self.lista_cmd.currentRow()
        d, pag, cmds = self.cmds_atuais()
        if cmds is None:
            return None
        if cur == len(cmds):
            return len(cmds)
        if rows:
            return rows[-1] + 1
        return len(cmds)

    def inserir(self, script=None):
        d, pag, cmds = self.cmds_atuais()
        if cmds is None:
            return
        if script is None:
            s = widgets.SeletorComando(self, self.proj)
            if s.exec() != QDialog.Accepted:
                return
            script = s.escolhido
        pos = self._pos_inserir()
        novo = self.proj.novo(script)
        cl = self.proj.classes.get(script)
        novos = [novo]
        if cl.nome in ("CmdElse", "CmdEnd", "CmdBreak") or not cl.campos:
            pass
        else:
            extra = "com Senão" if cl.nome == "CmdIf" else None
            dlg = widgets.DialogoRecurso(self, self.proj, novo, self._ctx(pag, cmds), "Novo: " + modelo.nome_bonito(cl), extra_check=extra)
            if dlg.exec() != QDialog.Accepted:
                return
            if cl.nome in ("CmdIf", "CmdWhile"):
                if dlg.extra and dlg.extra.isChecked():
                    novos.append(self.proj.novo(PASTA_CMD("cmd_else.gd")))
                novos.append(self.proj.novo(PASTA_CMD("cmd_end.gd")))
            if cl.nome == "CmdMostrarOpcoes" and dlg.criar_labels():
                pass   # tratado depois de inserir

        def fazer():
            cmds[pos:pos] = novos
            if cl.nome == "CmdMostrarOpcoes" and dlg.criar_labels():
                self._criar_labels_faltando(cmds, novo)
        self.mudar([d], fazer)
        self.atualizar_comandos(sel=[pos], atual=pos)
        self.atualizar_textos_paginas()

    def _criar_labels_faltando(self, cmds, opc):
        existentes = set(modelo.labels_da_lista(self.proj, cmds))
        faltam = [str(l) for l in itens(opc, "labels") if l and str(l) not in existentes]
        if not faltam:
            return
        saida = "fim_opcoes"
        k = 2
        while saida in existentes:
            saida = "fim_opcoes%d" % k
            k += 1
        lab = self.proj.classes.get(PASTA_CMD("cmd_label.gd"))
        got = self.proj.classes.get(PASTA_CMD("cmd_goto.gd"))
        for l in faltam:
            a = self.proj.novo(lab.caminho)
            modelo.definir(a, lab, "nome", l)
            g = self.proj.novo(got.caminho)
            modelo.definir(g, got, "label", saida)
            cmds.extend([a, g])
        a = self.proj.novo(lab.caminho)
        modelo.definir(a, lab, "nome", saida)
        cmds.append(a)

    def nova_fala(self):
        d, pag, cmds = self.cmds_atuais()
        if cmds is None:
            return
        script = PASTA_CMD("cmd_mostrar_msg.gd")
        cl = self.proj.classes.get(script)
        pos = self._pos_inserir()
        novo = self.proj.novo(script)
        for c in reversed(cmds[:pos]):
            if c.script == script:
                for k in ("personagem", "face", "posicao"):
                    if k in c.props:
                        modelo.definir(novo, cl, k, c.props[k])
                break
        dlg = widgets.DialogoRecurso(self, self.proj, novo, self._ctx(pag, cmds), "Nova fala")
        if dlg.exec() != QDialog.Accepted:
            return
        self.mudar([d], lambda: cmds.insert(pos, novo))
        self.atualizar_comandos(sel=[pos], atual=pos)
        self.atualizar_textos_paginas()

    def editar(self):
        d, pag, cmds = self.cmds_atuais()
        if cmds is None:
            return
        r = self.lista_cmd.currentRow()
        if r < 0:
            return
        if r >= len(cmds):
            self.inserir()
            return
        orig = cmds[r]
        cl = self.proj.classe_de(orig)
        if cl is None or not cl.campos:
            self.statusBar().showMessage("Este comando não tem campos.", 3000)
            return
        copia = tres.copiar_mantendo_ids(orig)
        dlg = widgets.DialogoRecurso(self, self.proj, copia, self._ctx(pag, cmds))
        if dlg.exec() != QDialog.Accepted:
            return
        if tres.valores_iguais(copia, orig) and not dlg.criar_labels():
            return

        def fazer():
            cmds[r] = copia
            if cl.nome == "CmdMostrarOpcoes" and dlg.criar_labels():
                self._criar_labels_faltando(cmds, copia)
        self.mudar([d], fazer)
        self.atualizar_comandos(sel=[r], atual=r)
        self.atualizar_textos_paginas()

    def apagar(self):
        d, pag, cmds = self.cmds_atuais()
        rows = self.linhas_sel()
        if cmds is None or not rows:
            return
        prof, par = modelo.estrutura(self.proj, cmds)
        sel = set(rows)
        soltos = []
        for r in rows:
            cl = self.proj.classe_de(cmds[r])
            if cl and cl.nome in modelo.ABRE + ("CmdEnd",) and par[r] is not None and par[r] not in sel:
                soltos.append(r)
        if soltos:
            mb = QMessageBox(self)
            mb.setWindowTitle("Apagar")
            mb.setText("A seleção tem Se/Enquanto/Fim sem o par.")
            b_bloco = mb.addButton("Apagar o bloco inteiro", QMessageBox.AcceptRole)
            b_linhas = mb.addButton("Só as linhas Se/Senão/Fim (o meio fica)", QMessageBox.AcceptRole)
            mb.addButton("Cancelar", QMessageBox.RejectRole)
            mb.exec()
            if mb.clickedButton() is b_bloco:
                for r in soltos:
                    a, b = sorted((r, par[r]))
                    sel.update(range(a, b + 1))
            elif mb.clickedButton() is b_linhas:
                for r in soltos:
                    a, b = sorted((r, par[r]))
                    sel.add(a)
                    sel.add(b)
                    for i in range(a, b):
                        c2 = self.proj.classe_de(cmds[i])
                        if c2 and c2.nome == "CmdElse" and par[i] == b:
                            sel.add(i)
            else:
                return

        def fazer():
            for r in sorted(sel, reverse=True):
                del cmds[r]
        self.mudar([d], fazer)
        m = min(sel)
        self.atualizar_comandos(sel=[min(m, len(cmds))], atual=min(m, len(cmds)))
        self.atualizar_textos_paginas()

    def mover(self, delta):
        d, pag, cmds = self.cmds_atuais()
        rows = self.linhas_sel()
        if cmds is None or not rows:
            return
        if (delta < 0 and rows[0] == 0) or (delta > 0 and rows[-1] == len(cmds) - 1):
            return

        def fazer():
            for r in (rows if delta < 0 else reversed(rows)):
                cmds[r], cmds[r + delta] = cmds[r + delta], cmds[r]
        self.mudar([d], fazer)
        nova = [r + delta for r in rows]
        self.atualizar_comandos(sel=nova, atual=self.lista_cmd.currentRow() + delta)

    def arrastar_comandos(self, alvo):
        d, pag, cmds = self.cmds_atuais()
        rows = self.linhas_sel()
        if cmds is None or not rows:
            return
        alvo = max(0, min(alvo, len(cmds)))
        if rows[0] <= alvo <= rows[-1] + 1 and rows == list(range(rows[0], rows[-1] + 1)):
            return
        mov = [cmds[r] for r in rows]
        antes = sum(1 for r in rows if r < alvo)

        def fazer():
            for r in reversed(rows):
                del cmds[r]
            p = alvo - antes
            cmds[p:p] = mov
        self.mudar([d], fazer)
        p = alvo - antes
        self.atualizar_comandos(sel=list(range(p, p + len(mov))), atual=p)

    def copiar(self, recortar=False):
        d, pag, cmds = self.cmds_atuais()
        rows = self.linhas_sel()
        if cmds is None or not rows:
            return
        CLIP["tipo"] = "comandos"
        CLIP["itens"] = [tres.copiar_profundo(cmds[r]) for r in rows]
        QGuiApplication.clipboard().setText("\n".join(modelo.resumo(self.proj, cmds[r])[0] for r in rows))
        if recortar:
            def fazer():
                for r in reversed(rows):
                    del cmds[r]
            self.mudar([d], fazer)
            self.atualizar_comandos(sel=[rows[0]], atual=rows[0])
            self.atualizar_textos_paginas()
        self.statusBar().showMessage("%d comando(s) %s" % (len(rows), "recortado(s)" if recortar else "copiado(s)"), 3000)

    def colar(self):
        d, pag, cmds = self.cmds_atuais()
        if cmds is None or CLIP["tipo"] != "comandos" or not CLIP["itens"]:
            return
        pos = self._pos_inserir()
        novos = [tres.copiar_profundo(c) for c in CLIP["itens"]]
        self.mudar([d], lambda: cmds.__setitem__(slice(pos, pos), novos))
        self.atualizar_comandos(sel=list(range(pos, pos + len(novos))), atual=pos)
        self.atualizar_textos_paginas()

    def duplicar(self):
        d, pag, cmds = self.cmds_atuais()
        rows = self.linhas_sel()
        if cmds is None or not rows:
            return
        novos = [tres.copiar_profundo(cmds[r]) for r in rows]
        pos = rows[-1] + 1
        self.mudar([d], lambda: cmds.__setitem__(slice(pos, pos), novos))
        self.atualizar_comandos(sel=list(range(pos, pos + len(novos))), atual=pos)
        self.atualizar_textos_paginas()

    def selecionar_bloco(self):
        d, pag, cmds = self.cmds_atuais()
        rows = self.linhas_sel()
        if cmds is None or not rows:
            return
        prof, par = modelo.estrutura(self.proj, cmds)
        sel = set(rows)
        for r in rows:
            if par[r] is not None:
                a, b = sorted((r, par[r]))
                # Senão: o bloco é o do Se dele
                if par[a] is not None and par[a] != b:
                    a = min(a, par[b]) if par[b] is not None else a
                sel.update(range(a, b + 1))
        self.lista_cmd.clearSelection()
        for r in sorted(sel):
            self.lista_cmd.item(r).setSelected(True)

    def ir_label(self):
        d, pag, cmds = self.cmds_atuais()
        r = self.lista_cmd.currentRow()
        if cmds is None or not (0 <= r < len(cmds)):
            return
        c = cmds[r]
        cl = self.proj.classe_de(c)
        if cl and cl.nome == "CmdLabel":
            nome = c.get("nome", "")
            quem = [i for i, x in enumerate(cmds) if nome in modelo.alvos_de_label(self.proj, x)]
            if not quem:
                self.statusBar().showMessage("Ninguém pula para '%s'." % nome, 4000)
                return
            self.lista_cmd.clearSelection()
            for i in quem:
                self.lista_cmd.item(i).setSelected(True)
            self.lista_cmd.setCurrentRow(quem[0], QItemSelectionModel.NoUpdate)
            self.lista_cmd.scrollToItem(self.lista_cmd.item(quem[0]))
            self.statusBar().showMessage("%d comando(s) pulam para '%s'" % (len(quem), nome), 4000)
            return
        alvos = modelo.alvos_de_label(self.proj, c)
        if not alvos:
            return
        # com opções: F12 de novo vai para o próximo label
        idx = getattr(self, "_ir_idx", 0) % len(alvos) if getattr(self, "_ir_de", None) == r else 0
        self._ir_de, self._ir_idx = r, idx + 1
        nome = alvos[idx]
        for i, x in enumerate(cmds):
            cl2 = self.proj.classe_de(x)
            if cl2 and cl2.nome == "CmdLabel" and x.get("nome", "") == nome:
                self.lista_cmd.setCurrentRow(i)
                self.lista_cmd.scrollToItem(self.lista_cmd.item(i), QAbstractItemView.PositionAtCenter)
                self._ir_de = i if len(alvos) == 1 else r
                self.statusBar().showMessage("label %s%s" % (nome, "  (F12 de novo: próximo)" if len(alvos) > 1 else ""), 3000)
                return
        self.statusBar().showMessage("Label '%s' não existe nesta página." % nome, 4000)

    def dialogo_texto(self):
        d, pag, cmds = self.cmds_atuais()
        if cmds is None:
            return
        rows = self.linhas_sel()
        if len(rows) >= 2:
            a, b = rows[0], rows[-1] + 1
        else:
            a, b = 0, len(cmds)
        trecho = cmds[a:b]
        texto = modelo.dialogo_para_texto(self.proj, trecho)
        script = PASTA_CMD("cmd_mostrar_msg.gd")
        tit = "Diálogo em texto  ·  %s pág. %d  ·  comandos %d a %d" % (d.nome, self.pag_atual()[1] + 1, a + 1, max(a + 1, b))
        dlg = widgets.DialogoTexto(self, self.proj, texto, tit)
        while True:
            if dlg.exec() != QDialog.Accepted:
                return
            try:
                novos = modelo.texto_para_dialogo(self.proj, dlg.texto(), list(trecho), script)
            except modelo.ErroDialogo as e:
                dlg.erro.setText(str(e))
                continue
            break
        # quem sumiu do texto ([[n]] apagado) sai da lista
        self.mudar([d], lambda: cmds.__setitem__(slice(a, b), novos))
        self.atualizar_comandos(sel=list(range(a, a + len(novos))), atual=a)
        self.atualizar_textos_paginas()

    def _menu_cmd(self, pos):
        m = QMenu(self)
        m.addAction("Editar\tEnter", self.editar)
        m.addAction("Inserir comando...\tInsert", self.inserir)
        m.addAction("Nova fala\tCtrl+M", self.nova_fala)
        sub = m.addMenu("Inserir rápido")
        for nome in ("cmd_mostrar_msg", "cmd_if", "cmd_else", "cmd_end", "cmd_label", "cmd_goto", "cmd_variavel", "cmd_esperar", "cmd_mover"):
            cl = self.proj.classes.get(PASTA_CMD(nome + ".gd"))
            if cl:
                sub.addAction(modelo.nome_bonito(cl), lambda s=cl.caminho: self.inserir(s))
        m.addSeparator()
        m.addAction("Copiar\tCtrl+C", self.copiar)
        m.addAction("Recortar\tCtrl+X", lambda: self.copiar(True))
        m.addAction("Colar\tCtrl+V", self.colar)
        m.addAction("Duplicar\tCtrl+D", self.duplicar)
        m.addAction("Apagar\tDel", self.apagar)
        m.addSeparator()
        m.addAction("Selecionar bloco\tCtrl+B", self.selecionar_bloco)
        m.addAction("Ir para label / quem usa\tF12", self.ir_label)
        m.addAction("Diálogo em texto\tCtrl+T", self.dialogo_texto)
        m.exec(self.lista_cmd.mapToGlobal(pos))

    def tecla_comandos(self, e):
        k, m = e.key(), e.modifiers()
        ctrl = bool(m & Qt.ControlModifier)
        if k in (Qt.Key_Return, Qt.Key_Enter) and not ctrl:
            self.editar()
        elif k == Qt.Key_Insert:
            self.inserir()
        elif k == Qt.Key_Delete:
            self.apagar()
        elif ctrl and k == Qt.Key_C:
            self.copiar()
        elif ctrl and k == Qt.Key_X:
            self.copiar(True)
        elif ctrl and k == Qt.Key_V:
            self.colar()
        elif ctrl and k == Qt.Key_D:
            self.duplicar()
        elif ctrl and k == Qt.Key_B:
            self.selecionar_bloco()
        elif ctrl and k == Qt.Key_T:
            self.dialogo_texto()
        elif ctrl and k == Qt.Key_M:
            self.nova_fala()
        elif k == Qt.Key_F12:
            self.ir_label()
        elif m & Qt.AltModifier and k in (Qt.Key_Up, Qt.Key_Down):
            self.mover(-1 if k == Qt.Key_Up else 1)
        elif k == Qt.Key_Left and not ctrl:
            self.lista_pag.setFocus()
        else:
            return False
        return True

    # ------------------------------------------------------------ geral
    def atualizar_tudo(self):
        sel_p = [(d.caminho, i) for d, i in self.paginas_sel()]
        rows = self.linhas_sel()
        cur = self.lista_cmd.currentRow()
        self.atualizar_titulo()
        self.atualizar_paginas(sel=sel_p)
        self.atualizar_comandos(sel=rows, atual=cur)

    def validar(self, doc):
        avisos = []
        for pi, pag in enumerate(doc.paginas):
            cmds = itens(pag, "comandos")
            prof, par = modelo.estrutura(self.proj, cmds)
            labels = set(modelo.labels_da_lista(self.proj, cmds))
            for i, c in enumerate(cmds):
                cl = self.proj.classe_de(c)
                n = cl.nome if cl else ""
                if n in modelo.ABRE + ("CmdEnd",) and par[i] is None:
                    avisos.append("%s pág. %d cmd %d: %s sem par" % (doc.nome, pi + 1, i + 1, modelo.nome_bonito(cl)))
                for l in modelo.alvos_de_label(self.proj, c):
                    if l not in labels:
                        avisos.append("%s pág. %d cmd %d: label '%s' não existe" % (doc.nome, pi + 1, i + 1, l))
                if cl is None:
                    avisos.append("%s pág. %d cmd %d: script desconhecido" % (doc.nome, pi + 1, i + 1))
        return avisos

    def salvar(self):
        mods = [d for d in self.docs.values() if d.modificado]
        if not mods:
            self.statusBar().showMessage("Nada para salvar.", 3000)
            return True
        avisos = []
        for d in mods:
            avisos += self.validar(d)
        if avisos:
            r = QMessageBox.question(self, "Salvar", "Problemas encontrados:\n\n" + "\n".join(avisos[:25]) +
                                     ("\n..." if len(avisos) > 25 else "") + "\n\nSalvar mesmo assim?")
            if r != QMessageBox.Yes:
                return False
        conflito = [d for d in mods if d.mudou_fora()]
        if conflito:
            r = QMessageBox.question(self, "Salvar", "Estes arquivos mudaram fora do editor (Godot?) depois que foram abertos aqui:\n\n" +
                                     "\n".join(d.nome for d in conflito) + "\n\nSobrescrever com a versão do editor?")
            if r != QMessageBox.Yes:
                return False
        pasta = modelo.pasta_backup(AQUI)
        for d in mods:
            try:
                d.salvar(pasta)
            except Exception as e:
                QMessageBox.critical(self, "Erro ao salvar", "%s:\n%s" % (d.nome, e))
                return False
        modelo.limpar_backups(AQUI)
        self.atualizar_titulo()
        self.statusBar().showMessage("Salvo: %s  (backup em backup/%s)" % (", ".join(d.nome for d in mods), os.path.basename(pasta)), 6000)
        return True

    def recarregar(self):
        mods = [d for d in self.docs.values() if d.modificado]
        if mods and QMessageBox.question(self, "Recarregar", "Há %d evento(s) não salvos. Descartar as mudanças e recarregar?" % len(mods)) != QMessageBox.Yes:
            return
        sel_p = [(d.caminho, i) for d, i in self.paginas_sel()]
        self.proj = modelo.Projeto(self.raiz)
        self.docs.clear()
        self.hist.clear()
        self.hist_refazer.clear()
        self.atualizar_eventos()
        self.atualizar_paginas(sel=sel_p)
        self.statusBar().showMessage("Recarregado (%d comandos, %d eventos)" % (len(self.proj.comandos), len(self.proj.eventos)), 4000)

    def checar_mudancas_fora(self):
        mudou = False
        for cam, d in list(self.docs.items()):
            if not os.path.exists(cam):
                continue
            if d.mudou_fora():
                if not d.modificado:
                    try:
                        self.docs[cam] = modelo.EventoDoc(self.proj, cam)
                        mudou = True
                    except Exception:
                        pass
                else:
                    self.statusBar().showMessage("Atenção: %s mudou fora do editor e tem mudanças não salvas aqui." % d.nome, 10000)
        if mudou:
            self.hist = [[x for x in h if x in self.docs.values()] for h in self.hist]
            self.hist = [h for h in self.hist if h]
            self.atualizar_tudo()

    def changeEvent(self, e):
        if e.type() == QEvent.ActivationChange and self.isActiveWindow():
            QTimer.singleShot(100, self.checar_mudancas_fora)
        super().changeEvent(e)

    def buscar(self):
        if not hasattr(self, "_busca"):
            self._busca = widgets.DialogoBusca(self, self)
            self._busca.ir_para.connect(self._ir_resultado)
        self._busca.show()
        self._busca.raise_()
        self._busca.q.setFocus()
        self._busca.q.selectAll()

    def _ir_resultado(self, cam, pag, cmd):
        self.selecionar_evento(cam, pag, cmd)

    def trocar_projeto(self):
        p = QFileDialog.getExistingDirectory(self, "Pasta do projeto Godot (com project.godot)", self.raiz)
        if p and os.path.exists(os.path.join(p, "project.godot")):
            if not self.salvar_ou_descartar():
                return
            self.raiz = p
            self.cfg["projeto"] = p
            self.recarregar()

    def salvar_ou_descartar(self):
        mods = [d for d in self.docs.values() if d.modificado]
        if not mods:
            return True
        r = QMessageBox.question(self, TITULO, "Salvar as mudanças em %d evento(s)?" % len(mods),
                                 QMessageBox.Save | QMessageBox.Discard | QMessageBox.Cancel)
        if r == QMessageBox.Save:
            return self.salvar()
        return r == QMessageBox.Discard

    def closeEvent(self, e):
        if not self.salvar_ou_descartar():
            e.ignore()
            return
        self._gravar_cfg()
        e.accept()

    def ajuda(self):
        QMessageBox.information(self, "Atalhos", AJUDA)


def PASTA_CMD(arq):
    return modelo.PASTA_COMANDOS + "/" + arq


AJUDA = """Geral
  Ctrl+S  salvar tudo (backup em backup/)      F5  recarregar scripts e arquivos
  Ctrl+Z / Ctrl+Y  desfazer / refazer           Ctrl+Shift+F  buscar/substituir em todos os eventos

Eventos
  Ctrl/Shift + clique: vários eventos. As páginas de todos aparecem juntas;
  selecione várias páginas e mude um campo: vale para todas.

Páginas
  Del apagar · Ctrl+D duplicar · Alt+↑/↓ mover · Ctrl+C / Ctrl+V copiar e colar (entre eventos também)
  Enter ou → vai para os comandos

Comandos
  Enter / duplo clique  editar (na última linha: inserir)
  Insert  inserir comando (digite para filtrar)        Ctrl+M  nova fala (mesmo falante da anterior)
  Del  apagar        Ctrl+C / Ctrl+X / Ctrl+V  copiar, recortar, colar (entre páginas e eventos)
  Ctrl+D  duplicar   Alt+↑/↓ ou arrastar  mover       Ctrl+B  selecionar o bloco Se ... Fim
  F12  ir para o label (no "ir para" / opções) ou achar quem usa o label (no label)
  Ctrl+T  diálogo em texto (as falas selecionadas, ou a página toda)
  ←  volta para as páginas
  Nos diálogos: Ctrl+Enter confirma.

Vermelho = label que não existe ou Se/Fim sem par. Azul claro = o par do bloco selecionado."""


def main():
    app = QApplication(sys.argv)
    app.setStyle(QStyleFactory.create("Fusion"))
    cfg = {}
    try:
        with open(os.path.join(AQUI, "config.json"), encoding="utf-8") as f:
            cfg = json.load(f)
    except Exception:
        pass
    raiz = None
    if len(sys.argv) > 1 and os.path.exists(os.path.join(sys.argv[1], "project.godot")):
        raiz = sys.argv[1]
    raiz = raiz or (cfg.get("projeto") if cfg.get("projeto") and os.path.exists(os.path.join(cfg["projeto"], "project.godot")) else None)
    raiz = raiz or achar_projeto()
    if not raiz:
        raiz = QFileDialog.getExistingDirectory(None, "Pasta do projeto Godot (com project.godot)")
        if not raiz or not os.path.exists(os.path.join(raiz, "project.godot")):
            return
    j = Janela(raiz)
    j.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
