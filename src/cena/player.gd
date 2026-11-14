# player.gd - VERSÃO COM ACELERAÇÃO
extends CharacterBody2D

# ===== CONSTANTES DE MOVIMENTO =====
const MAX_SPEED: float = 200.0		# Velocidade máxima
const ACCELERATION: float = 1000.0	 # Aceleração (px/s²)
const FRICTION: float = 600.0		 # Desaceleração (px/s²)
const FLIP_THRESHOLD: float = 0.5
## Multiplica velocidade e aceleração (1 = normal; o menu de debug usa 2).
var multiplicador_velocidade: float = 1.0
## Faixa de x onde a bruxa pode andar (o mapa_base escreve; infinito = sem limite).
## Fora dela pode voltar para dentro, mas não ir mais para fora.
var limite_x: Vector2 = Vector2(-INF, INF)

func velocidade_max() -> float:
	return MAX_SPEED * multiplicador_velocidade * (CORRIDA if correndo else 1.0)

# ===== CORRIDA / DASH =====
# Toque e, no 2º toque, segurar (InputManager): dash no início e segue correndo até parar.
const CORRIDA: float = 1.8          # velocidade da corrida (× andar)
const DASH: float = 2.8             # impulso do dash (× andar), cai até a corrida
const SOM_DASH := "dash"            # res://audio/se/dash.mp3 (toca se existir)
var correndo: bool = false

# ===== ANIMAÇÕES (sprites de tamanhos diferentes) =====
# Regra única para desenhar: o PÉ fica no MEIO, EMBAIXO do quadro (olhando para a direita).
# Qualquer largura ou altura funciona sem configurar nada: o código alinha o fundo de
# todos os quadros na mesma linha e centraliza na horizontal. A colisão nunca muda.
# Cada animação: arquivo (%02d = quadros 01, 02, 03... até faltar), quadros por segundo, loop.
const ANIMACOES := {
	"parado": {"arquivo": "res://assets/game_player/player_parado.png", "fps": 0.0, "loop": true},
	"correr": {"arquivo": "res://assets/game_player/player_correndo%02d.png", "fps": 10.0, "loop": true},
	"dash": {"arquivo": "res://assets/game_player/player_dash%02d.png", "fps": 12.0, "loop": false},
}
var _anims: Dictionary = {}     # nome -> {"quadros": [Texture2D], "fps", "loop"}
var _anim: String = ""
var _t_anim: float = 0.0
var _alt_ref: float = 0.0       # altura do parado: o fundo dos quadros fica onde está o dele
## Animação pedida por um evento (comando Animação). "" = automática (parado/correr).
var animacao_evento: String = ""

## Comando Animação: fixa uma animação ("" volta ao automático). false = não existe.
func animacao_por_evento(nome: String) -> bool:
	if nome != "" and not _anims.has(nome):
		return false
	animacao_evento = nome
	_anim = ""   # recomeça
	return true

func _carregar_animacoes() -> void:
	_anims.clear()
	for nome in ANIMACOES:
		var cfg: Dictionary = ANIMACOES[nome]
		var arq: String = cfg["arquivo"]
		var quadros: Array = []
		if "%" in arq:
			for k in range(1, 100):
				if not ResourceLoader.exists(arq % k):
					break
				quadros.append(load(arq % k))
		elif ResourceLoader.exists(arq):
			quadros.append(load(arq))
		if not quadros.is_empty():
			_anims[nome] = {"quadros": quadros, "fps": cfg["fps"], "loop": cfg["loop"]}
	if _anims.has("parado"):
		_alt_ref = _anims["parado"]["quadros"][0].get_height()
	elif sprite and sprite.texture:
		_alt_ref = sprite.texture.get_height()
	tocar("parado")

## Troca de animação (não reinicia se já é a atual). Sem os sprites dela, nada muda.
func tocar(nome: String) -> bool:
	if not _anims.has(nome):
		return false
	if nome != _anim:
		_anim = nome
		_t_anim = 0.0
	return true

func iniciar_dash(direcao: int) -> void:
	if direcao == 0:
		return
	correndo = true
	velocity.x = direcao * MAX_SPEED * multiplicador_velocidade * DASH
	_anim = ""   # recomeça a animação
	# poeira no chão onde ela estava (o pé fica no fundo do desenho do parado)
	PoeiraDash.soltar(get_parent(), global_position + Vector2(0, _alt_ref * 0.5), direcao)
	if ResourceLoader.exists("res://audio/se/%s.mp3" % SOM_DASH) and game_manager:
		var audio = game_manager.get_node_or_null("AudioManager")
		if audio:
			audio.play_se(SOM_DASH, 0.8, 0.05)
	if not tocar("dash"):
		tocar("correr")   # sem sprite de dash: vai direto para a corrida

func parar_corrida() -> void:
	correndo = false

## A cada frame: escolhe a animação e o quadro, e alinha o desenho pelo pé.
func _atualizar_sprite(delta: float) -> void:
	if sprite == null or _anims.is_empty():
		return
	if animacao_evento != "":
		tocar(animacao_evento)
	elif not correndo:
		tocar("parado")
	elif _anim == "parado" or _anim == "":
		tocar("correr")
	var a: Dictionary = _anims.get(_anim, {})
	if a.is_empty():
		return
	_t_anim += delta
	var n: int = a["quadros"].size()
	var i: int = int(_t_anim * float(a["fps"])) if float(a["fps"]) > 0.0 else 0
	if i >= n and not a["loop"]:
		if _anim == "dash" and correndo and tocar("correr"):
			_atualizar_sprite(0.0)
			return
		i = n - 1
	var tex: Texture2D = a["quadros"][i % n]
	if sprite.texture != tex:
		sprite.texture = tex
	# centrado na horizontal; fundo na mesma linha do fundo do parado
	sprite.offset = Vector2(0.0, (_alt_ref - tex.get_height()) * 0.5)

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
## Comando "Travar direção": andando, a bruxa não vira para o lado do movimento.
var direcao_travada: bool = false

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
	_carregar_animacoes()
	print("[Player] ===== INICIANDO =====")
	if zone:
		print("[Player] ✅ InteractionZone própria pronta (", zone.name, ")")
	else:
		print("[Player] ❌ InteractionZone NÃO encontrada!")

## Andando por um comando Mover com velocidade fixa (escolta, cutscene)?
func _anda_por_comando() -> bool:
	var im = game_manager.get_input_manager() if game_manager and game_manager.has_method("get_input_manager") else null
	return im != null and im.has_method("velocidade_fixa_ativa") and im.velocidade_fixa_ativa()

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
		elif _anda_por_comando():
			pass   # Mover com velocidade fixa: o InputManager manda na velocidade (sem fricção, senão a bruxa atrasa)
		else:
			# Vem do InputManager (clique), aplica fricção
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
			if abs(velocity.x) < 0.1:
				velocity.x = 0
	
	# 3. APLICA O MOVIMENTO
	var x_antes: float = global_position.x
	move_and_slide()
	_respeitar_limite(x_antes)
	
	#DEBUG, saber com quem colidiu
	# for i in get_slide_collision_count():
		# var collision = get_slide_collision(i)
		# print("[Player] Colidiu com: ", collision.get_collider().name)
	
	# 4. ATUALIZA A ANIMAÇÃO
	_update_animation()
	_atualizar_sprite(delta)

# 🔥 MÉTODO CHAMADO PELO INPUT MANAGER (clique)
func set_movement_direction(direction: int) -> void:
	"""Define a direção do movimento (usado pelo InputManager)"""
	movement_direction = direction
	
	# Atualiza o flip do sprite imediatamente
	if sprite and not direcao_travada:
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
	if sprite and not direcao_travada:
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
	parar_corrida()
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

## Não deixa passar de limite_x (se já estava fora, só não vai mais para fora).
func _respeitar_limite(x_antes: float) -> void:
	var piso: float = minf(x_antes, limite_x.x)
	var teto: float = maxf(x_antes, limite_x.y)
	if global_position.x < piso:
		global_position.x = piso
		velocity.x = 0.0
	elif global_position.x > teto:
		global_position.x = teto
		velocity.x = 0.0
