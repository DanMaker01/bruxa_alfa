extends Camera2D
# Câmera da bruxa. Segue o player e para nas bordas do mapa usando os limites
# nativos do Camera2D (o mapa_base escreve limit_left/right ao carregar).
# A desaceleração na borda vem do próprio Godot: position_smoothing + limit_smoothed.
# Fundo e frente continuarem andando na borda é feito no mapa_base (_parallax_na_borda).

## Desligado por enquanto (readme: "PROBLEMA" da câmera nas bordas). true = câmera
## desliza até a bruxa e desacelera nas bordas; false = segue seco e para seco.
const SUAVIZAR := false
## Freio suave na borda (px): nos últimos BORDA_SUAVE px antes de a câmera chegar no limite,
## ela vai desacelerando e só para de vez quando a bruxa chega na ponta do mapa.
## É uma conta direta da posição da bruxa (sem tempo), então nunca "se ajeita" ao entrar no mapa.
## Todas as camadas de parallax seguem a câmera, então também freiam juntas e nunca mostram
## área fora do mapa. 0 = desliga (para seco). Mínimo útil: metade da largura da tela / 2.
const BORDA_SUAVE: float = 0.0   # desligado: mexia na velocidade e quebrava o parallax

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
	position_smoothing_enabled = SUAVIZAR
	limit_smoothed = SUAVIZAR
	global_position = player.global_position
	reset_smoothing()

## X da câmera para a bruxa em x = p: igual a p no meio do mapa; perto das pontas desacelera
## (curva c·t² + d·t³) até parar no limite quando a bruxa chega na ponta.
func _x_suave(p: float) -> float:
	var meia: float = get_viewport_rect().size.x * 0.5 / zoom.x
	var a := float(limit_left) + meia     # centro da câmera encostada na esquerda
	var b := float(limit_right) - meia    # ... e na direita
	if b < a:
		return (a + b) * 0.5
	var m: float = maxf(BORDA_SUAVE, meia * 0.5)
	m = minf(m, (b - a) * 0.5)
	if BORDA_SUAVE <= 0.0 or m <= 0.0:
		return clampf(p, a, b)
	if p < a + m:
		return a + m - _curva(a + m - p, m, meia)
	if p > b - m:
		return b - m + _curva(p - (b - m), m, meia)
	return p

## Quanto a câmera anda (0..m) quando a bruxa anda "dist" a partir do começo da faixa de freio.
## A faixa da bruxa tem m + meia px; a da câmera, m. Encaixa com inclinação 1 no começo e 0 na ponta.
static func _curva(dist: float, m: float, meia: float) -> float:
	var L := m + meia
	var u := clampf(1.0 - dist / L, 0.0, 1.0)   # 1 no começo da faixa, 0 na ponta do mapa
	var r := minf(L / m, 3.0)                   # inclinação no começo (> 3 faria a câmera voltar; mapa pequeno)
	var c := 3.0 - r
	var d := r - 2.0
	var g := c * u * u + d * u * u * u          # g(1) = 1, g'(1) = r, g(0) = g'(0) = 0
	return m * (1.0 - g)

## Correndo, a câmera vai um pouco à frente da bruxa (mais tempo para reagir).
const ADIANTE_CORRIDA: float = 70.0    # px à frente
const VEL_ADIANTE: float = 130.0       # px/s com que a câmera vai e volta
var _adiante: float = 0.0
var _lado: float = 1.0

func _atualizar_adiante(delta: float) -> void:
	var correndo: bool = player.get("correndo") == true
	if absf(player.velocity.x) > 5.0:
		_lado = signf(player.velocity.x)
	var alvo: float = _lado * ADIANTE_CORRIDA if correndo else 0.0
	_adiante = move_toward(_adiante, alvo, VEL_ADIANTE * delta)

## Onde a câmera fica quando segue a bruxa.
func _alvo_bruxa() -> Vector2:
	return Vector2(_x_suave(player.global_position.x + _adiante), player.global_position.y)

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
		global_position = _alvo_bruxa()
		reset_smoothing()
	else:
		global_position = _dentro(global_position)
		_move_tween = create_tween()
		_move_tween.tween_property(self, "global_position", _dentro(_alvo_bruxa()), tempo)
		_move_tween.tween_callback(func(): is_following_player = true)

# ===== TELEPORTE =====
## Volta a seguir o player e pula direto para ele, sem suavização.
func snap_to_player():
	_kill_move_tween()
	_adiante = 0.0
	is_following_player = true
	global_position = _alvo_bruxa()
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
	_atualizar_adiante(delta)
	if is_following_player:
		global_position = _alvo_bruxa()

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
