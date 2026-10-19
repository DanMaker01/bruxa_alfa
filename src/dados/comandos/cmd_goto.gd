# Pula para um label.
class_name CmdGoto
extends Comando

@export var label: String = ""

func to_dict() -> Dictionary:
	return {"nome": "goto", "args": [label]}

func executar(interp, ev) -> int:
	if ev.labels.has(label):
		ev.current_index = ev.labels[label]
	else:
		interp.abortar(ev, "label não encontrado: " + label)
	return MANTER
