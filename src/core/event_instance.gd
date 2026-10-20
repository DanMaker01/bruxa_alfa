# event_instance.gd
# Uma página de evento em execução no Interpreter (vários rodam em paralelo).
class_name EventInstance
extends RefCounted

var id: int
var name: String
var page_index: int = -1
## Chave do nó do evento no mapa (self-variables). "" = sem nó (ex.: disparado pelo debug).
var chave_self: String = ""
## Nó do evento que disparou (WeakRef: o mapa pode ser trocado no meio).
var origem: WeakRef = null
var commands: Array = []          # Array de Comando (Resources da página)
var current_index: int = 0
var finished: bool = false
var labels: Dictionary = {}       # nome do label -> índice
## Mapa de blocos pré-calculado: índice de if/else/while/end/break -> info do bloco
var blocks: Dictionary = {}
var option_choice: int = -1
var pending_option_labels: Array = []

# ----- ESPERA (comando "esperar") -----
var is_waiting: bool = false
var wait_timer: float = 0.0

# ----- PAUSA -----
# Motivo da pausa. "" = rodando.
# "dialog" | "option" | "preparo" | "move" | "fade"
# Cada motivo só é retomado pelo seu próprio sinal, então um diálogo que
# termina nunca despausa um evento que está esperando fade/movimento.
var pause_reason: String = ""
var move_target_ref: WeakRef = null
## Último comando executado falhou (só para o sinal command_executed).
var falhou: bool = false

var is_paused: bool:
	get: return pause_reason != ""
var waiting_for_option: bool:
	get: return pause_reason == "option"
var waiting_for_preparo: bool:
	get: return pause_reason == "preparo"


func pause(reason: String) -> void:
	pause_reason = reason

func resume_and_advance() -> void:
	pause_reason = ""
	current_index += 1

func comando_atual() -> Comando:
	if current_index >= 0 and current_index < commands.size():
		return commands[current_index]
	return null
