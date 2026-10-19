# Vira a bruxa para um lado (sem andar).
class_name CmdDirecaoPlayer
extends Comando

enum Direcao { ESQ, DIR, INVERTER, PARA_EVENTO }
const NOMES := ["esq", "dir", "inverter", "evento"]

@export var direcao: Direcao = Direcao.DIR:
	set(v):
		direcao = v
		notify_property_list_changed()
## id do EventoData para onde olhar (direcao = PARA_EVENTO).
@export var evento: String = ""

func to_dict() -> Dictionary:
	return {"nome": "direcao_player", "args": [NOMES[direcao], evento if direcao == Direcao.PARA_EVENTO else ""]}

func executar(interp, ev) -> int:
	var gm = interp.game_manager
	var player = gm.get_player() if gm else null
	if not player or not player.has_method("virar"):
		interp.falhar(ev, self, "sem player")
		return AVANCAR
	match direcao:
		Direcao.ESQ: player.virar("esq")
		Direcao.DIR: player.virar("dir")
		Direcao.INVERTER: player.virar("dir" if player.get_direcao() == "esq" else "esq")
		Direcao.PARA_EVENTO:
			var no = interp.encontrar_evento(evento)
			if not no:
				interp.falhar(ev, self, "evento '" + evento + "' não encontrado no mapa")
				return AVANCAR
			player.virar("esq" if no.global_position.x < player.global_position.x else "dir")
	return AVANCAR

func _validate_property(property: Dictionary) -> void:
	if property.name == "evento" and direcao != Direcao.PARA_EVENTO:
		property.usage = PROPERTY_USAGE_STORAGE
