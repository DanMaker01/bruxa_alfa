# Move a bruxa ou um evento do mapa: até um X, até outro evento, um deslocamento, ou para.
# Funciona com a bruxa travada (cutscene). Junta os antigos mover_player, mover_evento e parar_movimento.
class_name CmdMover
extends Comando

enum Alvo { BRUXA, EVENTO }
enum Destino { X, ATE_EVENTO, DESLOCAR, PARAR }
enum Direcao { MANTER, ESQ, DIR, CENTRO }
const DESTINOS := ["x", "evento", "deslocar", "parar"]
const DIRECOES := ["", "esq", "dir", "centro"]

@export var alvo: Alvo = Alvo.BRUXA:
	set(v):
		alvo = v
		notify_property_list_changed()
## id do evento que vai andar (alvo = EVENTO).
@export var evento: String = ""
@export var destino: Destino = Destino.X:
	set(v):
		destino = v
		notify_property_list_changed()
## X de destino (destino = X).
@export var x: float = 0.0
## Y de destino do evento, se "manter_y" estiver desligado (destino = X, alvo = EVENTO).
@export var y: float = 0.0
## id do evento de destino (destino = ATE_EVENTO).
@export var ate_evento: String = ""
## Quanto andar a partir de onde está; negativo = para a esquerda (destino = DESLOCAR).
@export var deslocamento: float = 0.0
## Evento anda só na horizontal (mantém a altura atual).
@export var manter_y: bool = true
## px/s. Bruxa: 0 = normal (acelera como no jogo); > 0 = fixa, sem aceleração.
## Evento: 0 = 100 px/s.
@export var velocidade: float = 0.0
## Bruxa: para onde olhar ao chegar. Evento: para onde olha enquanto anda.
@export var direcao: Direcao = Direcao.MANTER
## Ligado: este evento espera o movimento terminar.
@export var esperar: bool = true

func to_dict() -> Dictionary:
	var quem := "bruxa" if alvo == Alvo.BRUXA else evento
	var para = [x, ate_evento, deslocamento, ""][destino]
	return {"nome": "mover", "args": [quem, DESTINOS[destino], para, velocidade, esperar]}

func executar(interp, ev) -> int:
	return _bruxa(interp, ev) if alvo == Alvo.BRUXA else _evento(interp, ev)

# ---------------- bruxa ----------------
func _bruxa(interp, ev) -> int:
	var gm = interp.game_manager
	var im = gm.get_input_manager() if gm else null
	var player = gm.get_player() if gm else null
	if not im or not player:
		interp.falhar(ev, self, "sem player/InputManager")
		return AVANCAR
	if destino == Destino.PARAR:
		if im.has_method("stop_movement"):
			im.stop_movement()
		return AVANCAR
	var alvo_x = _destino_x(interp, ev, player)
	if alvo_x == null:
		return AVANCAR
	im.move_to_position(alvo_x, player.global_position.y, velocidade)
	if esperar:
		ev.pause("move")
		ev.move_target_ref = weakref(player)
	_acompanhar_bruxa(interp, ev, im, player)
	return MANTER if esperar else AVANCAR

## Espera o InputManager terminar (chegou, travou ou foi cancelado), vira e libera o evento.
func _acompanhar_bruxa(interp, ev, im, player) -> void:
	var tree = interp.get_tree()
	var t := 0.0
	while is_instance_valid(im) and not im.is_moving and t < 0.5:   # espera COMEÇAR
		await tree.process_frame
		t += tree.root.get_process_delta_time()
	while is_instance_valid(im) and im.is_moving:
		await tree.process_frame
	if is_instance_valid(player) and (direcao == Direcao.ESQ or direcao == Direcao.DIR) and player.has_method("virar"):
		player.virar(DIRECOES[direcao])
	if esperar and not ev.finished and ev.pause_reason == "move":
		ev.move_target_ref = null
		ev.resume_and_advance()

# ---------------- evento ----------------
func _evento(interp, ev) -> int:
	var no = interp.encontrar_evento(evento)
	if not no or not no.has_method("move_to"):
		interp.falhar(ev, self, "evento '" + evento + "' não encontrado no mapa")
		return AVANCAR
	if destino == Destino.PARAR:
		if no.has_method("stop_movement"):
			no.stop_movement()
		return AVANCAR
	var alvo_x = _destino_x(interp, ev, no)
	if alvo_x == null:
		return AVANCAR
	var alvo_y: float = no.global_position.y if (manter_y or destino != Destino.X) else y
	var vel: float = velocidade if velocidade > 0.0 else 100.0
	var dir: String = DIRECOES[direcao] if direcao != Direcao.MANTER else "centro"
	if not esperar:
		no.move_to(alvo_x, alvo_y, vel, dir, Callable())
		return AVANCAR
	# pausa até o callback; se o alvo sumir (troca de mapa), o Interpreter segue sozinho
	ev.pause("move")
	ev.move_target_ref = weakref(no)
	no.move_to(alvo_x, alvo_y, vel, dir, func(_ok: bool):
		if not ev.finished and ev.pause_reason == "move":
			ev.move_target_ref = null
			ev.resume_and_advance()
	)
	return MANTER

## X de destino (ou null se falhou).
func _destino_x(interp, ev, quem: Node2D):
	match destino:
		Destino.X:
			return x
		Destino.ATE_EVENTO:
			var no = interp.encontrar_evento(ate_evento)
			if not no:
				interp.falhar(ev, self, "evento '" + ate_evento + "' não encontrado no mapa")
				return null
			return no.global_position.x
		Destino.DESLOCAR:
			return quem.global_position.x + deslocamento
	return null

func _validate_property(property: Dictionary) -> void:
	var mostrar := true
	match property.name:
		"evento": mostrar = alvo == Alvo.EVENTO
		"x": mostrar = destino == Destino.X
		"y": mostrar = destino == Destino.X and alvo == Alvo.EVENTO and not manter_y
		"manter_y": mostrar = destino == Destino.X and alvo == Alvo.EVENTO
		"ate_evento": mostrar = destino == Destino.ATE_EVENTO
		"deslocamento": mostrar = destino == Destino.DESLOCAR
		"velocidade", "direcao", "esperar": mostrar = destino != Destino.PARAR
		_: return
	if not mostrar:
		property.usage = PROPERTY_USAGE_STORAGE
