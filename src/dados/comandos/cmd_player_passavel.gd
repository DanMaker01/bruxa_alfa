# Deixa a bruxa passável (atravessa eventos e paredes) ou sólida de novo.
# Os eventos "touch" continuam detectando a bruxa mesmo passável.
class_name CmdPlayerPassavel
extends Comando

@export var passavel: bool = true

func to_dict() -> Dictionary:
	return {"nome": "player_passavel", "args": [passavel]}

func executar(interp, ev) -> int:
	var gm = interp.game_manager
	var player = gm.get_player() if gm else null
	if not player or not player.has_method("set_passavel"):
		interp.falhar(ev, self, "sem player")
		return AVANCAR
	player.set_passavel(passavel)
	return AVANCAR
