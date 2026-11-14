# Troca a animação da bruxa ou de um evento.
# Bruxa: nome de uma animação de player.gd (ANIMACOES: parado, correr, dash...).
#   Fica até outro comando Animação; vazio = volta ao automático (parado/correr).
# Evento: nome de uma animação do SpriteFrames da página.
#   Fica como a animação parada dele (a rota anda com "andar" e volta para ela);
#   vazio = volta à animação da página. Ao trocar de página, volta ao normal.
class_name CmdAnimacao
extends Comando

enum Alvo { BRUXA, EVENTO }

@export var alvo: Alvo = Alvo.BRUXA:
	set(v):
		alvo = v
		notify_property_list_changed()
## id do evento (alvo = EVENTO). Vazio = este evento.
@export var evento: String = ""
## Nome da animação. Vazio = volta à normal.
@export var animacao: String = ""


func to_dict() -> Dictionary:
	return {"nome": "animacao", "args": [evento if alvo == Alvo.EVENTO else "bruxa", animacao]}


func executar(interp, ev) -> int:
	if alvo == Alvo.BRUXA:
		var p = interp.game_manager.get_player() if interp.game_manager else null
		if p == null or not p.has_method("animacao_por_evento"):
			interp.falhar(ev, self, "bruxa não encontrada")
		elif not p.animacao_por_evento(animacao):
			interp.falhar(ev, self, "a bruxa não tem a animação '%s'" % animacao)
		return AVANCAR
	var no = null
	if evento == "":
		no = ev.origem.get_ref() if ev.origem else null
	else:
		no = interp.encontrar_evento(evento)
	var pg = no._get_active_page_node() if no and no.has_method("_get_active_page_node") else null
	if pg == null or not pg.has_method("set_animation"):
		interp.falhar(ev, self, "evento não encontrado")
		return AVANCAR
	if not pg.set_animation(animacao):
		interp.falhar(ev, self, "o evento não tem a animação '%s'" % animacao)
		return AVANCAR
	if "_rota_anim_base" in no:
		no._rota_anim_base = animacao   # a rota volta para esta quando para de andar
	return AVANCAR


func _validate_property(property: Dictionary) -> void:
	if property.name == "evento" and alvo != Alvo.EVENTO:
		property.usage = PROPERTY_USAGE_STORAGE
