# tres.py - leitura e escrita de recursos de texto do Godot 4 (.tres)
#
# Lê o arquivo inteiro para um grafo de objetos Python e escreve de volta no mesmo
# formato do Godot. Um arquivo lido e escrito sem mudanças sai idêntico.
#
#   doc = TresDoc.load(caminho)      doc.root -> Res (o [resource])
#   texto = doc.dumps()              doc.save(caminho)
#
# Valores:
#   int / float (GInt / GFloat guardam o texto original)   str   bool   None
#   StrName("x")  ->  &"x"           NodePathV("x") -> ^"x"
#   ExtRef(path, tipo, uid)          referência a arquivo externo
#   Res                              sub-recurso (o próprio objeto)
#   Call(nome, [args])               Vector2(1, 2), Color(...), PackedFloat32Array(...)...
#   TypedArray(tipo, [itens])        Array[ExtResource("x")]([...])
#   list                             [a, b]
#   GDict (dict ordenado)            {"a": 1}
#   Ident("inf")                     identificador solto (inf, nan, ...)

import os
import random
import re
import string
import heapq


# ---------------------------------------------------------------------------
# Tipos de valor
# ---------------------------------------------------------------------------
class GInt(int):
    txt = None


class GFloat(float):
    txt = None


class StrName(str):
    pass


class NodePathV(str):
    pass


class Ident(str):
    pass


class ExtRef:
    __slots__ = ("path", "tipo", "uid")

    def __init__(self, path, tipo="Resource", uid=None):
        self.path = path
        self.tipo = tipo
        self.uid = uid

    def __eq__(self, o):
        return isinstance(o, ExtRef) and o.path == self.path

    def __hash__(self):
        return hash(("ext", self.path))

    def __repr__(self):
        return "ExtRef(%r)" % self.path

    def __deepcopy__(self, memo):
        return self   # imutável na prática


class Call:
    __slots__ = ("nome", "args")

    def __init__(self, nome, args=None):
        self.nome = nome
        self.args = list(args or [])

    def __eq__(self, o):
        return isinstance(o, Call) and o.nome == self.nome and _eq_list(o.args, self.args)

    def __repr__(self):
        return "%s(%s)" % (self.nome, ", ".join(repr(a) for a in self.args))


class TypedArray:
    __slots__ = ("tipo", "itens")

    def __init__(self, tipo, itens=None):
        self.tipo = tipo      # valor: ExtRef (script) ou Ident("String") ...
        self.itens = list(itens or [])

    def __eq__(self, o):
        return isinstance(o, TypedArray) and _eq_val(o.tipo, self.tipo) and _eq_list(o.itens, self.itens)

    def __repr__(self):
        return "TypedArray(%r, %r)" % (self.tipo, self.itens)


class TypedDict:
    __slots__ = ("tipos", "d")

    def __init__(self, tipos, d):
        self.tipos = tipos
        self.d = d


class GDict(dict):
    multilinha = False


class Res:
    """Um recurso: [sub_resource] ou o [resource] raiz."""
    __slots__ = ("tipo", "rid", "props")

    def __init__(self, tipo="Resource", props=None, rid=None):
        self.tipo = tipo
        self.rid = rid
        self.props = dict(props or {})

    @property
    def script(self):
        s = self.props.get("script")
        return s.path if isinstance(s, ExtRef) else None

    def get(self, k, padrao=None):
        return self.props.get(k, padrao)

    def __repr__(self):
        return "Res(%s, %s)" % (self.script or self.tipo, self.rid)


def _eq_val(a, b):
    if isinstance(a, Res) or isinstance(b, Res):
        return a is b
    if isinstance(a, float) or isinstance(b, float):
        try:
            return float(a) == float(b)
        except (TypeError, ValueError):
            return False
    if isinstance(a, list) and isinstance(b, list):
        return _eq_list(a, b)
    return type(a) is type(b) and a == b if not isinstance(a, (int, str)) else a == b


def _eq_list(a, b):
    return len(a) == len(b) and all(_eq_val(x, y) for x, y in zip(a, b))


def valores_iguais(a, b):
    """Comparação "de conteúdo" (sub-recursos comparados pelos campos)."""
    if isinstance(a, Res) and isinstance(b, Res):
        if a is b:
            return True
        if a.props.keys() != b.props.keys():
            return False
        return all(valores_iguais(a.props[k], b.props[k]) for k in a.props)
    if isinstance(a, TypedArray) and isinstance(b, TypedArray):
        return valores_iguais(a.tipo, b.tipo) and len(a.itens) == len(b.itens) and \
            all(valores_iguais(x, y) for x, y in zip(a.itens, b.itens))
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(valores_iguais(x, y) for x, y in zip(a, b))
    if isinstance(a, Call) and isinstance(b, Call):
        return a.nome == b.nome and len(a.args) == len(b.args) and \
            all(valores_iguais(x, y) for x, y in zip(a.args, b.args))
    if isinstance(a, bool) or isinstance(b, bool):
        return isinstance(a, bool) and isinstance(b, bool) and a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(float(a) - float(b)) < 1e-9
    if isinstance(a, ExtRef) and isinstance(b, ExtRef):
        return a.path == b.path
    return type(a) is type(b) and a == b if type(a) in (StrName, NodePathV, Ident) or type(b) in (StrName, NodePathV, Ident) else a == b


# ---------------------------------------------------------------------------
# Leitura
# ---------------------------------------------------------------------------
class ErroTres(Exception):
    pass


class _SubRef:
    __slots__ = ("rid",)

    def __init__(self, rid):
        self.rid = rid


class _ExtId:
    __slots__ = ("eid",)

    def __init__(self, eid):
        self.eid = eid


_NUM = re.compile(r"[-+]?(\d+\.?\d*([eE][-+]?\d+)?|\.\d+([eE][-+]?\d+)?)")
_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


class _Leitor:
    def __init__(self, txt):
        self.t = txt
        self.i = 0
        self.n = len(txt)

    def erro(self, msg):
        linha = self.t.count("\n", 0, self.i) + 1
        raise ErroTres("%s (linha %d)" % (msg, linha))

    def ws(self, quebras=True):
        t, n = self.t, self.n
        while self.i < n:
            c = t[self.i]
            if c in " \t\r" or (quebras and c == "\n"):
                self.i += 1
            else:
                break

    def pega(self, c):
        self.ws()
        if self.i < self.n and self.t[self.i] == c:
            self.i += 1
            return True
        return False

    def espera(self, c):
        if not self.pega(c):
            self.erro("esperava %r" % c)

    def string(self):
        # self.t[self.i] == '"'
        self.i += 1
        t = self.t
        partes = []
        ini = self.i
        while True:
            j = self.i
            if j >= self.n:
                self.erro("string sem fim")
            c = t[j]
            if c == '"':
                partes.append(t[ini:j])
                self.i = j + 1
                return "".join(partes)
            if c == "\\":
                partes.append(t[ini:j])
                e = t[j + 1]
                mapa = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\", "b": "\b", "f": "\f", "'": "'"}
                if e == "u":
                    partes.append(chr(int(t[j + 2:j + 6], 16)))
                    self.i = j + 6
                elif e == "U":
                    partes.append(chr(int(t[j + 2:j + 8], 16)))
                    self.i = j + 8
                else:
                    partes.append(mapa.get(e, e))
                    self.i = j + 2
                ini = self.i
                continue
            self.i = j + 1

    def valor(self):
        self.ws()
        if self.i >= self.n:
            self.erro("valor esperado")
        t = self.t
        c = t[self.i]
        if c == '"':
            return self.string()
        if c == "&" and t[self.i + 1:self.i + 2] == '"':
            self.i += 1
            return StrName(self.string())
        if c == "^" and t[self.i + 1:self.i + 2] == '"':
            self.i += 1
            return NodePathV(self.string())
        if c == "[":
            self.i += 1
            itens = []
            if self.pega("]"):
                return itens
            while True:
                itens.append(self.valor())
                if self.pega(","):
                    if self.pega("]"):
                        return itens
                    continue
                self.espera("]")
                return itens
        if c == "{":
            ini = self.i
            self.i += 1
            d = GDict()
            if self.pega("}"):
                return d
            d.multilinha = "\n" in t[ini:t.find(":", ini) if t.find(":", ini) > 0 else ini + 2]
            while True:
                k = self.valor()
                self.espera(":")
                v = self.valor()
                d[_chave(k)] = v
                if self.pega(","):
                    if self.pega("}"):
                        return d
                    continue
                self.espera("}")
                return d
        m = _NUM.match(t, self.i)
        if m and (c.isdigit() or c in "-+."):
            s = m.group(0)
            self.i = m.end()
            if re.fullmatch(r"[-+]?\d+", s):
                v = GInt(int(s))
            else:
                v = GFloat(float(s))
            v.txt = s
            return v
        m = _IDENT.match(t, self.i)
        if m:
            nome = m.group(0)
            self.i = m.end()
            if nome == "true":
                return True
            if nome == "false":
                return False
            if nome == "null":
                return None
            if nome in ("Array", "Dictionary") and self.i < self.n and t[self.i] == "[":
                self.i += 1
                tipos = [self.valor()]
                while self.pega(","):
                    tipos.append(self.valor())
                self.espera("]")
                self.espera("(")
                conteudo = self.valor()
                self.espera(")")
                if nome == "Array":
                    return TypedArray(tipos[0], conteudo)
                return TypedDict(tipos, conteudo)
            self.ws(False)
            if self.i < self.n and t[self.i] == "(":
                self.i += 1
                args = []
                if not self.pega(")"):
                    while True:
                        args.append(self.valor())
                        if self.pega(","):
                            continue
                        self.espera(")")
                        break
                if nome == "ExtResource":
                    return _ExtId(str(args[0]))
                if nome == "SubResource":
                    return _SubRef(str(args[0]))
                return Call(nome, args)
            return Ident(nome)
        self.erro("valor inválido %r" % t[self.i:self.i + 20])


def _chave(k):
    return k


_HDR_ATTR = re.compile(r'(\w+)=("(?:[^"\\]|\\.)*"|[^\s\]]+)')


def _ler_cabecalho(linha):
    # "[tag a=1 b="x"]"
    corpo = linha.strip()[1:-1]
    tag = corpo.split(None, 1)[0]
    attrs = {}
    for k, v in _HDR_ATTR.findall(corpo[len(tag):]):
        if v.startswith('"'):
            v = v[1:-1].replace('\\"', '"').replace("\\\\", "\\")
        attrs[k] = v
    return tag, attrs


class TresDoc:
    def __init__(self):
        self.cab_tag = "gd_resource"
        self.cab = {"type": "Resource", "format": "3"}
        self.root = Res()
        self.ext_ids = {}        # path -> id original
        self.ext_ordem = []      # ExtRef na ordem original
        self.sub_ordem = []      # Res na ordem original
        self.caminho = None

    # ------------------------------------------------------------------ load
    @classmethod
    def load(cls, caminho):
        with open(caminho, "r", encoding="utf-8") as f:
            txt = f.read()
        d = cls.loads(txt)
        d.caminho = caminho
        return d

    @classmethod
    def loads(cls, txt):
        doc = cls()
        L = _Leitor(txt)
        exts = {}            # id -> ExtRef
        subs = {}            # id -> Res
        atual = None
        crus = []            # (Res, [(k, v)])
        while True:
            L.ws()
            if L.i >= L.n:
                break
            c = txt[L.i]
            if c == ";":
                L.i = txt.find("\n", L.i) if txt.find("\n", L.i) >= 0 else L.n
                continue
            if c == "[" and (L.i == 0 or txt[L.i - 1] == "\n"):
                fim = txt.find("\n", L.i)
                fim = L.n if fim < 0 else fim
                linha = txt[L.i:fim]
                L.i = fim
                tag, a = _ler_cabecalho(linha)
                if tag in ("gd_resource", "gd_scene"):
                    doc.cab_tag = tag
                    doc.cab = a
                elif tag == "ext_resource":
                    e = ExtRef(a.get("path"), a.get("type", "Resource"), a.get("uid"))
                    exts[a["id"]] = e
                    doc.ext_ids[e.path] = a["id"]
                    doc.ext_ordem.append(e)
                elif tag == "sub_resource":
                    atual = Res(a.get("type", "Resource"), rid=a.get("id"))
                    subs[atual.rid] = atual
                    doc.sub_ordem.append(atual)
                    crus.append((atual, []))
                elif tag == "resource":
                    atual = doc.root
                    crus.append((atual, []))
                else:
                    L.erro("seção desconhecida: " + tag)
                continue
            # propriedade
            m = re.compile(r'[^=\n]+?(?=\s*=)').match(txt, L.i)
            if not m or atual is None:
                L.erro("propriedade inválida")
            chave = m.group(0).strip()
            L.i = m.end()
            L.espera("=")
            v = L.valor()
            crus[-1][1].append((chave, v))

        def resolve(v):
            if isinstance(v, _ExtId):
                if v.eid not in exts:
                    raise ErroTres("ExtResource inexistente: " + v.eid)
                return exts[v.eid]
            if isinstance(v, _SubRef):
                if v.rid not in subs:
                    raise ErroTres("SubResource inexistente: " + v.rid)
                return subs[v.rid]
            if isinstance(v, list):
                return [resolve(x) for x in v]
            if isinstance(v, GDict):
                nd = GDict((resolve(k), resolve(x)) for k, x in v.items())
                nd.multilinha = v.multilinha
                return nd
            if isinstance(v, TypedArray):
                return TypedArray(resolve(v.tipo), resolve(v.itens))
            if isinstance(v, TypedDict):
                return TypedDict([resolve(x) for x in v.tipos], resolve(v.d))
            if isinstance(v, Call):
                return Call(v.nome, [resolve(x) for x in v.args])
            return v

        for res, pares in crus:
            for k, v in pares:
                res.props[k] = resolve(v)
        return doc

    # ------------------------------------------------------------------ dump
    def dumps(self):
        root = self.root
        # 1) sub-recursos alcançáveis, dependências antes de quem usa
        # posição original por id do sub-recurso (as fotos do desfazer são cópias com o mesmo id)
        orig_idx = {r.rid: i for i, r in enumerate(self.sub_ordem) if r.rid}
        filhos = {}       # id(res) -> [Res]
        prio = {}
        visit_ordem = []
        objs = {}

        def coletar(v, acc):
            if isinstance(v, Res):
                acc.append(v)
            elif isinstance(v, list):
                for x in v:
                    coletar(x, acc)
            elif isinstance(v, GDict):
                for k, x in v.items():
                    coletar(k, acc)
                    coletar(x, acc)
            elif isinstance(v, TypedArray):
                coletar(v.itens, acc)
            elif isinstance(v, TypedDict):
                coletar(v.d, acc)
            elif isinstance(v, Call):
                coletar(v.args, acc)

        def dfs(r, prio_pai, prof):
            acc = []
            for v in r.props.values():
                coletar(v, acc)
            filhos[id(r)] = acc
            for c in acc:
                if id(c) in objs:
                    continue
                objs[id(c)] = c
                if c.rid in orig_idx:
                    p = float(orig_idx[c.rid])
                else:
                    p = prio_pai - 0.001 * (prof + 1)
                prio[id(c)] = p
                dfs(c, p, prof + 1)
                visit_ordem.append(c)

        dfs(root, float(len(self.sub_ordem) + 1), 0)
        post = {id(r): i for i, r in enumerate(visit_ordem)}
        # Kahn: filho antes do pai; entre os prontos, menor prioridade
        pendentes = {}
        pais = {}
        for r in visit_ordem:
            fs = [c for c in filhos[id(r)]]
            uniq = {id(c) for c in fs if c is not r}
            pendentes[id(r)] = len(uniq)
            for cid in uniq:
                pais.setdefault(cid, []).append(r)
        heap = [(prio[id(r)], post[id(r)], id(r)) for r in visit_ordem if pendentes[id(r)] == 0]
        heapq.heapify(heap)
        ordem = []
        feitos = set()
        while heap:
            _, _, rid = heapq.heappop(heap)
            if rid in feitos:
                continue
            feitos.add(rid)
            r = objs[rid]
            ordem.append(r)
            for p in pais.get(rid, []):
                pendentes[id(p)] -= 1
                if pendentes[id(p)] == 0:
                    heapq.heappush(heap, (prio[id(p)], post[id(p)], id(p)))
        if len(ordem) != len(visit_ordem):
            raise ErroTres("ciclo entre sub-recursos")

        # 2) ids dos sub-recursos
        usados = set()
        for r in ordem:
            if r.rid and r.rid not in usados:
                usados.add(r.rid)
            else:
                r.rid = None
        for r in ordem:
            if not r.rid:
                r.rid = _novo_id(usados, (r.tipo or "Resource") + "_")
                usados.add(r.rid)

        # 3) ext_resources usados (ordem original, novos no fim)
        ext_usados = []
        vistos = set()

        def coletar_ext(v):
            if isinstance(v, ExtRef):
                if v.path not in vistos:
                    vistos.add(v.path)
                    ext_usados.append(v)
            elif isinstance(v, Res):
                return
            elif isinstance(v, list):
                for x in v:
                    coletar_ext(x)
            elif isinstance(v, GDict):
                for k, x in v.items():
                    coletar_ext(k)
                    coletar_ext(x)
            elif isinstance(v, TypedArray):
                coletar_ext(v.tipo)
                coletar_ext(v.itens)
            elif isinstance(v, TypedDict):
                for x in v.tipos:
                    coletar_ext(x)
                coletar_ext(v.d)
            elif isinstance(v, Call):
                coletar_ext(v.args)

        for r in ordem + [root]:
            for v in r.props.values():
                coletar_ext(v)
        # mantém os ext_resources originais mesmo sem uso (o Godot também guarda alguns assim)
        for e in self.ext_ordem:
            if e.path not in vistos:
                vistos.add(e.path)
                ext_usados.append(e)
        pos_orig = {e.path: i for i, e in enumerate(self.ext_ordem)}
        _seq = {e.path: i for i, e in enumerate(ext_usados)}
        ext_usados.sort(key=lambda e: pos_orig.get(e.path, 10 ** 9 + _seq[e.path]))
        # uid/tipo: vale o que o arquivo já tinha
        orig_ext = {e.path: e for e in self.ext_ordem}
        ext_usados = [orig_ext.get(e.path, e) if (orig_ext.get(e.path) and (orig_ext[e.path].uid or not e.uid)) else e for e in ext_usados]
        ids_ext = {}
        usados_e = set(self.ext_ids.values())
        for e in ext_usados:
            eid = self.ext_ids.get(e.path)
            if eid is None:
                eid = _novo_id(usados_e, "%d_" % (len(ids_ext) + 1))
                usados_e.add(eid)
                self.ext_ids[e.path] = eid
            ids_ext[e.path] = eid
            # ordem original passa a incluir os novos (para salvar de novo igual)
        self.ext_ordem = list(ext_usados)
        self.sub_ordem = list(ordem)

        # 4) texto
        cab = dict(self.cab)
        if "load_steps" in cab:
            cab["load_steps"] = str(len(ext_usados) + len(ordem) + 1)
        out = ["[" + self.cab_tag + _attrs(cab) + "]", ""]
        for e in ext_usados:
            a = {"type": e.tipo}
            if e.uid:
                a["uid"] = e.uid
            a["path"] = e.path
            a["id"] = ids_ext[e.path]
            out.append("[ext_resource" + _attrs(a, aspas=True) + "]")
        if ext_usados:
            out.append("")
        ctx = (ids_ext, None)
        for r in ordem:
            out.append('[sub_resource type="%s" id="%s"]' % (r.tipo, r.rid))
            for k, v in r.props.items():
                out.append("%s = %s" % (k, _fmt(v, ids_ext)))
            out.append("")
        out.append("[resource]")
        for k, v in root.props.items():
            out.append("%s = %s" % (k, _fmt(v, ids_ext)))
        return "\n".join(out) + "\n"

    def save(self, caminho=None):
        caminho = caminho or self.caminho
        txt = self.dumps()
        tmp = caminho + ".tmp_editor"
        with open(tmp, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)
        os.replace(tmp, caminho)
        self.caminho = caminho


def _attrs(a, aspas=False):
    partes = []
    for k, v in a.items():
        if not aspas and k == "format" or (not aspas and k == "load_steps"):
            partes.append("%s=%s" % (k, v))
        else:
            partes.append('%s="%s"' % (k, str(v).replace("\\", "\\\\").replace('"', '\\"')))
    return (" " + " ".join(partes)) if partes else ""


def _novo_id(usados, prefixo):
    alf = string.ascii_lowercase + string.digits
    while True:
        s = prefixo + "".join(random.choice(alf) for _ in range(5))
        if s not in usados:
            return s


def fmt_float(x):
    if isinstance(x, GFloat) and x.txt is not None:
        return x.txt
    x = float(x)
    if x != x:
        return "nan"
    if x in (float("inf"), float("-inf")):
        return "inf" if x > 0 else "inf_neg"
    if x == int(x) and abs(x) < 1e16:
        return "%d.0" % int(x)
    return repr(x)


def esc(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _fmt(v, ids):
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, Res):
        return 'SubResource("%s")' % v.rid
    if isinstance(v, ExtRef):
        return 'ExtResource("%s")' % ids[v.path]
    if isinstance(v, StrName):
        return "&" + esc(v)
    if isinstance(v, NodePathV):
        return "^" + esc(v)
    if isinstance(v, Ident):
        return str(v)
    if isinstance(v, str):
        return esc(v)
    if isinstance(v, int):
        if isinstance(v, GInt) and v.txt is not None:
            return v.txt
        return str(int(v))
    if isinstance(v, float):
        return fmt_float(v)
    if isinstance(v, TypedArray):
        return "Array[%s](%s)" % (_fmt(v.tipo, ids), _fmt(v.itens, ids))
    if isinstance(v, TypedDict):
        return "Dictionary[%s](%s)" % (", ".join(_fmt(x, ids) for x in v.tipos), _fmt(v.d, ids))
    if isinstance(v, list):
        return "[" + ", ".join(_fmt(x, ids) for x in v) + "]"
    if isinstance(v, dict):
        if not v:
            return "{}"
        itens = ["%s: %s" % (_fmt(k, ids), _fmt(x, ids)) for k, x in v.items()]
        if getattr(v, "multilinha", False):
            return "{\n" + ",\n".join(itens) + "\n}"
        return "{" + ", ".join(itens) + "}"
    if isinstance(v, Call):
        return "%s(%s)" % (v.nome, ", ".join(_fmt(x, ids) for x in v.args))
    raise ErroTres("valor sem formato: %r" % (v,))


# ---------------------------------------------------------------------------
# Ajudantes para valores comuns
# ---------------------------------------------------------------------------
def vec2(x, y):
    return Call("Vector2", [GFloat(x) if isinstance(x, float) else x, GFloat(y) if isinstance(y, float) else y])


def vec2_xy(v):
    if isinstance(v, Call) and v.nome == "Vector2" and len(v.args) == 2:
        return float(v.args[0]), float(v.args[1])
    return 0.0, 0.0


def color_rgba(v):
    if isinstance(v, Call) and v.nome == "Color":
        a = [float(x) for x in v.args] + [1.0] * 4
        return a[0], a[1], a[2], a[3]
    return 1.0, 1.0, 1.0, 1.0


def num(x):
    """Número para gravar: int vira float se precisar."""
    return x


def copiar_profundo(v, memo=None):
    """Cópia de valores/sub-recursos (ExtRef é compartilhado). Sub-recursos novos ficam sem id."""
    if memo is None:
        memo = {}
    if isinstance(v, Res):
        if id(v) in memo:
            return memo[id(v)]
        n = Res(v.tipo, rid=None)
        memo[id(v)] = n
        for k, x in v.props.items():
            n.props[k] = copiar_profundo(x, memo)
        return n
    if isinstance(v, list):
        return [copiar_profundo(x, memo) for x in v]
    if isinstance(v, GDict):
        d = GDict((copiar_profundo(k, memo), copiar_profundo(x, memo)) for k, x in v.items())
        d.multilinha = v.multilinha
        return d
    if isinstance(v, TypedArray):
        return TypedArray(v.tipo, copiar_profundo(v.itens, memo))
    if isinstance(v, TypedDict):
        return TypedDict(list(v.tipos), copiar_profundo(v.d, memo))
    if isinstance(v, Call):
        return Call(v.nome, copiar_profundo(v.args, memo))
    return v


def copiar_mantendo_ids(v, memo=None):
    """Como copiar_profundo, mas mantém os ids (para desfazer/refazer)."""
    if memo is None:
        memo = {}
    if isinstance(v, Res):
        if id(v) in memo:
            return memo[id(v)]
        n = Res(v.tipo, rid=v.rid)
        memo[id(v)] = n
        for k, x in v.props.items():
            n.props[k] = copiar_mantendo_ids(x, memo)
        return n
    if isinstance(v, list):
        return [copiar_mantendo_ids(x, memo) for x in v]
    if isinstance(v, GDict):
        d = GDict((copiar_mantendo_ids(k, memo), copiar_mantendo_ids(x, memo)) for k, x in v.items())
        d.multilinha = v.multilinha
        return d
    if isinstance(v, TypedArray):
        return TypedArray(v.tipo, copiar_mantendo_ids(v.itens, memo))
    if isinstance(v, TypedDict):
        return TypedDict(list(v.tipos), copiar_mantendo_ids(v.d, memo))
    if isinstance(v, Call):
        return Call(v.nome, copiar_mantendo_ids(v.args, memo))
    return v
