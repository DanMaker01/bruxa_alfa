# Leva a bruxa para outro mapa.
class_name CmdTeleportar
extends Comando

enum Direcao { CENTRO, ESQ, DIR }
const DIRECOES := ["centro", "esq", "dir"]

## Escolha o arquivo do mapa (botão da pasta no Inspector). Aceita também só o nome
## ("mapa_castelo_in03" ou "castelo_in03"), procurado em res://mapas/.
@export_file("*.tscn") var mapa: String = ""
@export var posicao: Vector2 = Vector2.ZERO
@export var direcao: Direcao = Direcao.CENTRO

## Caminho completo do mapa. O Inspector pode guardar "uid://..." (vale mesmo se o mapa
## for renomeado ou movido); um nome digitado é procurado em res://mapas/.
func _caminho() -> String:
	var m := mapa.strip_edges()
	if m.begins_with("uid://"):
		var id := ResourceUID.text_to_id(m)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
		return m   # load("uid://...") também funciona
	if m.begins_with("res://"):
		return m
	if m == "":
		return ""
	var nome := m.get_file().trim_suffix(".tscn")
	for tentativa in ["res://mapas/%s.tscn" % nome, "res://mapas/mapa_%s.tscn" % nome]:
		if ResourceLoader.exists(tentativa):
			return tentativa
	return "res://mapas/%s.tscn" % nome

func to_dict() -> Dictionary:
	return {"nome": "teleportar", "args": [_caminho().get_file().get_basename(), posicao.x, posicao.y, DIRECOES[direcao]]}

func executar(interp, ev) -> int:
	var caminho := _caminho()
	if caminho == "":
		interp.falhar(ev, self, "sem mapa")
		return AVANCAR
	var gm = interp.game_manager
	if gm and gm.has_method("get_input_manager"):
		var im = gm.get_input_manager()
		if im and im.has_method("stop_movement"):
			im.stop_movement()
	if not ResourceLoader.exists(caminho):
		interp.falhar(ev, self, "mapa não existe: '%s' (%s)" % [mapa, caminho])
		return AVANCAR
	interp.teleport_requested.emit(caminho, posicao.x, posicao.y, DIRECOES[direcao])
	return AVANCAR
