# Espera alguns segundos.
class_name CmdEsperar
extends Comando

@export var segundos: float = 1.0

func to_dict() -> Dictionary:
	return {"nome": "esperar", "args": [segundos]}

func executar(_interp, ev) -> int:
	ev.is_waiting = true
	ev.wait_timer = segundos
	return MANTER   # o Interpreter avança quando o tempo acabar
