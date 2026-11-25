# catalogo.py - aba Catálogo: as poções conhecidas (dados/pocoes/**/*.tres, PocaoReferencia).
# Proibidas ficam no fim da lista (em vermelho). À direita:
#   Matriz A ideal da poção (editável)
#   Efeito na personalidade: escolha um personagem e veja antes/depois (pentagrama) e em palavras
#   Comandos do efeito: o que a poção dispara além da matriz (ex.: Retorno -> voltar para casa);
#                       duplo clique edita, + insere, − apaga (grava o .tres na hora)
import os

from PySide6 import QtCore, QtWidgets as W

from nucleo import motor
from nucleo import tres_simples as ts
from nucleo.tabela import TabelaTres
from nucleo.visual import Pentagrama

TITULO = "Catálogo"
CAMPOS = [("nome", "texto", "", "nome"),
          ("distancia_max", "num", 0.0, "tolerância (0 = 0,05)"),
          ("aproveitamento_min_efeito", "num", 0.0, "aprov. mín. efeito"),
          ("descricao", "texto", "", "descrição")]


def _ordem(caminho):
    return ("proibidas" in caminho.replace("\\", "/").split("/"), os.path.basename(caminho))


class Aba(TabelaTres):
    def __init__(self, raiz):
        super().__init__(raiz, "dados/pocoes/**/*.tres", "PocaoReferencia", CAMPOS, com_matriz=True,
                         coluna_id="poção", ordem=_ordem)
        self.split.setSizes([650, 520])
        # efeito na personalidade
        caixa = W.QGroupBox("Efeito na personalidade")
        v = W.QVBoxLayout(caixa)
        h = W.QHBoxLayout()
        h.addWidget(W.QLabel("Em:"))
        self.pessoa = W.QComboBox()
        self.pessoas = [(os.path.splitext(os.path.basename(p))[0],
                         [float(ts.ler_campo(t, c, 0.0) or 0) for c in ("abertura", "consciencia", "extroversao", "amabilidade", "neuroticismo")])
                        for p, t in ts.listar(raiz, "dados/personalidades/*.tres", "PersonalidadeData")]
        self.pessoa.addItems([n for n, _ in self.pessoas])
        self.pessoa.currentIndexChanged.connect(self.atualizar)
        h.addWidget(self.pessoa, 1)
        v.addLayout(h)
        self.penta = Pentagrama(190)
        v.addWidget(self.penta)
        self.palavras = W.QLabel(wordWrap=True)
        v.addWidget(self.palavras)
        self.painel_lay.addWidget(caixa)
        # comandos do efeito
        caixa = W.QGroupBox("Comandos do efeito (além da matriz)")
        v = W.QVBoxLayout(caixa)
        self.cmds = W.QListWidget()
        self.cmds.setMaximumHeight(130)
        self.cmds.itemDoubleClicked.connect(lambda *_: self.editar_cmd())
        v.addWidget(self.cmds)
        h = W.QHBoxLayout()
        for txt, fn in (("+ inserir", self.inserir_cmd), ("editar", self.editar_cmd), ("− apagar", self.apagar_cmd)):
            b = W.QPushButton(txt)
            b.clicked.connect(fn)
            h.addWidget(b)
        v.addLayout(h)
        self.painel_lay.addWidget(caixa)
        self.fim_do_painel()
        self.linha_escolhida.connect(self.atualizar)
        self.mudou.connect(self.atualizar)
        self.atualizar()

    # ---------------------------------------------------------- efeito na personalidade
    def atualizar(self, *_):
        l = self.atual()
        if not l or not hasattr(self, "penta"):
            return
        mud = []
        if self.pessoas:
            nome, p = self.pessoas[max(0, self.pessoa.currentIndex())]
            q = ts.aplicar(l["A"], p)
            self.penta.definir(p, q, "%s (tracejado = antes)" % nome)
            mud = ["%s %.1f → %.1f" % (ts.TRACOS[k], p[k], q[k]) for k in range(5) if abs(q[k] - p[k]) > 0.005]
        self.palavras.setText("Matriz: " + "; ".join(ts.descrever_matriz(l["A"]))
                              + ("\nNa pessoa: " + ", ".join(mud) if mud else ""))
        self._mostrar_cmds()

    # ---------------------------------------------------------- comandos do efeito (motor do editor de eventos)
    def _doc(self):
        l = self.atual()
        if not l:
            return None, None
        _, tres, _ = motor.eventos()
        return l, tres.TresDoc.load(l["arq"])

    def _lista(self, doc):
        modelo, _, _ = motor.eventos()
        return modelo.itens(doc.root, "efeito")

    def _mostrar_cmds(self):
        self.cmds.clear()
        try:
            l, doc = self._doc()
            if not doc:
                return
            modelo, _, _ = motor.eventos()
            proj = motor.projeto(self.raiz)
            lst = self._lista(doc)
            for c in lst:
                self.cmds.addItem(modelo.resumo(proj, c)[0])
            if not lst:
                it = W.QListWidgetItem("(nenhum: o efeito é só a matriz)")
                it.setFlags(QtCore.Qt.NoItemFlags)
                self.cmds.addItem(it)
        except Exception as e:  # noqa: BLE001
            self.cmds.addItem("não deu para ler: %s" % e)

    def _gravar(self, l, doc):
        if l["sujo"]:
            W.QMessageBox.information(self, "Salve antes", "Salve as outras mudanças desta poção antes de mexer nos comandos.")
            return False
        doc.save(l["arq"])
        r = self.tab.currentRow()
        self.carregar()
        self.tab.setCurrentCell(r, 0)
        return True

    def inserir_cmd(self):
        l, doc = self._doc()
        if not doc:
            return
        modelo, _, widgets = motor.eventos()
        proj = motor.projeto(self.raiz)
        s = widgets.SeletorComando(self, proj)
        if not s.exec() or not s.escolhido:
            return
        novo = proj.novo(s.escolhido)
        if not widgets.editar_recurso(self, proj, novo, {"labels": [], "anims": []}, "Novo comando do efeito"):
            return
        lst = list(self._lista(doc)) + [novo]
        doc.root.props["efeito"] = proj.array_tipado(modelo.SCRIPT_COMANDO, lst)
        self._gravar(l, doc)

    def editar_cmd(self):
        i = self.cmds.currentRow()
        l, doc = self._doc()
        if not doc or not 0 <= i < len(self._lista(doc)):
            return
        _, _, widgets = motor.eventos()
        proj = motor.projeto(self.raiz)
        if widgets.editar_recurso(self, proj, self._lista(doc)[i], {"labels": [], "anims": []}):
            self._gravar(l, doc)

    def apagar_cmd(self):
        i = self.cmds.currentRow()
        l, doc = self._doc()
        if not doc or not 0 <= i < len(self._lista(doc)):
            return
        modelo, _, _ = motor.eventos()
        proj = motor.projeto(self.raiz)
        lst = list(self._lista(doc))
        del lst[i]
        if lst:
            doc.root.props["efeito"] = proj.array_tipado(modelo.SCRIPT_COMANDO, lst)
        else:
            doc.root.props.pop("efeito", None)
        self._gravar(l, doc)


def criar(raiz):
    return Aba(raiz)
