# DatabaseManager
# Carrega os dados globais do jogo a partir de res://dados/banco.tres (BancoDados):
# itens, personalidades e variáveis iniciais.
# Os eventos não passam mais por aqui: cada nó de evento aponta para o seu EventoData.

extends Node

const BANCO_PATH = "res://dados/banco.tres"
## Uma variável por arquivo (VariavelData). Todas as .tres desta pasta (e subpastas) entram.
const PASTA_VARIAVEIS = "res://dados/variaveis/"

var banco: BancoDados = null
var itens: Dictionary = {}            # id -> ItemData
var personalidades: Dictionary = {}   # id -> PersonalidadeData
var variaveis_iniciais: Dictionary = {}
var variaveis_descricao: Dictionary = {}   # nome -> descrição (VariavelData.descricao)

signal loaded
signal load_error(error)

func _ready():
	_load()

# ===== CARREGAMENTO =====

func _load():
	banco = load(BANCO_PATH) as BancoDados
	if banco == null:
		var msg = "Não foi possível carregar " + BANCO_PATH
		push_error("[DatabaseManager] " + msg)
		load_error.emit(msg)
		return

	itens.clear()
	for it in banco.itens:
		if it == null:
			continue
		if it.id == "":
			push_warning("[DatabaseManager] Item sem id: " + it.resource_path)
			continue
		if itens.has(it.id):
			push_warning("[DatabaseManager] Item com id repetido: " + it.id)
		itens[it.id] = it

	personalidades.clear()
	for p in banco.personalidades:
		if p and p.id != "":
			personalidades[p.id] = p

	variaveis_iniciais.clear()
	for v in banco.variaveis:
		if v and v.nome != "":
			variaveis_iniciais[v.nome] = v.valor_inicial()
	_carregar_variaveis(PASTA_VARIAVEIS)

	print("[DatabaseManager] Carregado: ", itens.size(), " itens, ", personalidades.size(),
		" personalidades, ", variaveis_iniciais.size(), " variáveis")
	loaded.emit()

func _carregar_variaveis(pasta: String) -> void:
	var dir := DirAccess.open(pasta)
	if dir == null:
		return
	for sub in dir.get_directories():
		_carregar_variaveis(pasta.path_join(sub))
	for arq in dir.get_files():
		var nome := arq.trim_suffix(".remap")   # no jogo exportado os .tres viram .tres.remap
		if not nome.ends_with(".tres"):
			continue
		var v = load(pasta.path_join(nome))
		if v is VariavelData and v.nome != "":
			if variaveis_iniciais.has(v.nome):
				push_warning("[DatabaseManager] Variável repetida: " + v.nome)
			variaveis_iniciais[v.nome] = v.valor_inicial()
			if v.get("descricao"):
				variaveis_descricao[v.nome] = v.descricao

## Descrição da variável (vazio se não tiver).
func get_var_descricao(nome: String) -> String:
	return str(variaveis_descricao.get(nome, ""))

# ===== CONSULTAS =====

## Retorna o ItemData do id, ou null.
func get_item(id: String) -> ItemData:
	return itens.get(id)

## id -> ItemData
func get_items() -> Dictionary:
	return itens

## Vetor inicial (O, C, E, A, N) da personalidade, ou [] se não existir.
func get_personality(id: String) -> Array:
	var p: PersonalidadeData = personalidades.get(id)
	return p.como_array() if p else []

## id -> Array (O, C, E, A, N)
func get_personalities() -> Dictionary:
	var out := {}
	for id in personalidades:
		out[id] = personalidades[id].como_array()
	return out

func get_initial_vars() -> Dictionary:
	return variaveis_iniciais.duplicate()

## Itens criados durante o jogo (ex.: poções do caldeirão).
## Ficam só na memória: o save/load ainda precisa guardá-los.
var itens_dinamicos: Dictionary = {}   # id -> ItemData

## Registra um item criado em tempo de jogo, para o inventário/HUD encontrá-lo pelo id.
func registrar_item(item: ItemData) -> void:
	if item == null or item.id == "":
		push_warning("[DatabaseManager] registrar_item: item sem id")
		return
	if itens.has(item.id) and not itens_dinamicos.has(item.id):
		push_warning("[DatabaseManager] registrar_item: id já existe no banco: " + item.id)
		return
	itens[item.id] = item
	itens_dinamicos[item.id] = item
	print("[DatabaseManager] ✨ Item registrado: ", item.id, " (", item.get_nome(), ")")

## Próximo id livre com o prefixo dado: "pocao_1", "pocao_2"...
func novo_id(prefixo: String) -> String:
	var n := 1
	while itens.has("%s_%d" % [prefixo, n]):
		n += 1
	return "%s_%d" % [prefixo, n]

func has_item(id: String) -> bool:
	return itens.has(id)

func has_personality(id: String) -> bool:
	return personalidades.has(id)

func debug():
	print("\n===== DATABASE (", BANCO_PATH, ") =====")
	print("ITENS (", itens.size(), "):")
	for id in itens:
		var it: ItemData = itens[id]
		print("  - ", id, " (", it.get_nome(), ") m=", it.m, " s=", it.s_menos, "/", it.s_mais,
			" T=[", it.T_min, ",", it.T_max, "] t=[", it.t_min, ",", it.t_max, "]")
	print("PERSONALIDADES (", personalidades.size(), "):")
	for id in personalidades:
		print("  - ", id, ": ", personalidades[id].como_array())
	print("VARIÁVEIS INICIAIS (", variaveis_iniciais.size(), "):")
	for nome in variaveis_iniciais:
		print("  - ", nome, " = ", variaveis_iniciais[nome])
	print("====================================\n")
