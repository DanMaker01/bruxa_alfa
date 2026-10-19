# Senão do bloco if.
class_name CmdElse
extends Comando

func to_dict() -> Dictionary:
	return {"nome": "else", "args": []}

# Só chega aqui executando o ramo verdadeiro: pula até depois do end.
func executar(interp, ev) -> int:
	var b = ev.blocks.get(ev.current_index)
	if b == null or not b.has("end"):
		interp.abortar(ev, "else sem if/end")
		return MANTER
	ev.current_index = b["end"] + 1
	return MANTER
