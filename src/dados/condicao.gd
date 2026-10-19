# condicao.gd
# Condição usada por páginas e pelos comandos if/while. O "tipo" escolhe o que testar:
#   VARIAVEL       variável do jogo (nome em "variavel")                   op valor
#   ITEM           quantidade de um item no inventário ("item")            op valor
#   PERSONALIDADE  traço O/C/E/A/N de uma personalidade (nome em "variavel") op valor
#   POSICAO_X/Y    posição da bruxa no mapa (px)                           op valor
#   DIRECAO_PLAYER para onde a bruxa olha ("direcao"), só == ou !=
# Uma página pode ter várias condições (PaginaData.condicoes): todas precisam valer.
# Páginas reavaliam quando muda uma variável, o inventário ou uma personalidade;
# posição/direção servem para if/while (numa página só são vistas na próxima reavaliação).
# Variáveis são sempre número (use 0 e 1 no lugar de falso/verdadeiro).
class_name Condicao
extends Resource

const PageSelector = preload("res://src/core/page_selector.gd")

enum Tipo { VARIAVEL, ITEM, PERSONALIDADE, POSICAO_X, POSICAO_Y, DIRECAO_PLAYER }
enum Operador { IGUAL, DIFERENTE, MAIOR, MENOR, MAIOR_IGUAL, MENOR_IGUAL }
enum Traco { O, C, E, A, N }
enum Direcao { ESQ, DIR }
const OPERADORES := ["==", "!=", ">", "<", ">=", "<="]
const TIPOS := ["var", "item", "personalidade", "x", "y", "direcao"]
const DIRECOES := ["esq", "dir"]

@export var tipo: Tipo = Tipo.VARIAVEL:
	set(v):
		tipo = v
		notify_property_list_changed()   # mostra só os campos do tipo escolhido
## Nome da variável (VARIAVEL) ou da personalidade (PERSONALIDADE).
@export var variavel: String = ""
@export var item: ItemData
@export var traco: Traco = Traco.O
@export var direcao: Direcao = Direcao.DIR
@export var operador: Operador = Operador.IGUAL
@export var valor: float = 0.0


func avaliar(game_temp) -> bool:
	if game_temp == null:
		return false
	var atual = null
	match tipo:
		Tipo.VARIAVEL:
			atual = game_temp.get_var(variavel)
		Tipo.ITEM:
			atual = game_temp.get_item_quantity(item.id if item else variavel)
		Tipo.PERSONALIDADE:
			atual = game_temp.get_personality_value(variavel, traco)
		Tipo.POSICAO_X, Tipo.POSICAO_Y:
			var p = _player(game_temp)
			if p == null:
				return false
			atual = p.global_position.x if tipo == Tipo.POSICAO_X else p.global_position.y
		Tipo.DIRECAO_PLAYER:
			var p = _player(game_temp)
			if p == null or not p.has_method("get_direcao"):
				return false
			var igual: bool = p.get_direcao() == DIRECOES[direcao]
			match operador:
				Operador.IGUAL: return igual
				Operador.DIFERENTE: return not igual
			return false
	return PageSelector.compare(atual, OPERADORES[operador], valor)

static func _player(game_temp) -> Node:
	return game_temp.get_node_or_null("/root/Main/Mundo/Player") if game_temp is Node else null

func to_dict() -> Dictionary:
	match tipo:
		Tipo.VARIAVEL:
			return {"var": variavel, "op": OPERADORES[operador], "val": valor}
		Tipo.ITEM:
			return {"tipo": "item", "item": item.id if item else variavel, "op": OPERADORES[operador], "val": valor}
		Tipo.PERSONALIDADE:
			return {"tipo": "personalidade", "nome": variavel, "traco": Traco.keys()[traco], "op": OPERADORES[operador], "val": valor}
		Tipo.DIRECAO_PLAYER:
			return {"tipo": "direcao", "op": OPERADORES[operador], "val": DIRECOES[direcao]}
	return {"tipo": TIPOS[tipo], "op": OPERADORES[operador], "val": valor}

# Inspector: esconde os campos que não valem para o tipo escolhido.
func _validate_property(property: Dictionary) -> void:
	var nome: String = property.name
	var mostrar := true
	match nome:
		"variavel": mostrar = tipo == Tipo.VARIAVEL or tipo == Tipo.PERSONALIDADE
		"item": mostrar = tipo == Tipo.ITEM
		"traco": mostrar = tipo == Tipo.PERSONALIDADE
		"direcao": mostrar = tipo == Tipo.DIRECAO_PLAYER
		"valor": mostrar = tipo != Tipo.DIRECAO_PLAYER
		_: return
	if not mostrar:
		property.usage = PROPERTY_USAGE_STORAGE   # continua salvo, só não aparece
