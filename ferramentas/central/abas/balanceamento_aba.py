# balanceamento_aba.py - aba Balanceamento: o balanceamento.py (receitas, sensibilidade,
# Monte Carlo, testes...) dentro da central. Precisa de matplotlib.
import os
import sys

from PySide6 import QtCore

TITULO = "Balanceamento"
PASTA = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def criar(raiz):
    if PASTA not in sys.path:
        sys.path.insert(0, PASTA)
    import balanceamento
    j = balanceamento.interface(so_janela=True)
    j.setWindowFlags(QtCore.Qt.Widget)
    return j
