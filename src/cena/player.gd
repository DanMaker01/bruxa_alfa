# player.gd - VERSÃO COM ACELERAÇÃO
extends CharacterBody2D

# ===== CONSTANTES DE MOVIMENTO =====
const MAX_SPEED: float = 200.0		# Velocidade máxima
const ACCELERATION: float = 1000.0	 # Aceleração (px/s²)
const FRICTION: float = 600.0		 # Desaceleração (px/s²)
const FLIP_THRESHOLD: float = 0.5
## Multiplica velocidade e aceleração (1 = normal; o menu de debug usa 2).
var multiplicador_velocidade: float = 1.0

func velocidade_max() -> float:
	return MAX_SPEED * multiplicador_velocidade

func aceleracao() -> float:
	return ACCELERATION * multiplicador_velocidade

# ===== PASSÁVEL (atravessar tudo) =====
# Só a máscara de colisão muda: a bruxa continua na camada dela, então as áreas
# dos eventos ("touch") ainda a detectam.
var _mask_original: int = -1

func set_passavel(passavel: bool) -> void:
	if passavel:
		if _mask_original < 0:
			_mask_original = collision_mask
		collision_mask = 0
	elif _mask_original >= 0:
		collision_mask = _mask_original
		_mask_original = -1

func is_passavel() -> bool:
	return _mask_original >= 0

# ===== DIREÇÃO (para onde a bruxa olha) =====
## "esq" ou "dir".
func get_direcao() -> String:
	return "esq" if sprite and sprite.flip_h else "dir"

## "esq", "dir" ou "centro" (centro = dir, como no teleporte).
func virar(direcao: String) -> void:
	if sprite:
		sprite.flip_h = direcao == "esq"

# ===== ESTADO =====
var movement_direction: int = 0	   # -1, 0, 1
var is_moving_from_input: bool = false
var is_event_running: bool = false

# ===== REFERÊNCIAS =====
@onready var sprite: Sprite2D = $Sprite2D
@onready var zone: InteractionZone = $InteractionZone
var game_manager = null

# player.gd - Adicione estas funções

func mostrar_player():
	"""Mostra o player (sprite + colisão)"""
	visible = true
	if sprite:
		sprite.visible = true
	print("[Player] 👁️ Player visível")

func sumir_player():
	"""Esconde o player (sprite + colisão)"""
	visible = false
	if sprite:
		sprite.visible = false
	print("[Player] 🫥 Player invisível")

func disable_interaction():
	"""Desativa a InteractionZone do player"""
	if zone:
		zone.monitoring = false
		zone.monitorable = false
		zone.input_pickable = false
		print("[Player] 🔒 Interação desativada")

func enable_interaction():
	"""Reativa a InteractionZone do player"""
	if zone:
		zone.monitoring = true
		zone.monitorable = true
		zone.input_pickable = true
		print("[Player] 🔓 Interação reativada")

# func disable_physics():
# 	"""Desativa o processamento de física do player"""
# 	set_physics_process(false)
# 	velocity = Vector2.ZERO
# 	print("[Player] 🔒 Física desativada")

# func enable_physics():
# 	"""Reativa o processamento de física do player"""
# 	set_physics_process(true)
# 	print("[Player] 🔓 Física reativada")

func _ready():
	print("[Player] ===== INICIANDO =====")
	if zone:
		print("[Player] ✅ InteractionZone própria pronta (", zone.name, ")")
	else:
		print("[Player] ❌ InteractionZone NÃO encontrada!")

# 🔥 MÉTODO PRINCIPAL DE MOVIMENTO COM ACELERAÇÃO
func _physics_process(delta: float) -> void:
	# 1. OBTÉM A DIREÇÃO DO INPUT (teclado)
	var direction_input = Input.get_axis("ui_left", "ui_right")
	# 🔥 travar_player também trava o teclado
	if game_manager and game_manager.has_method("is_player_locked") and game_manager.is_player_locked():
		direction_input = 0
	
	# 2. CALCULA ACELERAÇÃO/DESACELERAÇÃO
	if direction_input != 0:
		# MOVENDO: acelera até a velocidade máxima
		movement_direction = direction_input
		is_moving_from_input = true
		
		# Aplica aceleração
		velocity.x = move_toward(velocity.x, direction_input * velocidade_max(), aceleracao() * delta)
		
	else:
		# PARANDO: aplica fricção
		if is_moving_from_input:
			# Vem do input, aplica fricção
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
			if abs(velocity.x) < 0.1:
				velocity.x = 0
				is_moving_from_input = false
		else:
			# Vem do InputManager (clique), aplica fricção
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
			if abs(velocity.x) < 0.1:
				velocity.x = 0
	
	# 3. APLICA O MOVIMENTO
	move_and_slide()
	
	#DEBUG, saber com quem colidiu
	# for i in get_slide_collision_count():
		# var collision = get_slide_collision(i)
		# print("[Player] Colidiu com: ", collision.get_collider().name)
	
	# 4. ATUALIZA A ANIMAÇÃO
	_update_animation()

# 🔥 MÉTODO CHAMADO PELO INPUT MANAGER (clique)
func set_movement_direction(direction: int) -> void:
	"""Define a direção do movimento (usado pelo InputManager)"""
	movement_direction = direction
	
	# Atualiza o flip do sprite imediatamente
	if sprite:
		if direction > 0:
			sprite.flip_h = false
		elif direction < 0:
			sprite.flip_h = true

# 🔥 MÉTODO CHAMADO PELO INPUT MANAGER (movimento contínuo)
func set_target_velocity(target_x: float) -> void:
	"""Define a velocidade alvo (usado pelo InputManager para clique)"""
	if target_x > 0:
		velocity.x = move_toward(velocity.x, velocidade_max(), aceleracao() * get_process_delta_time())
	elif target_x < 0:
		velocity.x = move_toward(velocity.x, -velocidade_max(), aceleracao() * get_process_delta_time())
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * get_process_delta_time())

func _update_animation() -> void:
	if sprite:
		if velocity.x > FLIP_THRESHOLD:
			sprite.flip_h = false
		elif velocity.x < -FLIP_THRESHOLD:
			sprite.flip_h = true

func on_event_finished() -> void:
	is_event_running = false

func stop_movement() -> void:
	"""Para completamente o movimento do player com desaceleração suave"""
	# Aplica fricção para parar suavemente
	velocity.x = move_toward(velocity.x, 0, FRICTION * get_process_delta_time())
	if abs(velocity.x) < 0.1:
		velocity.x = 0
		movement_direction = 0
		is_moving_from_input = false
	print("[Player] 🛑 Movimento parando...")

func force_stop() -> void:
	"""Para o movimento imediatamente (sem desaceleração)"""
	velocity = Vector2.ZERO
	movement_direction = 0
	is_moving_from_input = false
	print("[Player] 🛑 Movimento forçado a parar")

# ===== DEBUG =====
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F11:
				_test_manual()

func _test_manual():
	print("\n🧪 TESTE MANUAL ATIVADO!")
	var mundo = get_node("/root/Main/Mundo")
	if not mundo:
		print("  ❌ Mundo não encontrado!")
		return
	
	var evento = _find_event(mundo, "Passagem")
	if not evento:
		print("  ❌ Evento Passagem não encontrado!")
		return
	
	print("  ✅ Evento encontrado: ", evento.name)
	
	if evento.has_method("_get_active_page_node"):
		var page = evento._get_active_page_node()
		if page and page.has_method("get_interaction_zone"):
			var area = page.get_interaction_zone()
			if area and zone:
				print("  📍 Zona do evento: ", area.name)
				print("	 monitoring: ", area.monitoring)
				print("	 collision_layer: ", area.collision_layer)
				print("	 collision_mask: ", area.collision_mask)
				
				print("\n  🔍 TESTANDO SOBREPOSIÇÃO...")
				if area.overlaps_area(zone):
					print("  ✅ SOBREPOSIÇÃO DETECTADA!")
					print("  🚀 ATIVANDO MANUALMENTE!")
					evento._activate()
				else:
					print("  ❌ NENHUMA SOBREPOSIÇÃO!")
					print("	 Player position: ", global_position)
					print("	 Área position: ", area.global_position)
					print("	 Distância: ", global_position.distance_to(area.global_position))

func _find_event(node: Node, target: String) -> Node:
	for child in node.get_children():
		if child.name == target and child.has_method("_activate"):
			return child
		var found = _find_event(child, target)
		if found:
			return found
	return null
