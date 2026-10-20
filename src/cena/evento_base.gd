# evento_base.gd - VERSÃO COMPLETA COM DEBUG
extends CharacterBody2D

const PageSelector = preload("res://src/core/page_selector.gd")

## Dados do evento (páginas, condições, comandos). Arraste um .tres de res://dados/eventos.
@export var evento: EventoData

signal event_triggered(evento: EventoData, origem: Node)
signal move_finished(success: bool)

var game_manager = null
## Distância máxima (px) entre o evento e a bruxa para um gatilho de toque disparar.
const DIST_MAX_TOQUE: float = 200.0
var interpreter = null


# ===== TRIGGER =====
var trigger: String = "click"  # "click", "touch", "parallel"
var player_near: bool = false

# ===== PÁGINAS =====
var pages_nodes: Array = []	  # Lista de nós de página
var pages_data: Array = []	   # Dados de cada página
var active_page_index: int = -1  # Página ativa atual
var pagina_scene = null		  # Cena da página (carregada uma vez)

# ===== MOVIMENTO =====
var is_moving: bool = false
var move_target: Vector2 = Vector2.ZERO
var move_speed: float = 100.0
var move_direction: String = "centro"
var move_original_direction: String = "centro"
var move_success: bool = false
var move_completed: bool = false
var move_timeout: float = 0.0
var move_max_time: float = 120.0
var move_callback: Callable = Callable()

# ===== CONTROLE DE ATIVAÇÃO =====
var is_event_running: bool = false
var activation_cooldown: float = 0.5
var last_activation_time: float = 0.0
var is_processing_activation: bool = false

func _update_page():
	"""Atualiza a página ativa baseado nas variáveis atuais (sem recriar tudo)"""
	if pages_data.is_empty() or not game_manager:
		return
	var game_temp = game_manager.game_temp
	if not game_temp:
		return
	# 🔥 MESMA REGRA DO INTERPRETER (página com condição verdadeira de maior índice)
	var new_index = PageSelector.select(pages_data, game_temp, chave_self())
	if new_index != active_page_index:
		_activate_page(new_index)

func _ready():
	print("\n🔍 [EventoBase] _ready() CHAMADO para: ", name)
	print("[EventoBase] evento: ", get_event_name())
	
	var endereco = "res://scenes/core/pagina.tscn"
	print("[EventoBase] tentando carregar cena da página: ",endereco)
	# CARREGA A CENA DA PÁGINA
	pagina_scene = load(endereco)
	if not pagina_scene:
		print("[EventoBase] ❌ ERRO:",endereco," não encontrado!")
		return
	
	print("[EventoBase] ✅",endereco," carregado!")
	
	_load_event_data()
	_update_page()
	
	# 🔥 CONECTA SINAIS DO EVENTO COM O GAME_MANAGER
	call_deferred("_connect_to_game_manager")
	
	print("[EventoBase] ✅ _ready() FINALIZADO para: ", name)
	print("=".repeat(50))

# evento_base.gd - Remova _connect_to_game_manager() ou modifique

func _connect_to_game_manager():
	"""Conecta o evento ao GameManager após o carregamento"""
	print("\n🔍 [EventoBase] _connect_to_game_manager() CHAMADO para: ", name)
	
	game_manager = get_node("/root/Main/GameManager")
	if game_manager:
		print("[EventoBase] ✅ GameManager encontrado!")
		# 🔥 NÃO CONECTA O SINAL AQUI - O MapaBase já faz isso!
		# if not event_triggered.is_connected(_on_event_triggered):
		#	 event_triggered.connect(_on_event_triggered)
		#	 print("[EventoBase] ✅ event_triggered conectado ao GameManager")
	else:
		print("[EventoBase] ❌ GameManager NÃO encontrado!")


func _process(_delta):
	# 🔥 "parallel": dispara sempre que a página ativa não estiver rodando
	if trigger == "parallel" and _can_activate():
		_do_activate()


func _load_event_data():
	print("\n🔍 [EventoBase] _load_event_data() CHAMADO para: ", name)
	
	game_manager = get_node("/root/Main/GameManager")
	if not game_manager:
		print("[EventoBase] ❌ GameManager não encontrado!")
		return
	
	interpreter = game_manager.get_node("Interpeter")
	if not interpreter:
		print("[EventoBase] ❌ Interpreter não encontrado!")
		return
	
	if evento == null:
		print("[EventoBase] ⚠️ Aviso: nó ", name, " sem EventoData")
		return
	
	var pages: Array = evento.paginas
	print("[EventoBase] Evento '", evento.id, "' páginas: ", pages.size())
	
	if pages.is_empty():
		print("[EventoBase] ❌ ERRO: Evento '", evento.id, "' sem páginas!")
		return
	
	# CRIA AS PÁGINAS USANDO A CENA
	_create_pages(pages)
	
	# SELECIONA A PÁGINA ATIVA
	# _select_active_page(pages)
	
	print("[EventoBase] ✅ _load_event_data() FINALIZADO para: ", name)

# ===== _create_pages() COM DEBUG =====
func _create_pages(pages: Array):
	"""Cria os nós de página usando a cena pagina.tscn"""
	print("\n🔍 [EventoBase] _create_pages() CHAMADO para: ", name)
	print("[EventoBase] Total de páginas: ", pages.size())
	# REMOVE PÁGINAS ANTIGAS
	for node in pages_nodes:
		node.queue_free()
	pages_nodes.clear()
	pages_data.clear()
	
	for i in range(pages.size()):
		var page_data = pages[i]
		
		# print("\n📄 Criando página ", i, "...")
		# print("  Dados: ", page_data)
		
		# INSTANCIA A CENA DA PÁGINA
		var page_node = pagina_scene.instantiate()
		page_node.name = "Pagina" + str(i)
		add_child(page_node)
		
		# print("  ✅ Nó criado: ", page_node.name)
		# print("  📤 Passando dados para configure():")
		# print("	area_pos: ", page_data.get("area_pos", "NÃO DEFINIDO"))
		# print("	area_scale: ", page_data.get("area_scale", "NÃO DEFINIDO"))
		# print("	area_size: ", page_data.get("area_size", "NÃO DEFINIDO"))
		
		# CONFIGURA A PÁGINA COM OS DADOS DO DATABASE
		page_node.configure(page_data)
		
		# 🔥 CONECTA OS SINAIS DA PÁGINA
		_connect_page_signals(page_node)
		
		# ARMAZENA REFERÊNCIAS
		pages_nodes.append(page_node)
		pages_data.append(page_data)
		
		print("  ✅ Página ", i, " criada e configurada!")
		
		# POR PADRÃO, DESATIVA TODAS AS PÁGINAS
		page_node.visible = false
		print("  🔒 Página desativada (visible = false)")
	
	print("\n✅ _create_pages() FINALIZADO para: ", name)
	print("=".repeat(50))

func _activate_page(index: int):
	"""Ativa uma página e desativa as outras"""
	print("\n🔍 [EventoBase] _activate_page() CHAMADO para: ", name, " - Índice: ", index)
	
	if index < 0 or index >= pages_nodes.size():
		print("[EventoBase] ❌ Índice inválido: ", index)
		return
	
	active_page_index = index
	
	for i in range(pages_nodes.size()):
		var node = pages_nodes[i]
		var is_active = (i == index)
		node.visible = is_active
		
		print("  Página ", i, " - visible: ", is_active)
		
		# ATIVA/DESATIVA O COLLISIONSHAPE2D (física) via página
		if node.has_method("set_active"):
			node.set_active(is_active)
			print("	set_active(", is_active, ") chamado")
	
	# 🔥 ATUALIZA O TRIGGER DA PÁGINA ATIVA
	if index < pages_data.size():
		trigger = pages_data[index].get_trigger()
		print("[EventoBase] Trigger atualizado: ", trigger)
	
	print("[EventoBase] ✅ Página ", index, " ativada para: ", name)

func _get_active_page_data() -> PaginaData:
	if active_page_index >= 0 and active_page_index < pages_data.size():
		return pages_data[active_page_index]
	return null

func _get_active_page_node() -> Node2D:
	if active_page_index >= 0 and active_page_index < pages_nodes.size():
		return pages_nodes[active_page_index]
	return null

# evento_base.gd - refresh_event() (já está correto)

func refresh_event():
	"""Reavalia a página ativa sem recriar tudo"""
	print("[EventoBase] 🔄 refresh_event() chamado para: ", name)
	
	# 🔥 SÓ REAVALIA A PÁGINA ATIVA
	# _reevaluate_active_page()
	_update_page()
	
	print("[EventoBase] ✅ refresh_event() concluído para: ", name)

# evento_base.gd - _reevaluate_active_page() CORRIGIDO


# ===== DETECÇÃO DE PLAYER VIA INTERACTIONZONE DA PÁGINA =====

func _connect_page_signals(page_node: Node):
	"""Conecta direto na InteractionZone da página (sem relay pela Pagina)"""
	print("\n🔍 [EventoBase] _connect_page_signals() CHAMADO para página: ", page_node.name)
	
	if not page_node.has_method("get_interaction_zone"):
		print("  ❌ Página não expõe get_interaction_zone()!")
		return
	
	var zone: InteractionZone = page_node.get_interaction_zone()
	if not zone:
		print("  ❌ InteractionZone NÃO encontrada na página!")
		return
	
	if not zone.interacted.is_connected(_on_zone_interacted):
		zone.interacted.connect(_on_zone_interacted)
		print("  ✅ interacted conectado!")
	
	if not zone.player_entered.is_connected(_on_zone_player_entered):
		zone.player_entered.connect(_on_zone_player_entered)
		print("  ✅ player_entered conectado!")
	
	if not zone.player_exited.is_connected(_on_zone_player_exited):
		zone.player_exited.connect(_on_zone_player_exited)
		print("  ✅ player_exited conectado!")

# ===== FUNÇÕES DE DETECÇÃO =====

# evento_base.gd - Em _on_zone_player_entered()

# evento_base.gd - _on_zone_player_entered()

func _on_zone_player_entered():
	var player = get_node("/root/Main/Mundo/Player")
	if not player:
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	print("🚪🚪🚪 [PLAYER ENTROU] Evento: ", name)
	print("  evento: ", get_event_name())
	print("  Posição evento: ", global_position)
	print("  Posição player: ", player.global_position)
	print("  Distância: ", dist)
	
	player_near = true
	print("[EventoBase] ✅ Player entrou na área de: ", name)
	
	# toque só vale com a bruxa perto de verdade (a física pode reportar a posição
	# antiga logo depois de um teletransporte)
	if trigger == "touch" and dist <= DIST_MAX_TOQUE and _can_activate():
		_do_activate()

func _on_zone_player_exited():
	player_near = false
	print("[EventoBase] Player saiu da área de: ", name)

# evento_base.gd
# evento_base.gd - Em _on_zone_interacted()

# evento_base.gd - Em _on_zone_interacted()

func _on_zone_interacted():
	if not _can_activate():
		return
	if trigger == "click":
		_on_interaction()
	else:
		_do_activate()

func _is_player_near() -> bool:
	"""Verifica se o player está perto do evento"""
	return player_near

# ===== ATIVAÇÃO DO EVENTO =====

# evento_base.gd - Substitua _on_interaction()

func _on_interaction():
	"""Processa o clique: se o player está longe, anda até o evento e ativa ao chegar"""
	if trigger == "click" and not _is_player_near():
		_try_move_player_to_event()
		return
	_do_activate()


func _try_move_player_to_event():
	# Um clique novo cancela a caminhada anterior (GameManager compara o click_id),
	# então não precisa de trava aqui.
	if not game_manager:
		return
	var arrived = await game_manager.move_player_to_event(self)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	# 🔥 CHEGOU: ativa o evento (antes o player andava e nada acontecia).
	# Só se o player estiver mesmo na zona: se o evento andou (ex.: bos_goblin
	# fugindo), chegar no ponto antigo não conta.
	if arrived and _is_player_near() and _can_activate():
		_do_activate()


func _can_activate() -> bool:
	"""Guard único de ativação para click / touch / parallel"""
	if is_processing_activation or evento == null:
		return false
	if active_page_index < 0:
		return false
	# trocando de mapa: passagens de toque esperam a carência do Teleporte
	if trigger == "touch" and game_manager and game_manager.has_method("teleportando") and game_manager.teleportando():
		return false
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_activation_time < get_cooldown():
		return false
	# A MESMA página não roda duas vezes; outra página do mesmo evento pode
	# (ex.: bos_goblin muda de página durante o "esperar" e pode ser clicado).
	if interpreter and interpreter.has_method("is_page_running"):
		if interpreter.is_page_running(get_event_name(), active_page_index, chave_self()):
			return false
	return true


func _activate():
	"""Ativa o evento respeitando o guard (chamado por GameManager/debug)"""
	if _can_activate():
		_do_activate()

func _do_activate():
	print("🔥 [EVENTO ATIVADO] ", name, " | event: ", get_event_name(), " | pág: ", active_page_index, " | trigger: ", trigger)
	is_processing_activation = true
	is_event_running = true
	last_activation_time = Time.get_ticks_msec() / 1000.0
	_virar_player_para_mim()

	event_triggered.emit(evento, self)

	await get_tree().process_frame
	if is_instance_valid(self):
		is_processing_activation = false

## A bruxa olha para o evento antes de interagir (clique e toque; paralelo não).
func _virar_player_para_mim() -> void:
	if trigger == "parallel":
		return
	var player = get_node_or_null("/root/Main/Mundo/Player")
	if player and player.has_method("virar"):
		var dx: float = global_position.x - player.global_position.x
		if absf(dx) > 4.0:
			player.virar("dir" if dx > 0.0 else "esq")

func on_event_finished():
	"""Chamado quando o evento termina sua execução"""
	print("\n📢 [EventoBase] on_event_finished() CHAMADO para: ", name)
	is_event_running = false
	last_activation_time = Time.get_ticks_msec() / 1000.0
	
	# NOTIFICA O PLAYER
	var player = get_node_or_null("/root/Main/Mundo/Player")
	if player and player.has_method("on_event_finished"):
		player.on_event_finished()
		print("  ✅ Player.on_event_finished() chamado")

func reset_event_state():
	"""Reseta completamente o estado do evento"""
	print("[EventoBase] 🔄 reset_event_state() chamado para: ", name)
	is_event_running = false
	is_processing_activation = false
	last_activation_time = 0.0
	
	var page = _get_active_page_node()
	if page and page.has_method("get_interaction_zone"):
		var zone: InteractionZone = page.get_interaction_zone()
		if zone:
			zone.reset_cooldown()
	
	if is_moving:
		_stop_movement(false)

func activate():
	_activate()

# ===== MOVIMENTO =====

func move_to(target_x: float, target_y: float, speed: float = 100.0, dir: String = "centro", callback: Callable = Callable()):
	if is_moving:
		print("[EventoBase] Já está em movimento!")
		if callback.is_valid(): callback.call(false)
		return
	
	move_target = Vector2(target_x, target_y)
	move_speed = speed
	move_direction = dir
	move_original_direction = "centro"
	move_timeout = 0.0
	move_success = false
	move_completed = false
	move_callback = callback
	is_moving = true
	
	print("[EventoBase] Movendo para (", target_x, ", ", target_y, ") a ", speed, "px/s")

func _physics_process(delta):
	if is_moving:
		_process_movement(delta)

func _process_movement(delta):
	if not is_moving:
		return
	
	if move_max_time>0:
		move_timeout += delta
		if move_timeout > move_max_time:
			print("[EventoBase] Timeout!")
			_stop_movement(false)
			return

	
	var current_pos = global_position
	var direction_vec = (move_target - current_pos).normalized()
	var distance = current_pos.distance_to(move_target)
	var step = move_speed * delta
	
	if distance < step:
		global_position = move_target
		print("[EventoBase] Chegou ao destino!")
		_stop_movement(true)
		return
	
	velocity = direction_vec * move_speed
	move_and_slide()

func _stop_movement(success: bool):
	if not is_moving:
		return
	
	is_moving = false
	move_success = success
	move_completed = true
	velocity = Vector2.ZERO
	
	print("[EventoBase] Movimento finalizado: ", "✅" if success else "❌")
	move_finished.emit(success)
	
	if move_callback.is_valid():
		move_callback.call(success)
		move_callback = Callable()

# ===== MÉTODOS PÚBLICOS =====

func is_moving_now() -> bool:
	return is_moving

func stop_movement():
	if is_moving:
		_stop_movement(false)

func get_trigger() -> String:
	return trigger

func is_player_near() -> bool:
	return _is_player_near()

func get_cooldown() -> float:
	"""Retorna o cooldown baseado no trigger"""
	match trigger:
		"click": return 0.3
		"touch": return 0.5
		"parallel": return 0.1
		_: return 1.0

func get_active_page_index() -> int:
	return active_page_index

func get_pages_count() -> int:
	return pages_nodes.size()

# ===== DEBUG =====

func debug():
	print("\n=== EVENTO DEBUG: ", name, " ===")
	print("  Nome do evento: ", get_event_name())
	print("  Trigger: ", trigger)
	print("  Movendo: ", is_moving)
	print("  Player perto: ", _is_player_near())
	print("  is_event_running: ", is_event_running)
	print("  Páginas: ", pages_nodes.size())
	print("  Página ativa: ", active_page_index)
	if is_moving:
		print("  Alvo: ", move_target)
	print("=========================\n")

func debug_signals():
	"""Debug dos sinais das páginas"""
	print("\n=== DEBUG SINAIS DO EVENTO: ", name, " ===")
	for page in pages_nodes:
		print("  Página: ", page.name)
		if page.has_method("get_interaction_zone"):
			var zone: InteractionZone = page.get_interaction_zone()
			if zone:
				print("	interacted conectado? ", zone.interacted.is_connected(_on_zone_interacted))
				print("	player_entered conectado? ", zone.player_entered.is_connected(_on_zone_player_entered))
				print("	player_exited conectado? ", zone.player_exited.is_connected(_on_zone_player_exited))
		print("	visible: ", page.visible)
		if page.has_method("is_player_near"):
			print("	player near: ", page.is_player_near())
	print("=========================\n")

# ===== CLIQUE =====
# Caminho ÚNICO de clique: _unhandled_input. Cliques consumidos pela UI
# (diálogo, opções, HUD) não chegam aqui. Antes havia também _input, que
# rodava em TODOS os eventos e mesmo com a UI na frente.

func _unhandled_input(event: InputEvent):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if trigger != "click" or not is_visible_in_tree():
		return
	if _zone_global_rect().has_point(get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		_on_zone_interacted()

func _zone_global_rect() -> Rect2:
	"""Retângulo da InteractionZone da página ativa em coordenadas globais
	(usa o transform real do shape, então posição/escala batem com a física)."""
	var page = _get_active_page_node()
	if not page or not page.has_method("get_interaction_zone"):
		return Rect2()
	var zone = page.get_interaction_zone()
	if not zone:
		return Rect2()
	var shape_node = zone.get_node_or_null("CollisionShape2D")
	if not shape_node or not (shape_node.shape is RectangleShape2D):
		return Rect2()
	var sz: Vector2 = shape_node.shape.size
	return shape_node.global_transform * Rect2(-sz / 2.0, sz)


# ===== SELF-VARIABLES =====
var _chave_self: String = ""

## Chave única deste nó: "<arquivo do mapa>:<caminho dentro do mapa>"
## (ex.: "mapa_estradaA:Eventos/AreaCogumelo/AreaCogumelo_0"). Estável entre visitas ao mapa.
func chave_self() -> String:
	if _chave_self == "" and is_inside_tree():
		var mapa := _mapa_raiz()
		if mapa:
			_chave_self = mapa.scene_file_path.get_file().get_basename() + ":" + str(mapa.get_path_to(self))
		else:
			_chave_self = str(get_path())
	return _chave_self

## Nó raiz do mapa (filho direto de /root/Main/Mundo).
func _mapa_raiz() -> Node:
	var n: Node = self
	while n.get_parent() and n.get_parent().name != "Mundo":
		n = n.get_parent()
	return n if n.get_parent() else null

func get_event_name() -> String:
	"""Id do EventoData (usado por move_event / parar_movimento para achar o nó)"""
	return evento.id if evento else ""

func is_running() -> bool:
	"""Retorna se o evento está em execução"""
	return is_event_running
