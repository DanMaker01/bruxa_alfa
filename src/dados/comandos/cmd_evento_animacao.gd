# Troca a animação de um evento do mapa (temporário, na página ativa).
# animacao vazia = volta para a animação definida na página.
class_name CmdEventoAnimacao
extends Comando

## id do EventoData do evento.
@export var evento: String = ""
## Nome da animação no SpriteFrames da página. Vazio = animação da página.
@export var animacao: String = ""

func to_dict() -> Dictionary:
	return {"nome": "mudar_animacao", "args": [evento, animacao]}

func executar(interp, ev) -> int:
	var no = interp.encontrar_evento(evento)
	var pagina = no._get_active_page_node() if no and no.has_method("_get_active_page_node") else null
	if not pagina or not pagina.has_method("set_animation"):
		interp.falhar(ev, self, "evento '" + evento + "' não encontrado (ou sem página ativa)")
		return AVANCAR
	if not pagina.set_animation(animacao):
		interp.aviso(ev, "animação '" + animacao + "' não existe em '" + evento + "'")
	return AVANCAR
