# Deixa um evento do mapa passável (a bruxa atravessa) ou sólido.
# Vale para a página ativa, até o evento trocar de página.
class_name CmdEventoPassavel
extends Comando

## id do EventoData do evento.
@export var evento: String = ""
@export var passavel: bool = true

func to_dict() -> Dictionary:
	return {"nome": "evento_passavel", "args": [evento, passavel]}

func executar(interp, ev) -> int:
	var no = interp.encontrar_evento(evento)
	var pagina = no._get_active_page_node() if no and no.has_method("_get_active_page_node") else null
	if not pagina or not pagina.has_method("set_passavel"):
		interp.falhar(ev, self, "evento '" + evento + "' não encontrado (ou sem página ativa)")
		return AVANCAR
	pagina.set_passavel(passavel)
	return AVANCAR
