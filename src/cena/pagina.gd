# pagina.gd - VERSÃO COM DEBUG DETALHADO

extends StaticBody2D

# ===== DADOS DA PÁGINA =====
var animacao: String = "idle"
var animacao_padrao: String = "idle"   # a da página (set_animation("") volta para ela)
var direcao: String = "centro"          # "centro", "esq" ou "dir"
var passavel: bool = true
var _arte_esquerda: bool = false   # PaginaData.sprite_olha_esquerda
var trigger_type: String = "click"

# ===== REFERÊNCIAS =====
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_zone: InteractionZone = $InteractionZone

# ===== DEBUG =====
var debug_data: Dictionary = {}

func _ready():
	pass
	_debug_zone_state("_ready_INICIO")
	
	if interaction_zone:
		# CONFIGURA A ZONA (quem escuta os sinais dela agora é o evento_base
		# diretamente, via get_interaction_zone() - pagina não faz mais relay)
		interaction_zone.trigger_type = trigger_type
		pass
		_debug_zone_state("_ready_FIM")
	else:
		pass
		pass

func configure(data: PaginaData):
	"""Configura a página com os dados do PaginaData"""
	pass
	pass
	
	_debug_zone_state("configure_INICIO")
	
	# ===== CARREGA SPRITEFRAMES =====
	var frames: SpriteFrames = data.sprite_frames
	if frames:
		if animated_sprite:
			animated_sprite.sprite_frames = frames
			pass
	else:
		pass
	
	# ===== TOCA ANIMAÇÃO =====
	animacao = data.animacao
	animacao_padrao = data.animacao
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(animacao):
			animated_sprite.play(animacao)
			pass
		else:
			var animations = animated_sprite.sprite_frames.get_animation_names()
			if animations.size() > 0:
				animated_sprite.play(animations[0])
				pass
			else:
				pass
	
	# ===== ALINHAMENTO PELO PÉ =====
	# Quadros de tamanhos diferentes: o pé fica no meio, embaixo do quadro. O fundo de todos
	# fica na linha do fundo do 1º quadro da animação da página (centrado na horizontal).
	_alt_ref = tamanho_base().y / maxf(0.001, absf(animated_sprite.scale.y)) if animated_sprite else 0.0
	if animated_sprite and not animated_sprite.frame_changed.is_connected(_alinhar_quadro):
		animated_sprite.frame_changed.connect(_alinhar_quadro)
		animated_sprite.animation_changed.connect(_alinhar_quadro)
	_alinhar_quadro()

	# ===== DIREÇÃO =====
	_arte_esquerda = data.sprite_olha_esquerda
	set_direcao(PaginaData.DIRECOES[data.direcao])

	# ===== CONFIGURA COLISÃO (StaticBody2D) =====
	var colisao_pos: Vector2 = data.colisao_pos
	var colisao_scale: Vector2 = data.colisao_scale

	if collision_shape:
		collision_shape.position = Vector2(colisao_pos[0], colisao_pos[1])
		# collision_shape.scale = Vector2(colisao_scale[0], colisao_scale[1])

		# Tamanho = tamanho do sprite x escala (32x32 sem sprite).
		# Shape novo sempre: não acumula se configure() rodar de novo.
		var new_size = tamanho_base() * colisao_scale
		collision_shape.shape = RectangleShape2D.new()
		collision_shape.shape.size = new_size

		pass
	# ===== CONFIGURA INTERACTION ZONE =====
	pass

	if interaction_zone:
		# 📍 POSIÇÃO DA ÁREA
		var pos: Vector2 = data.area_pos
		interaction_zone.position = pos
		debug_data["area_pos_aplicado"] = pos
		
		# 📏 ÁREA (tamanho = tamanho do sprite x escala; 32x32 sem sprite)
		var shape_node = interaction_zone.get_node_or_null("CollisionShape2D")
		if shape_node:
			var area_size = tamanho_base() * data.area_scale
			shape_node.shape = RectangleShape2D.new()
			shape_node.shape.size = area_size
			debug_data["shape_size_final"] = area_size
		else:
			pass

		# ⚡ TRIGGER
		trigger_type = data.get_trigger()
		interaction_zone.trigger_type = trigger_type
		pass
		
		# 🔄 COOLDOWN
		interaction_zone.cooldown = data.cooldown
		pass
	
	# ===== CONFIGURA PASSAVEL =====
	passavel = data.passavel
	if collision_shape:
		collision_shape.disabled = passavel
		pass
	
	# ===== ATIVA ZONA =====
	if interaction_zone:
		interaction_zone.set_zone_active(true)
		pass
	
	if interaction_zone:
		interaction_zone.set_zone_active(true)
		pass

	_debug_zone_state("configure_FIM")
	
	pass
	pass
	pass

const TAMANHO_SEM_SPRITE := Vector2(32, 32)
var _alt_ref: float = 0.0   # altura (px da textura) do 1º quadro da animação da página

func _alinhar_quadro() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null or _alt_ref <= 0.0:
		return
	var sf := animated_sprite.sprite_frames
	var a: StringName = animated_sprite.animation
	if not sf.has_animation(a) or animated_sprite.frame >= sf.get_frame_count(a):
		return
	var tex := sf.get_frame_texture(a, animated_sprite.frame)
	if tex:
		animated_sprite.offset = Vector2(0.0, (_alt_ref - tex.get_height()) * 0.5)

## Tamanho base da colisão e da área: o 1º quadro da animação atual
## (x escala do sprite). Sem sprite: 32x32.
func tamanho_base() -> Vector2:
	if animated_sprite and animated_sprite.sprite_frames:
		var anim: StringName = animated_sprite.animation
		var sf := animated_sprite.sprite_frames
		if sf.has_animation(anim) and sf.get_frame_count(anim) > 0:
			var tex := sf.get_frame_texture(anim, 0)
			if tex:
				return tex.get_size() * animated_sprite.scale.abs()
	return TAMANHO_SEM_SPRITE

# ===== MÉTODOS PÚBLICOS =====

## Troca a animação da página (temporário). "" volta para a animação da página.
func set_animation(anim_name: String) -> bool:
	if anim_name == "":
		anim_name = animacao_padrao
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		animacao = anim_name
		pass
		return true
	return false

## Para onde o evento olha. A arte é desenhada olhando para a direita (como a bruxa):
## "esq" espelha; "dir" e "centro" deixam como está.
func set_direcao(nova: String) -> void:
	direcao = nova
	if animated_sprite:
		# arte olhando para a direita: "esq" espelha. Arte olhando para a esquerda: "dir" espelha.
		if _arte_esquerda:
			animated_sprite.flip_h = nova == "dir"
		else:
			animated_sprite.flip_h = nova == "esq"

func get_direcao() -> String:
	return direcao

func set_passavel(value: bool):
	passavel = value
	if collision_shape:
		collision_shape.disabled = passavel
		pass

# pagina.gd - Em set_active()

func set_active(active: bool):
	visible = active
	
	if collision_shape:
		collision_shape.disabled = passavel if active else true
		pass
	else:
		pass

	if interaction_zone:
		interaction_zone.set_zone_active(active)
		# 🔥 GARANTE QUE input_pickable FICA TRUE PARA CLICK
		if trigger_type == "click":
			interaction_zone.input_pickable = true
			pass

func is_passavel() -> bool:
	return passavel

func get_animation() -> String:
	return animacao

func get_trigger() -> String:
	return trigger_type

func is_player_near() -> bool:
	if interaction_zone:
		return interaction_zone.player_near
	return false

func get_interaction_zone() -> InteractionZone:
	return interaction_zone

# ===== FUNÇÕES DE DEBUG =====

func _debug_zone_state(label: String):
	"""Debug do estado da zona"""
	pass
	if interaction_zone:
		# print("  ✅ interaction_zone existe")
		# print("  position: ", interaction_zone.position)
		# print("  scale: ", interaction_zone.scale)
		# print("  trigger_type: ", interaction_zone.trigger_type)
		# print("  cooldown: ", interaction_zone.cooldown)
		# print("  monitoring: ", interaction_zone.monitoring)
		# print("  monitorable: ", interaction_zone.monitorable)
		# print("  input_pickable: ", interaction_zone.input_pickable)
		# print("  player_near: ", interaction_zone.player_near)
		
		var shape = interaction_zone.get_node_or_null("CollisionShape2D")
		if shape:
			pass
			if shape.shape:
				pass
				if shape.shape is RectangleShape2D:
					pass
			else:
				pass
		else:
			pass
	else:
		pass

func _list_children() -> String:
	"""Lista os filhos do nó"""
	var names = []
	for child in get_children():
		names.append(child.name + " (" + child.get_class() + ")")
	return ", ".join(names)

func debug():
	pass
	# print("  Nome: ", name)
	# print("  Animação: ", animacao)
	# print("  Passável: ", passavel)
	# print("  Trigger: ", trigger_type)
	# print("  Visible: ", visible)
	# print("  Player near: ", is_player_near())
	# print("  Debug data: ", debug_data)
	# if interaction_zone:
	# 	print("  Zone trigger: ", interaction_zone.trigger_type)
	# 	print("  Zone cooldown: ", interaction_zone.cooldown)
	# 	print("  Zone monitoring: ", interaction_zone.monitoring)
	# 	print("  Zone player_near: ", interaction_zone.player_near)
	# 	print("  Zone position: ", interaction_zone.position)
	# 	print("  Zone scale: ", interaction_zone.scale)
	pass

func debug_area():
	pass
	# print("  Nome: ", name)
	# print("  Visible: ", visible)
	# print("  Trigger: ", trigger_type)
	# print("  Debug data: ", debug_data)
	# if interaction_zone:
	# 	print("  Zone trigger: ", interaction_zone.trigger_type)
	# 	print("  Zone monitoring: ", interaction_zone.monitoring)
	# 	print("  Zone monitorable: ", interaction_zone.monitorable)
	# 	print("  Zone input_pickable: ", interaction_zone.input_pickable)
	# 	print("  Zone position: ", interaction_zone.position)
	# 	print("  Zone scale: ", interaction_zone.scale)
	# 	print("  Zone player_near: ", interaction_zone.player_near)
	pass
