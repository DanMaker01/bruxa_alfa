# game_input_manager.gd - VERSÃO CORRIGIDA
extends Node

# ===== REFERÊNCIAS =====
var player = null
var game_manager = null
var interpreter = null

# ===== ESTADO DE MOVIMENTO =====
var is_moving: bool = false
var is_dragging: bool = false
var is_mouse_pressed: bool = false

var target_position: Vector2 = Vector2.ZERO
# Movimento automático (ex.: andar até um evento clicado). Não é cancelado ao soltar
# o dedo/mouse nem por arrasto; só por um NOVO clique.
var auto_moving: bool = false
# Incrementa a cada clique novo no mundo — quem iniciou um auto-movimento usa isso
# para saber se o jogador mudou de ideia.
var click_id: int = 0
# Detecção de "travado": se a bruxa não sai do lugar (ex.: colisão de um evento
# não passável), para onde conseguiu chegar em vez de ficar empurrando.
const STUCK_TIME: float = 0.25
const STUCK_MIN_MOVE: float = 0.5
var _stuck_timer: float = 0.0
var _last_x: float = 0.0
# Direção em que ficou bloqueada enquanto o dedo segue apertado: não tenta de novo
# na mesma direção até o dedo apontar para o outro lado ou ser solto.
var _blocked_dir: int = 0
const HOLD_DEAD_ZONE: float = 10.0
var mouse_position: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.ZERO

# 🔥 REMOVIDO: MAX_SPEED, ACCELERATION, FRICTION
# AGORA USA DIRETAMENTE DO PLAYER

func _ready():
	call_deferred("_initialize")

func _initialize():
	game_manager = get_node("/root/Main/GameManager")
	if game_manager:
		interpreter = game_manager.get_node("Interpeter")
	
	var mundo = get_node("/root/Main/Mundo")
	if mundo:
		player = mundo.get_node("Player")
		if player:
			print("[InputManager] Inicializado!")
			debug()

func _process(delta):
	if get_tree().paused:
		return
	
	if not player:
		return
	
	# 🔥 SEGURANDO: o destino é o ponto sob o dedo, atualizado TODO frame.
	# Assim ela segue o dedo sem parar e recomeçar (a câmera anda junto com ela,
	# então o ponto do mundo sob o dedo muda mesmo com o dedo parado).
	# Durante o fade e a troca de mapa ela fica parada; com o dedo ainda apertado,
	# volta a andar sozinha quando a tela clarear (sem precisar clicar de novo).
	if is_mouse_pressed and not auto_moving:
		if _segurar_player():
			if is_moving:
				_stop_here()
			return
		_follow_finger()
	
	# 🔥 MOVIMENTO POR CLIQUE
	if is_moving:
		var dist = target_position.x - player.global_position.x
		var distance = abs(dist)
		
		# 🔥 VERIFICA SE CHEGOU (segurando, só "chega" se o dedo estiver em cima dela)
		if distance < 3.0:
			player.global_position.x = target_position.x
			is_moving = false
			auto_moving = false
			last_direction = Vector2.ZERO
			player.velocity.x = 0
			
			if player.has_method("set_movement_direction"):
				player.set_movement_direction(0)
			
			print("[InputManager] ✅ Chegou em X: ", player.global_position.x)
			return
		
		# 🔥 TRAVOU NUM OBSTÁCULO? PARA ONDE CONSEGUIU CHEGAR
		if abs(player.global_position.x - _last_x) < STUCK_MIN_MOVE:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
		_last_x = player.global_position.x
		if _stuck_timer >= STUCK_TIME:
			print("[InputManager] ⛔ Bloqueado em X: ", player.global_position.x, " (alvo ", target_position.x, ")")
			_blocked_dir = 1 if target_position.x > player.global_position.x else -1
			_stop_here()
			return
		
		# 🔥 ACELERA PROGRESSIVAMENTE (USA DIRETAMENTE O PLAYER)
		var direction = 1 if dist > 0 else -1
		if _vel_fixa > 0.0:
			# movimento por comando com velocidade fixa: sem aceleração (acompanha eventos)
			player.velocity.x = direction * _vel_fixa
		else:
			var target_vel = direction * player.velocidade_max()
			player.velocity.x = move_toward(player.velocity.x, target_vel, player.aceleracao() * delta)
		
		# Atualiza direção do sprite
		if player.has_method("set_movement_direction"):
			player.set_movement_direction(direction)
		
		last_direction = Vector2(direction, 0)
		
		# 🔥 CORREÇÃO DE OVERSHOOT (se passou do alvo)
		var new_dist = target_position.x - player.global_position.x
		if (new_dist > 0 and direction < 0) or (new_dist < 0 and direction > 0):
			player.global_position.x = target_position.x
			is_moving = false
			auto_moving = false
			last_direction = Vector2.ZERO
			player.velocity.x = 0
			print("[InputManager] ✅ Chegou (corrigido overshoot)")

	# Sem "arrastar contínuo": segurar parado NÃO gera novos destinos
	# (antes, como a câmera anda com a bruxa, o ponto sob o dedo mudava
	# e ela seguia andando). O destino só muda quando o dedo se move.

func _input(event):
	# Soltar o dedo é tratado SEMPRE (mesmo sobre o HUD, pausado ou em diálogo),
	# senão o jogo acharia que o dedo continua apertado e ela seguiria o dedo.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_mouse_pressed:
			is_mouse_pressed = false
			is_dragging = false
			_blocked_dir = 0
			# Ao soltar, ela segue até o último ponto (ou para onde conseguir).
		return
	
	if get_tree().paused:
		return
	
	if game_manager and game_manager.is_player_locked():
		return
	
	if interpreter and interpreter.is_processing_dialog():
		return
	
	if event is InputEventMouseButton:
		# IGNORA CLIQUE NO HUD (Y > 640)
		if event.position.y > 640:
			return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_mouse_pressed = true
				_vel_fixa = 0.0
				is_dragging = true
				mouse_position = event.position
				click_id += 1
				auto_moving = false  # clique novo cancela andar-até-evento
				_blocked_dir = 0
				
				if not player:
					return
				
				var camera = get_viewport().get_camera_2d()
				if not camera:
					return
				
				var world_click = camera.get_canvas_transform().affine_inverse() * event.position
				var new_target_x = world_click.x
				
				if abs(new_target_x - player.global_position.x) < 10.0:
					return
				
				target_position = Vector2(new_target_x, player.global_position.y)
				_start_moving()
				print("[InputManager] 🖱️ Clique em X: ", new_target_x)
			
	elif event is InputEventMouseMotion:
		if is_mouse_pressed:
			# Só guarda a posição do dedo; _process recalcula o destino todo frame.
			mouse_position = event.position

func _follow_finger():
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	var wx = (camera.get_canvas_transform().affine_inverse() * mouse_position).x
	var d = wx - player.global_position.x
	target_position = Vector2(wx, player.global_position.y)
	if is_moving or abs(d) < HOLD_DEAD_ZONE:
		return
	var dir = 1 if d > 0 else -1
	if dir == _blocked_dir:
		return  # já bateu num obstáculo nessa direção; espera o dedo mudar de lado
	_blocked_dir = 0
	_start_moving()

func _start_moving():
	is_moving = true
	_stuck_timer = 0.0
	_last_x = player.global_position.x if player else 0.0

func _stop_here():
	"""Para no lugar (sem deslizar), usado quando a bruxa não consegue avançar."""
	is_moving = false
	auto_moving = false
	_stuck_timer = 0.0
	last_direction = Vector2.ZERO
	if player:
		player.velocity.x = 0
		if player.has_method("set_movement_direction"):
			player.set_movement_direction(0)

# ===== MÉTODOS PÚBLICOS =====

## Velocidade fixa (px/s) do movimento atual por comando; 0 = normal, com aceleração.
var _vel_fixa: float = 0.0

func move_to(x: float):
	_vel_fixa = 0.0
	"""Move o player para uma posição X"""
	print("[InputManager] Movendo para X: ", x)
	target_position = Vector2(x, player.global_position.y if player else 0)
	_start_moving()
	auto_moving = true

func move_to_position(target_x: float, target_y: float, velocidade: float = 0.0):
	"""Move o player para uma posição específica (Y é ignorado).
	velocidade > 0: anda nessa velocidade fixa, sem aceleração (cutscenes com outros eventos)."""
	_vel_fixa = velocidade
	print("[InputManager] Movendo para posição: (", target_x, ", ", target_y, ")")
	var y = player.global_position.y if player else 0
	target_position = Vector2(target_x, y)
	_start_moving()
	auto_moving = true

func move_to_event(event_node: Node2D):
	"""Move o player até a posição X de um evento"""
	if not event_node:
		print("[InputManager] ❌ Evento inválido!")
		return
	
	var event_x = event_node.global_position.x
	var y = player.global_position.y if player else 0
	move_to_position(event_x, y)

func stop_movement():
	"""Para o movimento do player com desaceleração suave"""
	_vel_fixa = 0.0
	print("[InputManager] Parando movimento (com desaceleração)")
	is_moving = false
	auto_moving = false
	is_dragging = false
	last_direction = Vector2.ZERO
	
	if player and player.has_method("stop_movement"):
		player.stop_movement()

func force_stop():
	"""Para o movimento imediatamente"""
	print("[InputManager] Forçando parada imediata")
	is_moving = false
	auto_moving = false
	is_dragging = false
	is_mouse_pressed = false
	last_direction = Vector2.ZERO
	
	if player and player.has_method("force_stop"):
		player.force_stop()

## true enquanto a tela está em fade (escurecendo, escura ou clareando) ou o mapa está trocando.
func _segurar_player() -> bool:
	if game_manager == null:
		return false
	if game_manager.has_method("trocando_mapa") and game_manager.trocando_mapa():
		return true
	return game_manager.has_method("tela_em_fade") and game_manager.tela_em_fade()

func get_player_position() -> Vector2:
	if player:
		return player.global_position
	return Vector2.ZERO

func can_move() -> bool:
	if game_manager and game_manager.is_player_locked():
		return false
	return true

func is_player_moving() -> bool:
	return is_moving or (player and abs(player.velocity.x) > 1.0)

## manter_dedo = true: para o movimento mas lembra que o dedo continua apertado
## (usado na troca de mapa, para ela seguir andando na tela nova).
func force_reset(manter_dedo: bool = false):
	"""Força o reset completo do InputManager"""
	print("[InputManager] 🔄 force_reset() chamado", " (mantendo o dedo)" if manter_dedo else "")
	
	is_moving = false
	auto_moving = false
	is_dragging = false
	_blocked_dir = 0
	if not manter_dedo:
		is_mouse_pressed = false
		mouse_position = Vector2.ZERO
	last_direction = Vector2.ZERO
	target_position = Vector2.ZERO
	
	if player and player.has_method("force_stop"):
		player.force_stop()
		print("[InputManager] Player.force_stop() chamado.")
	
	if player:
		player.velocity = Vector2.ZERO

	print("[InputManager] ✅ Reset concluído")

# ===== DEBUG =====

func debug():
	print("[InputManager] Player X: ", player.global_position.x if player else "null")
	print("[InputManager] Player Y: ", player.global_position.y if player else "null")
	print("[InputManager] Moving: ", is_moving)
	print("[InputManager] Dragging: ", is_dragging)
	print("[InputManager] MAX_SPEED (do Player): ", player.MAX_SPEED if player else "null")
	print("[InputManager] ACCELERATION (do Player): ", player.ACCELERATION if player else "null")
	print("[InputManager] FRICTION (do Player): ", player.FRICTION if player else "null")
	print("[InputManager] Target X: ", target_position.x)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				debug()
			KEY_F2:
				force_reset()
				print("[InputManager] Reset forçado")