extends Camera2D

# ===== ESTADO =====
var is_following_player: bool = true
var target_position: Vector2 = Vector2.ZERO

# ===== SHAKE =====
var shake_intensity: float = 0.0
var shake_speed: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var original_offset: Vector2 = Vector2.ZERO

# ===== BORDA SUAVE =====
## Perto da borda do mapa a câmera desacelera em vez de bater no limite: nos últimos
## BORDA_SUAVE px ela vai cada vez mais devagar e só encosta na borda bem no fim.
## (O Camera2D trava seco em limit_left/right; aqui esses limites são lidos e trocados
## por esta curva, então o mapa e o parallax nunca param de repente.)
## 0 = para seco na borda (as CamadaParallax com continuar_na_borda seguem andando).
const BORDA_SUAVE: float = 200.0
const SEM_LIMITE: int = 10000000
var _lim_esq: float = -INF
var _lim_dir: float = INF

# ===== REFERÊNCIAS =====
@onready var player = get_parent()
var _move_tween: Tween = null

func _ready():
	original_offset = offset
	# 🔥 A câmera é filha do Player, mas com top_level ela NÃO herda o movimento dele.
	# Assim mover_camera fica realmente parada no ponto pedido; quando
	# is_following_player = true, _process copia a posição do player.
	top_level = true
	global_position = player.global_position
	reset_smoothing()
	print("[Camera2D] Inicializada! offset original: ", original_offset)

# ===== MOVER CÂMERA =====
func mover_camera(posicao: Vector2, velocidade: float = 0.0):
	"""
	Move a câmera para uma posição fixa.
	Se velocidade = 0, teleporta instantaneamente.
	Se velocidade > 0, move suavemente.
	"""
	print("[Camera2D] 🎥 mover_camera para: ", posicao, " | velocidade: ", velocidade)
	
	is_following_player = false
	target_position = posicao
	_kill_move_tween()
	
	if velocidade <= 0.0:
		# 🔥 TELEPORTE INSTANTÂNEO
		global_position = target_position
		print("[Camera2D] ✅ Câmera movida instantaneamente para: ", global_position)
	else:
		# 🔥 MOVIMENTO SUAVE
		var tween = create_tween()
		_move_tween = tween
		tween.tween_property(self, "global_position", target_position, velocidade)
		tween.tween_callback(func():
			print("[Camera2D] ✅ Câmera movida suavemente para: ", global_position)
		)

# ===== RESETAR CÂMERA =====
func resetar_posicao_camera(velocidade: float = 0.0):
	"""
	Volta a câmera a seguir o player.
	Se velocidade = 0, volta instantaneamente.
	Se velocidade > 0, move suavemente até a posição do player.
	"""
	print("[Camera2D] 🎥 resetar_posicao_camera | velocidade: ", velocidade)
	_kill_move_tween()
	
	if velocidade <= 0.0:
		# 🔥 VOLTA INSTANTÂNEA
		is_following_player = true
		global_position = player.global_position
		print("[Camera2D] ✅ Câmera resetada (instantâneo) para: ", global_position)
	else:
		# 🔥 VOLTA SUAVE
		var tween = create_tween()
		_move_tween = tween
		tween.tween_property(self, "global_position", player.global_position, velocidade)
		tween.tween_callback(func():
			is_following_player = true
			print("[Camera2D] ✅ Câmera resetada (suave) para: ", global_position)
		)

# ===== TELEPORTE =====
func snap_to_player():
	"""Volta a seguir o player e pula direto para ele, sem suavização (usado no teleporte)."""
	_kill_move_tween()
	is_following_player = true
	_ler_limites()
	global_position = Vector2(_x_suave(player.global_position.x), player.global_position.y)
	reset_smoothing()

func _kill_move_tween():
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null

# ===== TREMER CÂMERA =====
func tremer_camera(intensidade: float, velocidade: float, duracao: float):
	"""
	Faz a câmera tremer.
	intensidade: magnitude do tremor (px)
	velocidade: frequência do tremor
	duracao: tempo total do tremor (segundos)
	"""
	print("[Camera2D] 🎥 tremer_camera | intensidade: ", intensidade, " | velocidade: ", velocidade, " | duracao: ", duracao)
	
	shake_intensity = intensidade
	shake_speed = velocidade
	shake_duration = duracao
	shake_timer = 0.0

# ===== PROCESSAMENTO =====
func _process(delta):
	# 🔥 SE ESTIVER SEGUINDO O PLAYER
	if is_following_player:
		global_position = Vector2(_x_suave(player.global_position.x), player.global_position.y)
	
	# 🔥 SHAKE
	if shake_duration > 0.0:
		shake_timer += delta
		
		if shake_timer >= shake_duration:
			# 🔥 TERMINA O SHAKE
			shake_duration = 0.0
			shake_timer = 0.0
			shake_offset = Vector2.ZERO
			offset = original_offset
			print("[Camera2D] ✅ Shake finalizado")
		else:
			# 🔥 APLICA O SHAKE
			var progress = shake_timer / shake_duration
			var current_intensity = shake_intensity * (1.0 - progress)  # Diminui com o tempo
			
			shake_offset.x = randf_range(-current_intensity, current_intensity)
			shake_offset.y = randf_range(-current_intensity, current_intensity)
			
			offset = original_offset + shake_offset

## O mapa_base escreve limit_left/right ao carregar: guarda e solta o limite horizontal.
func _ler_limites() -> void:
	if limit_left > -SEM_LIMITE:
		_lim_esq = float(limit_left)
		limit_left = -SEM_LIMITE
	if limit_right < SEM_LIMITE:
		_lim_dir = float(limit_right)
		limit_right = SEM_LIMITE

## x do centro da câmera: igual ao do player no meio do mapa; perto das bordas,
## aproxima a borda de forma exponencial (sem quina, sem tranco).
func _x_suave(x: float) -> float:
	_ler_limites()
	var meia: float = get_viewport_rect().size.x * 0.5 / zoom.x
	var a: float = _lim_esq + meia
	var b: float = _lim_dir - meia
	if not is_finite(a) or not is_finite(b) or b <= a:
		return x
	var z: float = minf(BORDA_SUAVE, (b - a) * 0.5)
	if z <= 0.0:
		return clampf(x, a, b)
	if x < a + z:
		return a + z * exp((x - (a + z)) / z)
	if x > b - z:
		return b - z * exp(((b - z) - x) / z)
	return x

# ===== DEBUG =====
func debug():
	print("\n=== CAMERA2D DEBUG ===")
	print("  is_following_player: ", is_following_player)
	print("  global_position: ", global_position)
	print("  target_position: ", target_position)
	print("  offset: ", offset)
	print("  original_offset: ", original_offset)
	print("  shake_duration: ", shake_duration)
	print("  shake_timer: ", shake_timer)
	print("  shake_intensity: ", shake_intensity)
	print("======================\n")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F7:
				debug()
