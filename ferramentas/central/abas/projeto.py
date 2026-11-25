# projeto.py - aba Projeto: o git do projeto, só para ver (não grava nada no git).
#   Agora:    arquivos mudados e não salvos no git (git status).
#   Versões:  os últimos commits; escolha um para ver o que mudou DE LÁ ATÉ AGORA (arquivos e
#             linhas + / −) e clique num arquivo para ver a diferença.
# Precisa do git instalado (o mesmo que o GitHub Desktop / VS Code usam).
import subprocess

from PySide6 import QtCore, QtGui, QtWidgets as W

TITULO = "Projeto"


def git(raiz, *args):
    try:
        r = subprocess.run(["git", *args], cwd=raiz, capture_output=True, text=True, encoding="utf-8", errors="replace",
                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        return r.stdout if r.returncode == 0 else ("(git: %s)" % r.stderr.strip())
    except FileNotFoundError:
        return "(git não encontrado: instale o git ou abra pelo GitHub Desktop)"


class Aba(W.QWidget):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        lay = W.QVBoxLayout(self)
        lay.setContentsMargins(6, 6, 6, 6)
        h = W.QHBoxLayout()
        self.ramo = W.QLabel()
        h.addWidget(self.ramo, 1)
        b = W.QPushButton("Atualizar")
        b.clicked.connect(self.atualizar)
        h.addWidget(b)
        lay.addLayout(h)
        split = W.QSplitter()
        esq = W.QWidget()
        v = W.QVBoxLayout(esq)
        v.setContentsMargins(0, 0, 0, 0)
        v.addWidget(W.QLabel("Versões (escolha uma para comparar com agora):"))
        self.commits = W.QListWidget()
        self.commits.setFont(QtGui.QFont("Consolas", 9))
        self.commits.currentRowChanged.connect(self._commit)
        v.addWidget(self.commits, 1)
        split.addWidget(esq)
        meio = W.QWidget()
        v = W.QVBoxLayout(meio)
        v.setContentsMargins(0, 0, 0, 0)
        self.titulo = W.QLabel("Mudados agora (não commitados):")
        v.addWidget(self.titulo)
        self.arqs = W.QTableWidget(0, 3)
        self.arqs.setHorizontalHeaderLabels(["arquivo", "+", "−"])
        self.arqs.verticalHeader().setVisible(False)
        self.arqs.setEditTriggers(W.QAbstractItemView.NoEditTriggers)
        self.arqs.setSelectionBehavior(W.QAbstractItemView.SelectRows)
        self.arqs.horizontalHeader().setSectionResizeMode(0, W.QHeaderView.Stretch)
        self.arqs.currentCellChanged.connect(lambda *_: self._diff())
        v.addWidget(self.arqs, 1)
        self.total = W.QLabel()
        v.addWidget(self.total)
        split.addWidget(meio)
        self.txt = W.QPlainTextEdit(readOnly=True)
        self.txt.setFont(QtGui.QFont("Consolas", 9))
        self.txt.setLineWrapMode(W.QPlainTextEdit.NoWrap)
        split.addWidget(self.txt)
        split.setSizes([330, 380, 600])
        lay.addWidget(split, 1)
        self.base = None
        self.atualizar()

    def atualizar(self):
        r = git(self.raiz, "rev-parse", "--abbrev-ref", "HEAD").strip()
        ult = git(self.raiz, "log", "-1", "--format=%h %s (%cr)").strip()
        self.ramo.setText("ramo: %s   ·   último commit: %s" % (r, ult))
        self.commits.blockSignals(True)
        self.commits.clear()
        it = W.QListWidgetItem("(agora: o que não foi commitado)")
        it.setData(QtCore.Qt.UserRole, None)
        self.commits.addItem(it)
        for linha in git(self.raiz, "log", "-80", "--format=%h|%ad|%s", "--date=short").splitlines():
            if "|" not in linha:
                self.commits.addItem(linha)
                continue
            h, data, msg = linha.split("|", 2)
            it = W.QListWidgetItem("%s  %s  %s" % (h, data, msg))
            it.setData(QtCore.Qt.UserRole, h)
            self.commits.addItem(it)
        self.commits.blockSignals(False)
        self.commits.setCurrentRow(0)
        self._commit(0)

    def _commit(self, k):
        it = self.commits.item(k)
        self.base = it.data(QtCore.Qt.UserRole) if it else None
        if self.base:
            self.titulo.setText("De %s até agora (inclui o que não foi commitado):" % self.base)
            out = git(self.raiz, "diff", "--numstat", self.base)
        else:
            self.titulo.setText("Mudados agora (não commitados):")
            out = git(self.raiz, "diff", "--numstat", "HEAD")
            novos = [l[3:] for l in git(self.raiz, "status", "--porcelain").splitlines() if l.startswith("??")]
            out += "".join("-\t-\t%s (novo)\n" % n for n in novos)
        linhas = [l.split("\t") for l in out.splitlines() if l.count("\t") >= 2]
        self.arqs.setRowCount(len(linhas))
        mais = menos = 0
        for r, (a, b, f) in enumerate(linhas):
            for c, x in enumerate([f, a, b]):
                item = W.QTableWidgetItem(x)
                if c == 1:
                    item.setForeground(QtGui.QColor("#3a9d4a"))
                if c == 2:
                    item.setForeground(QtGui.QColor("#e53935"))
                self.arqs.setItem(r, c, item)
            mais += int(a) if a.isdigit() else 0
            menos += int(b) if b.isdigit() else 0
        self.total.setText("%d arquivo(s) · +%d −%d linhas" % (len(linhas), mais, menos))
        self.txt.clear()
        if not linhas and out.startswith("("):
            self.txt.setPlainText(out)

    def _diff(self):
        r = self.arqs.currentRow()
        if r < 0 or not self.arqs.item(r, 0):
            return
        f = self.arqs.item(r, 0).text()
        if f.endswith(" (novo)"):
            self.txt.setPlainText("(arquivo novo, ainda fora do git)")
            return
        self.txt.setPlainText(git(self.raiz, "diff", self.base or "HEAD", "--", f) or "(sem diferença de texto)")


def criar(raiz):
    return Aba(raiz)
