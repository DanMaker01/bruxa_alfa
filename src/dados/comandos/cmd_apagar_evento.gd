# Apaga um evento do mapa até a bruxa sair do mapa (ao voltar, ele reaparece).
# Para sumir de vez, use uma variável/self-variable e uma página vazia.
class_name CmdApagarEvento
extends Comando

## id do evento. Vazio = o próprio evento que está rodando.
@export var evento: String = ""

func to_dict() -> Dictionary:
	return {"nome": "apagar_evento", "args": [evento if evento != "" else "(este)"]}

func executar(interp, ev) -> int:
	var no = null
	if evento == "":
		no = ev.origem.get_ref() if ev.origem else null
	else:
		no = interp.encontrar_evento(evento)
	if no == null or not is_instance_valid(no):
		interp.falhar(ev, self, "evento não encontrado no mapa")
		return AVANCAR
	# o comando em execução continua: os comandos são Resources, não dependem do nó
	no.queue_free()
	return AVANCAR
