# motor.py - acesso ao "motor" das ferramentas antigas, sem abrir as janelas delas:
#   eventos(): módulos do editor de eventos (modelo, tres, widgets) - leitor/gravador de .tres
#              completo, esquema dos comandos lido dos scripts do jogo, formulários de campos
#   balanceamento(): módulos do balanceamento (simulador_caldeirao como sim, balanceamento como bal)
import os
import sys

FERRAMENTAS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PASTA_EVENTOS = os.path.join(FERRAMENTAS, "editor_eventos")
_projetos = {}


def eventos():
    if PASTA_EVENTOS not in sys.path:
        sys.path.insert(0, PASTA_EVENTOS)
    import modelo
    import tres
    import widgets
    return modelo, tres, widgets


def projeto(raiz):
    """modelo.Projeto (classes e comandos lidos dos scripts do jogo), um por raiz."""
    modelo, _, _ = eventos()
    if raiz not in _projetos:
        _projetos[raiz] = modelo.Projeto(raiz)
    return _projetos[raiz]


def balanceamento():
    if FERRAMENTAS not in sys.path:
        sys.path.insert(0, FERRAMENTAS)
    import simulador_caldeirao as sim
    import balanceamento as bal
    return sim, bal
