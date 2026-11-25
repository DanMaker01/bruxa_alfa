# tres_simples.py - ler e trocar campos simples de um .tres do Godot sem reescrever o resto
# (o arquivo fica igual, só a linha do campo muda). Para recursos com sub-recursos (eventos,
# efeitos) use o motor completo do editor de eventos (ver nucleo/motor.py).
import glob
import os
import re

TRACOS = ["O", "C", "E", "A", "N"]
NOMES_TRACOS = {"O": "Abertura", "C": "Conscienciosidade", "E": "Extroversão", "A": "Amabilidade", "N": "Neuroticismo"}


def achar_projeto(inicio=None):
    p = os.path.abspath(inicio or os.path.dirname(__file__))
    for _ in range(8):
        if os.path.exists(os.path.join(p, "project.godot")):
            return p
        p = os.path.dirname(p)
    return None


def ler(caminho):
    with open(caminho, encoding="utf-8") as f:
        return f.read()


def escrever(caminho, texto):
    with open(caminho, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)


def classe(t):
    m = re.search(r'script_class="([^"]+)"', t.split("\n", 1)[0])
    return m.group(1) if m else ""


def listar(raiz, padrao, script_class):
    """[(caminho, texto)] dos .tres que casam com o padrão e são da classe."""
    out = []
    for p in sorted(glob.glob(os.path.join(raiz, padrao), recursive=True)):
        t = ler(p)
        if classe(t) == script_class:
            out.append((p, t))
    return out


def _secao_resource(t):
    i = t.find("\n[resource]")
    return (i + 1, len(t)) if i >= 0 else (0, len(t))


_RE_STR = r'"((?:[^"\\]|\\.)*)"'


def ler_campo(t, campo, padrao=None):
    a, b = _secao_resource(t)
    sec = t[a:b]
    m = re.search(r"^%s = %s" % (re.escape(campo), _RE_STR), sec, re.M | re.S)
    if m:
        return m.group(1).replace('\\"', '"').replace("\\\\", "\\")
    m = re.search(r"^%s = (.+)$" % re.escape(campo), sec, re.M)
    if not m:
        return padrao
    v = m.group(1).strip()
    if v in ("true", "false"):
        return v == "true"
    try:
        return float(v)
    except ValueError:
        return v


def _fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        f = float(v)
        return repr(round(f, 6)) if f != int(f) else "%d.0" % int(f)
    s = str(v).replace("\\", "\\\\").replace('"', '\\"')
    return '"%s"' % s


def gravar_campo(t, campo, valor):
    """Troca (ou acrescenta logo depois do script) 'campo = valor' na seção [resource]."""
    a, b = _secao_resource(t)
    sec = t[a:b]
    novo = "%s = %s" % (campo, _fmt(valor))
    pad_str = r"^%s = %s" % (re.escape(campo), _RE_STR)
    if re.search(pad_str, sec, re.M | re.S):
        sec = re.sub(pad_str, lambda m: novo, sec, count=1, flags=re.M | re.S)
    elif re.search(r"^%s = .+$" % re.escape(campo), sec, re.M):
        sec = re.sub(r"^%s = .+$" % re.escape(campo), lambda m: novo, sec, count=1, flags=re.M)
    else:
        m = re.search(r"^script = .+$", sec, re.M)
        pos = m.end() if m else len(sec.rstrip("\n"))
        sec = sec[:pos] + "\n" + novo + sec[pos:]
    return t[:a] + sec + t[b:]


def identidade():
    return [[1.0 if i == j else 0.0 for j in range(5)] for i in range(5)]


def ler_matriz(t, campo="A"):
    m = re.search(r"^%s = Array\[PackedFloat32Array\]\(\[(.*)\]\)$" % campo, t, re.M)
    if not m:
        return identidade()
    linhas = re.findall(r"PackedFloat32Array\(([^)]*)\)", m.group(1))
    M = [[float(x) for x in l.split(",")] for l in linhas]
    return M if len(M) == 5 and all(len(l) == 5 for l in M) else identidade()


def gravar_matriz(t, M, campo="A"):
    def num(x):
        x = round(float(x), 6)
        return ("%d" % x) if x == int(x) else repr(x)
    linha = "%s = Array[PackedFloat32Array]([%s])" % (
        campo, ", ".join("PackedFloat32Array(%s)" % ", ".join(num(x) for x in l) for l in M))
    if re.search(r"^%s = Array\[PackedFloat32Array\]" % campo, t, re.M):
        return re.sub(r"^%s = Array\[PackedFloat32Array\].*$" % campo, lambda m: linha, t, count=1, flags=re.M)
    a, b = _secao_resource(t)
    return t[:b].rstrip("\n") + "\n" + linha + "\n" + t[b:]


def mult_vetor(M, p):
    return [sum(M[i][j] * p[j] for j in range(5)) for i in range(5)]


def descrever_matriz(M, limite=0.005):
    """Frases curtas do que a matriz faz: 'N × 0,56 (cai 44%)', 'C recebe 30% de O'."""
    out = []
    for i, tr in enumerate(TRACOS):
        d = M[i][i]
        if abs(d - 1.0) > limite:
            if d < 0:
                out.append("%s inverte (× %.2f)" % (tr, d))
            else:
                out.append("%s × %.2f (%s %d%%)" % (tr, d, "sobe" if d > 1 else "cai", round(abs(d - 1) * 100)))
        for j, tr2 in enumerate(TRACOS):
            if i != j and abs(M[i][j]) > limite:
                out.append("%s %s %d%% de %s" % (tr, "recebe" if M[i][j] > 0 else "perde", round(abs(M[i][j]) * 100), tr2))
    return out or ["não muda nada (identidade)"]


# ---------------------------------------------------------------- banco.tres
def ids_no_banco(raiz, lista):
    t = ler(os.path.join(raiz, "dados", "banco.tres"))
    ext = {i: p for p, i in re.findall(r'path="res://([^"]+)" id="([^"]+)"', t)}
    m = re.search(r"^%s = Array\[[^\]]+\]\(\[(.*)\]\)$" % lista, t, re.M)
    if not m:
        return set()
    return {os.path.splitext(os.path.basename(ext.get(i, "")))[0] for i in re.findall(r'ExtResource\("([^"]+)"\)', m.group(1))}


def registrar_no_banco(raiz, caminho_res, lista):
    arq = os.path.join(raiz, "dados", "banco.tres")
    t = ler(arq)
    if caminho_res in t:
        return False
    nid = "cx_%s" % os.path.splitext(os.path.basename(caminho_res))[0]
    t = t.replace("\n\n[resource]", '\n[ext_resource type="Resource" path="%s" id="%s"]\n\n[resource]' % (caminho_res, nid), 1)
    t = re.sub(r"^(%s = Array\[[^\]]+\]\(\[.*)(\]\))$" % lista, lambda m: m.group(1) + ', ExtResource("%s")' % nid + m.group(2),
               t, count=1, flags=re.M)
    escrever(arq, t)
    return True


# ---------------------------------------------------------------- borda (igual ao jogo, CmdAplicarPocao)
BORDAS = ["corte", "projetiva", "tanh"]


def _interno(p, borda):
    import math
    x = max(-0.999, min(0.999, p / 10.0))
    if borda == "projetiva":
        return 10.0 * x / (1.0 - abs(x))
    if borda == "tanh":
        return 10.0 * math.atanh(x)
    return p


def _traco(u, borda):
    import math
    if borda == "projetiva":
        return u / (1.0 + abs(u) / 10.0)
    if borda == "tanh":
        return 10.0 * math.tanh(u / 10.0)
    return max(-10.0, min(10.0, u))


def aplicar(M, p, borda="corte", doses=1):
    """p' = M·p com a borda do jogo, 'doses' vezes."""
    for _ in range(doses):
        u = [_interno(x, borda) for x in p]
        p = [_traco(v, borda) for v in mult_vetor(M, u)]
    return p
