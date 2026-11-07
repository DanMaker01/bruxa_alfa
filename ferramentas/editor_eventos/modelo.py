# modelo.py - projeto Godot, documentos de evento e textos de resumo dos comandos.

import glob
import os
import re
import shutil
import time

import esquema
import tres
from tres import Res, ExtRef, TypedArray, GInt, GFloat, Call

SCRIPT_PAGINA = "res://src/dados/pagina_data.gd"
SCRIPT_EVENTO = "res://src/dados/evento_data.gd"
SCRIPT_CONDICAO = "res://src/dados/condicao.gd"
SCRIPT_PASSO = "res://src/dados/passo_rota.gd"
SCRIPT_COMANDO = "res://src/dados/comandos/comando.gd"
PASTA_COMANDOS = "res://src/dados/comandos"

# nome curto de cada comando (o resto vem do nome do arquivo)
NOMES = {
    "CmdMostrarMsg": "Mensagem", "CmdMostrarOpcoes": "Opções", "CmdIf": "Se", "CmdElse": "Senão",
    "CmdEnd": "Fim", "CmdWhile": "Enquanto", "CmdBreak": "Sair do enquanto", "CmdLabel": "Label",
    "CmdGoto": "Ir para label", "CmdVariavel": "Variável", "CmdItem": "Item", "CmdEsperar": "Esperar",
    "CmdFade": "Fade", "CmdSom": "Som", "CmdMover": "Mover", "CmdCamera": "Câmera",
    "CmdTeleportar": "Teleportar", "CmdBalao": "Balão", "CmdMostrarEfeito": "Efeito",
    "CmdLegenda": "Legenda", "CmdPlayer": "Bruxa (travar/sumir)", "CmdHud": "HUD",
    "CmdChamarEvento": "Chamar evento", "CmdPassavel": "Passável", "CmdDirecao": "Direção",
    "CmdEventoAnimacao": "Animação do evento", "CmdApagarEvento": "Apagar evento",
    "CmdEstiloDialogo": "Estilo do diálogo", "CmdPreparo": "Preparo (caldeirão)",
    "CmdPularComToque": "Pular com toque", "CmdAplicarPocao": "Aplicar poção",
    "CmdClassificarPersonalidade": "Classificar personalidade",
    "CmdMudarPersonalidade": "Mudar personalidade",
}

# categorias (cor no editor e grupos do menu de inserir)
CATEGORIAS = {
    "dialogo": ["CmdMostrarMsg", "CmdMostrarOpcoes", "CmdLegenda", "CmdEstiloDialogo", "CmdBalao"],
    "fluxo": ["CmdIf", "CmdElse", "CmdEnd", "CmdWhile", "CmdBreak", "CmdLabel", "CmdGoto",
              "CmdChamarEvento", "CmdPularComToque", "CmdEsperar"],
    "dados": ["CmdVariavel", "CmdItem", "CmdAplicarPocao", "CmdClassificarPersonalidade",
              "CmdMudarPersonalidade", "CmdPreparo"],
    "cena": ["CmdMover", "CmdDirecao", "CmdCamera", "CmdFade", "CmdTeleportar", "CmdPlayer",
             "CmdPassavel", "CmdEventoAnimacao", "CmdApagarEvento", "CmdMostrarEfeito", "CmdSom", "CmdHud"],
}
NOME_CATEGORIA = {"dialogo": "Diálogo", "fluxo": "Fluxo", "dados": "Variáveis e itens", "cena": "Cena", "outros": "Outros"}


def categoria(nome_classe):
    for k, v in CATEGORIAS.items():
        if nome_classe in v:
            return k
    return "outros"


def nome_bonito(cl):
    if cl.nome in NOMES:
        return NOMES[cl.nome]
    base = os.path.splitext(os.path.basename(cl.arquivo))[0]
    base = base[4:] if base.startswith("cmd_") else base
    return base.replace("_", " ").capitalize()


def _n(v):
    """Número sem ".0" sobrando."""
    try:
        f = float(v)
    except (TypeError, ValueError):
        return str(v)
    return str(int(f)) if f == int(f) else ("%g" % f)


class Projeto:
    def __init__(self, raiz):
        self.raiz = os.path.abspath(raiz)
        self.classes = {}          # res path -> Classe
        self.por_nome = {}         # class_name -> Classe
        self.comandos = []         # Classes de comando (sem a base)
        self.uids = {}             # res path -> uid
        self.carregar()

    # ------------------------------------------------------------ caminhos
    def disco(self, res):
        if res.startswith("res://"):
            return os.path.join(self.raiz, *res[6:].split("/"))
        return res

    def res(self, disco):
        rel = os.path.relpath(os.path.abspath(disco), self.raiz).replace(os.sep, "/")
        return "res://" + rel

    # ------------------------------------------------------------ carga
    def carregar(self):
        self.classes.clear()
        self.por_nome.clear()
        self.comandos = []
        base = [SCRIPT_PAGINA, SCRIPT_EVENTO, SCRIPT_CONDICAO, SCRIPT_PASSO]
        arquivos = base + [self.res(p) for p in sorted(glob.glob(os.path.join(self.disco(PASTA_COMANDOS), "*.gd")))]
        for r in arquivos:
            d = self.disco(r)
            if not os.path.exists(d):
                continue
            try:
                cl = esquema.ler_classe(d, r)
            except Exception as e:     # um script com erro não derruba o editor
                print("aviso: não li", r, e)
                continue
            self.classes[r] = cl
            self.por_nome[cl.nome] = cl
            uidf = d + ".uid"
            if os.path.exists(uidf):
                with open(uidf, encoding="utf-8") as f:
                    self.uids[r] = f.read().strip()
            if r.startswith(PASTA_COMANDOS) and r != SCRIPT_COMANDO and cl.extends == "Comando":
                self.comandos.append(cl)
        # enums de outras classes (Condicao.Letra, CmdBalao.Emocao)
        for cl in self.classes.values():
            for c in cl.campos:
                if c.tipo == "enum" and c.enum is None and c.classe and "." in c.classe:
                    dono, en = c.classe.rsplit(".", 1)
                    outra = self.por_nome.get(dono)
                    c.enum = outra.enums.get(en) if outra else None
                    if c.enum is None:
                        c.enum = []
                    nome_pad = getattr(c, "_enum_padrao_nome", None)
                    if nome_pad and nome_pad in c.enum:
                        c.padrao, c.tem_padrao = GInt(c.enum.index(nome_pad)), True
                    elif not c.tem_padrao:
                        c.padrao, c.tem_padrao = GInt(0), True
            esquema.aplicar_regras(cl)
        self.comandos.sort(key=lambda cl: (list(CATEGORIAS).index(categoria(cl.nome)) if categoria(cl.nome) in CATEGORIAS else 99,
                                           (CATEGORIAS.get(categoria(cl.nome)) or []).index(cl.nome) if cl.nome in (CATEGORIAS.get(categoria(cl.nome)) or []) else 0,
                                           nome_bonito(cl)))
        self.indexar()

    def indexar(self):
        self.eventos = sorted(glob.glob(os.path.join(self.raiz, "dados", "eventos", "**", "*.tres"), recursive=True))
        self.falantes = {}      # stem -> {"res", "nome", "faces"}
        for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "falantes", "*.tres"))):
            nome, faces = "", []
            try:
                d = tres.TresDoc.load(p)
                nome = d.root.get("nome", "")
                fc = d.root.get("faces")
                if isinstance(fc, dict):
                    faces = [str(k) for k in fc.keys()]
            except Exception:
                pass
            self.falantes[os.path.splitext(os.path.basename(p))[0]] = {"res": self.res(p), "nome": nome, "faces": faces}
        self.itens = self._lista_res("dados/itens", "id")
        self.personalidades = self._lista_res("dados/personalidades", "id")
        self.variaveis = {}
        for p in sorted(glob.glob(os.path.join(self.raiz, "dados", "variaveis", "*.tres"))):
            try:
                d = tres.TresDoc.load(p)
                self.variaveis[d.root.get("nome") or os.path.splitext(os.path.basename(p))[0]] = d.root.get("descricao", "")
            except Exception:
                pass
        self.animacoes = {}     # res -> [nomes]
        for p in sorted(glob.glob(os.path.join(self.raiz, "animacoes", "*.tres"))):
            nomes = []
            try:
                with open(p, encoding="utf-8") as f:
                    nomes = re.findall(r'"name":\s*&"([^"]*)"', f.read())
            except Exception:
                pass
            self.animacoes[self.res(p)] = nomes or ["default"]
        self.mapas = sorted(self.res(p) for p in glob.glob(os.path.join(self.raiz, "mapas", "**", "*.tscn"), recursive=True))
        self.audio = {}
        for canal in ("bgm", "bgs", "se"):
            self.audio[canal] = sorted(self.res(p) for p in glob.glob(os.path.join(self.raiz, "audio", canal, "**", "*.mp3"), recursive=True))
        self.ids_evento = []
        for p in self.eventos:
            self.ids_evento.append(os.path.splitext(os.path.basename(p))[0])

    def _lista_res(self, pasta, campo_id):
        out = {}
        for p in sorted(glob.glob(os.path.join(self.raiz, *pasta.split("/"), "*.tres"))):
            ident = os.path.splitext(os.path.basename(p))[0]
            nome = ""
            try:
                d = tres.TresDoc.load(p)
                ident = d.root.get(campo_id) or ident
                nome = d.root.get("nome", "")
            except Exception:
                pass
            out[self.res(p)] = {"id": ident, "nome": nome}
        return out

    # ------------------------------------------------------------ refs
    def uid_de(self, res):
        if res in self.uids:
            return self.uids[res]
        d = self.disco(res)
        uid = None
        try:
            if d.endswith(".gd"):
                if os.path.exists(d + ".uid"):
                    with open(d + ".uid", encoding="utf-8") as f:
                        uid = f.read().strip()
            elif d.endswith(".tres") or d.endswith(".tscn"):
                with open(d, encoding="utf-8") as f:
                    m = re.search(r'uid="(uid://[^"]+)"', f.readline())
                    uid = m.group(1) if m else None
            elif os.path.exists(d + ".import"):
                with open(d + ".import", encoding="utf-8") as f:
                    m = re.search(r'uid="(uid://[^"]+)"', f.read())
                    uid = m.group(1) if m else None
        except Exception:
            uid = None
        self.uids[res] = uid
        return uid

    def ext(self, res, tipo=None):
        if tipo is None:
            if res.endswith(".gd"):
                tipo = "Script"
            elif res.startswith("res://animacoes/"):
                tipo = "SpriteFrames"
            elif res.endswith(".png"):
                tipo = "Texture2D"
            else:
                tipo = "Resource"
        return ExtRef(res, tipo, self.uid_de(res))

    def classe_de(self, res_obj):
        s = res_obj.script if isinstance(res_obj, Res) else None
        return self.classes.get(s) if s else None

    # ------------------------------------------------------------ novos recursos
    def novo(self, script_res):
        r = Res("Resource")
        r.props["script"] = self.ext(script_res, "Script")
        cl = self.classes.get(script_res)
        if cl and cl.nome in ("CmdIf", "CmdWhile"):
            r.props["condicao"] = self.novo(SCRIPT_CONDICAO)
        return r

    def nova_pagina(self):
        return self.novo(SCRIPT_PAGINA)

    def array_tipado(self, script_elem, itens=None):
        return TypedArray(self.ext(script_elem, "Script"), itens or [])


# ---------------------------------------------------------------------------
# Leitura e escrita de campos (com padrão: campo igual ao padrão sai do arquivo)
# ---------------------------------------------------------------------------
def valor_campo(res, campo):
    if campo.nome in res.props:
        return res.props[campo.nome]
    return campo.padrao


def normalizar(campo, v):
    if campo.tipo == "float" and isinstance(v, (int, float)) and not isinstance(v, bool):
        if isinstance(v, GFloat) and v.txt is not None and float(v.txt) == float(v):
            return v
        return GFloat(float(v))
    if campo.tipo in ("int", "enum") and isinstance(v, (int, float)) and not isinstance(v, bool):
        return GInt(int(v))
    return v


def definir(res, cl, nome, v):
    """Grava o campo respeitando o padrão e a ordem dos campos da classe."""
    campo = cl.campo(nome) if cl else None
    if campo is not None:
        v = normalizar(campo, v)
        if campo.tem_padrao and _igual_padrao(campo, v):
            res.props.pop(nome, None)
            return
    if nome in res.props:
        res.props[nome] = v
        return
    # insere na posição certa
    ordem = (["script"] + cl.ordem) if cl else []
    if nome not in ordem:
        res.props[nome] = v
        return
    alvo = ordem.index(nome)
    novos = {}
    inserido = False
    for k, x in res.props.items():
        if not inserido and k in ordem and ordem.index(k) > alvo:
            novos[nome] = v
            inserido = True
        novos[k] = x
    if not inserido:
        novos[nome] = v
    res.props.clear()
    res.props.update(novos)


def _igual_padrao(campo, v):
    p = campo.padrao
    if campo.tipo == "Array":
        itens = v.itens if isinstance(v, TypedArray) else v
        return isinstance(itens, list) and len(itens) == 0
    if campo.tipo == "Res":
        return v is None
    if p is None and v is None:
        return True
    if p is None:
        return False
    return tres.valores_iguais(p, v)


def itens(res, nome):
    v = res.props.get(nome)
    if isinstance(v, TypedArray):
        return v.itens
    if isinstance(v, list):
        return v
    return []


def definir_lista(proj, res, nome, lista, script_elem=None, tipo_basico=None):
    cl = proj.classe_de(res)
    if not lista:
        res.props.pop(nome, None)
        return
    atual = res.props.get(nome)
    if isinstance(atual, TypedArray):
        v = TypedArray(atual.tipo, list(lista))
    elif script_elem:
        v = proj.array_tipado(script_elem, list(lista))
    elif tipo_basico:
        v = TypedArray(tres.Ident(tipo_basico), list(lista))
    else:
        v = list(lista)
    definir(res, cl, nome, v)


# ---------------------------------------------------------------------------
# Documento de evento
# ---------------------------------------------------------------------------
class EventoDoc:
    MAX_DESFAZER = 200

    def __init__(self, proj, caminho):
        self.proj = proj
        self.caminho = caminho
        self.doc = tres.TresDoc.load(caminho)
        self.mtime = os.path.getmtime(caminho)
        self.modificado = False
        self.desfazer_pilha = []
        self.refazer_pilha = []

    @classmethod
    def criar(cls, proj, caminho, ident):
        d = tres.TresDoc()
        d.cab = {"type": "Resource", "script_class": "EventoData", "format": "3"}
        d.root.props["script"] = proj.ext(SCRIPT_EVENTO, "Script")
        d.root.props["id"] = ident
        d.root.props["paginas"] = proj.array_tipado(SCRIPT_PAGINA, [proj.nova_pagina()])
        d.save(caminho)
        return cls(proj, caminho)

    @property
    def nome(self):
        return os.path.splitext(os.path.basename(self.caminho))[0]

    @property
    def root(self):
        return self.doc.root

    @property
    def paginas(self):
        v = self.root.props.get("paginas")
        if not isinstance(v, TypedArray):
            v = self.proj.array_tipado(SCRIPT_PAGINA, list(v) if isinstance(v, list) else [])
            self.root.props["paginas"] = v
        return v.itens

    # desfazer / refazer: fotografia do recurso raiz
    def _foto(self):
        return tres.copiar_mantendo_ids(self.root)

    def antes_de_mudar(self):
        self.desfazer_pilha.append(self._foto())
        if len(self.desfazer_pilha) > self.MAX_DESFAZER:
            self.desfazer_pilha.pop(0)
        self.refazer_pilha.clear()
        self.modificado = True

    def desfazer(self):
        if not self.desfazer_pilha:
            return False
        self.refazer_pilha.append(self._foto())
        self.doc.root = self.desfazer_pilha.pop()
        self.modificado = True
        return True

    def refazer(self):
        if not self.refazer_pilha:
            return False
        self.desfazer_pilha.append(self._foto())
        self.doc.root = self.refazer_pilha.pop()
        self.modificado = True
        return True

    def mudou_fora(self):
        try:
            return abs(os.path.getmtime(self.caminho) - self.mtime) > 0.001
        except OSError:
            return False

    def limpar_vazios(self):
        """Listas vazias são o padrão: saem do arquivo (como o Godot faz)."""
        vistos = set()

        def rec(r):
            if not isinstance(r, Res) or id(r) in vistos:
                return
            vistos.add(id(r))
            cl = self.proj.classe_de(r)
            for k in list(r.props):
                v = r.props[k]
                if cl and cl.campo(k) and cl.campo(k).tipo == "Array":
                    lst = v.itens if isinstance(v, TypedArray) else v
                    if isinstance(lst, list) and not lst:
                        del r.props[k]
                        continue
                for x in (v.itens if isinstance(v, TypedArray) else v if isinstance(v, list) else [v]):
                    rec(x)
        rec(self.root)

    def salvar(self, pasta_backup=None):
        self.limpar_vazios()
        if pasta_backup and os.path.exists(self.caminho):
            os.makedirs(pasta_backup, exist_ok=True)
            shutil.copy2(self.caminho, os.path.join(pasta_backup, os.path.basename(self.caminho)))
        self.doc.save(self.caminho)
        self.mtime = os.path.getmtime(self.caminho)
        self.modificado = False


# ---------------------------------------------------------------------------
# Estrutura (if / else / end / while) e labels
# ---------------------------------------------------------------------------
ABRE = ("CmdIf", "CmdWhile")


def estrutura(proj, cmds):
    """Devolve (profundidade[i], par[i]) - par: if->end, else->end, end->if, while->end."""
    prof = []
    par = [None] * len(cmds)
    pilha = []
    d = 0
    for i, c in enumerate(cmds):
        cl = proj.classe_de(c)
        n = cl.nome if cl else ""
        if n in ABRE:
            prof.append(d)
            pilha.append([i, None])
            d += 1
        elif n == "CmdElse":
            prof.append(max(d - 1, 0))
            if pilha:
                pilha[-1][1] = i
        elif n == "CmdEnd":
            d = max(d - 1, 0)
            prof.append(d)
            if pilha:
                ini, els = pilha.pop()
                par[ini] = i
                par[i] = ini
                if els is not None:
                    par[els] = i
        else:
            prof.append(d)
    return prof, par


def labels_da_lista(proj, cmds):
    out = []
    for c in cmds:
        cl = proj.classe_de(c)
        if cl and cl.nome == "CmdLabel":
            out.append(c.get("nome", ""))
    return out


def alvos_de_label(proj, c):
    cl = proj.classe_de(c)
    if not cl:
        return []
    if cl.nome in ("CmdGoto", "CmdPularComToque"):
        return [c.get("label", "")]
    if cl.nome == "CmdMostrarOpcoes":
        return [str(x) for x in itens(c, "labels")]
    return []


# ---------------------------------------------------------------------------
# Resumo de uma linha
# ---------------------------------------------------------------------------
def enum_nome(cl, res, campo, minusculo=True):
    c = cl.campo(campo) if cl else None
    if not c or not c.enum:
        return str(res.get(campo, ""))
    v = res.get(campo, c.padrao)
    try:
        s = c.enum[int(v)]
    except (TypeError, ValueError, IndexError):
        s = str(v)
    return s.lower() if minusculo else s


def nome_ref(proj, v):
    if isinstance(v, ExtRef):
        return os.path.splitext(os.path.basename(v.path))[0]
    if isinstance(v, Res):
        return "(embutido)"
    return "-"


def falante_nome(proj, v):
    if isinstance(v, ExtRef):
        stem = os.path.splitext(os.path.basename(v.path))[0]
        f = proj.falantes.get(stem)
        return (f["nome"] or stem) if f else stem
    return ""


def texto_condicao(proj, c):
    if not isinstance(c, Res):
        return "(sem condição)"
    cl = proj.classe_de(c) or proj.por_nome.get("Condicao")
    tipo = enum_nome(cl, c, "tipo", False)
    op = ["==", "!=", ">", "<", ">=", "<="]
    try:
        o = op[int(c.get("operador", 0))]
    except (ValueError, IndexError, TypeError):
        o = "?"
    val = _n(c.get("valor", 0.0))
    if tipo == "VARIAVEL":
        return "%s %s %s" % (c.get("variavel", "") or "?", o, val)
    if tipo == "ITEM":
        it = c.get("item")
        nome = nome_ref(proj, it) if it else (c.get("variavel", "") or "?")
        return "item %s %s %s" % (nome, o, val)
    if tipo == "PERSONALIDADE":
        return "%s.%s %s %s" % (c.get("variavel", "") or "?", enum_nome(cl, c, "traco", False), o, val)
    if tipo == "POSICAO_X":
        return "bruxa x %s %s" % (o, val)
    if tipo == "POSICAO_Y":
        return "bruxa y %s %s" % (o, val)
    if tipo == "DIRECAO_PLAYER":
        return "bruxa olha %s %s" % ("para" if o == "==" else "não para", enum_nome(cl, c, "direcao"))
    if tipo == "SELF_VAR":
        return "self %s %s %s" % (enum_nome(cl, c, "letra", False), o, val)
    if tipo == "ITEM_NOME":
        return 'itens "%s" %s %s' % (c.get("variavel", ""), o, val)
    return "%s %s %s" % (tipo.lower(), o, val)


def _uma_linha(s, n=90):
    s = (s or "").replace("\n", " / ")
    return s if len(s) <= n else s[:n - 1] + "…"


def _alvo(cl, c, campo="alvo", ev="evento"):
    a = enum_nome(cl, c, campo)
    if a == "evento":
        return c.get(ev, "") or "este evento"
    return a


def resumo(proj, c):
    """(texto, categoria) para mostrar na lista."""
    cl = proj.classe_de(c)
    if cl is None:
        return ("? %s" % (c.script or c.tipo), "outros")
    n = cl.nome
    cat = categoria(n)
    g = c.get
    if n == "CmdMostrarMsg":
        quem = falante_nome(proj, g("personagem"))
        extra = []
        if g("face"):
            extra.append(g("face"))
        if g("posicao", -1.0) is not None and float(g("posicao", -1.0)) >= 0:
            extra.append("@" + _n(g("posicao")))
        cab = quem + (" (" + ", ".join(extra) + ")" if extra else "")
        return ((cab + ": " if cab else "") + _uma_linha(g("texto", ""), 120), cat)
    if n == "CmdMostrarOpcoes":
        ops = [str(x) for x in itens(c, "opcoes")]
        lbs = [str(x) for x in itens(c, "labels")]
        pares = ["%s → %s" % (o, lbs[i] if i < len(lbs) else "?") for i, o in enumerate(ops)]
        quem = falante_nome(proj, g("personagem"))
        return ("Opções%s: %s  [%s]" % (" (" + quem + ")" if quem else "", _uma_linha(g("pergunta", ""), 60), " | ".join(pares)), cat)
    if n == "CmdIf":
        return ("Se  " + texto_condicao(proj, g("condicao")), cat)
    if n == "CmdWhile":
        return ("Enquanto  " + texto_condicao(proj, g("condicao")), cat)
    if n == "CmdElse":
        return ("Senão", cat)
    if n == "CmdEnd":
        return ("Fim", cat)
    if n == "CmdBreak":
        return ("Sair do enquanto", cat)
    if n == "CmdLabel":
        return ("■ " + (g("nome", "") or "?"), cat)
    if n == "CmdGoto":
        return ("→ ir para " + (g("label", "") or "?"), cat)
    if n == "CmdPularComToque":
        return ("Toque pula para → " + (g("label", "") or "?"), cat)
    if n == "CmdVariavel":
        ops = ["=", "+=", "-=", "*=", "/=", "aleatório"]
        try:
            o = ops[int(g("operacao", 0))]
        except (ValueError, IndexError, TypeError):
            o = "?"
        if enum_nome(cl, c, "escopo") == "do_evento":
            alvo = "self " + enum_nome(cl, c, "letra", False) + (" (" + g("evento") + ")" if g("evento") else "")
        else:
            alvo = g("variavel", "") or "?"
        if o == "aleatório":
            return ("Var  %s = aleatório %s..%s" % (alvo, _n(g("valor", 0)), _n(g("valor_max", 1))), cat)
        return ("Var  %s %s %s" % (alvo, o, _n(g("valor", 0.0))), cat)
    if n == "CmdItem":
        a = enum_nome(cl, c, "acao")
        if a == "limpar":
            return ("Item  esvaziar inventário", cat)
        return ("Item  %s %s x%s" % ("+" if a == "adicionar" else "−", nome_ref(proj, g("item")), _n(g("quantidade", 1))), cat)
    if n == "CmdEsperar":
        return ("Esperar %s s" % _n(g("segundos", 1.0)), cat)
    if n == "CmdFade":
        t = enum_nome(cl, c, "tipo").replace("_", " ")
        return ("%s %s s%s" % (t.capitalize(), _n(g("tempo", 1.0)), "" if g("esperar", True) else " (sem esperar)"), cat)
    if n == "CmdSom":
        return ("Som %s  %s%s" % (enum_nome(cl, c, "canal", False), os.path.basename(g("arquivo", "") or "?"),
                                  "" if float(g("volume", 1.0)) == 1.0 else "  vol " + _n(g("volume"))), cat)
    if n == "CmdMover":
        quem = _alvo(cl, c)
        d = enum_nome(cl, c, "destino")
        if d == "x":
            dest = "x=" + _n(g("x", 0))
            if quem != "bruxa" and not g("manter_y", True):
                dest += ", y=" + _n(g("y", 0))
        elif d == "ate_evento":
            dest = "até " + (g("ate_evento", "") or "bruxa")
        elif d == "deslocar":
            dest = "%+g px" % float(g("deslocamento", 0.0))
        else:
            dest = "parar"
        ext = []
        if float(g("velocidade", 0.0) or 0):
            ext.append(_n(g("velocidade")) + " px/s")
        if enum_nome(cl, c, "direcao") != "manter":
            ext.append("olha " + enum_nome(cl, c, "direcao"))
        if not g("esperar", True):
            ext.append("sem esperar")
        return ("Mover %s → %s%s" % (quem, dest, ("  (" + ", ".join(ext) + ")") if ext else ""), cat)
    if n == "CmdCamera":
        a = enum_nome(cl, c, "acao")
        if a == "mover":
            x, y = tres.vec2_xy(g("posicao"))
            return ("Câmera → (%s, %s) em %s s" % (_n(x), _n(y), _n(g("tempo", 0.0))), cat)
        if a == "voltar":
            return ("Câmera volta para a bruxa (%s s)" % _n(g("tempo", 0.0)), cat)
        return ("Câmera treme %s px por %s s" % (_n(g("intensidade", 10)), _n(g("duracao", 1.0))), cat)
    if n == "CmdTeleportar":
        x, y = tres.vec2_xy(g("posicao"))
        m = os.path.splitext(os.path.basename(g("mapa", "") or "?"))[0]
        return ("Teleportar → %s (%s, %s) %s" % (m, _n(x), _n(y), enum_nome(cl, c, "direcao")), cat)
    if n == "CmdBalao":
        return ("Balão %s em %s" % (enum_nome(cl, c, "emocao"), _alvo(cl, c)), cat)
    if n == "CmdMostrarEfeito":
        return ("Efeito %s em %s" % (enum_nome(cl, c, "tipo"), _alvo(cl, c)), cat)
    if n == "CmdLegenda":
        return ("Legenda: " + _uma_linha(g("texto", ""), 100), cat)
    if n == "CmdPlayer":
        return ("Bruxa: " + enum_nome(cl, c, "acao"), cat)
    if n == "CmdHud":
        return ("HUD: " + ("mostrar" if g("mostrar", True) else "esconder"), cat)
    if n == "CmdChamarEvento":
        return ("Chamar evento: %s%s" % (nome_ref(proj, g("evento")), "" if g("esperar", True) else " (sem esperar)"), cat)
    if n == "CmdPassavel":
        return ("%s fica %s" % (_alvo(cl, c), "passável" if g("passavel", True) else "sólido"), cat)
    if n == "CmdDirecao":
        d = enum_nome(cl, c, "direcao")
        if d == "olhar_para":
            d = "olha para " + (g("olhar_para", "") or "bruxa")
        return ("Direção %s: %s" % (_alvo(cl, c), d), cat)
    if n == "CmdEventoAnimacao":
        return ("Animação %s: %s" % (g("evento", "") or "este evento", g("animacao", "") or "(da página)"), cat)
    if n == "CmdApagarEvento":
        return ("Apagar evento %s%s" % (g("evento", "") or "(este)", " e parar" if g("parar", False) else ""), cat)
    if n == "CmdPreparo":
        return ("Preparo: " + ("abrir" if g("abrir", True) else "fechar"), cat)
    if n == "CmdAplicarPocao":
        return ("Aplicar poção em %s → %s" % (g("personalidade", "") or "?", g("variavel", "aplicou_pocao")), cat)
    # genérico: campos diferentes do padrão
    partes = []
    for campo in cl.campos:
        if campo.nome in c.props:
            v = c.props[campo.nome]
            if campo.tipo == "enum" and campo.enum:
                try:
                    v = campo.enum[int(v)].lower()
                except (ValueError, IndexError, TypeError):
                    pass
            elif isinstance(v, ExtRef):
                v = nome_ref(proj, v)
            elif isinstance(v, (int, float)) and not isinstance(v, bool):
                v = _n(v)
            elif isinstance(v, str):
                v = _uma_linha(v, 30)
            elif isinstance(v, Call):
                v = "(" + ", ".join(_n(a) for a in v.args) + ")"
            else:
                v = "…"
            partes.append("%s=%s" % (campo.nome, v))
    return (nome_bonito(cl) + ("  " + ", ".join(partes) if partes else ""), cat)


def resumo_pagina(proj, pag, i):
    cl = proj.classes.get(SCRIPT_PAGINA)
    conds = [texto_condicao(proj, x) for x in itens(pag, "condicoes")]
    gat = enum_nome(cl, pag, "gatilho")
    spr = nome_ref(proj, pag.get("sprite_frames")) if pag.get("sprite_frames") else "sem sprite"
    n = len(itens(pag, "comandos"))
    return "%d  [%s]  %s  ·  %s  ·  %d cmd" % (i + 1, gat, " E ".join(conds) if conds else "sempre", spr, n)


# ---------------------------------------------------------------------------
# Diálogo como texto
# ---------------------------------------------------------------------------
# Formato:
#   @padre                 muda quem fala (nome do arquivo em dados/falantes)
#   @padre:pensando 100    com face e posição (0 a 100)
#   @-                     sem nome e sem foto
#   texto...               uma fala; linhas seguidas = quebra de linha na mesma fala
#   (linha em branco)      separa as falas
#   [[3]] Esperar 1 s      comando que não é fala (fica como está; pode mover ou apagar a linha)
# Uma fala sem @ antes usa quem falou por último.
MARCA = re.compile(r"^\[\[(\d+)\]\]")


def dialogo_para_texto(proj, cmds):
    linhas = []
    ultimo = None
    prof, _par = estrutura(proj, cmds)
    for i, c in enumerate(cmds):
        cl = proj.classe_de(c)
        if cl and cl.nome == "CmdMostrarMsg":
            per = c.get("personagem")
            stem = os.path.splitext(os.path.basename(per.path))[0] if isinstance(per, ExtRef) else "-"
            face = c.get("face", "") or ""
            pos = c.get("posicao", -1.0)
            pos = float(pos) if pos is not None else -1.0
            cab = (stem, face, pos)
            if cab != ultimo:
                h = "@" + stem + (":" + face if face else "") + (" " + _n(pos) if pos >= 0 else "")
                if linhas and linhas[-1] != "":
                    linhas.append("")
                linhas.append(h)
                ultimo = cab
            elif linhas and linhas[-1] != "":
                linhas.append("")
            for ln in (c.get("texto", "") or "").split("\n"):
                if ln == "":
                    linhas.append("\\")
                elif ln.startswith("@") or ln.startswith("[[") or ln.startswith("\\"):
                    linhas.append("\\" + ln)
                else:
                    linhas.append(ln)
        else:
            # comandos seguidos ficam juntos; uma linha em branco separa das falas
            if linhas and linhas[-1] != "" and not MARCA.match(linhas[-1]):
                linhas.append("")
            linhas.append("[[%d]] %s%s" % (i + 1, "    " * prof[i], resumo(proj, c)[0]))
    return "\n".join(linhas) + "\n"


class ErroDialogo(Exception):
    pass


def texto_para_dialogo(proj, texto, originais, script_msg):
    """Converte o texto de volta em comandos. originais: os comandos que viraram [[n]]."""
    saida = []
    atual = ("-", "", -1.0)
    bloco = []
    usados = set()
    # falas originais, na ordem: a n-ésima fala nova reaproveita a n-ésima antiga
    # (mantém campos extras, como metadata)
    msgs_orig = [c for c in originais if c is not None and c.script == script_msg]
    cont = [0]

    def fecha():
        if not bloco:
            return
        stem, face, pos = atual
        cl = proj.classes.get(script_msg)
        if cont[0] < len(msgs_orig):
            r = msgs_orig[cont[0]]     # o próprio objeto: mantém o id no arquivo
            for k in ("personagem", "face", "posicao", "texto"):
                r.props.pop(k, None)
        else:
            r = proj.novo(script_msg)
        cont[0] += 1
        if stem != "-":
            f = proj.falantes.get(stem)
            if not f:
                raise ErroDialogo("falante desconhecido: @%s (veja dados/falantes)" % stem)
            definir(r, cl, "personagem", proj.ext(f["res"], "Resource"))
        if face:
            definir(r, cl, "face", face)
        if pos >= 0:
            definir(r, cl, "posicao", GFloat(pos))
        definir(r, cl, "texto", "\n".join(bloco))
        saida.append(r)
        bloco.clear()

    for num, ln in enumerate(texto.split("\n"), 1):
        s = ln.rstrip("\r")
        if s.strip() == "":
            fecha()
            continue
        m = MARCA.match(s)
        if m:
            fecha()
            k = int(m.group(1)) - 1
            if k < 0 or k >= len(originais) or originais[k] is None:
                raise ErroDialogo("linha %d: [[%d]] não existe" % (num, k + 1))
            if k in usados:
                raise ErroDialogo("linha %d: [[%d]] repetido (copie o comando na lista, não aqui)" % (num, k + 1))
            usados.add(k)
            saida.append(originais[k])
            continue
        if s.startswith("@"):
            fecha()
            cab = s[1:].strip().split()
            if not cab:
                raise ErroDialogo("linha %d: @ sem nome" % num)
            nome = cab[0]
            face = ""
            if ":" in nome:
                nome, face = nome.split(":", 1)
            pos = -1.0
            if len(cab) > 1:
                try:
                    pos = float(cab[1].rstrip("%"))
                except ValueError:
                    raise ErroDialogo("linha %d: posição inválida %r" % (num, cab[1]))
            if nome != "-" and nome not in proj.falantes:
                raise ErroDialogo("linha %d: falante desconhecido @%s" % (num, nome))
            atual = (nome, face, pos)
            continue
        if s == "\\":
            bloco.append("")
            continue
        if s.startswith("\\"):
            s = s[1:]
        bloco.append(s)
    fecha()
    return saida


# ---------------------------------------------------------------------------
# Busca
# ---------------------------------------------------------------------------
def textos_de(res, caminho=""):
    """Gera (caminho_campo, valor_str) de todos os textos de um recurso (recursivo)."""
    vistos = set()

    def rec(v, cam):
        if isinstance(v, Res):
            if id(v) in vistos:
                return
            vistos.add(id(v))
            for k, x in v.props.items():
                if k != "script":
                    yield from rec(x, cam + "." + k if cam else k)
        elif isinstance(v, TypedArray):
            for i, x in enumerate(v.itens):
                yield from rec(x, "%s[%d]" % (cam, i))
        elif isinstance(v, list):
            for i, x in enumerate(v):
                yield from rec(x, "%s[%d]" % (cam, i))
        elif isinstance(v, ExtRef):
            yield cam, os.path.splitext(os.path.basename(v.path))[0]
        elif isinstance(v, str):
            yield cam, str(v)

    yield from rec(res, caminho)


def pasta_backup(raiz_editor):
    p = os.path.join(raiz_editor, "backup", time.strftime("%Y%m%d_%H%M%S"))
    return p


def limpar_backups(raiz_editor, manter=30):
    base = os.path.join(raiz_editor, "backup")
    if not os.path.isdir(base):
        return
    pastas = sorted(d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d)))
    for d in pastas[:-manter]:
        shutil.rmtree(os.path.join(base, d), ignore_errors=True)
