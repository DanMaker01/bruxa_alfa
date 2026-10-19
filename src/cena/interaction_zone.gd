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

	print("[InteractionZone] _ready() - input_pickable: ", input_pickable)
	print("[InteractionZone] _ready() - collision_layer: ", collision_layer)
	print("[InteractionZone] _ready() - collision_mask: ", collision_mask)

	area_entered.connect(_on_enter)
	body_entered.connect(_on_enter)
	area_exited.connect(_on_exit)
	body_exited.connect(_on_exit)
	input_event.connect(_on_click)

# ===== DETECÇÃO =====

# interaction_zone.gd - _on_enter() com debug completo

func _on_enter(other):
	# 🔥 DEBUG COMPLETO DO NÓ QUE ENTROU
	print("\n" + "=".repeat(60))
	print("🚪🚪🚪 [ZONA TOCADA]")
	print("  📍 Zona do evento: ", str(get_parent().name) if get_parent() else "?")
	print("  📍 Evento pai: ", str(get_parent().get_parent().name) if get_parent() and get_parent().get_parent() else "?")
	print("  📍 trigger_type: ", trigger_type)
	print("  📍 Posição da zona: ", global_position)
	
	# 🔥 INFORMAÇÕES DO NÓ QUE ENTROU
	print("\n  📦 NÓ QUE ENTROU:")
	print("	Nome: ", other.name)
	print("	Classe: ", other.get_class())
	print("	Posição: ", other.global_position if other.has_method("get_global_position") else "N/A")
	
	# 🔥 TENTA IDENTIFICAR O QUE É
	if other is CharacterBody2D:
		print("	✅ É um CharacterBody2D (provavelmente o Player)")
	elif other is Area2D:
		print("	⚠️ É uma Area2D (pode ser a InteractionZone do Player!)")
		# 🔥 MOSTRA O PAI DA AREA
		var parent = other.get_parent()
		if parent:
			print("	Pai da Area2D: ", parent.name, " (", parent.get_class(), ")")
			if parent.name == "Player":
				print("	✅ É a InteractionZone do PLAYER!")
	elif other is CollisionShape2D:
		print("	⚠️ É uma CollisionShape2D (estranho!)")
	
	# 🔥 DISTÂNCIA ENTRE PLAYER E ZONA
	var player = get_node("/root/Main/Mundo/Player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		print("\n  📏 Distância Player-Zona: ", dist)
		if dist > 100:
			print("  ⚠️⚠️⚠️ PLAYER LONGE DA ZONA! (", dist, "px)")
		else:
			print("  ✅ Player perto da zona")
	
	print("=".repeat(60))
	
	if not _is_player(other):
		print("  ❌ NÃO é o player, ignorando!")
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
	print("[InteractionZone] 🖱️ _on_click() chamado! trigger_type: ", trigger_type)
	print("  event: ", event)
	
	if trigger_type != "click":
		print("  ⏭️ trigger_type não é click: ", trigger_type)
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[InteractionZone] ✅ Clique válido, chamando _try_interact()")
		_try_interact()
	else:
		print("  ⏭️ Evento não é clique esquerdo pressionado")

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
		print("[InteractionZone] ⏭️ Cooldown ativo")
		return false
	
	# 🔥 VERIFICA DISTÂNCIA ANTES DE EMITIR O SINAL
	var player = get_node("/root/Main/Mundo/Player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist > 200:
			print("[InteractionZone] ⏭️ Player longe! (", dist, "px) - ignorando")
			return false
	
	_last_trigger_time = now
	print("[InteractionZone] 🔥 EMITINDO interacted!")
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
	
	print("[InteractionZone] set_zone_active(", active, ") - input_pickable: ", input_pickable)


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
