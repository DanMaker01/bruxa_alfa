# Vira um evento do mapa para um lado (sem trocar a animação).
# Vale para a página ativa, até o evento trocar de página.
class_name CmdDirecaoEvento
extends Comando

enum Direcao { CENTRO, ESQ, DIR, INVERTER, PARA_PLAYER }
const NOMES := ["centro", "esq", "dir", "inverter", "player"]

## id do EventoData do evento.
@export var evento: String = ""
@export var direcao: Direcao = Direcao.DIR

func to_dict() -> Dictionary:
	return {"nome": "direcao_evento", "args": [evento, NOMES[direcao]]}

func executar(interp, ev) -> int:
	var no = interp.encontrar_evento(evento)
	var pagina = no._get_active_page_node() if no and no.has_method("_get_active_page_node") else null
	if not pagina or not pagina.has_method("set_direcao"):
		interp.falhar(ev, self, "evento '" + evento + "' não encontrado (ou sem página ativa)")
		return AVANCAR
	match direcao:
		Direcao.CENTRO: pagina.set_direcao("centro")
		Direcao.ESQ: pagina.set_direcao("esq")
		Direcao.DIR: pagina.set_direcao("dir")
		Direcao.INVERTER: pagina.set_direcao("dir" if pagina.get_direcao() == "esq" else "esq")
		Direcao.PARA_PLAYER:
			var player = interp.game_manager.get_player() if interp.game_manager else null
			if player:
				pagina.set_direcao("esq" if player.global_position.x < no.global_position.x else "dir")
	return AVANCAR
