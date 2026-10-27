extends Camera2D
# Câmera da bruxa. Segue o player e para nas bordas do mapa usando os limites
# nativos do Camera2D (o mapa_base escreve limit_left/right ao carregar).
# A desaceleração na borda vem do próprio Godot: position_smoothing + limit_smoothed.
# Fundo e frente continuarem andando na borda é feito no mapa_base (_parallax_na_borda).

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

# ===== REFERÊNCIAS =====
@onready var player = get_parent()
var _move_tween: Tween = null

func _ready():
	original_offset = offset
	# A câmera é filha do Player, mas com top_level ela NÃO herda o movimento dele.
	# Assim mover_camera fica parada no ponto pedido; seguindo, _process copia o player.
	top_level = true
	limit_smoothed = true
	global_position = player.global_position
	reset_smoothing()

## Ponto mais próximo de p que a câmera consegue mostrar (respeita os limites).
func _dentro(p: Vector2) -> Vector2:
	var meia: Vector2 = get_viewport_rect().size * 0.5 / zoom
	var a := float(limit_left) + meia.x
	var b := float(limit_right) - meia.x
	if b >= a:
		p.x = clampf(p.x, a, b)
	var c := float(limit_top) + meia.y
	var d := float(limit_bottom) - meia.y
	if d >= c:
		p.y = clampf(p.y, c, d)
	return p

# ===== MOVER CÂMERA =====
## tempo = 0: pula na hora. tempo > 0: anda até lá em "tempo" segundos.
func mover_camera(posicao: Vector2, tempo: float = 0.0):
	is_following_player = false
	_kill_move_tween()
	# começa de onde a tela está de fato (o player pode estar além do limite)
	global_position = _dentro(global_position)
	target_position = _dentro(posicao)
	if tempo <= 0.0:
		global_position = target_position
		reset_smoothing()
	else:
		_move_tween = create_tween()
		_move_tween.tween_property(self, "global_position", target_position, tempo)

# ===== RESETAR CÂMERA =====
## Volta a seguir o player (tempo = 0: na hora).
func resetar_posicao_camera(tempo: float = 0.0):
	_kill_move_tween()
	if tempo <= 0.0:
		is_following_player = true
		global_position = player.global_position
		reset_smoothing()
	else:
		global_position = _dentro(global_position)
		_move_tween = create_tween()
		_move_tween.tween_property(self, "global_position", _dentro(player.global_position), tempo)
		_move_tween.tween_callback(func(): is_following_player = true)

# ===== TELEPORTE =====
## Volta a seguir o player e pula direto para ele, sem suavização.
func snap_to_player():
	_kill_move_tween()
	is_following_player = true
	global_position = player.global_position
	reset_smoothing()

func _kill_move_tween():
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null

# ===== TREMER CÂMERA =====
func tremer_camera(intensidade: float, velocidade: float, duracao: float):
	shake_intensity = intensidade
	shake_speed = velocidade
	shake_duration = duracao
	shake_timer = 0.0

# ===== PROCESSAMENTO =====
func _process(delta):
	if is_following_player:
		global_position = player.global_position

	if shake_duration > 0.0:
		shake_timer += delta
		if shake_timer >= shake_duration:
			shake_duration = 0.0
			shake_timer = 0.0
			shake_offset = Vector2.ZERO
			offset = original_offset
		else:
			var current_intensity = shake_intensity * (1.0 - shake_timer / shake_duration)
			shake_offset.x = randf_range(-current_intensity, current_intensity)
			shake_offset.y = randf_range(-current_intensity, current_intensity)
			offset = original_offset + shake_offset

# ===== DEBUG =====
func debug():
	print("\n=== CAMERA2D DEBUG ===")
	print("  is_following_player: ", is_following_player)
	print("  global_position: ", global_position, " | centro da tela: ", get_screen_center_position())
	print("  limites: ", limit_left, " .. ", limit_right)
	print("  offset: ", offset)
	print("======================\n")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F7:
		debug()
