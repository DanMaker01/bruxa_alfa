# eventos.py - aba Eventos (editor próprio da central; o motor é o do editor de eventos antigo:
# leitura/gravação de .tres, comandos e campos lidos dos scripts do jogo, formulários).
#   Esquerda: lista dos eventos (por nome), filtro, novo evento
#   Meio:     páginas (abas) com as condições/aparência da página, e a lista de comandos
#             (indentada pelos blocos Se/Senão/Fim, cores por tipo: diálogo, fluxo, dados, cena)
#   Direita:  os campos do comando escolhido (muda na hora)
#   Ctrl+S salva (com backup em editor_eventos/backup/), Ctrl+Z / Ctrl+Y desfaz / refaz,
#   Insert insere comando, Del apaga, Alt+↑/↓ move, Ctrl+D duplica.
import os

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import motor

TITULO = "Eventos"


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        self.modelo, self.tres, self.widgets = motor.eventos()
        self.proj = motor.projeto(raiz)
        self.docs = {}
        self.doc = None
        self.pag = 0
        self.form_pag = None
        self.forms = []     # formulários abertos (para gravar/parar o texto pendente antes de trocar)
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        barra = W.QHBoxLayout()
        for txt, fn, atalho in (("Salvar", self.salvar, "Ctrl+S"), ("Desfazer", self.desfazer, "Ctrl+Z"),
                                ("Refazer", self.refazer, "Ctrl+Y"), ("Recarregar", self.recarregar, "F5")):
            b = W.QPushButton(txt)
            b.setToolTip(atalho)
            b.clicked.connect(fn)
            barra.addWidget(b)
            QtGui.QShortcut(QtGui.QKeySequence(atalho), self, activated=fn)
        barra.addStretch(1)
        self.status = W.QLabel()
        barra.addWidget(self.status)
        lay.addLayout(barra)
        split = W.QSplitter(QtCore.Qt.Horizontal)
        split.addWidget(self._lado_eventos())
        split.addWidget(self._meio())
        self.rol_cmd = W.QScrollArea()
        self.rol_cmd.setWidgetResizable(True)
        self.rol_cmd.setWidget(W.QLabel("  (escolha um comando)"))
        split.addWidget(self.rol_cmd)
        split.setSizes([230, 560, 420])
        lay.addWidget(split, 1)
        self.listar_eventos()

    # ================================================================ eventos
    def _lado_eventos(self):
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        v.setContentsMargins(0, 0, 0, 0)
        self.filtro = W.QLineEdit(placeholderText="filtrar eventos...")
        self.filtro.textChanged.connect(self.listar_eventos)
        v.addWidget(self.filtro)
        self.arvore = W.QTreeWidget()
        self.arvore.setHeaderHidden(True)
        self.arvore.setRootIsDecorated(False)
        self.arvore.currentItemChanged.connect(self._evento_escolhido)
        v.addWidget(self.arvore, 1)
        b = W.QPushButton("Novo evento")
        b.clicked.connect(self.novo_evento)
        v.addWidget(b)
        return w

    def _pasta(self):
        return os.path.join(self.raiz, "dados", "eventos")

    def listar_eventos(self, *_):
        filtro = self.filtro.text().lower()
        atual = self.doc.caminho if self.doc else None
        self.arvore.blockSignals(True)
        self.arvore.clear()
        for nome in sorted(os.listdir(self._pasta())):
            if not nome.endswith(".tres") or (filtro and filtro not in nome.lower()):
                continue
            caminho = os.path.join(self._pasta(), nome)
            d = self.docs.get(caminho)
            it = W.QTreeWidgetItem(self.arvore, [nome[:-5] + (" *" if d and d.modificado else "")])
            it.setData(0, QtCore.Qt.UserRole, caminho)
            if caminho == atual:
                self.arvore.setCurrentItem(it)
        self.arvore.blockSignals(False)

    def _evento_escolhido(self, it, *_):
        caminho = it.data(0, QtCore.Qt.UserRole) if it else None
        if not caminho:
            return
        d = self.docs.get(caminho)
        if d is None or (d.mudou_fora() and not d.modificado):
            try:
                d = self.modelo.EventoDoc(self.proj, caminho)
            except Exception as e:  # noqa: BLE001
                W.QMessageBox.warning(self, "Erro", "Não deu para ler %s:\n%s" % (os.path.basename(caminho), e))
                return
            self.docs[caminho] = d
        self.doc = d
        self.pag = 0
        self.montar_paginas()

    def abrir(self, caminho, pag=None, cmd=None):
        """Abre o evento (caminho do .tres) na página `pag` e seleciona o comando `cmd` (vindo de outra aba)."""
        if not os.path.exists(caminho):
            return False
        self.filtro.blockSignals(True)
        self.filtro.clear()
        self.filtro.blockSignals(False)
        self.listar_eventos()
        for k in range(self.arvore.topLevelItemCount()):
            it = self.arvore.topLevelItem(k)
            if os.path.normcase(it.data(0, QtCore.Qt.UserRole)) == os.path.normcase(caminho):
                self.arvore.setCurrentItem(it)
                self.arvore.scrollToItem(it)
                break
        if self.doc and pag is not None:
            self.abas_pag.setCurrentIndex(max(0, min(pag, len(self.doc.paginas) - 1)))
            self._pagina_escolhida(self.abas_pag.currentIndex())
        if cmd is not None:
            self.lista.setCurrentRow(max(0, min(cmd, self.lista.count() - 1)))
        return True

    def novo_evento(self):
        nome, ok = W.QInputDialog.getText(self, "Novo evento", "nome do arquivo (ex.: cidadeA_npc4):")
        nome = nome.strip().replace(" ", "_")
        if not ok or not nome:
            return
        caminho = os.path.join(self._pasta(), nome + ".tres")
        if os.path.exists(caminho):
            W.QMessageBox.warning(self, "Já existe", "%s já existe." % nome)
            return
        self.docs[caminho] = self.modelo.EventoDoc.criar(self.proj, caminho, nome)
        self.doc = self.docs[caminho]
        self.listar_eventos()

    # ================================================================ páginas e comandos
    def _meio(self):
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        v.setContentsMargins(0, 0, 0, 0)
        h = W.QHBoxLayout()
        self.abas_pag = W.QTabBar()
        self.abas_pag.currentChanged.connect(self._pagina_escolhida)
        h.addWidget(self.abas_pag, 1)
        for txt, fn, dica in (("+", self.nova_pagina, "nova página"), ("−", self.apagar_pagina, "apagar página")):
            b = W.QToolButton(text=txt)
            b.setToolTip(dica)
            b.clicked.connect(fn)
            h.addWidget(b)
        v.addLayout(h)
        self.caixa_pag = W.QGroupBox("Página (vale a última com todas as condições verdadeiras)")
        self.caixa_pag.setCheckable(True)
        self.caixa_pag.setChecked(False)
        self.caixa_pag.toggled.connect(lambda on: self.rol_pag.setVisible(on))
        vv = W.QVBoxLayout(self.caixa_pag)
        self.rol_pag = W.QScrollArea()
        self.rol_pag.setWidgetResizable(True)
        self.rol_pag.setMaximumHeight(260)
        self.rol_pag.setVisible(False)
        vv.addWidget(self.rol_pag)
        v.addWidget(self.caixa_pag)
        h = W.QHBoxLayout()
        for txt, fn, dica in (("Inserir", self.inserir, "Insert"), ("Apagar", self.apagar, "Del"),
                              ("↑", lambda: self.mover(-1), "Alt+↑"), ("↓", lambda: self.mover(1), "Alt+↓"),
                              ("Duplicar", self.duplicar, "Ctrl+D")):
            b = W.QPushButton(txt)
            b.setToolTip(dica)
            b.clicked.connect(fn)
            h.addWidget(b)
        v.addLayout(h)
        self.lista = W.QListWidget()
        self.lista.setFont(self.widgets.fonte_mono(10))
        self.lista.currentRowChanged.connect(self._comando_escolhido)
        v.addWidget(self.lista, 1)
        for tecla, fn in (("Insert", self.inserir), ("Delete", self.apagar), ("Alt+Up", lambda: self.mover(-1)),
                          ("Alt+Down", lambda: self.mover(1)), ("Ctrl+D", self.duplicar)):
            QtGui.QShortcut(QtGui.QKeySequence(tecla), self.lista, activated=fn, context=QtCore.Qt.WidgetShortcut)
        return w

    def _pagina(self):
        if not self.doc or not self.doc.paginas:
            return None
        return self.doc.paginas[min(self.pag, len(self.doc.paginas) - 1)]

    def _cmds(self):
        p = self._pagina()
        return self.modelo.itens(p, "comandos") if p is not None else []

    def _ctx(self):
        p = self._pagina()
        anims = []
        spr = p.get("sprite_frames") if p is not None else None
        if isinstance(spr, self.tres.ExtRef):
            anims = self.proj.animacoes.get(spr.path, [])
        return {"labels": self.modelo.labels_da_lista(self.proj, self._cmds()), "anims": anims}

    def montar_paginas(self):
        self.abas_pag.blockSignals(True)
        while self.abas_pag.count():
            self.abas_pag.removeTab(0)
        if self.doc:
            for i, p in enumerate(self.doc.paginas):
                self.abas_pag.addTab(self.modelo.resumo_pagina(self.proj, p, i)[:40])
            self.abas_pag.setCurrentIndex(min(self.pag, max(0, len(self.doc.paginas) - 1)))
        self.abas_pag.blockSignals(False)
        self._montar_form_pagina()
        self.montar_lista()
        self._status()

    def _pagina_escolhida(self, i):
        self.pag = max(0, i)
        self._montar_form_pagina()
        self.montar_lista()

    def _montar_form_pagina(self):
        p = self._pagina()
        if p is None:
            self.rol_pag.setWidget(W.QLabel("  (sem página)"))
            return
        cl = self.proj.classes.get(self.modelo.SCRIPT_PAGINA)
        self._parar([self.form_pag], True)
        self.form_pag = self.widgets.FormRecurso(self.proj, cl, [p], self._ctx(), self._pagina_mudou)
        self.rol_pag.setWidget(self.form_pag)

    def _pagina_mudou(self, nome, valor):
        p = self._pagina()
        cl = self.proj.classes.get(self.modelo.SCRIPT_PAGINA)
        self._mudar(lambda: self._definir(p, cl, nome, valor))
        self.abas_pag.setTabText(self.pag, self.modelo.resumo_pagina(self.proj, p, self.pag)[:40])

    def _parar_forms(self, emitir):
        """Campos de texto gravam com um pequeno atraso: antes de trocar o formulário,
        grava o que estava sendo digitado (emitir) ou só descarta (depois de desfazer/recarregar)."""
        self._parar(self.forms, emitir)
        self.forms = []

    @staticmethod
    def _parar(forms, emitir):
        for f in forms:
            for ed in getattr(f, "eds", {}).values():
                t = getattr(ed, "_timer", None)
                if t is not None and t.isActive():
                    t.stop()
                    if emitir:
                        try:
                            ed.emitir()
                        except RuntimeError:
                            pass

    def montar_lista(self, linha=None):
        self._parar_forms(False)
        cmds = self._cmds()
        prof, par = self.modelo.estrutura(self.proj, cmds)
        sel = self.lista.currentRow() if linha is None else linha
        self.lista.blockSignals(True)
        self.lista.clear()
        for i, c in enumerate(cmds):
            cl = self.proj.classe_de(c)
            txt, cat = self.modelo.resumo(self.proj, c)
            it = W.QListWidgetItem("    " * prof[i] + txt)
            it.setForeground(QtGui.QColor(self.widgets.CORES.get(cat, "#999")))
            if cl and cl.nome in ("CmdIf", "CmdWhile", "CmdElse", "CmdEnd") and par[i] is None:
                it.setForeground(QtGui.QColor("#e53935"))
                it.setToolTip("bloco sem par (Se/Senão/Fim)")
            self.lista.addItem(it)
        fim = W.QListWidgetItem("    ◇ (fim: Insert aqui acrescenta no final)")
        fim.setForeground(QtGui.QColor("#777"))
        self.lista.addItem(fim)
        self.lista.blockSignals(False)
        self.lista.setCurrentRow(max(0, min(sel, self.lista.count() - 1)))
        self._comando_escolhido(self.lista.currentRow())

    def _comando_escolhido(self, i):
        self._parar_forms(True)
        cmds = self._cmds()
        if not 0 <= i < len(cmds):
            self.rol_cmd.setWidget(W.QLabel("  (escolha um comando)"))
            return
        c = cmds[i]
        cl = self.proj.classe_de(c)
        if cl is None:
            self.rol_cmd.setWidget(W.QLabel("  script desconhecido"))
            return
        w = W.QWidget()
        v = W.QVBoxLayout(w)
        tit = W.QLabel("<b>%s</b>" % self.modelo.nome_bonito(cl))
        v.addWidget(tit)
        if cl.descricao:
            d = W.QLabel(cl.descricao.split("\n")[0], wordWrap=True)
            d.setToolTip(cl.descricao)
            d.setStyleSheet("color:#999")
            v.addWidget(d)
        f = self.widgets.FormRecurso(self.proj, cl, [c], self._ctx(), lambda n, val, c=c, cl=cl: self._comando_mudou(c, cl, n, val))
        self.forms.append(f)
        v.addWidget(f)
        v.addStretch(1)
        self.rol_cmd.setWidget(w)

    def _definir(self, res, cl, nome, valor):
        m = self.modelo
        if cl and cl.nome == "CmdMostrarOpcoes" and nome == "opcoes":
            ops, lbs = valor
            m.definir_lista(self.proj, res, "opcoes", ops, tipo_basico="String")
            m.definir_lista(self.proj, res, "labels", lbs, tipo_basico="String")
            return
        campo = cl.campo(nome) if cl else None
        if campo and campo.tipo == "Array":
            if campo.elem == "String":
                m.definir_lista(self.proj, res, nome, valor, tipo_basico="String")
            else:
                sub = self.proj.por_nome.get(campo.elem)
                m.definir_lista(self.proj, res, nome, valor, script_elem=sub.caminho if sub else None)
        else:
            m.definir(res, cl, nome, valor)

    def _comando_mudou(self, c, cl, nome, valor):
        self._mudar(lambda: self._definir(c, cl, nome, valor))
        cmds = self._cmds()
        i = next((k for k, x in enumerate(cmds) if x is c), -1)
        prof, _ = self.modelo.estrutura(self.proj, cmds)
        if 0 <= i < len(prof):
            self.lista.item(i).setText("    " * prof[i] + self.modelo.resumo(self.proj, c)[0])

    # ================================================================ ações
    def _mudar(self, fn):
        if not self.doc:
            return
        self.doc.antes_de_mudar()
        try:
            fn()
        except Exception as e:  # noqa: BLE001
            self.doc.desfazer()
            self.doc.refazer_pilha.clear()
            W.QMessageBox.warning(self, "Erro", "Não deu para fazer isso:\n%s" % e)
        self._status()

    def _lista_editavel(self):
        p = self._pagina()
        if p is None:
            return None
        if not isinstance(p.props.get("comandos"), self.tres.TypedArray):
            p.props["comandos"] = self.proj.array_tipado(self.modelo.SCRIPT_COMANDO, list(self.modelo.itens(p, "comandos")))
        return p.props["comandos"].itens

    def inserir(self):
        self._parar_forms(True)
        if self._pagina() is None:
            return
        s = self.widgets.SeletorComando(self, self.proj)
        if not s.exec() or not s.escolhido:
            return
        novo = self.proj.novo(s.escolhido)
        i = min(self.lista.currentRow(), len(self._cmds()))
        i = len(self._cmds()) if i < 0 else i
        self._mudar(lambda: self._lista_editavel().insert(i, novo))
        self.montar_lista(i)

    def apagar(self):
        self._parar_forms(True)
        i = self.lista.currentRow()
        if not 0 <= i < len(self._cmds()):
            return
        self._mudar(lambda: self._lista_editavel().pop(i))
        self.montar_lista(i)

    def mover(self, d):
        self._parar_forms(True)
        i = self.lista.currentRow()
        n = len(self._cmds())
        if not 0 <= i < n or not 0 <= i + d < n:
            return

        def fazer():
            l = self._lista_editavel()
            l[i], l[i + d] = l[i + d], l[i]
        self._mudar(fazer)
        self.montar_lista(i + d)

    def duplicar(self):
        self._parar_forms(True)
        i = self.lista.currentRow()
        if not 0 <= i < len(self._cmds()):
            return
        copia = self.tres.copiar_profundo(self._cmds()[i])
        self._mudar(lambda: self._lista_editavel().insert(i + 1, copia))
        self.montar_lista(i + 1)

    def nova_pagina(self):
        if not self.doc:
            return
        self._mudar(lambda: self.doc.paginas.append(self.proj.nova_pagina()))
        self.pag = len(self.doc.paginas) - 1
        self.montar_paginas()

    def apagar_pagina(self):
        if not self.doc or len(self.doc.paginas) <= 1:
            return
        if W.QMessageBox.question(self, "Apagar página", "Apagar a página %d?" % (self.pag + 1)) != W.QMessageBox.Yes:
            return
        self._mudar(lambda: self.doc.paginas.pop(self.pag))
        self.pag = max(0, self.pag - 1)
        self.montar_paginas()

    def _descartar_pendentes(self):
        self._parar([self.form_pag], False)
        self._parar_forms(False)

    def desfazer(self):
        self._descartar_pendentes()
        if self.doc and self.doc.desfazer():
            self.montar_paginas()

    def refazer(self):
        self._descartar_pendentes()
        if self.doc and self.doc.refazer():
            self.montar_paginas()

    def salvar(self):
        self._parar([self.form_pag], True)
        self._parar_forms(True)
        n = 0
        pasta = self.modelo.pasta_backup(motor.PASTA_EVENTOS)
        for d in self.docs.values():
            if not d.modificado:
                continue
            if d.mudou_fora() and W.QMessageBox.question(
                    self, "Mudou fora", "%s mudou fora daqui (Godot?). Gravar por cima?" % d.nome) != W.QMessageBox.Yes:
                continue
            d.salvar(pasta)
            n += 1
        try:
            self.modelo.limpar_backups(motor.PASTA_EVENTOS)
        except Exception:  # noqa: BLE001
            pass
        self.listar_eventos()
        self._status("salvo(s): %d" % n)

    def recarregar(self):
        if self.tem_mudancas() and W.QMessageBox.question(self, "Recarregar", "Descartar as mudanças não salvas?") != W.QMessageBox.Yes:
            return
        self.proj.carregar()
        self.docs.clear()
        self.doc = None
        self.listar_eventos()
        self.montar_paginas()

    def tem_mudancas(self):
        return any(d.modificado for d in self.docs.values())

    def _status(self, extra=""):
        n = sum(1 for d in self.docs.values() if d.modificado)
        self.status.setText(("%d evento(s) não salvo(s)" % n if n else "tudo salvo") + ("  · " + extra if extra else ""))
        if self.doc:
            it = self.arvore.currentItem()
            if it and it.data(0, QtCore.Qt.UserRole):
                it.setText(0, self.doc.nome + (" *" if self.doc.modificado else ""))


def criar(raiz):
    return Aba(raiz)
