# save_jogo.gd
# Salvar e carregar o jogo (menu de pausa e menu principal).
# Cada save é uma pasta user://saves/save_<data>/ com:
#   dados.json             variáveis, personalidades, inventário, self vars, livro,
#                          itens vistos, mapa, posição e direção da bruxa
#   itens/<id>.tres        itens criados no jogo (poções do caldeirão), que não existem em res://
#   pocoes_nomeadas.tres   nomes de poção que a bruxa deu
class_name SaveJogo
extends RefCounted

const PASTA := "user://saves/"
const VERSAO: int = 1


## Salva agora. Devolve o nome da pasta do save ("" se falhou).
static func salvar(gm) -> String:
	var gt = gm.game_temp if gm else null
	if gt == null:
		return ""
	var nome := "save_" + Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "_")
	var pasta := PASTA + nome + "/"
	DirAccess.make_dir_recursive_absolute(pasta + "itens")
	var dados := {
		"versao": VERSAO,
		"quando": Time.get_datetime_string_from_system(false, true),
		"variaveis": gt.variaveis.duplicate(true),
		"personalidades": gt.personalidades.duplicate(true),
		"inventario": gt.inventario.duplicate(true),
		"self_vars": gt.self_vars.duplicate(true),
		"livro": gt.livro.duplicate(true),
		"itens_vistos": gt.itens_vistos.duplicate(true),
		"hud": _hud_visivel(gm),
	}
	var onde := onde_esta(gm)
	dados.merge(onde, true)
	# itens criados no jogo (poções): guardados como recurso
	var db = gm.database
	if db and "itens_dinamicos" in db:
		var ids: Array = []
		for id in db.itens_dinamicos:
			var it: ItemData = db.itens_dinamicos[id]
			if it and ResourceSaver.save(it, pasta + "itens/" + id + ".tres") == OK:
				ids.append(id)
		dados["itens_dinamicos"] = ids
	if gt.pocoes_nomeadas:
		ResourceSaver.save(gt.pocoes_nomeadas, pasta + "pocoes_nomeadas.tres")
	var f := FileAccess.open(pasta + "dados.json", FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(dados, "\t"))
	f.close()
	return nome

## Saves existentes, do mais novo para o mais antigo: [{"nome", "quando", "mapa"}].
static func listar() -> Array:
	var out: Array = []
	var dir := DirAccess.open(PASTA)
	if dir == null:
		return out
	for nome in dir.get_directories():
		var d := _ler(nome)
		if d.is_empty():
			continue
		out.append({"nome": nome, "quando": str(d.get("quando", "")), "mapa": str(d.get("mapa", "")).get_file().get_basename()})
	out.sort_custom(func(a, b): return a["nome"] > b["nome"])
	return out

static func existe_algum() -> bool:
	return not listar().is_empty()

## Carrega um save (pelo nome da pasta) e leva a bruxa para o mapa salvo.
static func carregar(gm, nome: String) -> bool:
	var d := _ler(nome)
	var gt = gm.game_temp if gm else null
	if d.is_empty() or gt == null:
		return false
	var pasta := PASTA + nome + "/"
	# itens criados no jogo primeiro (o inventário e o livro apontam para eles)
	var db = gm.database
	for id in d.get("itens_dinamicos", []):
		var caminho: String = pasta + "itens/" + str(id) + ".tres"
		if ResourceLoader.exists(caminho) and db and db.has_method("registrar_item"):
			var it = ResourceLoader.load(caminho, "", ResourceLoader.CACHE_MODE_IGNORE)
			if it is ItemData:
				if "itens_dinamicos" in db:
					db.itens_dinamicos.erase(it.id)
				if "itens" in db:
					db.itens.erase(it.id)
				db.registrar_item(it)
	if ResourceLoader.exists(pasta + "pocoes_nomeadas.tres"):
		var cat = ResourceLoader.load(pasta + "pocoes_nomeadas.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
		if cat is CatalogoPocoes:
			gt.pocoes_nomeadas = cat
	gt.variaveis = (d.get("variaveis", {}) as Dictionary).duplicate(true)
	var pers := {}
	var ps: Dictionary = d.get("personalidades", {})
	for k in ps:
		pers[k] = Array(ps[k])
	gt.personalidades = pers
	var inv := {}
	var isalvo: Dictionary = d.get("inventario", {})
	for k in isalvo:
		inv[k] = int(isalvo[k])
	gt.inventario = inv
	gt.self_vars = (d.get("self_vars", {}) as Dictionary).duplicate(true)
	gt.livro = numeros_inteiros((d.get("livro", {}) as Dictionary).duplicate(true))
	gt.itens_vistos = (d.get("itens_vistos", {}) as Dictionary).duplicate(true)
	gt.variables_changed.emit()
	gt.inventory_changed.emit()
	for k in pers:
		gt.personality_changed.emit(k)
	# mapa, posição, bruxa visível e HUD
	var p = gm.get_player()
	if p:
		if p.has_method("mostrar_player"):
			p.mostrar_player()
		if p.has_method("enable_interaction"):
			p.enable_interaction()
	if bool(d.get("hud", true)) and gm.has_method("mostrar_hud"):
		gm.mostrar_hud()
	if d.has("mapa") and gm.get("teleporte"):
		gm.teleporte.teleportar(str(d["mapa"]), float(d.get("x", 0.0)), float(d.get("y", 0.0)), str(d.get("direcao", "centro")))
		if gm.has_method("fade_in"):
			gm.fade_in(0.6)   # a tela clareia no mapa salvo (mesmo se a intro tinha escurecido)
	return true

static func apagar(nome: String) -> void:
	var pasta := PASTA + nome + "/"
	var itens := DirAccess.open(pasta + "itens")
	if itens:
		for a in itens.get_files():
			itens.remove(a)
		DirAccess.remove_absolute(pasta + "itens")
	var dir := DirAccess.open(pasta)
	if dir:
		for a in dir.get_files():
			dir.remove(a)
	DirAccess.remove_absolute(pasta)

## Mapa (cena) e posição da bruxa agora.
static func onde_esta(gm) -> Dictionary:
	var m = gm.get_node_or_null("/root/Main/Mundo")
	var p = gm.get_player()
	if m == null or p == null:
		return {}
	for c in m.get_children():
		if c.name != "Player" and c.scene_file_path != "":
			var dir := "centro"
			if p.has_method("get_direcao"):
				dir = p.get_direcao()
			return {"mapa": c.scene_file_path, "x": p.global_position.x, "y": p.global_position.y, "direcao": dir}
	return {}

static func _hud_visivel(gm) -> bool:
	var hud = gm.get_node_or_null("/root/Main/CanvasLayer/HUD")
	return hud != null and hud.visible

static func _ler(nome: String) -> Dictionary:
	var f := FileAccess.open(PASTA + nome + "/dados.json", FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

## JSON devolve todo número como float: ids e contagens voltam a ser inteiros.
static func numeros_inteiros(v):
	if v is Dictionary:
		for k in v:
			v[k] = numeros_inteiros(v[k])
		return v
	if v is Array:
		for i in v.size():
			v[i] = numeros_inteiros(v[i])
		return v
	if v is float and is_equal_approx(v, roundf(v)) and absf(v) < 1e9:
		return int(v)
	return v
