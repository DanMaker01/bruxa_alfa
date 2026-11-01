# esquema.py - lê os scripts .gd (comandos, PaginaData, Condicao, PassoRota...) e
# monta a lista de campos de cada classe: nome, tipo, padrão, enum, dicas e descrição.
# Assim o editor acompanha o jogo: um comando ou campo novo aparece sozinho.

import os
import re

import tres


class Campo:
    def __init__(self, nome):
        self.nome = nome
        self.tipo = "Variant"      # bool int float String Vector2 Color enum Res Array
        self.classe = None         # tipo declarado original (ex.: Personagem, Array[String])
        self.enum = None           # lista de nomes (enum)
        self.elem = None           # tipo do elemento (Array)
        self.padrao = None         # valor padrão (valor tres) ou None se desconhecido
        self.tem_padrao = False
        self.dica = None           # multiline | file:*.mp3 | range:a,b,c | enum_str:...
        self.doc = ""
        self.grupo = ""
        self.visivel_se = None     # (campo, [valores]) heurística/regras

    def __repr__(self):
        return "Campo(%s:%s=%r)" % (self.nome, self.tipo, self.padrao)


class Classe:
    def __init__(self, caminho):
        self.caminho = caminho              # res://...
        self.arquivo = ""
        self.nome = ""                      # class_name
        self.extends = ""
        self.descricao = ""                 # comentário do topo
        self.enums = {}                     # nome -> [itens]
        self.consts = {}                    # nome -> texto
        self.campos = []                    # [Campo]

    def campo(self, nome):
        for c in self.campos:
            if c.nome == nome:
                return c
        return None

    @property
    def ordem(self):
        return [c.nome for c in self.campos]


_RE_ENUM = re.compile(r"^enum\s+(\w+)\s*\{(.*?)\}", re.S | re.M)
_RE_CONST = re.compile(r"^const\s+(\w+)\s*(?::\s*[\w\[\]]+)?\s*:?=\s*(.+)$", re.M)
_RE_EXPORT = re.compile(r"^@export(\w*)(\((.*?)\))?\s+var\s+(\w+)\s*(?::\s*([\w\.\[\]]+))?\s*(?::?=\s*(.*?))?\s*(:)?\s*$")


def _limpa_comentario(s):
    out = []
    dentro = False
    for i, c in enumerate(s):
        if c == '"':
            dentro = not dentro
        if c == "#" and not dentro:
            break
        out.append(c)
    return "".join(out)


def ler_classe(caminho_disco, caminho_res):
    cl = Classe(caminho_res)
    cl.arquivo = caminho_disco
    with open(caminho_disco, encoding="utf-8") as f:
        txt = f.read()
    linhas = txt.splitlines()
    # descrição: comentários do topo (antes de class_name/extends)
    desc = []
    for ln in linhas:
        s = ln.strip()
        if s.startswith("#"):
            t = s.lstrip("#").strip()
            if t.endswith(".gd") or t.startswith("====="):
                continue
            desc.append(t)
        elif s.startswith("@tool") or s == "":
            if desc and s == "":
                desc.append("")
            continue
        else:
            break
    cl.descricao = "\n".join(desc).strip()
    m = re.search(r"^class_name\s+(\w+)", txt, re.M)
    cl.nome = m.group(1) if m else os.path.splitext(os.path.basename(caminho_disco))[0]
    m = re.search(r"^extends\s+(\w+)", txt, re.M)
    cl.extends = m.group(1) if m else ""
    for m in _RE_ENUM.finditer(txt):
        corpo = "\n".join(_limpa_comentario(l) for l in m.group(2).splitlines())
        itens = [x.strip().split("=")[0].strip() for x in corpo.split(",")]
        cl.enums[m.group(1)] = [x for x in itens if x]
    for m in _RE_CONST.finditer(txt):
        cl.consts[m.group(1)] = _limpa_comentario(m.group(2)).strip()

    doc = []
    grupo = ""
    i = 0
    while i < len(linhas):
        ln = linhas[i]
        s = ln.strip()
        if s.startswith("##"):
            doc.append(s[2:].strip())
            i += 1
            continue
        if s.startswith("@export_group"):
            g = re.search(r'"([^"]*)"', s)
            grupo = g.group(1) if g else ""
            doc = []
            i += 1
            continue
        if s.startswith("@export") and " var " in s:
            m = _RE_EXPORT.match(_limpa_comentario(s).strip())
            if m:
                tipo_exp, args, nome, tipo, padrao, setter = m.group(1), m.group(3), m.group(4), m.group(5), m.group(6), m.group(7)
                # só no inspetor (getter próprio): não é salvo, pula
                prox = linhas[i + 1].strip() if i + 1 < len(linhas) else ""
                if setter and prox.startswith("get"):
                    doc = []
                    i += 1
                    continue
                c = Campo(nome)
                c.doc = " ".join(doc).strip()
                c.grupo = grupo
                c.classe = tipo
                _tipo(cl, c, tipo, tipo_exp, args)
                if padrao is not None and padrao != "":
                    c.padrao, c.tem_padrao = _padrao(cl, c, padrao.rstrip(":").strip())
                else:
                    c.padrao, c.tem_padrao = _padrao_tipo(c)
                cl.campos.append(c)
            doc = []
            i += 1
            continue
        if s and not s.startswith("#"):
            doc = []
        i += 1
    return cl


ESCALARES = {"bool", "int", "float", "String", "Vector2", "Color", "StringName"}


def _tipo(cl, c, tipo, tipo_exp, args):
    if tipo_exp == "_multiline":
        c.dica = "multiline"
    elif tipo_exp == "_file":
        c.dica = "file:" + (re.findall(r'"([^"]*)"', args or "") or ["*"])[0]
    elif tipo_exp == "_range":
        c.dica = "range:" + (args or "")
    elif tipo_exp == "_enum":
        c.dica = "enum_str"
        c.enum = re.findall(r'"([^"]*)"', args or "")
    if tipo is None:
        c.tipo = "Variant"
        return
    if tipo.startswith("Array["):
        c.tipo = "Array"
        c.elem = tipo[6:-1]
        return
    if tipo in ESCALARES:
        c.tipo = tipo
        return
    # enum local ou Outro.Enum
    if tipo in cl.enums:
        c.tipo = "enum"
        c.enum = cl.enums[tipo]
        c.classe = tipo
        return
    if "." in tipo:
        c.tipo = "enum"
        c.classe = tipo    # resolvido depois (Projeto.resolver_enums)
        return
    c.tipo = "Res"


def _padrao_tipo(c):
    return {
        "bool": (False, True), "int": (tres.GInt(0), True), "float": (tres.GFloat(0.0), True),
        "String": ("", True), "enum": (tres.GInt(0), True),
    }.get(c.tipo, (None, c.tipo in ("Res",)))


def _padrao(cl, c, expr):
    expr = expr.strip()
    if expr in cl.consts and expr != cl.consts[expr]:
        return _padrao(cl, c, cl.consts[expr])
    if c.tipo == "enum" or (c.dica == "enum_str"):
        partes = expr.split(".")
        if len(partes) >= 2:
            c._enum_padrao_nome = partes[-1]
            if c.enum and partes[-1] in c.enum:
                return tres.GInt(c.enum.index(partes[-1])), True
            return None, False   # resolvido depois
        try:
            return tres.GInt(int(expr)), True
        except ValueError:
            return tres.GInt(0), True
    if expr in ("true", "false"):
        return expr == "true", True
    if expr == "null":
        return None, True
    if expr in ("Vector2.ZERO",):
        return tres.vec2(0, 0), True
    if expr in ("Vector2.ONE",):
        return tres.vec2(1, 1), True
    if expr.startswith("Color."):
        cores = {"WHITE": (1, 1, 1, 1), "BLACK": (0, 0, 0, 1), "RED": (1, 0, 0, 1), "TRANSPARENT": (1, 1, 1, 0)}
        rgba = cores.get(expr[6:])
        if rgba:
            return tres.Call("Color", [tres.GInt(x) if float(x).is_integer() else tres.GFloat(x) for x in rgba]), True
        return None, False
    if expr.startswith("[]"):
        return [], True
    try:
        v = tres._Leitor(expr).valor()
        if isinstance(v, tres.GInt) and c.tipo == "float":
            v = tres.GFloat(float(v))
        if isinstance(v, tres.Call) and v.nome == "Color" and len(v.args) == 3:
            v.args.append(tres.GInt(1))
        return v, True
    except Exception:
        return None, False


# ---------------------------------------------------------------------------
# Regras de visibilidade (o que o _validate_property de cada script esconde)
# ---------------------------------------------------------------------------
_REGRAS_FIXAS = {
    "Condicao": {
        "variavel": ("tipo", ["VARIAVEL", "PERSONALIDADE", "ITEM_NOME"]),
        "item": ("tipo", ["ITEM"]),
        "traco": ("tipo", ["PERSONALIDADE"]),
        "direcao": ("tipo", ["DIRECAO_PLAYER"]),
        "letra": ("tipo", ["SELF_VAR"]),
        "valor": ("tipo", ["VARIAVEL", "ITEM", "PERSONALIDADE", "POSICAO_X", "POSICAO_Y", "SELF_VAR", "ITEM_NOME"]),
    },
    "PassoRota": {
        "distancia": ("tipo", ["MOVER", "FRENTE", "TRAS", "ALEATORIO", "PULAR"]),
        "altura": ("tipo", ["PULAR"]),
        "olhar": ("tipo", ["OLHAR"]),
        "fixar": ("tipo", ["FIXAR_DIRECAO"]),
        "segundos": ("tipo", ["ESPERAR", "BALAO"]),
        "segundos_max": ("tipo", ["ESPERAR"]),
        "emocao": ("tipo", ["BALAO"]),
        "velocidade": ("tipo", ["VELOCIDADE"]),
        "animacao": ("tipo", ["ANIMACAO"]),
    },
    "CmdCamera": {
        "tempo": ("acao", ["MOVER", "VOLTAR"]),
        "intensidade": ("acao", ["TREMER"]),
        "velocidade": ("acao", ["TREMER"]),
        "duracao": ("acao", ["TREMER"]),
    },
    "CmdItem": {
        "item": ("acao", ["ADICIONAR", "REMOVER"]),
        "quantidade": ("acao", ["ADICIONAR", "REMOVER"]),
    },
    "CmdMover": {
        "x": ("destino", ["X"]),
        "manter_y": ("alvo", ["EVENTO"]),
    },
    "PaginaData": {
        "rota": ("movimento", ["ROTA"]),
        "rota_repetir": ("movimento", ["ROTA"]),
        "rota_pular_se_bloqueado": ("movimento", ["ROTA"]),
        "rota_velocidade": ("movimento", ["ROTA"]),
        "rota_raio": ("movimento", ["ROTA"]),
    },
}


def aplicar_regras(cl):
    fixas = _REGRAS_FIXAS.get(cl.nome, {})
    # heurística: "(alvo = EVENTO)" / "(destino = X, alvo = EVENTO)" na descrição do campo
    enums = {c.nome: c for c in cl.campos if c.tipo == "enum" and c.enum}
    for c in cl.campos:
        regras = []
        for campo, valor in re.findall(r"(\w+)\s*=\s*([A-Z][A-Z_]*)\b", c.doc):
            if campo in enums and valor in enums[campo].enum and campo != c.nome:
                regras.append((campo, [valor]))
        if regras:
            c.visivel_se = regras[0] if len(regras) == 1 else regras
        if c.nome in fixas:
            c.visivel_se = fixas[c.nome]


def visivel(cl, campo, res):
    """O campo deve aparecer para este recurso?"""
    regra = campo.visivel_se
    if not regra:
        return True
    regras = regra if isinstance(regra, list) else [regra]
    for nome, valores in regras:
        c2 = cl.campo(nome)
        if not c2 or not c2.enum:
            continue
        v = res.props.get(nome, c2.padrao)
        try:
            atual = c2.enum[int(v)]
        except (TypeError, ValueError, IndexError):
            continue
        if atual not in valores:
            return False
    return True
