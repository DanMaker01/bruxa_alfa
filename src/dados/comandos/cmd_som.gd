# Toca uma música (BGM), ambiente (BGS) ou efeito (SE).
class_name CmdSom
extends Comando

enum Canal { BGM, BGS, SE }
const NOMES := ["tocar_bgm", "tocar_bgs", "tocar_se"]

@export var canal: Canal = Canal.SE
## Arquivo .mp3 em res://audio/bgm, bgs ou se (a pasta deve bater com o canal).
@export_file("*.mp3") var arquivo: String = ""
@export_range(0.0, 1.0, 0.01) var volume: float = 1.0

func to_dict() -> Dictionary:
	return {"nome": NOMES[canal], "args": [arquivo.get_file().get_basename(), volume]}

func executar(interp, _ev) -> int:
	var audio = interp.get_audio_manager()
	var nome_arquivo: String = arquivo.get_file().get_basename()
	if not audio or nome_arquivo == "":
		return AVANCAR
	match canal:
		Canal.BGM: audio.play_bgm(nome_arquivo, volume)
		Canal.BGS: audio.play_bgs(nome_arquivo, volume)
		Canal.SE: audio.play_se(nome_arquivo, volume)
	return AVANCAR
