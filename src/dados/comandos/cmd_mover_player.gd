# Faz a bruxa andar até um X, até um evento ou um deslocamento a partir de onde está.
# Funciona com a bruxa travada (cutscene). Para sozinha se bater num obstáculo.
class_name CmdMoverPlayer
extends Comando

enum Modo { PARA_X, PARA_EVENTO, DESLOCAR }
enum DirecaoFinal { MANTER, ESQ, DIR }
const MODOS := ["x", "evento", "deslocar"]
const DIRECOES := ["", "esq", "dir"]

@export var modo: Modo = Modo.PARA_X:
	set(v):
		modo = v
		notify_property_list_changed()
## Posição X de destino (modo PARA_X).
@export var x: float = 0.0
## id do EventoData do evento de destino (modo PARA_EVENTO).
@export var evento: String = ""
## Quanto andar a partir da posição atual; negativo = para a esquerda (modo DESLOCAR).
@export var deslocamento: float = 0.0
## Para onde olhar ao chegar.
@export var direcao_final: DirecaoFinal = DirecaoFinal.MANTER
## Se ligado, o evento atual espera a bruxa chegar.
@export var esperar: bool = true

func to_dict() -> Dictionary:
	var alvo = x if modo == Modo.PARA_X else (evento if modo == Modo.PARA_EVENTO else deslocamento)
	return {"nome": "mover_player", "args": [MODOS[modo], alvo, DIRECOES[direcao_final], esperar]}

func executar(interp, ev) -> int:
	var gm = interp.game_manager
	var im = gm.get_input_manager() if gm else null
	var player = gm.get_player() if gm else null
	if not im or not player:
		interp.falhar(ev, self, "sem player/InputManager")
		return AVANCAR
	var alvo_x: float
	match modo:
		Modo.PARA_X:
			alvo_x = x
		Modo.PARA_EVENTO:
			var no = interp.encontrar_evento(evento)
			if not no:
				interp.falhar(ev, self, "evento '" + evento + "' não encontrado no mapa")
				return AVANCAR
			alvo_x = no.global_position.x
		Modo.DESLOCAR:
			alvo_x = player.global_position.x + deslocamento
	im.move_to_position(alvo_x, player.global_position.y)
	if esperar:
		ev.pause("move")
		ev.move_target_ref = weakref(player)
	_acompanhar(interp, ev, im, player)
	return MANTER if esperar else AVANCAR

## Espera o InputManager terminar (chegou, travou ou foi cancelado), vira e libera o evento.
func _acompanhar(interp, ev, im, player) -> void:
	var tree = interp.get_tree()
	# espera o movimento COMEÇAR (pode levar alguns frames) antes de esperar ele acabar
	var t := 0.0
	while is_instance_valid(im) and not im.is_moving and t < 0.5:
		await tree.process_frame
		t += tree.root.get_process_delta_time()
	while is_instance_valid(im) and im.is_moving:
		await tree.process_frame
	if is_instance_valid(player) and direcao_final != DirecaoFinal.MANTER and player.has_method("virar"):
		player.virar(DIRECOES[direcao_final])
	if esperar and not ev.finished and ev.pause_reason == "move":
		ev.move_target_ref = null
		ev.resume_and_advance()

func _validate_property(property: Dictionary) -> void:
	var mostrar := true
	match property.name:
		"x": mostrar = modo == Modo.PARA_X
		"evento": mostrar = modo == Modo.PARA_EVENTO
		"deslocamento": mostrar = modo == Modo.DESLOCAR
		_: return
	if not mostrar:
		property.usage = PROPERTY_USAGE_STORAGE
