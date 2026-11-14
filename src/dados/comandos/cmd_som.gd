# Toca uma música (BGM), ambiente (BGS) ou efeito (SE).
# Tom: -1..1 = -12..+12 semitons (0 = sem alteração). Muda a velocidade junto.
class_name CmdSom
extends Comando

enum Canal { BGM, BGS, SE }
const NOMES := ["tocar_bgm", "tocar_bgs", "tocar_se"]

@export var canal: Canal = Canal.SE
## Arquivo .mp3 em res://audio/bgm, bgs ou se (a pasta deve bater com o canal).
@export_file("*.mp3") var arquivo: String = ""
@export_range(0.0, 1.0, 0.01) var volume: float = 1.0
## -1 = 12 semitons abaixo, 0 = normal, 1 = 12 semitons acima.
@export_range(-1.0, 1.0, 0.01) var tom: float = 0.0

func to_dict() -> Dictionary:
	return {"nome": NOMES[canal], "args": [_nome(), volume, tom]}

## Nome do arquivo sem extensão (o Inspector pode guardar "uid://...").
func _nome() -> String:
	var c := arquivo
	if c.begins_with("uid://"):
		var id := ResourceUID.text_to_id(c)
		c = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
	return c.get_file().get_basename()

func executar(interp, _ev) -> int:
	var audio = interp.get_audio_manager()
	var nome_arquivo: String = _nome()
	if not audio or nome_arquivo == "":
		return AVANCAR
	match canal:
		Canal.BGM: audio.play_bgm(nome_arquivo, volume, tom)
		Canal.BGS: audio.play_bgs(nome_arquivo, volume, tom)
		Canal.SE: audio.play_se(nome_arquivo, volume, 0.0, tom)
	return AVANCAR
