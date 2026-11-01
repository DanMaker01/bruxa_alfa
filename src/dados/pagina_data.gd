# pagina_data.gd
# Uma página de evento: quando vale (condição), como dispara (gatilho),
# aparência, área/colisão e a lista de comandos.
class_name PaginaData
extends Resource

enum Gatilho { CLIQUE, TOQUE, PARALELO }
enum Direcao { CENTRO, ESQ, DIR }
enum Movimento { FIXO, ROTA }
const GATILHOS := ["click", "touch", "parallel"]
const DIRECOES := ["centro", "esq", "dir"]

## Condições da página: TODAS precisam ser verdadeiras (ex.: tem o item E var1 == 1 E var2 >= 3).
## Cada uma pode ser variável, item, personalidade, posição ou direção da bruxa.
## Vazio = a página vale sempre. Vence a ÚLTIMA página cujas condições são todas verdadeiras.
@export var condicoes: Array[Condicao] = []
@export var gatilho: Gatilho = Gatilho.CLIQUE
@export var passavel: bool = true
@export var cooldown: float = 0.3

@export_group("Aparência")
@export var sprite_frames: SpriteFrames
@export var animacao: String = "default"
@export var direcao: Direcao = Direcao.CENTRO

@export_group("Colisão e área")
@export var colisao_pos: Vector2 = Vector2.ZERO
## Tamanho da colisão = tamanho do sprite x escala (64x64 sem sprite).
@export var colisao_scale: Vector2 = Vector2.ONE
@export var area_pos: Vector2 = Vector2.ZERO
## Tamanho da área de interação = tamanho do sprite x escala (64x64 sem sprite).
@export var area_scale: Vector2 = Vector2.ONE

@export_group("Movimento autônomo")
## FIXO = parado (só se move por comando). ROTA = repete os passos da "rota" sozinho,
## sem travar o jogo; o gatilho da página continua valendo. Pausa enquanto a própria
## página roda (clique/toque) ou enquanto um comando Mover move este evento.
@export var movimento: Movimento = Movimento.FIXO:
	set(v):
		movimento = v
		notify_property_list_changed()
@export var rota: Array[PassoRota] = []
## Ligado: no fim da rota, recomeça. Desligado: faz uma vez e fica parado.
@export var rota_repetir: bool = true
## Ligado: se der de cara com algo sólido, desiste daquele passo e segue a rota.
## Desligado: fica tentando até conseguir passar.
@export var rota_pular_se_bloqueado: bool = true
## Velocidade inicial da rota (px/s). O passo VELOCIDADE troca no meio.
@export var rota_velocidade: float = 80.0
## Não se afasta mais que isso (px) do ponto onde começou. 0 = sem limite.
@export var rota_raio: float = 0.0

@export_group("Comandos")
@export var comandos: Array[Comando] = []


func get_trigger() -> String:
	return GATILHOS[gatilho]


## true se TODAS as condições da lista forem verdadeiras.
## chave_self: chave do nó do evento (para condições de self-variable).
func condicoes_ok(game_temp, chave_self: String = "") -> bool:
	for c in condicoes:
		if c and not c.avaliar(game_temp, chave_self):
			return false
	return true


## Lista de comandos no formato {nome, args} (só para debug; o Interpreter executa os Resources).
func comandos_dict() -> Array:
	var lista: Array = []
	for c in comandos:
		if c:
			lista.append(c.to_dict())
	return lista


func _validate_property(property: Dictionary) -> void:
	if property.name in ["rota", "rota_repetir", "rota_pular_se_bloqueado", "rota_velocidade", "rota_raio"] \
			and movimento != Movimento.ROTA:
		property.usage = PROPERTY_USAGE_STORAGE
