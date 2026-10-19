# Move um evento do mapa até uma posição.
class_name CmdMoverEvento
extends Comando

enum Direcao { CENTRO, ESQ, DIR }
const DIRECOES := ["centro", "esq", "dir"]

## id do EventoData do evento a mover.
@export var evento: String = ""
@export var posicao: Vector2 = Vector2.ZERO
@export var velocidade: float = 100.0
@export var direcao: Direcao = Direcao.CENTRO
## Se ligado, o evento atual espera o movimento terminar.
@export var esperar: bool = true

func to_dict() -> Dictionary:
	return {"nome": "move_event", "args": [evento, posicao.x, posicao.y, velocidade, DIRECOES[direcao], esperar]}

func executar(interp, ev) -> int:
	var alvo = interp.encontrar_evento(evento)
	if not alvo or not alvo.has_method("move_to"):
		interp.falhar(ev, self, "evento '" + evento + "' não encontrado no mapa")
		return AVANCAR
	if not esperar:
		alvo.move_to(posicao.x, posicao.y, velocidade, DIRECOES[direcao], Callable())
		return AVANCAR
	# Pausa até o callback. Se o alvo sumir (troca de mapa), o Interpreter detecta e segue.
	ev.pause("move")
	ev.move_target_ref = weakref(alvo)
	alvo.move_to(posicao.x, posicao.y, velocidade, DIRECOES[direcao], func(_ok: bool):
		if not ev.finished and ev.pause_reason == "move":
			ev.move_target_ref = null
			ev.resume_and_advance()
	)
	return MANTER
