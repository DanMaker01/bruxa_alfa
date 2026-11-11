extends Node

var variaveis = {}
var personalidades = {}
var inventario = {}
## Self-variables: chave do evento ("mapa:caminho/do/no") -> {"A": 0/1, ...}
var self_vars: Dictionary = {}
## Posições sorteadas pelas áreas de spawn: chave da área -> Array[Vector2]
var spawns: Dictionary = {}
## Poções que o jogador nomeou nesta sessão (catálogo do jogador).
var pocoes_nomeadas: CatalogoPocoes = CatalogoPocoes.new()
## Livro de receitas (ver LivroReceitas). Vazio até o database carregar.
var livro: Dictionary = {}
## Itens que a bruxa já teve alguma vez (id -> true): o livro só deixa escolher esses.
var itens_vistos: Dictionary = {}

var database = null
var database_pronto = false

signal variables_changed
signal personality_changed(name)
signal inventory_changed

func _ready():
	print("[GameTemp] Inicializando...")
	database = get_parent().get_node("DatabaseManager")
	
	if database:
		if database.is_connected("loaded", Callable(self, "_on_database_loaded")):
			print("[GameTemp] Database já conectado")
		else:
			database.loaded.connect(_on_database_loaded)
			print("[GameTemp] Conectado ao sinal loaded do DatabaseManager")
		
		if not database.itens.is_empty():
			print("[GameTemp] Database já carregado, inicializando...")
			_on_database_loaded()
	else:
		push_error("[GameTemp] DatabaseManager não encontrado!")

func _on_database_loaded():
	print("[GameTemp] Database carregado, copiando dados...")
	
	var vars_iniciais = database.get_initial_vars()
	variaveis = vars_iniciais.duplicate()
	print("[GameTemp] Variáveis copiadas: ", variaveis)
	
	var pers_iniciais = database.get_personalities()
	for nome in pers_iniciais:
		personalidades[nome] = pers_iniciais[nome].duplicate()
	print("[GameTemp] Personalidades copiadas: ", personalidades.keys())
	
	inventario = {}
	print("[GameTemp] Inventário vazio")
	self_vars = {}
	spawns = {}
	pocoes_nomeadas = CatalogoPocoes.new()
	livro = LivroReceitas.novo(LivroReceitas.receitas_conhecidas())
	itens_vistos = {}
	
	database_pronto = true
	print("[GameTemp] ===== PRONTO =====")

# ===== VARIÁVEIS =====

## Variáveis são sempre número: uma que não existe vale 0.
func get_var(nome: String):
	return variaveis.get(nome, 0.0)

func set_var(nome: String, valor):
	var old = variaveis.get(nome)
	variaveis[nome] = valor
	print("[GameTemp] 🔄 Variável alterada: ", nome, " (", old, " -> ", valor, ")")
	variables_changed.emit()

func add_var(nome: String, valor):
	var atual = variaveis.get(nome, 0)
	set_var(nome, atual + valor)

func sub_var(nome: String, valor):
	var atual = variaveis.get(nome, 0)
	set_var(nome, atual - valor)

func has_var(nome: String) -> bool:
	return variaveis.has(nome)

func get_all_vars() -> Dictionary:
	print("[GameTemp] 📊 Retornando todas as variáveis: ", variaveis)
	return variaveis.duplicate()

# ===== SELF-VARIABLES (uma por evento no mapa) =====

func get_self_var(chave: String, letra: String) -> float:
	return float(self_vars.get(chave, {}).get(letra, 0.0))

func set_self_var(chave: String, letra: String, valor: float) -> void:
	if chave == "":
		return
	if not self_vars.has(chave):
		self_vars[chave] = {}
	self_vars[chave][letra] = valor
	print("[GameTemp] 🔄 Self-var ", chave, " ", letra, " = ", valor)
	variables_changed.emit()   # páginas reavaliam como numa variável comum

## Apaga as self-variables de todas as chaves que começam com o prefixo (sem emitir sinal).
func limpar_self_vars(prefixo: String) -> void:
	for chave in self_vars.keys():
		if str(chave).begins_with(prefixo):
			self_vars.erase(chave)

# ===== PERSONALIDADES =====

func get_personality(nome: String) -> Array:
	return personalidades.get(nome, [])

func set_personality(nome: String, valores: Array):
	personalidades[nome] = valores
	print("[GameTemp] Personalidade alterada: ", nome, " = ", valores)
	personality_changed.emit(nome)

func add_personality_value(nome: String, index: int, valor):
	if personalidades.has(nome):
		var pers = personalidades[nome]
		if index >= 0 and index < pers.size():
			pers[index] = pers[index] + valor
			personality_changed.emit(nome)
			print("[GameTemp] Personalidade ", nome, "[", index, "] = ", pers[index])

func has_personality(nome: String) -> bool:
	return personalidades.has(nome)

func get_all_personalities() -> Dictionary:
	return personalidades.duplicate()

func get_personality_value(pers_name: String, index: int) -> float:
	if personalidades.has(pers_name):
		var pers = personalidades[pers_name]
		if index >= 0 and index < pers.size():
			return pers[index]
	return 0.0

# ===== INVENTÁRIO =====

func add_item(item_name: String, quantidade: int = 1):
	if database and database.has_item(item_name):
		itens_vistos[item_name] = true
		if inventario.has(item_name):
			inventario[item_name] += quantidade
		else:
			inventario[item_name] = quantidade
		print("[GameTemp] Item adicionado: ", item_name, " x", quantidade, " (total: ", inventario[item_name], ")")
		inventory_changed.emit()
		var main = get_tree().current_scene
		if main:
			var gm = main.get_node_or_null("GameManager")
			if gm and gm.has_method("_show_notification"):
				var item: ItemData = database.get_item(item_name)
				var nome = item.get_nome() if item else item_name
				gm._show_notification("+" + str(quantidade) + " " + nome)
	else:
		print("[GameTemp] ERRO: Item não existe no database: ", item_name)

func remove_item(item_name: String, quantidade: int = 1):
	if inventario.has(item_name):
		var atual = inventario[item_name]
		if atual <= quantidade:
			inventario.erase(item_name)
			print("[GameTemp] Item removido completamente: ", item_name)
		else:
			inventario[item_name] = atual - quantidade
			print("[GameTemp] Item removido: ", item_name, " x", quantidade, " (restam: ", inventario[item_name], ")")
		inventory_changed.emit()
	else:
		print("[GameTemp] Item não encontrado no inventário: ", item_name)

func get_item_quantity(item_name: String) -> int:
	return inventario.get(item_name, 0)

func has_item(item_name: String) -> bool:
	return inventario.has(item_name)

func has_item_quantity(item_name: String, quantidade: int) -> bool:
	return inventario.get(item_name, 0) >= quantidade

func get_inventory() -> Dictionary:
	return inventario.duplicate()

func get_inventory_count() -> int:
	var total = 0
	for qtd in inventario.values():
		total += qtd
	return total

func get_inventory_items() -> Array:
	return inventario.keys()

func clear_inventory():
	inventario = {}
	print("[GameTemp] Inventário limpo")
	inventory_changed.emit()

# ===== UTILITÁRIOS =====

func reset():
	print("[GameTemp] Resetando estado...")
	if database and database_pronto:
		_on_database_loaded()
	else:
		push_error("[GameTemp] Database não pronto para reset")

func debug():
	print("\n=== GAME TEMP DEBUG ===")
	print("VARIÁVEIS:")
	for nome in variaveis:
		print("  ", nome, " = ", variaveis[nome])
	
	print("\nPERSONALIDADES:")
	for nome in personalidades:
		print("  ", nome, ": ", personalidades[nome])
	
	print("\nINVENTÁRIO:")
	if inventario.is_empty():
		print("  (vazio)")
	else:
		for item in inventario:
			print("  - ", item, " x", inventario[item])
	print("========================\n")
