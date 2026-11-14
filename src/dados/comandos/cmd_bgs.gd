# Liga ou desliga um som de ambiente (BGS) sem mexer nos outros que estão tocando.
# Cada BGS tem o seu volume e fica em loop. Ao trocar de mapa, ficam só os do mapa novo.
# DESLIGAR_TODOS para todos.
class_name CmdBgs
extends Comando

enum Acao { LIGAR, DESLIGAR, DESLIGAR_TODOS }

@export var acao: Acao = Acao.LIGAR:
	set(v):
		acao = v
		notify_property_list_changed()
## Arquivo em res://audio/bgs/ (ex.: vento.mp3).
@export_file("*.mp3") var arquivo: String = ""
@export_range(0.0, 1.0, 0.01) var volume: float = 0.5
## Tom: -1 = 12 semitons abaixo, 0 = normal, 1 = 12 semitons acima.
@export_range(-1.0, 1.0, 0.01) var tom: float = 0.0

func to_dict() -> Dictionary:
	return {"nome": "bgs", "args": [["ligar", "desligar", "desligar_todos"][acao], _nome(), volume, tom]}

func _nome() -> String:
	var c := arquivo
	if c.begins_with("uid://"):
		var id := ResourceUID.text_to_id(c)
		c = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
	return c.get_file().get_basename()

func executar(interp, ev) -> int:
	var audio = interp.game_manager.get_node_or_null("AudioManager") if interp.game_manager else null
	if audio == null or not audio.has_method("ligar_bgs"):
		interp.falhar(ev, self, "AudioManager não encontrado")
		return AVANCAR
	match acao:
		Acao.LIGAR:
			if _nome() == "":
				interp.falhar(ev, self, "arquivo vazio")
			else:
				audio.ligar_bgs(_nome(), volume, tom)
		Acao.DESLIGAR:
			audio.desligar_bgs(_nome())
		Acao.DESLIGAR_TODOS:
			audio.definir_bgs([])
	return AVANCAR

func _validate_property(property: Dictionary) -> void:
	if acao == Acao.DESLIGAR_TODOS and property.name in ["arquivo", "volume"]:
		property.usage = PROPERTY_USAGE_STORAGE
	elif acao == Acao.DESLIGAR_TODOS and property.name == "tom":
		property.usage = PROPERTY_USAGE_STORAGE
	elif acao == Acao.DESLIGAR and property.name in ["volume", "tom"]:
		property.usage = PROPERTY_USAGE_STORAGE
