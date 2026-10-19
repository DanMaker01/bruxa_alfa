# Para o movimento de um evento do mapa.
class_name CmdPararMovimento
extends Comando

## id do EventoData do evento.
@export var evento: String = ""

func to_dict() -> Dictionary:
	return {"nome": "parar_movimento", "args": [evento]}

func executar(interp, ev) -> int:
	var alvo = interp.encontrar_evento(evento)
	if not alvo or not alvo.has_method("stop_movement"):
		interp.falhar(ev, self, "evento '" + evento + "' não encontrado no mapa")
		return AVANCAR
	alvo.stop_movement()
	return AVANCAR
