# Chama outro evento (EventoData de res://dados/eventos/): roda a página válida dele
# como se os comandos estivessem aqui. Use para cenas que aparecem em mais de um
# lugar (ex.: a entrega da poção, que pode começar pelo rei, pela princesa ou na chegada).
# Labels, if/else e goto valem só dentro do evento chamado.
class_name CmdChamarEvento
extends Comando

@export var evento: EventoData
## Ligado: este evento espera o chamado terminar antes de seguir.
@export var esperar: bool = true

func to_dict() -> Dictionary:
	return {"nome": "chamar_evento", "args": [evento.id if evento else ""]}

func executar(interp, ev) -> int:
	if evento == null:
		interp.falhar(ev, self, "nenhum evento escolhido")
		return AVANCAR
	var filho = interp.chamar_evento(evento, ev)
	if filho == null:
		interp.falhar(ev, self, "evento '%s' não rodou" % evento.id)
		return AVANCAR
	if not esperar:
		return AVANCAR
	ev.filho = filho
	ev.pause("chamado")
	return MANTER
