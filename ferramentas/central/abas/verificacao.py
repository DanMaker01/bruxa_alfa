# verificacao.py - aba Verificação: um botão que procura problemas antes de exportar.
#   erro:  referência quebrada (arquivo que não existe), teleporte para mapa que não existe,
#          evento citado por nome que não existe, label que não existe, receita com item/chama errados.
#   aviso: item/personalidade fora do banco.tres, travessão (—) nos textos, fala vazia, espaço duplo,
#          item sem ícone, opções sem label, variável não declarada / que ninguém muda ou testa,
#          face que o personagem não tem.
#   info:  evento que não está em nenhum mapa e ninguém chama.
# Duplo clique abre o evento na aba Eventos. Só leitura: corrige-se nas outras abas ou no Godot.
import glob
import os
import re

from PySide6 import QtCore, QtGui, QtWidgets as W

from nucleo import indice as ind
from nucleo import navegar
from nucleo import tres_simples as ts

TITULO = "Verificação"
NIVEIS = {"erro": "#e53935", "aviso": "#f2a33a", "info": "#7a8aa0"}
CAMPOS_EVENTO = ("evento", "evento_alvo", "ate_evento")


def verificar(raiz, I):
    out = []      # (nivel, arquivo, onde, msg, evento, pag, cmd)
    T = I.tres

    def add(nivel, arq, onde, msg, d=None):
        out.append((nivel, arq, onde, msg, d["ev"] if d else None, d["pag"] if d else None, d.get("i") if d else None))

    rel = lambda p: os.path.relpath(p, raiz).replace("\\", "/")
    # --- referências quebradas em .tres e .tscn
    arqs = glob.glob(os.path.join(raiz, "dados", "**", "*.tres"), recursive=True) + \
        glob.glob(os.path.join(raiz, "mapas", "**", "*.tscn"), recursive=True) + \
        glob.glob(os.path.join(raiz, "scenes", "**", "*.tscn"), recursive=True)
    for p in arqs:
        txt = ind._ler(p)
        for res in re.findall(r'path="(res://[^"]+)"', txt):
            if not os.path.exists(os.path.join(raiz, *res[6:].split("/"))):
                add("erro", rel(p), "", "arquivo não existe: %s" % res)
    # --- banco
    for lista, pasta in (("itens", "itens"), ("personalidades", "personalidades")):
        banco = ts.ids_no_banco(raiz, lista)
        for p in glob.glob(os.path.join(raiz, "dados", pasta, "*.tres")):
            if ind.stem(p) not in banco:
                add("aviso", rel(p), "", "não está em dados/banco.tres (%s): o jogo não carrega" % lista)
    # --- itens sem ícone, textos dos dados
    for p in glob.glob(os.path.join(raiz, "dados", "itens", "*.tres")):
        if not re.search(r"^icone = ", ind._ler(p), re.M):
            add("aviso", rel(p), "", "item sem ícone")
    for p in glob.glob(os.path.join(raiz, "dados", "**", "*.tres"), recursive=True):
        if os.sep + "eventos" + os.sep in p:
            continue
        for campo, val in re.findall(r'^(\w+) = "((?:[^"\\]|\\.)*)"', ind._ler(p), re.M):
            if "—" in val:
                add("aviso", rel(p), campo, "travessão no texto")
    # --- eventos
    nos_mapa = {n["nome"] for d in I.mapas.values() for n in d["nos"]}
    ids = set(I.ids) | set(I.docs) | nos_mapa
    labels = {}
    for d in I.cmds:
        if d["cl"] == "CmdLabel":
            labels.setdefault((d["ev"], d["pag"]), set()).add(d["res"].get("nome", ""))
    chamados = set()
    for d in I.cmds:
        c, cl = d["res"], d["cl"]
        onde = I.onde(d)
        for campo in CAMPOS_EVENTO:
            v = c.get(campo)
            if isinstance(v, str) and v and v not in ids:
                add("erro", d["ev"], onde, "%s: evento \"%s\" não existe" % (cl, v), d)
            if isinstance(v, T.ExtRef):
                chamados.add(ind.stem(v.path))
        if cl == "CmdTeleportar":
            m = str(c.get("mapa", "") or "")
            if not m:
                add("erro", d["ev"], onde, "teleporte sem mapa", d)
            elif I.resolver_mapa(m) is None:
                add("erro", d["ev"], onde, "teleporte para mapa que não existe: %s" % m, d)
        for alvo in I.modelo.alvos_de_label(I.proj, c):
            if alvo and alvo not in labels.get((d["ev"], d["pag"]), set()):
                add("erro", d["ev"], onde, "label \"%s\" não existe nesta página" % alvo, d)
        if cl == "CmdMostrarOpcoes":
            ops = I.modelo.itens(c, "opcoes")
            lbs = I.modelo.itens(c, "labels")
            if len(lbs) < len(ops):
                add("aviso", d["ev"], onde, "%d opções e %d labels" % (len(ops), len(lbs)), d)
        if cl in ("CmdMostrarMsg", "CmdMostrarOpcoes"):
            face = c.get("face", "") or ""
            pers = c.get("personagem")
            if face and isinstance(pers, T.ExtRef):
                fal = I.proj.falantes.get(ind.stem(pers.path))
                if fal and fal["faces"] and face not in fal["faces"]:
                    add("aviso", d["ev"], onde, "face \"%s\" não existe em %s" % (face, ind.stem(pers.path)), d)
    for f in I.falas():
        d = f["d"]
        if "—" in f["texto"]:
            add("aviso", d["ev"], I.onde(d), "travessão: " + f["texto"][:60], d)
        if not f["texto"].strip():
            add("aviso", d["ev"], I.onde(d), "%s vazia" % f["tipo"], d)
        if "  " in f["texto"]:
            add("aviso", d["ev"], I.onde(d), "espaço duplo: " + f["texto"][:60], d)
    # --- variáveis
    for n in sorted(set(I.vars) | set(I.muda) | set(I.testa)):
        if n in I.codigo:
            continue
        if n not in I.vars:
            add("aviso", "dados/variaveis", n, "variável usada mas não declarada")
        elif not I.muda.get(n) and not I.testa.get(n):
            add("aviso", rel(I.vars[n]["arq"]), n, "variável que ninguém usa")
        elif not I.muda.get(n):
            add("aviso", rel(I.vars[n]["arq"]), n, "variável que ninguém muda (fica no valor inicial)")
        elif not I.testa.get(n):
            add("aviso", rel(I.vars[n]["arq"]), n, "variável que ninguém testa")
    # --- receitas (passos do livro)
    try:
        estados = set(re.findall(r'\{"id":\s*"(\w+)"', ind._ler(os.path.join(raiz, "src", "livro", "estados_chama.gd"))))
    except Exception:  # noqa: BLE001
        estados = set()
    itens = {ind.stem(p) for p in glob.glob(os.path.join(raiz, "dados", "itens", "*.tres"))}
    for p in glob.glob(os.path.join(raiz, "dados", "receitas", "*.tres")):
        try:
            doc = T.TresDoc.load(p)
        except Exception as e:  # noqa: BLE001
            add("erro", rel(p), "", "não deu para ler: %s" % e)
            continue
        pl = doc.root.get("passos_livro")
        for k, ps in enumerate(pl.itens if isinstance(pl, T.TypedArray) else []):
            if not isinstance(ps, dict):
                continue
            if ps.get("tipo") == "chama" and estados and ps.get("estado") not in estados:
                add("erro", rel(p), "passo %d" % (k + 1), "chama \"%s\" não existe" % ps.get("estado"))
            if ps.get("tipo") == "ingrediente" and ps.get("item") not in itens:
                add("erro", rel(p), "passo %d" % (k + 1), "item \"%s\" não existe" % ps.get("item"))
    # --- eventos soltos
    colocados = {n["evento"] for d in I.mapas.values() for n in d["nos"]}
    citados = set()
    for p in glob.glob(os.path.join(raiz, "dados", "**", "*.tres"), recursive=True) + glob.glob(os.path.join(raiz, "src", "**", "*.gd"), recursive=True):
        citados |= set(re.findall(r'dados/eventos/(\w+)\.tres', ind._ler(p)))
    for ev in sorted(I.docs):
        if ev not in colocados and ev not in chamados and ev not in citados:
            add("info", ev, "", "não está em nenhum mapa e ninguém chama", {"ev": ev, "pag": 0, "i": None})
    for p, msg in I.erros:
        add("erro", rel(p), "", msg)
    return out


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        b = W.QPushButton("Verificar")
        b.clicked.connect(self.verificar)
        h.addWidget(b)
        self.niveis = {}
        for n in NIVEIS:
            cb = W.QCheckBox(n)
            cb.setChecked(True)
            cb.toggled.connect(self._mostrar)
            h.addWidget(cb)
            self.niveis[n] = cb
        self.filtro = W.QLineEdit(placeholderText="filtrar...")
        self.filtro.textChanged.connect(self._mostrar)
        h.addWidget(self.filtro, 1)
        lay.addLayout(h)
        self.resumo = W.QLabel("Aperte Verificar.")
        lay.addWidget(self.resumo)
        self.tab = W.QTableWidget(0, 4)
        self.tab.setHorizontalHeaderLabels(["nível", "arquivo", "onde", "problema"])
        self.tab.verticalHeader().setVisible(False)
        self.tab.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.tab.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.tab.horizontalHeader().setStretchLastSection(True)
        self.tab.cellDoubleClicked.connect(self._abrir)
        lay.addWidget(self.tab, 1)
        self.res = []

    def verificar(self):
        W.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
        try:
            I = ind.indice(self.raiz, novo=True)
            self.res = verificar(self.raiz, I)
        finally:
            W.QApplication.restoreOverrideCursor()
        cont = {n: sum(1 for r in self.res if r[0] == n) for n in NIVEIS}
        self.resumo.setText("  ·  ".join("%s: %d" % (n, c) for n, c in cont.items())
                            + ("   (pode exportar)" if cont["erro"] == 0 else "   (corrija os erros antes de exportar)"))
        self._mostrar()

    def _mostrar(self, *_):
        txt = self.filtro.text().lower()
        self.vis = [r for r in self.res if self.niveis[r[0]].isChecked() and (not txt or txt in " ".join(str(x) for x in r[:4]).lower())]
        self.vis.sort(key=lambda r: (list(NIVEIS).index(r[0]), r[1]))
        self.tab.setRowCount(len(self.vis))
        for k, r in enumerate(self.vis):
            for c in range(4):
                it = W.QTableWidgetItem(str(r[c]))
                if c == 0:
                    it.setForeground(QtGui.QColor(NIVEIS[r[0]]))
                self.tab.setItem(k, c, it)
        self.tab.resizeColumnsToContents()

    def _abrir(self, k, _c):
        if 0 <= k < len(self.vis) and self.vis[k][4]:
            r = self.vis[k]
            navegar.abrir_evento(r[4], r[5], r[6])


def criar(raiz):
    return Aba(raiz)
