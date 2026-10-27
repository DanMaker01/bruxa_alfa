# Vira a bruxa ou um evento para um lado (sem andar e sem trocar a animação).
# No evento vale para a página ativa, até ele trocar de página.
# Junta os antigos direcao_player e direcao_evento.
class_name CmdDirecao
extends Comando

enum Alvo { BRUXA, EVENTO }
enum Direcao { ESQ, DIR, INVERTER, CENTRO, OLHAR_PARA }
const NOMES := ["esq", "dir", "inverter", "centro", "olhar_para"]

@export var alvo: Alvo = Alvo.BRUXA:
	set(v):
		alvo = v
		notify_property_list_changed()
## id do evento que vira (alvo = EVENTO).
@export var evento: String = ""
@export var direcao: Direcao = Direcao.DIR:
	set(v):
		direcao = v
		notify_property_list_changed()
## Para quem olhar (direcao = OLHAR_PARA): id de um evento. Vazio = a bruxa.
@export var olhar_para: String = ""

func to_dict() -> Dictionary:
	return {"nome": "direcao", "args": ["bruxa" if alvo == Alvo.BRUXA else evento, NOMES[direcao], olhar_para]}

func executar(interp, ev) -> int:
	var player = interp.game_manager.get_player() if interp.game_manager else null
	var no = player if alvo == Alvo.BRUXA else interp.encontrar_evento(evento)
	# a bruxa vira pelo player; o evento pela página ativa
	var quem = player if alvo == Alvo.BRUXA else (no._get_active_page_node() if no and no.has_method("_get_active_page_node") else null)
	if quem == null or no == null:
		interp.falhar(ev, self, "alvo não encontrado")
		return AVANCAR
	var atual: String = quem.get_direcao() if quem.has_method("get_direcao") else "dir"
	var lado := ""
	match direcao:
		Direcao.ESQ: lado = "esq"
		Direcao.DIR: lado = "dir"
		Direcao.CENTRO: lado = "centro" if alvo == Alvo.EVENTO else atual
		Direcao.INVERTER: lado = "dir" if atual == "esq" else "esq"
		Direcao.OLHAR_PARA:
			var outro = player if olhar_para == "" else interp.encontrar_evento(olhar_para)
			if outro == null:
				interp.falhar(ev, self, "'" + olhar_para + "' não encontrado")
				return AVANCAR
			lado = "esq" if outro.global_position.x < no.global_position.x else "dir"
	if alvo == Alvo.BRUXA and quem.has_method("virar"):
		quem.virar(lado)
	elif quem.has_method("set_direcao"):
		quem.set_direcao(lado)
	return AVANCAR

func _validate_property(property: Dictionary) -> void:
	var mostrar := true
	match property.name:
		"evento": mostrar = alvo == Alvo.EVENTO
		"olhar_para": mostrar = direcao == Direcao.OLHAR_PARA
		_: return
	if not mostrar:
		property.usage = PROPERTY_USAGE_STORAGE
