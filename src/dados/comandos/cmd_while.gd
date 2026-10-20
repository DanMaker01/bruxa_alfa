# Repete o bloco enquanto a condição for verdadeira (fecha com CmdEnd).
class_name CmdWhile
extends Comando

@export var condicao: Condicao

func to_dict() -> Dictionary:
	return {"nome": "while", "args": [condicao.to_dict()] if condicao else [null]}

func executar(interp, ev) -> int:
	var b = ev.blocks.get(ev.current_index)
	if b == null or not b.has("end"):
		interp.abortar(ev, "while sem end")
		return MANTER
	if interp.avaliar(condicao, ev):
		ev.current_index += 1
	else:
		ev.current_index = b["end"] + 1
	return MANTER
