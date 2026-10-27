# mapa_base.gd
extends Node2D

## Música do mapa (res://audio/bgm/*.mp3). Vazio = sem música (para a que estiver tocando).
## Se for a mesma do mapa anterior, ela só continua (igual RPG Maker).
@export_file("*.mp3") var bgm: String = ""
@export_range(0.0, 1.0, 0.01) var bgm_volume: float = 1.0

var game_manager = null
var interpeter = null
signal map_event_triggered(evento_id)

# Limites base da câmera **** r - Vai depender do tamanho do mapa.
var cam = {"l":256.0, "r":640.0, "t":0.0, "b":0.0}

# mapa_base.gd - No _ready()

# mapa_base.gd - Versão final recomendada
func _find_sprite_recursive(node: Node) -> Sprite2D:
	"""Busca recursivamente por um Sprite2D dentro do nó"""
	for child in node.get_children():
		if child is Sprite2D:
			return child
		var found = _find_sprite_recursive(child)
		if found:
			return found
	return null

func _calc_limits():
	var n = _find_frente()
	if n:
		var sprite = _find_sprite_recursive(n)
		if sprite and sprite.texture:
			var tex_size = sprite.texture.get_size()
			var effective_width = tex_size.x * sprite.scale.x
			var sprite_left = sprite.global_position.x
			var sprite_right = sprite_left + effective_width
			
			# 🔥 LIMITES AJUSTADOS
			cam.l = 0
			cam.r = sprite_right
			cam.b = 960
			
			print("[MapaBase] Limites: L:", cam.l, " R:", cam.r)
			return

func _find_frente():
	for c in get_children():
		if c is Parallax2D and c.name == "Meio" :
			print("[MapaBase] MEIO encontrada!")
			return c
	print("[MapaBase] MEIO não encontrada!")
	return null



func _ready():
	game_manager = get_node("/root/Main/GameManager")
	interpeter = game_manager.get_node("Interpeter") if game_manager else null
	_calc_limits()
	_apply_limits()
	_preparar_parallax()
	_connect_events()
	call_deferred("_tocar_bgm")   # deferred: o AudioManager pode ainda não estar pronto
	
	# 🔥 EXIBE LIMITES DA CÂMERA
	print("\n📷 [CÂMERA] ", name, " | L:", cam.l, " R:", cam.r, " T:", cam.t, " B:", cam.b)
	
	await get_tree().process_frame
	_debug_list_events()
	print("=".repeat(60))


func _tocar_bgm() -> void:
	var audio = game_manager.get_node_or_null("AudioManager") if game_manager else null
	if audio == null or audio.get("bgm_player") == null:
		return
	# play_bgm já ignora se for a mesma música tocando; "" para a música
	audio.play_bgm(bgm.get_file().get_basename() if bgm != "" else "", bgm_volume)

func _debug_limits_simple():
	"""Debug simples dos limites da câmera"""
	print("\n📷 [CÂMERA] ", name)
	print("  L: ", cam.l, " | R: ", cam.r, " | T: ", cam.t, " | B: ", cam.b)
	print("  Largura: ", cam.r - cam.l)

func _debug_list_events():
	print("\n" + "=".repeat(60))
	print("📋 [DEBUG] EVENTOS NO MAPA: ", name)
	print("=".repeat(60))
	
	var eventos = get_node_or_null("Eventos")
	if not eventos:
		print("  ❌ Nó 'Eventos' não encontrado!")
		return
	
	_list_events_recursive(eventos, "")
	print("=".repeat(60))

func _list_events_recursive(node: Node, prefix: String):
	for child in node.get_children():
		if child.has_method("get_event_name"):
			var pos = child.global_position if child.has_method("get_global_position") else Vector2.ZERO
			var trigger = child.get_trigger() if child.has_method("get_trigger") else "?"
			var event_name = child.get_event_name() if child.has_method("get_event_name") else "?"
			print(prefix, "📌 ", child.name)
			print(prefix, "   event_name: ", event_name)
			print(prefix, "   pos: ", pos)
			print(prefix, "   trigger: ", trigger)
		
		_list_events_recursive(child, prefix + "  ")

func _apply_limits():
	var cam_node = get_node("/root/Main/Mundo/Player/Camera2D")
	if cam_node:
		cam_node.limit_left = cam.l
		cam_node.limit_top = cam.t
		cam_node.limit_right = cam.r
		cam_node.limit_bottom = cam.b

func _connect_events():
	print("[MapaBase] 🔍 Conectando eventos do mapa: ", name)
	var eventos = get_node_or_null("Eventos")
	if eventos:
		print("[MapaBase] ✅ Nó 'Eventos' encontrado!")
		_connect_recursive(eventos)
	else:
		print("[MapaBase] ⚠️ Nó 'Eventos' NÃO encontrado!")

func _connect_recursive(node):
	# print("[MapaBase] 📂 Verificando nó: ", node.name, " (filhos: ", node.get_child_count(), ")")
	for c in node.get_children():
		# print("[MapaBase]   - Verificando: ", c.name)
		
		# 🔥 VERIFICA SE É UM EVENTO (tem event_triggered)
		if c.has_signal("event_triggered"):
			if not c.event_triggered.is_connected(_on_event_triggered):
				c.event_triggered.connect(_on_event_triggered)
				print("[MapaBase] ✅ Evento CONECTADO: ", c.name, " -> ", c.get_event_name() if c.has_method("get_event_name") else "?")
			else:
				print("[MapaBase] ⚠️ Evento já conectado: ", c.name)
		
		# 🔥 CONTINUA BUSCANDO NOS FILHOS (para páginas)
		_connect_recursive(c)

func _on_event_triggered(evento: EventoData, origem: Node = null):
	if evento == null:
		return
	print("[MapaBase] Evento: ", evento.id)
	if game_manager and game_manager.has_method("on_map_event"):
		game_manager.on_map_event(evento, origem)
	elif interpeter and interpeter.has_method("trigger_event"):
		interpeter.trigger_event(evento, origem)
	map_event_triggered.emit(evento.id)


# ===== PARALLAX NA BORDA =====
# Quando a câmera para na borda do mapa, as camadas com fator diferente de 1
# (fundo 0.2, frente 1.1...) continuam andando como se a câmera ainda seguisse a bruxa.
# As camadas com fator 1 (Meio, Eventos) param junto com a câmera.
# Também nunca deixa aparecer a ponta de uma imagem: o deslocamento é limitado ao
# tamanho dela (camadas com repetição/loop não têm limite).
# Na tela: x = x_local + scroll_offset.x - fator * (borda esquerda da câmera).
const PARALLAX_SUAVE := 4.0   # igual ao position_smoothing_speed da câmera
var _camadas: Array = []
var _centro_virtual: float = NAN

func _preparar_parallax() -> void:
	_camadas.clear()
	_centro_virtual = NAN
	for c in get_children():
		if c is Parallax2D and not is_equal_approx(c.scroll_scale.x, 1.0):
			var ext := _extensao_x(c)
			_camadas.append({"no": c, "base": c.scroll_offset.x, "esq": ext.x, "dir": ext.y,
				"loop": c.repeat_size.x > 0.0})

## Menor e maior x (no espaço da camada) das imagens dentro dela.
func _extensao_x(camada: Node) -> Vector2:
	var r := Vector2(INF, -INF)
	var pilha: Array = camada.get_children(true)
	while not pilha.is_empty():
		var n = pilha.pop_back()
		pilha.append_array(n.get_children(true))
		if not (n is Sprite2D) or n.texture == null:
			continue
		var xf := Transform2D.IDENTITY
		var p: Node = n
		while p != camada:
			xf = p.transform * xf
			p = p.get_parent()
		var ret: Rect2 = n.get_rect()
		for canto in [ret.position, ret.end, Vector2(ret.position.x, ret.end.y), Vector2(ret.end.x, ret.position.y)]:
			var x: float = (xf * canto).x
			r.x = minf(r.x, x)
			r.y = maxf(r.y, x)
	return r

func _process(delta: float) -> void:
	if _camadas.is_empty():
		return
	var cam := get_viewport().get_camera_2d()
	var player = get_node_or_null("/root/Main/Mundo/Player")
	if cam == null or player == null:
		return
	var px: float = player.global_position.x
	var k := 1.0 - exp(-PARALLAX_SUAVE * delta)
	if is_nan(_centro_virtual):   # primeiro quadro no mapa: sem deslizar
		_centro_virtual = px
		k = 1.0
	else:
		_centro_virtual = lerpf(_centro_virtual, px, k)
	var centro: float = cam.get_screen_center_position().x
	var largura: float = get_viewport_rect().size.x / cam.zoom.x
	var cam_esq: float = centro - largura * 0.5
	# quanto a bruxa "passou" do ponto onde a câmera parou (0 no meio do mapa e em cenas)
	var diff: float = _centro_virtual - centro if cam.get("is_following_player") else 0.0
	for c in _camadas:
		var no: Parallax2D = c.no
		if not is_instance_valid(no):
			continue
		var f: float = no.scroll_scale.x
		var alvo: float = c.base - f * diff
		if not c.loop and is_finite(c.esq):
			var lo: float = largura - c.dir + f * cam_esq   # borda direita da imagem fora da tela
			var hi: float = -c.esq + f * cam_esq            # borda esquerda da imagem fora da tela
			if lo <= hi:
				alvo = clampf(alvo, lo, hi)
		no.scroll_offset.x = lerpf(no.scroll_offset.x, alvo, k)
