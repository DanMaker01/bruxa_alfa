# navegar.py - ir de uma aba para outra (ex.: duplo clique numa fala abre o evento na aba Eventos).
# A janela central se registra aqui ao abrir.
import os

central = None


def aba(nome):
    """Mostra a aba `nome` (módulo em abas/) e devolve o widget dela (ou None)."""
    if central is None:
        return None
    return central.mostrar(nome)


def abrir_evento(evento, pag=None, cmd=None):
    """Abre o evento (id ou caminho) na aba Eventos, na página e no comando dados (0 = primeiro)."""
    w = aba("eventos")
    if w is None or not hasattr(w, "abrir"):
        return False
    if not os.path.isabs(str(evento)):
        evento = os.path.join(central.raiz, "dados", "eventos", str(evento) + ".tres")
    return w.abrir(evento, pag, cmd)


def abrir_uso(u):
    """Abre um indice.Uso: evento na aba Eventos; os outros não fazem nada (a aba mostra o caminho)."""
    if u.evento:
        return abrir_evento(u.evento, u.pag, u.cmd)
    return False
