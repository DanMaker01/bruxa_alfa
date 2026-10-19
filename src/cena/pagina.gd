# pagina.gd - VERSÃO COM DEBUG DETALHADO

extends StaticBody2D

# ===== DADOS DA PÁGINA =====
var animacao: String = "idle"
var animacao_padrao: String = "idle"   # a da página (set_animation("") volta para ela)
var direcao: String = "centro"          # "centro", "esq" ou "dir"
var passavel: bool = true
var trigger_type: String = "click"

# ===== REFERÊNCIAS =====
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_zone: InteractionZone = $InteractionZone

# ===== DEBUG =====
var debug_data: Dictionary = {}

func _ready():
	print("\n🔍 [Pagina] _ready() CHAMADO para: ", name)
	_debug_zone_state("_ready_INICIO")
	
	if interaction_zone:
		# CONFIGURA A ZONA (quem escuta os sinais dela agora é o evento_base
		# diretamente, via get_interaction_zone() - pagina não faz mais relay)
		interaction_zone.trigger_type = trigger_type
		print("[Pagina] ✅ InteractionZone configurada!")
		_debug_zone_state("_ready_FIM")
	else:
		print("[Pagina] ❌ InteractionZone NÃO encontrada!")
		print("[Pagina]   Filhos disponíveis: ", _list_children())

func configure(data: PaginaData):
	"""Configura a página com os dados do PaginaData"""
	print("\n🔍 [Pagina] configure() CHAMADO para: ", name)
	print("[Pagina] Dados recebidos: ", data)
	
	_debug_zone_state("configure_INICIO")
	
	# ===== CARREGA SPRITEFRAMES =====
	var frames: SpriteFrames = data.sprite_frames
	if frames:
		if animated_sprite:
			animated_sprite.sprite_frames = frames
			print("[Pagina] ✅ SpriteFrames: ", frames.resource_path)
	else:
		print("[Pagina] ⚠️ Página sem sprite_frames")
	
	# ===== TOCA ANIMAÇÃO =====
	animacao = data.animacao
	animacao_padrao = data.animacao
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(animacao):
			animated_sprite.play(animacao)
			print("[Pagina] ✅ Animação: ", animacao)
		else:
			var animations = animated_sprite.sprite_frames.get_animation_names()
			if animations.size() > 0:
				animated_sprite.play(animations[0])
				print("[Pagina] ⚠️ Animação '", animacao, "' não encontrada. Usando: ", animations[0])
			else:
				print("[Pagina] ❌ Nenhuma animação disponível!")
	
	# ===== DIREÇÃO =====
	set_direcao(PaginaData.DIRECOES[data.direcao])

	# ===== CONFIGURA COLISÃO (StaticBody2D) =====
	var colisao_pos: Vector2 = data.colisao_pos
	var colisao_scale: Vector2 = data.colisao_scale

	if collision_shape:
		collision_shape.position = Vector2(colisao_pos[0], colisao_pos[1])
		# collision_shape.scale = Vector2(colisao_scale[0], colisao_scale[1])

		# 🔥 CRIA O SHAPE SE NÃO EXISTIR
		if collision_shape.shape == null:
			collision_shape.shape = RectangleShape2D.new()
			collision_shape.shape.size = Vector2(10, 10)

		# 🔥 REDIMENSIONA O SHAPE BASEADO NA ESCALA
		var base_size = collision_shape.shape.size
		var new_size = Vector2(base_size.x * colisao_scale[0], base_size.y * colisao_scale[1])
		collision_shape.shape.size = new_size

		print("[Pagina] ✅ Colisão StaticBody2D: pos=", colisao_pos, " scale=", colisao_scale, " shape=", new_size)
	# ===== CONFIGURA INTERACTION ZONE =====
	print("\n🔍 [Pagina] Configurando INTERACTION ZONE...")

	if interaction_zone:
		# 📍 POSIÇÃO DA ÁREA
		var pos: Vector2 = data.area_pos
		interaction_zone.position = pos
		debug_data["area_pos_aplicado"] = pos
		
		# 📏 ESCALA DA ÁREA (tamanho = 10 px x escala)
		if true:
			var scale_factor: Vector2 = data.area_scale
			# interaction_zone.scale = scale_factor
			print("[Pagina] ✅ Área ESCALA aplicada: ", scale_factor)
			debug_data["area_scale_aplicado"] = scale_factor
			
			# 🔥 REDIMENSIONA O SHAPE BASEADO NA ESCALA
			var shape_node = interaction_zone.get_node_or_null("CollisionShape2D")
			if shape_node:
				# 🔥 SE O SHAPE FOR NULL, CRIA UM
				if shape_node.shape == null:
					shape_node.shape = RectangleShape2D.new()
					shape_node.shape.size = Vector2(10, 10)  # TAMANHO BASE
					print("[Pagina] ✅ CollisionShape2D criado")
				
				# REDIMENSIONA O SHAPE
				var base_size = shape_node.shape.size
				var new_size = Vector2(base_size.x * scale_factor.x, base_size.y * scale_factor.y)
				shape_node.shape.size = new_size
				print("[Pagina] ✅ Shape redimensionado: ", base_size, " -> ", new_size)
				debug_data["shape_size_final"] = new_size
			else:
				print("[Pagina] ⚠️ CollisionShape2D não encontrado!")
		
		# ⚡ TRIGGER
		trigger_type = data.get_trigger()
		interaction_zone.trigger_type = trigger_type
		print("[Pagina] ✅ Trigger aplicado: ", trigger_type)
		
		# 🔄 COOLDOWN
		interaction_zone.cooldown = data.cooldown
		print("[Pagina] ✅ Cooldown aplicado: ", interaction_zone.cooldown)
	
	# ===== CONFIGURA PASSAVEL =====
	passavel = data.passavel
	if collision_shape:
		collision_shape.disabled = passavel
		print("[Pagina] ✅ passavel: ", passavel)
	
	# ===== ATIVA ZONA =====
	if interaction_zone:
		interaction_zone.set_zone_active(true)
		print("[Pagina] ✅ Zona ativada (monitoring, monitorable, input_pickable)")
	
	if interaction_zone:
		interaction_zone.set_zone_active(true)
		print("[pagina] zona ativada com input_pickable=true")

	_debug_zone_state("configure_FIM")
	
	print("\n🔍 [Pagina] configure() FINALIZADO para: ", name)
	print("[Pagina] Dados debug: ", debug_data)
	print("=".repeat(50))

# ===== MÉTODOS PÚBLICOS =====

## Troca a animação da página (temporário). "" volta para a animação da página.
func set_animation(anim_name: String) -> bool:
	if anim_name == "":
		anim_name = animacao_padrao
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		animacao = anim_name
		print("[Pagina] Animação alterada: ", anim_name)
		return true
	return false

## Para onde o evento olha. A arte é desenhada olhando para a direita (como a bruxa):
## "esq" espelha; "dir" e "centro" deixam como está.
func set_direcao(nova: String) -> void:
	direcao = nova
	if animated_sprite:
		animated_sprite.flip_h = nova == "esq"

func get_direcao() -> String:
	return direcao

func set_passavel(value: bool):
	passavel = value
	if collision_shape:
		collision_shape.disabled = passavel
		print("[Pagina] passavel alterado para ", passavel)

# pagina.gd - Em set_active()

func set_active(active: bool):
	visible = active
	
	if collision_shape:
		collision_shape.disabled = passavel if active else true
		print("[Pagina] set_active(", active, ") - passavel: ", passavel, " - collision.disabled: ", collision_shape.disabled)	
	else:
		print("  ❌ shape é NULL!")

	if interaction_zone:
		interaction_zone.set_zone_active(active)
		# 🔥 GARANTE QUE input_pickable FICA TRUE PARA CLICK
		if trigger_type == "click":
			interaction_zone.input_pickable = true
			print("[Pagina] set_active() - input_pickable forçado para true")

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
	print("\n🔍 [DEBUG ZONE] ", label)
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
			print("  CollisionShape2D existe: ", shape.name)
			if shape.shape:
				print("	shape tipo: ", shape.shape.get_class())
				if shape.shape is RectangleShape2D:
					print("	size: ", shape.shape.size)
			else:
				print("	❌ shape é NULL!")
		else:
			print("  ❌ CollisionShape2D NÃO encontrado!")
	else:
		print("  ❌ interaction_zone é NULL!")

func _list_children() -> String:
	"""Lista os filhos do nó"""
	var names = []
	for child in get_children():
		names.append(child.name + " (" + child.get_class() + ")")
	return ", ".join(names)

func debug():
	print("\n=== PAGINA DEBUG ===")
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
	print("=====================\n")

func debug_area():
	print("\n=== PAGINA DEBUG ÁREA ===")
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
	print("========================\n")
