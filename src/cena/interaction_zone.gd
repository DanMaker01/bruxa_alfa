# interaction_zone.gd
class_name InteractionZone
extends Area2D

# ===== SINAIS =====
# Único sinal de ativação: a zona decide sozinha, baseado no trigger_type,
# quando uma entrada/clique deve virar uma interação de verdade.
signal player_entered
signal player_exited
signal interacted

# ===== CONFIGURAÇÃO =====
@export var trigger_type: String = "click"  # click / touch / parallel
@export var cooldown: float = 0.3

# ===== ESTADO =====
var player_near: bool = false
var _last_trigger_time: float = 0.0


func _ready():
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	input_pickable = true  # 🔥 ESSENCIAL

	pass
	pass
	pass

	area_entered.connect(_on_enter)
	body_entered.connect(_on_enter)
	area_exited.connect(_on_exit)
	body_exited.connect(_on_exit)
	input_event.connect(_on_click)

# ===== DETECÇÃO =====

# interaction_zone.gd - _on_enter() com debug completo

func _on_enter(other):
	if not _is_player(other):
		pass
		return
	
	player_near = true
	player_entered.emit()
	
	if trigger_type == "touch":
		_try_interact()

func _on_exit(other):
	if not _is_player(other):
		return
	player_near = false
	player_exited.emit()

# interaction_zone.gd - Em _on_click()

func _on_click(_viewport, event, _shape_idx):
	pass
	pass
	
	if trigger_type != "click":
		pass
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pass
		_try_interact()
	else:
		pass

func _is_player(other: Node) -> bool:
	# other pode ser uma Area2D (ex: InteractionZone do Player) ou o próprio
	# CharacterBody2D do Player, dependendo de qual sinal (area_* ou body_*) disparou
	if other.name == "Player":
		return true
	var parent = other.get_parent()
	return parent != null and parent.name == "Player"

# interaction_zone.gd - Em _try_interact()

# interaction_zone.gd - _try_interact()

func _try_interact() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_trigger_time < cooldown:
		pass
		return false
	
	# 🔥 VERIFICA DISTÂNCIA ANTES DE EMITIR O SINAL
	var player = get_node("/root/Main/Mundo/Player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist > 200:
			pass
			return false
	
	_last_trigger_time = now
	pass
	interacted.emit()
	return true
# ===== CONTROLE EXTERNO =====

# interaction_zone.gd - Em set_zone_active()

func set_zone_active(active: bool):
	"""Liga/desliga a zona por completo"""
	monitoring = active
	monitorable = active
	
	# 🔥 PARA CLICK, input_pickable DEVE SER TRUE SEMPRE
	if trigger_type == "click":
		input_pickable = true
	else:
		input_pickable = active
	
	if not active:
		player_near = false
	
	pass


func reset_cooldown():
	"""Zera o cooldown, útil se o evento for reiniciado externamente (reset_event_state)"""
	_last_trigger_time = 0.0

# ===== CONFIGURAÇÃO DINÂMICA =====
func setup(layer: int = 1, mask: int = 1, monitor: bool = true):
	collision_layer = layer
	collision_mask = mask
	monitoring = monitor
	monitorable = monitor
	input_pickable = monitor

func set_size(size: Vector2):
	var shape = get_node_or_null("CollisionShape2D")
	if shape:
		if shape.shape == null:
			shape.shape = RectangleShape2D.new()
		shape.shape.size = size
