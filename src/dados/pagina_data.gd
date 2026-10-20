# pagina_data.gd
# Uma página de evento: quando vale (condição), como dispara (gatilho),
# aparência, área/colisão e a lista de comandos.
class_name PaginaData
extends Resource

enum Gatilho { CLIQUE, TOQUE, PARALELO }
enum Direcao { CENTRO, ESQ, DIR }
const GATILHOS := ["click", "touch", "parallel"]
const DIRECOES := ["centro", "esq", "dir"]

## Condições da página: TODAS precisam ser verdadeiras (ex.: tem o item E var1 == 1 E var2 >= 3).
## Cada uma pode ser variável, item, personalidade, posição ou direção da bruxa.
## Vazio = a página vale sempre. Vence a ÚLTIMA página cujas condições são todas verdadeiras.
@export var condicoes: Array[Condicao] = []
## (formato antigo, uma condição só) Se preenchida, também precisa ser verdadeira.
## Fica escondida quando vazia; use "condicoes".
@export var condicao: Condicao
@export var gatilho: Gatilho = Gatilho.CLIQUE
@export var passavel: bool = true
@export var cooldown: float = 0.3

@export_group("Aparência")
@export var sprite_frames: SpriteFrames
@export var animacao: String = "default"
@export var direcao: Direcao = Direcao.CENTRO

@export_group("Colisão e área")
@export var colisao_pos: Vector2 = Vector2.ZERO
## Tamanho da colisão = 10 px x escala.
@export var colisao_scale: Vector2 = Vector2.ONE
@export var area_pos: Vector2 = Vector2.ZERO
## Tamanho da área de interação = 10 px x escala.
@export var area_scale: Vector2 = Vector2.ONE

@export_group("Comandos")
@export var comandos: Array[Comando] = []


func get_trigger() -> String:
	return GATILHOS[gatilho]


## true se a condição antiga (se houver) e TODAS as condições da lista forem verdadeiras.
## chave_self: chave do nó do evento (para condições de self-variable).
func condicoes_ok(game_temp, chave_self: String = "") -> bool:
	if condicao and not condicao.avaliar(game_temp, chave_self):
		return false
	for c in condicoes:
		if c and not c.avaliar(game_temp, chave_self):
			return false
	return true


# Inspector: esconde o campo antigo "condicao" quando está vazio.
func _validate_property(property: Dictionary) -> void:
	if property.name == "condicao" and condicao == null:
		property.usage = PROPERTY_USAGE_STORAGE


## Lista de comandos no formato {nome, args} (só para debug; o Interpreter executa os Resources).
func comandos_dict() -> Array:
	var lista: Array = []
	for c in comandos:
		if c:
			lista.append(c.to_dict())
	return lista
