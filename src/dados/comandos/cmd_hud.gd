# Mostra ou esconde o HUD.
class_name CmdHud
extends Comando

@export var mostrar: bool = true

func to_dict() -> Dictionary:
	return {"nome": "mostrar_hud" if mostrar else "sumir_hud", "args": []}

func executar(interp, _ev) -> int:
	var gm = interp.game_manager
	var metodo := "mostrar_hud" if mostrar else "sumir_hud"
	if gm and gm.has_method(metodo):
		gm.call(metodo)
	return AVANCAR
