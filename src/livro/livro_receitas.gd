# livro_receitas.gd
# Dados do livro de receitas (guardados no GameTemp.livro, um Dictionary simples para o
# save/load depois). Só funções estáticas; a cena (CenaLivro) mostra e edita.
#
# livro = {
#   "paginas":    [página, ...]    efetivas e de NPC, na ordem do livro (contam no limite)
#   "rascunhos":  [página, ...]    temporárias, uma por preparo, as mais novas no fim
#   "max":        12               páginas do livro
#   "max_rascunhos": 10            a mais antiga some quando passa disso
#   "memorizada": id ou -1         receita que vira guia no próximo preparo (só uma, até terminar a poção)
#   "prox_id":    int
# }
# página = {
#   "id": int, "tipo": "efetiva" | "npc" | "rascunho", "nome": String,
#   "passos": [ {"tipo": "chama", "estado": "normal"} | {"tipo": "ingrediente", "item": "erva", "qtd": 8, "seg": 40.0} ],
#   "resultado": {} | {"pocao": String, "a": float, "vezes": int},   ({} = nunca feita)
#   "quando": String,
# }
# "Finalizar" é sempre o último passo: não fica guardado, o livro mostra sozinho.
class_name LivroReceitas
extends RefCounted

const MAX_PAGINAS: int = 12
const MAX_RASCUNHOS: int = 10
const PASTA_RECEITAS := "res://dados/receitas/"
const PASTA_ITENS := "res://dados/itens/"


static func novo(receitas_npc: Array = []) -> Dictionary:
	var l := {"paginas": [], "rascunhos": [], "max": MAX_PAGINAS, "max_rascunhos": MAX_RASCUNHOS,
		"memorizada": -1, "prox_id": 1}
	for r in receitas_npc:
		var p := _pagina(l, "npc", r.nome, r.passos_livro.duplicate(true))
		l["paginas"].append(p)
	return l

## Receitas que a bruxa já conhece (ReceitaData com conhecida = true e passos_livro).
static func receitas_conhecidas() -> Array:
	var r := []
	var dir := DirAccess.open(PASTA_RECEITAS)
	if dir == null:
		return r
	var arqs: Array = []
	for a in dir.get_files():
		var n := a.trim_suffix(".remap")
		if n.ends_with(".tres"):
			arqs.append(n)
	arqs.sort()
	for n in arqs:
		var rec = load(PASTA_RECEITAS + n)
		if rec is ReceitaData and rec.conhecida and not rec.passos_livro.is_empty():
			r.append(rec)
	return r


# ---------------------------------------------------------------------------
static func cheio(l: Dictionary) -> bool:
	return l["paginas"].size() >= int(l["max"])

static func nova_pagina(l: Dictionary) -> Dictionary:
	if cheio(l):
		return {}
	var p := _pagina(l, "efetiva", "Receita sem nome", [])
	l["paginas"].append(p)
	return p

## Cópia editável (de qualquer página, inclusive de NPC e rascunho). Vai logo depois da original.
static func copiar(l: Dictionary, p: Dictionary) -> Dictionary:
	if cheio(l):
		return {}
	var c := _pagina(l, "efetiva", str(p["nome"]) + " (cópia)", p["passos"].duplicate(true))
	var i: int = l["paginas"].find(p)
	if i >= 0:
		l["paginas"].insert(i + 1, c)
	else:
		l["paginas"].append(c)
	return c

static func apagar(l: Dictionary, p: Dictionary) -> void:
	l["paginas"].erase(p)
	l["rascunhos"].erase(p)
	if int(l["memorizada"]) == int(p["id"]):
		l["memorizada"] = -1

## Rascunho vira página efetiva (sai dos rascunhos). Livro cheio = não passa.
static func passar_a_limpo(l: Dictionary, p: Dictionary) -> bool:
	if cheio(l) or not l["rascunhos"].has(p):
		return false
	l["rascunhos"].erase(p)
	p["tipo"] = "efetiva"
	if str(p["nome"]).begins_with("Rascunho"):
		p["nome"] = "Receita sem nome"
	_nome_pela_pocao(p)
	l["paginas"].append(p)
	return true

## Todo preparo terminado anota um rascunho (a integração com o caldeirão chama isto).
static func adicionar_rascunho(l: Dictionary, passos: Array, resultado: Dictionary) -> Dictionary:
	var p := _pagina(l, "rascunho", "Rascunho", passos)
	p["resultado"] = resultado
	l["rascunhos"].append(p)
	while l["rascunhos"].size() > int(l["max_rascunhos"]):
		var velho: Dictionary = l["rascunhos"].pop_front()
		if int(l["memorizada"]) == int(velho["id"]):
			l["memorizada"] = -1
	return p

## Preparo terminado: se bater com uma página (mesmos passos, tempos ±1 s), soma nela
## (vezes + 1, guarda o melhor resultado); senão anota um rascunho. Devolve a página.
## extra: {"item": id do item da poção, "A": matriz, "nomeavel": bool} (para dar nome depois).
static func registrar_preparo(l: Dictionary, passos: Array, pocao: String, a: float, extra: Dictionary = {}) -> Dictionary:
	for p in l["paginas"] + l["rascunhos"]:
		if TranscritorReceita.iguais(p["passos"], passos):
			var r: Dictionary = p.get("resultado", {})
			var vezes: int = int(r.get("vezes", 0)) + 1
			if r.is_empty() or a > float(r.get("a", 0.0)):
				r = {"pocao": pocao, "a": a}
				r.merge(extra, true)
			r["vezes"] = vezes
			p["resultado"] = r
			_nome_pela_pocao(p)
			return p
	var novo := {"pocao": pocao, "a": a, "vezes": 1}
	novo.merge(extra, true)
	var pag := adicionar_rascunho(l, passos, novo)
	pag["escrever"] = true   # a bruxa escreve a página quando abrir o livro (animação)
	_nome_pela_pocao(pag)
	return pag

const NOMES_PADRAO := ["Rascunho", "Receita sem nome"]

## A receita que dá uma poção com nome leva o nome da poção (se a bruxa não deu outro).
static func _nome_pela_pocao(p: Dictionary) -> void:
	var r: Dictionary = p.get("resultado", {})
	if r.is_empty() or r.get("nomeavel", false):
		return
	if str(p.get("nome", "")) in NOMES_PADRAO:
		p["nome"] = str(r.get("pocao", p["nome"]))

## Nome dado no livro a uma poção sem nome: muda o resultado da página, o item no
## inventário e registra no catálogo do jogador (as próximas iguais já vêm com o nome).
static func nomear_pocao(l: Dictionary, p: Dictionary, nome: String, db = null, game_temp = null) -> bool:
	var r: Dictionary = p.get("resultado", {})
	nome = nome.strip_edges()
	if nome == "" or not r.get("nomeavel", false):
		return false
	r["pocao"] = nome
	r["nomeavel"] = false
	_nome_pela_pocao(p)
	var it: ItemData = item(str(r.get("item", "")), db) if r.has("item") else null
	if it:
		it.nome = nome
		it.efeito = CatalogoPocoes.efeito_de(nome)
	if r.has("A"):
		CatalogoPocoes.registrar(nome, r["A"], it.descricao if it else "")
	if game_temp and game_temp.has_signal("inventory_changed"):
		game_temp.inventory_changed.emit()   # HUD mostra o nome novo
	return true

static func memorizar(l: Dictionary, p: Dictionary) -> void:
	l["memorizada"] = -1 if int(l["memorizada"]) == int(p["id"]) else int(p["id"])

static func esta_memorizada(l: Dictionary, p: Dictionary) -> bool:
	return int(l["memorizada"]) == int(p["id"])

static func pagina_memorizada(l: Dictionary) -> Dictionary:
	for p in l["paginas"] + l["rascunhos"]:
		if int(p["id"]) == int(l["memorizada"]):
			return p
	return {}


# ---------------------------------------------------------------------------
## Ingredientes somados na ordem em que aparecem: [[id, qtd], ...]
static func ingredientes(p: Dictionary) -> Array:
	var ordem: Array = []
	var qtd := {}
	for s in p["passos"]:
		if s.get("tipo") == "ingrediente":
			var id: String = s["item"]
			if not qtd.has(id):
				ordem.append(id)
				qtd[id] = 0
			qtd[id] += int(s.get("qtd", 1))
	var r := []
	for id in ordem:
		r.append([id, qtd[id]])
	return r

static func texto_passo(s: Dictionary, db = null) -> String:
	if s.get("tipo") == "chama":
		return "Chama " + EstadosChama.nome(s["estado"]).to_lower()
	if s.get("tipo") == "ingrediente":
		var q: int = int(s.get("qtd", 1))
		return "%s%s, %d s" % [nome_item(s["item"], db), " ×%d" % q if q > 1 else "", roundi(float(s.get("seg", 0.0)))]
	return "?"

static func nome_item(id: String, db = null) -> String:
	var it := item(id, db)
	return it.get_nome() if it else id

static func item(id: String, db = null) -> ItemData:
	if db and db.has_method("get_item"):
		var it = db.get_item(id)
		if it:
			return it
	var caminho := PASTA_ITENS + id + ".tres"
	if ResourceLoader.exists(caminho):
		return load(caminho) as ItemData
	return null

## Ingredientes de cozinhar (algum gabarito de cozimento, temperatura ou tempo).
static func eh_ingrediente(it: ItemData) -> bool:
	return it != null and (it.m > 0.0 or it.T_min > 0.0 or it.T_max > 0.0 or it.t_min > 0.0 or it.t_max > 0.0)

## Todos os ingredientes do jogo (cena aberta sozinha, sem GameTemp).
static func todos_ingredientes(db = null) -> Array:
	var ids: Array = []
	if db and db.has_method("get_items"):
		ids = db.get_items().keys()
	else:
		var dir := DirAccess.open(PASTA_ITENS)
		if dir:
			for a in dir.get_files():
				var n := a.trim_suffix(".remap")
				if n.ends_with(".tres"):
					ids.append(n.get_basename())
	var r := []
	for id in ids:
		if eh_ingrediente(item(id, db)):
			r.append(id)
	r.sort()
	return r


# ---------------------------------------------------------------------------
static func _pagina(l: Dictionary, tipo: String, nome: String, passos: Array) -> Dictionary:
	var p := {"id": int(l["prox_id"]), "tipo": tipo, "nome": nome, "passos": passos,
		"resultado": {}, "quando": Time.get_datetime_string_from_system(false, true)}
	l["prox_id"] = int(l["prox_id"]) + 1
	return p
