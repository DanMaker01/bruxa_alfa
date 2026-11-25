#!/usr/bin/env python3
# central.py - ferramenta única do bruxa_alfa: uma janela com abas.
#
#   python ferramentas/central/central.py        (precisa de: pip install PySide6; Balanceamento: matplotlib)
#
# nucleo/: peças comuns (ler/gravar .tres, tabela genérica, matriz, pentagrama, gráficos,
#          acesso ao motor do editor de eventos e do simulador).
# abas/:   cada aba é um módulo com TITULO e criar(raiz) -> QWidget. A aba só é carregada
# quando é aberta pela primeira vez (a janela abre rápido e uma aba com erro não derruba
# as outras). Para criar uma aba nova: um arquivo em abas/ e o nome dele em ABAS abaixo.
# As ferramentas antigas (balanceamento.py, editor_eventos.py) continuam funcionando sozinhas;
# as abas Eventos e Balanceamento são próprias, mas usam o motor delas.
import importlib
import os
import sys
import traceback

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

try:
    from PySide6 import QtCore, QtWidgets as W
except ImportError:
    print("A ferramenta central precisa do PySide6.  Instale com:\n\n    pip install PySide6 matplotlib\n")
    sys.exit(1)

from nucleo import navegar
from nucleo.tres_simples import achar_projeto

# ordem das abas (módulos em abas/)
ABAS = ["personalidades", "itens", "catalogo", "receitas", "eventos", "falas", "flags", "onde_usado", "mapas",
        "mercadores", "chamas", "balanceamento", "calibracao", "verificacao", "projeto"]


class Central(W.QMainWindow):
    def __init__(self, raiz):
        super().__init__()
        self.raiz = raiz
        self.setWindowTitle("Bruxa - ferramentas (%s)" % os.path.basename(raiz))
        self.resize(1300, 850)
        self.tabs = W.QTabWidget()
        self.setCentralWidget(self.tabs)
        self.modulos = {}
        self.feitas = {}
        for nome in ABAS:
            titulo = nome
            try:
                mod = importlib.import_module("abas." + nome)
                titulo = getattr(mod, "TITULO", nome)
                self.modulos[nome] = mod
            except Exception:
                self.modulos[nome] = None
                self.feitas[nome] = self._erro(traceback.format_exc())
            vaga = W.QWidget()
            W.QVBoxLayout(vaga)
            self.tabs.addTab(vaga, titulo)
        self.tabs.currentChanged.connect(self._abrir)
        navegar.central = self
        self._abrir(0)

    def _erro(self, txt):
        t = W.QPlainTextEdit(txt)
        t.setReadOnly(True)
        return t

    def _abrir(self, i):
        nome = ABAS[i]
        vaga = self.tabs.widget(i)
        if nome in self.feitas and self.feitas[nome].parent() is vaga:
            return
        if nome not in self.feitas:
            W.QApplication.setOverrideCursor(QtCore.Qt.WaitCursor)
            try:
                self.feitas[nome] = self.modulos[nome].criar(self.raiz)
            except Exception:
                self.feitas[nome] = self._erro("Erro ao abrir a aba:\n\n" + traceback.format_exc())
            finally:
                W.QApplication.restoreOverrideCursor()
        vaga.layout().setContentsMargins(0, 0, 0, 0)
        vaga.layout().addWidget(self.feitas[nome])

    def mostrar(self, nome):
        """Vai para a aba `nome` e devolve o widget dela."""
        if nome not in ABAS:
            return None
        i = ABAS.index(nome)
        self.tabs.setCurrentIndex(i)
        self._abrir(i)
        return self.feitas.get(nome)

    def closeEvent(self, e):
        sujas = [n for n, w in self.feitas.items() if getattr(w, "tem_mudancas", lambda: False)()]
        if sujas:
            r = W.QMessageBox.question(self, "Sair", "Há mudanças não salvas em: %s.\nSair mesmo assim?" % ", ".join(sujas))
            if r != W.QMessageBox.Yes:
                e.ignore()
                return
        e.accept()


def main():
    app = W.QApplication.instance() or W.QApplication(sys.argv)
    app.setStyle("Fusion")
    raiz = sys.argv[1] if len(sys.argv) > 1 else achar_projeto(AQUI)
    if not raiz or not os.path.exists(os.path.join(raiz, "project.godot")):
        raiz = W.QFileDialog.getExistingDirectory(None, "Pasta do projeto Godot (com project.godot)")
        if not raiz:
            return 1
    j = Central(raiz)
    j.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
