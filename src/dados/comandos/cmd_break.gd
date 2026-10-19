# Sai do while mais interno.
class_name CmdBreak
extends Comando

func to_dict() -> Dictionary:
	return {"nome": "break", "args": []}

func executar(interp, ev) -> int:
	var b = ev.blocks.get(ev.current_index)
	if b == null or not b.has("end"):
		interp.abortar(ev, "break fora de while")
		return MANTER
	ev.current_index = b["end"] + 1
	return MANTER
