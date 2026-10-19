# mapa_base.gd
extends Node2D

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
	_connect_events()
	
	# 🔥 EXIBE LIMITES DA CÂMERA
	print("\n📷 [CÂMERA] ", name, " | L:", cam.l, " R:", cam.r, " T:", cam.t, " B:", cam.b)
	
	await get_tree().process_frame
	_debug_list_events()
	print("=".repeat(60))


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

func _on_event_triggered(evento: EventoData):
	if evento == null:
		return
	print("[MapaBase] Evento: ", evento.id)
	if game_manager and game_manager.has_method("on_map_event"):
		game_manager.on_map_event(evento)
	elif interpeter and interpeter.has_method("trigger_event"):
		interpeter.trigger_event(evento)
	map_event_triggered.emit(evento.id)
