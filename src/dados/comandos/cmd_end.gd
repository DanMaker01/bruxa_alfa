# Fim de bloco if / while.
class_name CmdEnd
extends Comando

func to_dict() -> Dictionary:
	return {"nome": "end", "args": []}

func executar(interp, ev) -> int:
	var b = ev.blocks.get(ev.current_index)
	if b == null:
		interp.aviso(ev, "end sem if/while (ignorado)")
		return AVANCAR
	if b["type"] == "while":
		ev.current_index = b["start"]   # volta e reavalia a condição
		return MANTER
	return AVANCAR
