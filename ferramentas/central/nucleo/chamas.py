# chamas.py - curvas de aproveitamento conforme a cor da chama (usa o simulador do caldeirão).
# A subida da temperatura não depende do item: simula uma vez por chama (acender, esperar a cor
# firmar, jogar 1 item, cozinhar) e guarda o histórico; depois cada item é só avaliado nele.
from PySide6 import QtGui

SEG_SIM = 300.0     # quanto tempo de caldo simular por chama
_hist = {}          # estado -> (t0, [(t, T)])


def cor(sim, estado, alfa=255):
    e = sim.ESTADO.get(estado)
    c = QtGui.QColor.fromRgbF(*e["cor"][:3]) if e else QtGui.QColor("#888")
    c.setAlpha(alfa)
    return c


def estados(sim):
    """As chamas que se pode pedir numa receita (sem 'apagado')."""
    return [e for e in sim.ESTADOS if e["id"] != "apagado"]


def historico(sim, estado):
    if estado not in _hist:
        fake = {"id": "_teste", "A": [[1.0 if i == j else 0.0 for j in range(5)] for i in range(5)],
                "m": 0.0, "s_menos": 1000.0, "s_mais": 1000.0, "T_min": 0.0, "k_min": 0.25, "T_max": 0.0, "k_max": 0.25,
                "t_min": 0.0, "h_min": 0.25, "t_max": 0.0, "h_max": 0.25}
        rec = {"chave": "_teste", "passos": [{"tipo": "chama", "estado": estado},
                                             {"tipo": "ingrediente", "item": "_teste", "qtd": 1, "seg": SEG_SIM}]}
        r = sim.simular(rec, {"_teste": fake}, sim.Jogadora())
        t0 = r["entradas"][0][0] if r["entradas"] else 0.0
        _hist[estado] = (t0, [(h[0], h[1]) for h in r["hist"]])
    return _hist[estado]


def curva_item(sim, item, estado, seg_max, n=120):
    """[(segundos no caldo, aproveitamento)] para 1 item jogado na chama `estado` já firme."""
    t0, h = historico(sim, estado)
    seg_max = min(seg_max, SEG_SIM)
    return [(s, sim.diagnostico(item, t0, h, t0 + s)["a"]) for s in [seg_max * k / n for k in range(1, n + 1)]]
