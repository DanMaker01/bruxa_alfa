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
	pass
	pass
	
	var endereco = "res://scenes/core/pagina.tscn"
	pass
	# CARREGA A CENA DA PÁGINA
	pagina_scene = load(endereco)
	if not pagina_scene:
		pass
		return
	
	pass
	
	_load_event_data()
	_update_page()
	
	# 🔥 CONECTA SINAIS DO EVENTO COM O GAME_MANAGER
	call_deferred("_connect_to_game_manager")
	
	pass
	pass

# evento_base.gd - Remova _connect_to_game_manager() ou modifique

func _connect_to_game_manager():
	"""Conecta o evento ao GameManager após o carregamento"""
	pass
	
	game_manager = get_node("/root/Main/GameManager")
	if game_manager:
		pass
		# 🔥 NÃO CONECTA O SINAL AQUI - O MapaBase já faz isso!
		# if not event_triggered.is_connected(_on_event_triggered):
		#	 event_triggered.connect(_on_event_triggered)
		#	 print("[EventoBase] ✅ event_triggered conectado ao GameManager")
	else:
		pass


func _process(_delta):
	# 🔥 "parallel": dispara sempre que a página ativa não estiver rodando
	if trigger == "parallel" and _can_activate():
		_do_activate()


func _load_event_data():
	pass
	
	game_manager = get_node("/root/Main/GameManager")
	if not game_manager:
		pass
		return
	
	interpreter = game_manager.get_node("Interpeter")
	if not interpreter:
		pass
		return
	
	if evento == null:
		pass
		return
	
	var pages: Array = evento.paginas
	pass
	
	if pages.is_empty():
		pass
		return
	
	# CRIA AS PÁGINAS USANDO A CENA
	_create_pages(pages)
	
	# SELECIONA A PÁGINA ATIVA
	# _select_active_page(pages)
	
	pass

# ===== _create_pages() COM DEBUG =====
func _create_pages(pages: Array):
	"""Cria os nós de página usando a cena pagina.tscn"""
	pass
	pass
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
		
		pass
		
		# POR PADRÃO, DESATIVA TODAS AS PÁGINAS
		page_node.visible = false
		pass
	
	pass
	pass

func _activate_page(index: int):
	"""Ativa uma página e desativa as outras"""
	pass
	
	if index < 0 or index >= pages_nodes.size():
		pass
		return
	
	active_page_index = index
	
	for i in range(pages_nodes.size()):
		var node = pages_nodes[i]
		var is_active = (i == index)
		node.visible = is_active
		
		pass
		
		# ATIVA/DESATIVA O COLLISIONSHAPE2D (física) via página
		if node.has_method("set_active"):
			node.set_active(is_active)
			pass
	
	# 🔥 ATUALIZA O TRIGGER DA PÁGINA ATIVA
	if index < pages_data.size():
		trigger = pages_data[index].get_trigger()
		pass
	
	pass

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
	pass
	
	# 🔥 SÓ REAVALIA A PÁGINA ATIVA
	# _reevaluate_active_page()
	_update_page()
	
	pass

# evento_base.gd - _reevaluate_active_page() CORRIGIDO


# ===== DETECÇÃO DE PLAYER VIA INTERACTIONZONE DA PÁGINA =====

func _connect_page_signals(page_node: Node):
	"""Conecta direto na InteractionZone da página (sem relay pela Pagina)"""
	pass
	
	if not page_node.has_method("get_interaction_zone"):
		pass
		return
	
	var zone: InteractionZone = page_node.get_interaction_zone()
	if not zone:
		pass
		return
	
	if not zone.interacted.is_connected(_on_zone_interacted):
		zone.interacted.connect(_on_zone_interacted)
		pass
	
	if not zone.player_entered.is_connected(_on_zone_player_entered):
		zone.player_entered.connect(_on_zone_player_entered)
		pass
	
	if not zone.player_exited.is_connected(_on_zone_player_exited):
		zone.player_exited.connect(_on_zone_player_exited)
		pass

# ===== FUNÇÕES DE DETECÇÃO =====

# evento_base.gd - Em _on_zone_player_entered()

# evento_base.gd - _on_zone_player_entered()

func _on_zone_player_entered():
	var player = get_node("/root/Main/Mundo/Player")
	if not player:
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	pass
	pass
	pass
	pass
	pass
	
	player_near = true
	pass
	
	# toque só vale com a bruxa perto de verdade (a física pode reportar a posição
	# antiga logo depois de um teletransporte)
	if trigger == "touch" and dist <= DIST_MAX_TOQUE and _can_activate():
		_do_activate()

func _on_zone_player_exited():
	player_near = false
	pass

# evento_base.gd
# evento_base.gd - Em _on_zone_interacted()

# evento_base.gd - Em _on_zone_interacted()

## Bruxa travada (comando Travar player): clique em evento não faz nada.
func _clique_travado() -> bool:
	return game_manager != null and game_manager.has_method("is_player_locked") and game_manager.is_player_locked()

func _on_zone_interacted():
	if trigger == "click" and _clique_travado():
		return
	if not _can_activate():
		return
	if trigger == "click" and not _pagina_tem_comandos():
		return   # página vazia: clique não faz nada (nem leva a bruxa até lá)
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
	var p = game_manager.get_player() if game_manager else null
	if arrived and (_is_player_near() or player_encostado() or (p and encostado_na_colisao(p))) and _can_activate():
		_do_activate()


## A bruxa está colada no evento (centro dela até ENCOSTO px da área de interação, na horizontal)?
## Para eventos sólidos: a colisão segura a bruxa antes de ela entrar na área.
const ENCOSTO: float = 90.0
func player_encostado() -> bool:
	var player = game_manager.get_player() if game_manager else null
	if player == null:
		return false
	var r := _zone_global_rect()
	if r.size == Vector2.ZERO:
		return false
	return player.global_position.x >= r.position.x - ENCOSTO and player.global_position.x <= r.end.x + ENCOSTO


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
	pass
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
	pass
	is_event_running = false
	last_activation_time = Time.get_ticks_msec() / 1000.0
	
	# NOTIFICA O PLAYER
	var player = get_node_or_null("/root/Main/Mundo/Player")
	if player and player.has_method("on_event_finished"):
		player.on_event_finished()
		pass

func reset_event_state():
	"""Reseta completamente o estado do evento"""
	pass
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
		pass
		if callback.is_valid(): callback.call(false)
		return
	
	_rota_cancelar_passo()   # comando Mover manda: a rota pausa e larga o passo atual
	move_target = Vector2(target_x, target_y)
	move_speed = speed
	move_direction = dir
	move_original_direction = "centro"
	# andando, vira sozinho para o lado do movimento (a menos que a direção esteja travada)
	if not direcao_travada and absf(target_x - global_position.x) >= 1.0:
		_rota_set_dir("dir" if target_x > global_position.x else "esq")
	move_timeout = 0.0
	move_success = false
	move_completed = false
	move_callback = callback
	is_moving = true
	
	pass

func _physics_process(delta):
	if is_moving:
		_process_movement(delta)
	_rota_process(delta)

func _process_movement(delta):
	if not is_moving:
		return
	
	if move_max_time>0:
		move_timeout += delta
		if move_timeout > move_max_time:
			pass
			_stop_movement(false)
			return

	
	var current_pos = global_position
	var direction_vec = (move_target - current_pos).normalized()
	var distance = current_pos.distance_to(move_target)
	var step = move_speed * delta
	
	if distance < step:
		global_position = move_target
		pass
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
	# ao chegar: para onde olhar (Mover > direção; "" = fica como está)
	if move_direction != "" and not direcao_travada:
		_rota_set_dir(move_direction)
	
	pass
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
	pass
	pass
	pass
	pass
	pass
	pass
	pass
	pass
	if is_moving:
		pass
	pass

func debug_signals():
	"""Debug dos sinais das páginas"""
	pass
	for page in pages_nodes:
		pass
		if page.has_method("get_interaction_zone"):
			var zone: InteractionZone = page.get_interaction_zone()
			if zone:
				pass
				pass
				pass
		pass
		if page.has_method("is_player_near"):
			pass
	pass

# ===== CLIQUE =====
# Caminho ÚNICO de clique: _unhandled_input. Cliques consumidos pela UI
# (diálogo, opções, HUD) não chegam aqui. Antes havia também _input, que
# rodava em TODOS os eventos e mesmo com a UI na frente.

func _unhandled_input(event: InputEvent):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if trigger != "click" or not is_visible_in_tree():
		return
	if _clique_travado():
		return   # bruxa travada (autostart, cutscene): eventos de clique não respondem
	# página sem comandos não segura o clique: ele passa para o evento de trás
	if not _pagina_tem_comandos():
		return
	if _zone_global_rect().has_point(get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		_destacar_toque()
		_on_zone_interacted()

## Feedback de toque: o sprite da página clareia rapidinho (self_modulate, não briga com o PISCAR).
const COR_TOQUE := Color(1.6, 1.6, 1.6)
func _destacar_toque() -> void:
	var pg = _get_active_page_node()
	var spr = pg.get("animated_sprite") if pg else null
	if not (spr is CanvasItem):
		return
	spr.self_modulate = COR_TOQUE
	spr.create_tween().tween_property(spr, "self_modulate", Color.WHITE, 0.3)

func _pagina_tem_comandos() -> bool:
	var dados: PaginaData = _get_active_page_data()
	return dados != null and not dados.comandos.is_empty()

## Retângulo da colisão (StaticBody da página ativa) em coordenadas globais, mesmo se
## o evento for passável (a colisão fica desligada, mas o tamanho vale como "corpo").
func rect_colisao_global() -> Rect2:
	var page = _get_active_page_node()
	var shape_node = page.get_node_or_null("CollisionShape2D") if page else null
	if not shape_node or not (shape_node.shape is RectangleShape2D):
		return Rect2()
	var sz: Vector2 = shape_node.shape.size
	return shape_node.global_transform * Rect2(-sz / 2.0, sz)

## Meia largura da colisão da bruxa (global).
static func meia_largura(player: Node2D) -> float:
	var cs = player.get_node_or_null("CollisionShape2D")
	if cs and cs.shape is RectangleShape2D:
		return cs.shape.size.x * 0.5 * absf(cs.global_transform.get_scale().x)
	return 40.0

const FOLGA_ENCOSTO: float = 6.0
## Clique: x onde a bruxa encosta na colisão, do lado em que ela está; null = já encostada.
func alvo_encostar(player: Node2D):
	var r := rect_colisao_global()
	if r.size == Vector2.ZERO:
		r = _zone_global_rect()
	if r.size == Vector2.ZERO:
		return global_position.x
	var m := meia_largura(player)
	var x: float = player.global_position.x
	if x + m < r.position.x - FOLGA_ENCOSTO:
		return r.position.x - m
	if x - m > r.end.x + FOLGA_ENCOSTO:
		return r.end.x + m
	return null

func encostado_na_colisao(player: Node2D) -> bool:
	return alvo_encostar(player) == null

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


# ===== MOVIMENTO AUTÔNOMO (rota da página) =====
# PaginaData.movimento = ROTA: o evento executa os PassoRota da página em ordem, sozinho.
# Pausa enquanto a própria página roda (clique/toque) e enquanto um comando Mover o move.
var _rota_pagina: int = -1
var _rota_i: int = 0
var _rota_espera: float = 0.0
var _rota_andando: bool = false
var _rota_alvo_x: float = 0.0
var _rota_vel: float = 80.0
var _rota_fixa: bool = false
## Comando "Travar direção": andando (Mover ou rota), o evento não vira para o lado do movimento.
var direcao_travada: bool = false
var _rota_fim: bool = false          # rota sem repetir terminou
var _rota_origem_x: float = NAN      # para o "rota_raio"
var _rota_anim_base: String = ""     # animação parada (passo ANIMACAO)
var _rota_pulo: Dictionary = {}      # {de, para, dur, t, h}

func _rota_reiniciar(p: PaginaData) -> void:
	_rota_pagina = active_page_index
	_rota_i = 0
	_rota_espera = 0.0
	_rota_fim = false
	_rota_fixa = false
	_rota_anim_base = ""
	_rota_vel = p.rota_velocidade if p else 80.0
	_rota_cancelar_passo()
	if is_nan(_rota_origem_x):
		_rota_origem_x = global_position.x

func _rota_cancelar_passo() -> void:
	if _rota_andando:
		_rota_andando = false
		_rota_anim("")
	if not _rota_pulo.is_empty():
		_rota_pulo = {}
		_rota_sprite_y(0.0)
		_rota_anim("")

func _rota_process(delta: float) -> void:
	var p := _get_active_page_data()
	if p == null or p.movimento != PaginaData.Movimento.ROTA or p.rota.is_empty():
		if _rota_pagina != -1:
			_rota_cancelar_passo()
			_rota_pagina = -1
		return
	if _rota_pagina != active_page_index:
		_rota_reiniciar(p)
	if not _rota_pulo.is_empty():   # pulo começado termina mesmo com a rota em pausa
		_rota_pular(delta)
		return
	if _rota_fim or is_moving:
		return
	if trigger != "parallel" and interpreter and interpreter.has_method("is_page_running") \
			and interpreter.is_page_running(get_event_name(), active_page_index, chave_self()):
		_rota_cancelar_passo()
		return
	if _rota_andando:
		_rota_andar(delta, p)
		return
	if _rota_espera > 0.0:
		_rota_espera -= delta
		return
	_rota_proximo(p)

## Executa passos instantâneos até achar um que leva tempo (andar, pular, esperar...).
func _rota_proximo(p: PaginaData) -> void:
	for _g in range(p.rota.size() + 1):
		if _rota_i >= p.rota.size():
			if not p.rota_repetir:
				_rota_fim = true
				return
			_rota_i = 0
		var passo: PassoRota = p.rota[_rota_i]
		_rota_i += 1
		if passo == null or randf() > passo.chance:
			continue
		if _rota_executar(passo, p):
			return

## true = o passo leva tempo (a rota espera ele acabar).
func _rota_executar(passo: PassoRota, p: PaginaData) -> bool:
	match passo.tipo:
		PassoRota.Tipo.MOVER:
			return _rota_iniciar_andar(passo.distancia, true, p)
		PassoRota.Tipo.FRENTE:
			return _rota_iniciar_andar(_rota_lado() * passo.distancia, true, p)
		PassoRota.Tipo.TRAS:
			return _rota_iniciar_andar(-_rota_lado() * passo.distancia, false, p)
		PassoRota.Tipo.ALEATORIO:
			var d: float = passo.distancia * randf_range(0.5, 1.0) * (1.0 if randf() < 0.5 else -1.0)
			return _rota_iniciar_andar(d, true, p)
		PassoRota.Tipo.PULAR:
			return _rota_iniciar_pulo(_rota_lado() * passo.distancia, passo.altura, p)
		PassoRota.Tipo.OLHAR:
			_rota_olhar(passo.olhar)
		PassoRota.Tipo.FIXAR_DIRECAO:
			_rota_fixa = passo.fixar
		PassoRota.Tipo.ESPERAR:
			_rota_espera = randf_range(passo.segundos, passo.segundos_max) if passo.segundos_max > passo.segundos else passo.segundos
			return true
		PassoRota.Tipo.BALAO:
			CmdBalao.mostrar(self, passo.emocao, passo.segundos, _rota_altura_sprite() * 0.5 + 24.0)
			_rota_espera = passo.segundos
			return true
		PassoRota.Tipo.VELOCIDADE:
			_rota_vel = maxf(passo.velocidade, 1.0)
		PassoRota.Tipo.ANIMACAO:
			_rota_anim_base = passo.animacao
			_rota_anim("")
	return false

## dx limitado pelo rota_raio (0 = sem limite).
func _rota_limitar(dx: float, p: PaginaData) -> float:
	if p.rota_raio <= 0.0:
		return dx
	var x: float = global_position.x
	return clampf(x + dx, _rota_origem_x - p.rota_raio, _rota_origem_x + p.rota_raio) - x

func _rota_iniciar_andar(dx: float, virar: bool, p: PaginaData) -> bool:
	dx = _rota_limitar(dx, p)
	if absf(dx) < 1.0:
		return false
	if virar and not _rota_fixa and not direcao_travada:
		_rota_set_dir("dir" if dx > 0.0 else "esq")
	if p.rota_pular_se_bloqueado and _rota_bloqueado(signf(dx) * 2.0):
		return false
	_rota_alvo_x = global_position.x + dx
	_rota_andando = true
	_rota_anim("andar")
	return true

func _rota_andar(delta: float, p: PaginaData) -> void:
	var falta: float = _rota_alvo_x - global_position.x
	var passo: float = _rota_vel * delta
	if absf(falta) <= passo:
		global_position.x = _rota_alvo_x
		_rota_cancelar_passo()
		return
	var dx: float = signf(falta) * passo
	if _rota_bloqueado(dx):
		if p.rota_pular_se_bloqueado:
			_rota_cancelar_passo()   # desiste deste passo; senão fica tentando
		return
	global_position.x += dx

func _rota_iniciar_pulo(dx: float, h: float, p: PaginaData) -> bool:
	dx = _rota_limitar(dx, p)
	if absf(dx) >= 1.0:
		if not _rota_fixa and not direcao_travada:
			_rota_set_dir("dir" if dx > 0.0 else "esq")
		if _rota_bloqueado(dx):
			if p.rota_pular_se_bloqueado:
				return false
			_rota_i -= 1           # tenta de novo daqui a pouco
			_rota_espera = 0.3
			return true
	var x: float = global_position.x
	_rota_pulo = {"de": x, "para": x + dx, "dur": maxf(0.35, absf(dx) / _rota_vel), "t": 0.0, "h": h}
	_rota_anim("pular")
	return true

func _rota_pular(delta: float) -> void:
	_rota_pulo["t"] += delta
	var k: float = minf(_rota_pulo["t"] / _rota_pulo["dur"], 1.0)
	global_position.x = lerpf(_rota_pulo["de"], _rota_pulo["para"], k)
	_rota_sprite_y(-4.0 * _rota_pulo["h"] * k * (1.0 - k))
	if k >= 1.0:
		_rota_pulo = {}
		_rota_sprite_y(0.0)
		_rota_anim("")

## Algo sólido no caminho? A colisão do evento fica na página (StaticBody2D), então
## testa o shape dela. Página passável (colisão desligada) nunca é bloqueada.
func _rota_bloqueado(dx: float) -> bool:
	var pg = _get_active_page_node()
	var cs: CollisionShape2D = pg.get("collision_shape") if pg else null
	if cs == null or cs.shape == null or cs.disabled:
		return false
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cs.shape
	q.transform = cs.global_transform
	q.motion = Vector2(dx, 0.0)
	q.collision_mask = pg.collision_mask
	q.exclude = [pg.get_rid(), get_rid()]
	var r: PackedFloat32Array = get_world_2d().direct_space_state.cast_motion(q)
	return r.size() > 0 and r[0] < 1.0

func _rota_olhar(o: int) -> void:
	var player = get_node_or_null("/root/Main/Mundo/Player")
	var atual := _rota_dir()
	match o:
		PassoRota.Olhar.ESQ: _rota_set_dir("esq")
		PassoRota.Olhar.DIR: _rota_set_dir("dir")
		PassoRota.Olhar.INVERTER: _rota_set_dir("dir" if atual == "esq" else "esq")
		PassoRota.Olhar.ALEATORIO: _rota_set_dir("esq" if randf() < 0.5 else "dir")
		PassoRota.Olhar.PARA_BRUXA, PassoRota.Olhar.LONGE_DA_BRUXA:
			if player:
				var esq: bool = player.global_position.x < global_position.x
				if o == PassoRota.Olhar.LONGE_DA_BRUXA:
					esq = not esq
				_rota_set_dir("esq" if esq else "dir")

func _rota_dir() -> String:
	var pg = _get_active_page_node()
	return pg.get_direcao() if pg and pg.has_method("get_direcao") else "centro"

func _rota_lado() -> float:
	return -1.0 if _rota_dir() == "esq" else 1.0

func _rota_set_dir(lado: String) -> void:
	var pg = _get_active_page_node()
	if pg and pg.has_method("set_direcao"):
		pg.set_direcao(lado)

## Troca a animação se ela existir no SpriteFrames ("" = a parada da rota/página).
func _rota_anim(nome: String) -> void:
	var pg = _get_active_page_node()
	if pg == null or not pg.has_method("set_animation"):
		return
	if nome != "" and pg.set_animation(nome):
		return
	pg.set_animation(_rota_anim_base)

## Sobe/desce só o desenho (o corpo e a colisão ficam no chão).
func _rota_sprite_y(y: float) -> void:
	var pg = _get_active_page_node()
	var s = pg.get("animated_sprite") if pg else null
	if s == null:
		return
	if not s.has_meta("rota_y0"):
		s.set_meta("rota_y0", s.position.y)
	s.position.y = s.get_meta("rota_y0") + y

func _rota_altura_sprite() -> float:
	var pg = _get_active_page_node()
	var s = pg.get("animated_sprite") if pg else null
	if s and s.sprite_frames and s.sprite_frames.has_animation(s.animation):
		var tex = s.sprite_frames.get_frame_texture(s.animation, 0)
		if tex:
			return tex.get_height() * absf(s.scale.y * pg.scale.y)
	return 80.0
