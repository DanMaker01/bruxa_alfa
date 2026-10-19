# Abre ou fecha a cena de preparo de poções (abrir: o evento espera o preparo fechar).
class_name CmdPreparo
extends Comando

@export var abrir: bool = true

func to_dict() -> Dictionary:
	return {"nome": "abrir_preparo" if abrir else "fechar_preparo", "args": []}

func executar(interp, ev) -> int:
	var gm = interp.game_manager
	if abrir:
		if not (gm and gm.has_method("abrir_preparo")):
			interp.falhar(ev, self, "GameManager sem abrir_preparo")
			return AVANCAR
		ev.pause("preparo")   # retomado por Interpreter.on_preparo_fechado
		gm.abrir_preparo()
		return MANTER
	if gm and gm.has_method("fechar_preparo"):
		gm.fechar_preparo()
	return AVANCAR
