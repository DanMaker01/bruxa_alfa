# Leva a bruxa para outro mapa.
class_name CmdTeleportar
extends Comando

enum Direcao { CENTRO, ESQ, DIR }
const DIRECOES := ["centro", "esq", "dir"]

@export_file("*.tscn") var mapa: String = ""
@export var posicao: Vector2 = Vector2.ZERO
@export var direcao: Direcao = Direcao.CENTRO

func to_dict() -> Dictionary:
	return {"nome": "teleportar", "args": [mapa.get_file().get_basename(), posicao.x, posicao.y, DIRECOES[direcao]]}

func executar(interp, ev) -> int:
	var nome_mapa: String = mapa.get_file().get_basename()
	if nome_mapa == "":
		interp.falhar(ev, self, "sem mapa")
		return AVANCAR
	var gm = interp.game_manager
	if gm and gm.has_method("get_input_manager"):
		var im = gm.get_input_manager()
		if im and im.has_method("stop_movement"):
			im.stop_movement()
	interp.teleport_requested.emit(nome_mapa, posicao.x, posicao.y, DIRECOES[direcao])
	return AVANCAR
