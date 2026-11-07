# Trava ou destrava a direção da bruxa ou de um evento.
# Travada: andando (Mover, rota, clique), não vira para o lado do movimento.
# O comando Direção continua virando mesmo travada. Use para exceções
# (ex.: andar de costas). Destrave depois.
class_name CmdTravarDirecao
extends Comando

enum Alvo { BRUXA, EVENTO }

@export var alvo: Alvo = Alvo.BRUXA:
	set(v):
		alvo = v
		notify_property_list_changed()
## id do evento (alvo = EVENTO). Vazio = este evento.
@export var evento: String = ""
## Ligado = trava; desligado = destrava.
@export var travar: bool = true


func to_dict() -> Dictionary:
	return {"nome": "travar_direcao" if travar else "destravar_direcao", "args": [evento if alvo == Alvo.EVENTO else "bruxa"]}


func executar(interp, ev) -> int:
	var no = null
	if alvo == Alvo.BRUXA:
		no = interp.game_manager.get_player() if interp.game_manager else null
	elif evento == "":
		no = ev.origem.get_ref() if ev.origem else null
	else:
		no = interp.encontrar_evento(evento)
	if no == null or not ("direcao_travada" in no):
		interp.falhar(ev, self, "alvo não encontrado")
		return AVANCAR
	no.direcao_travada = travar
	return AVANCAR


func _validate_property(property: Dictionary) -> void:
	if property.name == "evento" and alvo != Alvo.EVENTO:
		property.usage = PROPERTY_USAGE_STORAGE
