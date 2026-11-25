# indice.py - lê o projeto inteiro uma vez (eventos, mapas, variáveis, receitas, scripts) e
# responde perguntas: onde algo é usado, quem muda/testa cada variável, falas de cada
# personagem, passagens dos mapas. Usado pelas abas Verificação, Onde é usado, Flags, Falas,
# Mapas e Mercadores. É só leitura; Recarregar relê tudo.
import glob
import os
import re

from nucleo import motor

_cache = {}


def indice(raiz, novo=False):
    if novo or raiz not in _cache:
        _cache[raiz] = Indice(raiz)
    return _cache[raiz]


def stem(caminho):
    return os.path.splitext(os.path.basename(str(caminho)))[0]


def _ler(p):
    try:
        with open(p, encoding="utf-8") as f:
            return f.read()
    except Exception:  # noqa: BLE001
        return ""


class Uso:
    """Um lugar onde algo aparece."""
    __slots__ = ("arquivo", "evento", "pag", "cmd", "onde", "texto", "tipo")

    def __init__(self, arquivo, onde, texto, evento=None, pag=None, cmd=None, tipo=""):
        self.arquivo, self.onde, self.texto = arquivo, onde, texto
        self.evento, self.pag, self.cmd, self.tipo = evento, pag, cmd, tipo


class Indice:
    def __init__(self, raiz):
        self.raiz = raiz
        self.modelo, self.tres, _ = motor.eventos()
        self.proj = motor.projeto(raiz)
        self.proj.indexar()
        self.erros = []
        self._eventos()
        self._mapas()
        self._variaveis()

    # ---------------------------------------------------------- eventos
    def _eventos(self):
        """self.cmds: um dict por comando (também os dentro de efeitos e condições de página)."""
        T = self.tres
        self.docs = {}          # id do evento -> TresDoc
        self.arq_evento = {}    # id -> caminho
        self.cmds = []          # {ev, pag, i, cl, res, arq}
        self.ids = {}           # id do EventoData (o que os comandos citam por nome) -> nome do arquivo
        self.conds = []         # {ev, pag, i (None = condição da página), res}
        for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "eventos", "**", "*.tres"), recursive=True)):
            ev = stem(p)
            try:
                d = T.TresDoc.load(p)
            except Exception as e:  # noqa: BLE001
                self.erros.append((p, "não deu para ler: %s" % e))
                continue
            self.docs[ev], self.arq_evento[ev] = d, p
            self.ids[str(d.root.get("id") or ev)] = ev
            pags = d.root.get("paginas")
            pags = pags.itens if isinstance(pags, T.TypedArray) else []
            for k, pg in enumerate(pags):
                if not isinstance(pg, T.Res):
                    continue
                for c in self._lista(pg, "condicoes"):
                    self.conds.append({"ev": ev, "pag": k, "i": None, "res": c, "arq": p})
                for i, c in enumerate(self._lista(pg, "comandos")):
                    cl = self.proj.classe_de(c)
                    self.cmds.append({"ev": ev, "pag": k, "i": i, "cl": cl.nome if cl else "?", "res": c, "arq": p})
                    cond = c.get("condicao")
                    if isinstance(cond, T.Res):
                        self.conds.append({"ev": ev, "pag": k, "i": i, "res": cond, "arq": p})

    def _lista(self, res, campo):
        v = res.get(campo)
        if isinstance(v, self.tres.TypedArray):
            return [x for x in v.itens if isinstance(x, self.tres.Res)]
        if isinstance(v, list):
            return [x for x in v if isinstance(x, self.tres.Res)]
        return []

    def resumo(self, c):
        try:
            return self.modelo.resumo(self.proj, c)[0]
        except Exception:  # noqa: BLE001
            return "?"

    def onde(self, d):
        return "pág %d · cmd %d" % (d["pag"] + 1, d["i"] + 1) if d.get("i") is not None else "pág %d · condição" % (d["pag"] + 1)

    def uso_cmd(self, d, tipo=""):
        return Uso(d["arq"], self.onde(d), self.resumo(d["res"]), d["ev"], d["pag"], d["i"], tipo)

    def uso_cond(self, d, tipo=""):
        return Uso(d["arq"], self.onde(d), "se " + self.modelo.texto_condicao(self.proj, d["res"]), d["ev"], d["pag"], d["i"], tipo)

    # ---------------------------------------------------------- mapas
    def _mapas(self):
        """self.mapas: res do mapa -> {"arq", "nos": [{nome, tipo, evento, pos, props}]}"""
        self.mapas = {}
        self.uid_mapa = {}
        for p in sorted(glob.glob(os.path.join(self.raiz, "mapas", "**", "*.tscn"), recursive=True)):
            txt = _ler(p)
            ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', txt)}
            nos = []
            for bloco in re.split(r"\n(?=\[node )", txt):
                m = re.match(r'\[node name="([^"]+)"', bloco)
                if not m:
                    continue
                props = dict(re.findall(r"^(\w[\w/]*) = (.+)$", bloco, re.M))
                ev = props.get("evento", "")
                mm = re.match(r'ExtResource\("([^"]+)"\)', ev)
                if not mm:
                    continue
                pos = re.match(r"Vector2\(([-\d.e]+), ([-\d.e]+)\)", props.get("position", ""))
                scr = re.match(r'ExtResource\("([^"]+)"\)', props.get("script", ""))
                nos.append({"nome": m.group(1), "evento": stem(ext.get(mm.group(1), "?")),
                            "script": stem(ext.get(scr.group(1), "")) if scr else "",
                            "pos": (float(pos.group(1)), float(pos.group(2))) if pos else None, "props": props})
            self.mapas[self.proj.res(p)] = {"arq": p, "nos": nos, "texto": txt}
            mu = re.search(r'uid="(uid://[^"]+)"', txt.split("\n", 1)[0])
            if mu:
                self.uid_mapa[mu.group(1)] = self.proj.res(p)

    def resolver_mapa(self, m):
        """Como CmdTeleportar._caminho: uid://, res:// ou só o nome. Devolve o res:// ou None."""
        m = (m or "").strip()
        if not m:
            return None
        if m.startswith("uid://"):
            return self.uid_mapa.get(m)
        if m.startswith("res://"):
            return m if m in self.mapas else None
        nome = os.path.basename(m)
        if nome.endswith(".tscn"):
            nome = nome[:-5]
        for t in ("res://mapas/%s.tscn" % nome, "res://mapas/mapa_%s.tscn" % nome):
            if t in self.mapas:
                return t
        return None

    def mapas_do_evento(self, ev):
        return [m for m, d in self.mapas.items() if any(n["evento"] == ev for n in d["nos"])]

    def teleportes(self, ev):
        """[(mapa destino, (x, y))] dos CmdTeleportar do evento."""
        out = []
        for d in self.cmds:
            if d["ev"] == ev and d["cl"] == "CmdTeleportar":
                pos = d["res"].get("posicao")
                xy = None
                if isinstance(pos, self.tres.Call) and len(pos.args) >= 2:
                    xy = (float(pos.args[0]), float(pos.args[1]))
                bruto = str(d["res"].get("mapa", "") or "")
                out.append((self.resolver_mapa(bruto) or bruto, xy))
        return out

    # ---------------------------------------------------------- variáveis
    def _variaveis(self):
        T = self.tres
        self.vars = {}      # nome -> {arq, inicial, descricao}
        for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "variaveis", "*.tres"))):
            try:
                d = T.TresDoc.load(p)
            except Exception:  # noqa: BLE001
                continue
            nome = d.root.get("nome") or stem(p)
            self.vars[nome] = {"arq": p, "inicial": float(d.root.get("valor_numero", 0.0) or 0.0),
                               "descricao": d.root.get("descricao", "") or ""}
        self.muda, self.testa, self.codigo = {}, {}, {}
        for d in self.cmds:
            c, cl = d["res"], d["cl"]
            nome = None
            if cl == "CmdVariavel":
                if int(c.get("escopo", 0) or 0) == 0:
                    nome = c.get("variavel", "")
            elif "variavel" in c.props and isinstance(c.get("variavel"), str):
                nome = c.get("variavel")
            elif cl == "CmdLoja":
                nome = "loja_trocas"
            if cl == "CmdLoja":
                self.muda.setdefault("ouro", []).append(self.uso_cmd(d, "muda"))
            if cl == "CmdClassificarPersonalidade":     # prefixo_O ... prefixo_N e prefixo_extremo
                pre = c.get("prefixo", "missao01") or "missao01"
                for suf in ("O", "C", "E", "A", "N", "extremo"):
                    self.muda.setdefault("%s_%s" % (pre, suf), []).append(self.uso_cmd(d, "muda"))
            if nome:
                self.muda.setdefault(nome, []).append(self.uso_cmd(d, "muda"))
        for d in self.conds:
            c = d["res"]
            tipo = int(c.get("tipo", 0) or 0)
            if tipo == 0 and c.get("variavel"):        # VARIAVEL
                self.testa.setdefault(c.get("variavel"), []).append(self.uso_cond(d, "testa"))
        # scripts do jogo que citam o nome entre aspas
        nomes = set(self.vars) | set(self.muda) | set(self.testa)
        for p in glob.glob(os.path.join(self.raiz, "src", "**", "*.gd"), recursive=True):
            txt = _ler(p)
            for n in nomes:
                if '"%s"' % n in txt:
                    linha = next((k + 1 for k, l in enumerate(txt.splitlines()) if '"%s"' % n in l), 0)
                    self.codigo.setdefault(n, []).append(Uso(p, "linha %d" % linha, "script do jogo", tipo="código"))

    # ---------------------------------------------------------- onde é usado
    def usos(self, alvo, em_textos=False):
        """Tudo que cita `alvo` (id de evento/item/personagem/variável/falante, nome de mapa)."""
        T = self.tres
        alvo = alvo.strip()
        if not alvo:
            return []
        out = []

        def cita(v, prof=0):
            if prof > 6:
                return False
            if isinstance(v, T.ExtRef):
                return stem(v.path) == alvo or v.path == alvo
            if isinstance(v, str):
                return v == alvo or stem(v) == alvo if v.startswith("res://") else (v == alvo or (em_textos and alvo.lower() in v.lower()))
            if isinstance(v, T.Res):
                return any(cita(x, prof + 1) for k, x in v.props.items() if k != "script")
            if isinstance(v, T.TypedArray):
                return any(cita(x, prof + 1) for x in v.itens)
            if isinstance(v, (list, tuple)):
                return any(cita(x, prof + 1) for x in v)
            if isinstance(v, dict):
                return any(cita(k, prof + 1) or cita(x, prof + 1) for k, x in v.items())
            if isinstance(v, T.TypedDict):
                return cita(getattr(v, "d", {}), prof + 1)
            if isinstance(v, T.Call):
                return any(cita(x, prof + 1) for x in v.args)
            return False

        for d in self.cmds:
            if cita(d["res"]):
                out.append(self.uso_cmd(d, "evento"))
        for d in self.conds:
            if d["i"] is None and cita(d["res"]):
                out.append(self.uso_cond(d, "evento"))
        for m, dm in self.mapas.items():
            for n in dm["nos"]:
                if n["evento"] == alvo:
                    out.append(Uso(dm["arq"], "nó %s" % n["nome"], "colocado no mapa%s" % (" em %d, %d" % n["pos"] if n["pos"] else ""), tipo="mapa"))
        # outros dados (.tres fora de eventos) e scripts
        pastas = ["dados/itens", "dados/pocoes", "dados/receitas", "dados/personalidades", "dados/falantes", "dados"]
        for pasta in pastas:
            for p in glob.glob(os.path.join(self.raiz, *pasta.split("/"), "**" if pasta != "dados" else "", "*.tres"), recursive=pasta != "dados"):
                if stem(p) == alvo and pasta != "dados":
                    continue
                txt = _ler(p)
                if re.search(r'(/%s\.(tres|tscn)"|"%s")' % (re.escape(alvo), re.escape(alvo)), txt):
                    out.append(Uso(p, os.path.relpath(p, self.raiz).replace("\\", "/"), "cita no arquivo", tipo="dados"))
        for p in glob.glob(os.path.join(self.raiz, "src", "**", "*.gd"), recursive=True):
            txt = _ler(p)
            if '"%s"' % alvo in txt:
                linha = next((k + 1 for k, l in enumerate(txt.splitlines()) if '"%s"' % alvo in l), 0)
                out.append(Uso(p, "linha %d" % linha, "script do jogo", tipo="código"))
        vistos, unicos = set(), []
        for u in out:
            ch = (u.arquivo, u.onde, u.texto)
            if ch not in vistos:
                vistos.add(ch)
                unicos.append(u)
        return unicos

    def alvos_conhecidos(self):
        """Lista de (rotulo, id) para o combo da aba Onde é usado."""
        out = []
        out += [("evento", e) for e in sorted(self.docs)]
        out += [("item", stem(p)) for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "itens", "*.tres")))]
        out += [("personalidade", stem(p)) for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "personalidades", "*.tres")))]
        out += [("poção", stem(p)) for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "pocoes", "**", "*.tres"), recursive=True))]
        out += [("receita", stem(p)) for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "receitas", "*.tres")))]
        out += [("falante", stem(p)) for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "falantes", "*.tres")))]
        out += [("variável", v) for v in sorted(set(self.vars) | set(self.muda) | set(self.testa))]
        out += [("mapa", stem(m)) for m in sorted(self.mapas)]
        return out

    # ---------------------------------------------------------- falas
    def falas(self):
        """[{falante (stem ou ""), tipo, texto, uso}] na ordem dos eventos."""
        out = []
        for d in self.cmds:
            c, cl = d["res"], d["cl"]
            pers = c.get("personagem")
            f = stem(pers.path) if isinstance(pers, self.tres.ExtRef) else ""
            if cl == "CmdMostrarMsg":
                out.append({"falante": f, "tipo": "fala", "texto": str(c.get("texto", "") or ""), "d": d})
            elif cl == "CmdMostrarOpcoes":
                op = c.get("opcoes")
                op = op.itens if isinstance(op, self.tres.TypedArray) else (op or [])
                txt = str(c.get("pergunta", "") or "")
                out.append({"falante": f, "tipo": "opções", "texto": (txt + "\n" if txt else "") + " | ".join(str(x) for x in op), "d": d})
            elif cl == "CmdLegenda":
                out.append({"falante": "(legenda)", "tipo": "legenda", "texto": str(c.get("texto", "") or ""), "d": d})
        return out
