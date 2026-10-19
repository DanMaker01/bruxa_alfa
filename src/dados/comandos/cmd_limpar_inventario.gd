# Esvazia o inventário.
class_name CmdLimparInventario
extends Comando

func to_dict() -> Dictionary:
	return {"nome": "limpar_inventario", "args": []}

func executar(interp, _ev) -> int:
	if interp.game_temp:
		interp.game_temp.clear_inventory()
	return AVANCAR
