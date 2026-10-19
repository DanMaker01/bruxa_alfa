# Início de bloco condicional (fecha com CmdEnd; CmdElse opcional).
class_name CmdIf
extends Comando

@export var condicao: Condicao

func to_dict() -> Dictionary:
	return {"nome": "if", "args": [condicao.to_dict()] if condicao else [null]}

# Blocos pré-calculados pelo Interpreter (ev.blocks), então if/while aninhados funcionam.
func executar(interp, ev) -> int:
	var b = ev.blocks.get(ev.current_index)
	if b == null or not b.has("end"):
		interp.abortar(ev, "if sem end")
		return MANTER
	if interp.avaliar(condicao):
		ev.current_index += 1
	elif b["else"] != -1:
		ev.current_index = b["else"] + 1
	else:
		ev.current_index = b["end"] + 1
	return MANTER
