# Deixa a bruxa ou um evento passável (atravessa) ou sólido de novo.
# Evento: vale para a página ativa, até ele trocar de página.
# Bruxa: os eventos de toque continuam detectando ela mesmo passável.
# Junta os antigos player_passavel e evento_passavel.
class_name CmdPassavel
extends Comando

enum Alvo { BRUXA, EVENTO }

@export var alvo: Alvo = Alvo.EVENTO:
	set(v):
		alvo = v
		notify_property_list_changed()
## id do evento (alvo = EVENTO).
@export var evento: String = ""
@export var passavel: bool = true

func to_dict() -> Dictionary:
	return {"nome": "passavel", "args": ["bruxa" if alvo == Alvo.BRUXA else evento, passavel]}

func executar(interp, ev) -> int:
	var alvo_no
	if alvo == Alvo.BRUXA:
		alvo_no = interp.game_manager.get_player() if interp.game_manager else null
	else:
		var no = interp.encontrar_evento(evento)
		alvo_no = no._get_active_page_node() if no and no.has_method("_get_active_page_node") else null
	if alvo_no == null or not alvo_no.has_method("set_passavel"):
		interp.falhar(ev, self, "alvo não encontrado")
		return AVANCAR
	alvo_no.set_passavel(passavel)
	return AVANCAR

func _validate_property(property: Dictionary) -> void:
	if property.name == "evento" and alvo != Alvo.EVENTO:
		property.usage = PROPERTY_USAGE_STORAGE
