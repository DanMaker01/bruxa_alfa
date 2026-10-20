# carta.gd
# Uma carta do HUD que vira entre faces. Cada face é um filho Control (tela cheia da carta):
#   "Verso"          → costas da carta (estado de repouso)
#   face_aberta      → o que o jogador abre com um toque (ex.: "Inventario", "Status")
#   face_prioridade  → aparece sozinha quando algum filho dela fica visível
#                      (ex.: "Dialogo" com a DialogBox dentro, "Opcoes" com a OptionBox)
# Filhos que não são faces (fundo, moldura...) ficam sempre visíveis.
#
# - Toque no verso → vira para face_aberta.
# - Aberta, sem nenhum toque/arraste na carta por tempo_aberta s → desvira.
#   "segurar = true" (ex.: popup do item aberto) impede de desvirar.
# - Prioridade (diálogo) ganha de tudo; quando acaba, volta para onde estava.
# - ativa = false (HUD escondido): a carta some, mas ainda aparece para o diálogo.
#
# Virada na diagonal: ao iniciar, todos os filhos vão para um Node2D "Giro" no centro
# da carta; a virada achata o Giro ao longo de um eixo inclinado (angulo_diagonal),
# como uma carta girando em torno da sua diagonal. Use face("Nome") para achar uma face.
class_name Carta
extends Control

const NADA := ""
const VERSO := "Verso"
## z absoluto na face de prioridade: acima da tela escura do diálogo (150).
## Nas outras faces a carta fica no z normal (abaixo do menu de pausa etc.).
const Z_CARTA: int = 160
## Espera antes de sair da face de prioridade (evita virar entre duas falas seguidas).
const ESPERA_VOLTAR: float = 0.2

@export var face_aberta: String = "Inventario"
@export var face_prioridade: String = "Dialogo"
## Segundos sem interação até desvirar sozinha.
@export var tempo_aberta: float = 4.0
## Duração da virada inteira (s).
@export var tempo_virar: float = 0.35
## Inclinação do eixo da virada (graus). 0 = vira na horizontal; 45 = na diagonal.
@export_range(-90.0, 90.0) var angulo_diagonal: float = 45.0

var ativa: bool = true:
	set(v):
		ativa = v
		# desativou com a carta em repouso: some na hora (sem animação)
		if not v and not _virando and _atual != face_prioridade and is_node_ready():
			_mostrar(NADA)
var segurar: bool = false:
	set(v):
		segurar = v
		_ocioso = 0.0

var _atual: String = VERSO
var _alvo_manual: String = VERSO   # VERSO ou face_aberta (escolha do jogador)
var _ocioso: float = 0.0
var _virando: bool = false
var _sem_prioridade: float = 0.0
var _giro: Node2D
var _achatar: float = 1.0          # 1 = carta aberta, ~0 = de lado (no meio da virada)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # o jogo pausa no diálogo
	_criar_giro()
	resized.connect(_ajustar_giro)
	_mostrar(VERSO if ativa else NADA)

## Põe todos os filhos num Node2D centrado na carta (Control não tem skew; Node2D tem).
func _criar_giro() -> void:
	_giro = Node2D.new()
	_giro.name = "Giro"
	var filhos := get_children()
	add_child(_giro)
	for c in filhos:
		c.reparent(_giro, false)
	_ajustar_giro()

func _ajustar_giro() -> void:
	if not _giro:
		return
	for c in _giro.get_children():
		if c is Control:
			# fora de um Control as âncoras não valem: tamanho fixo da carta, centrado no Giro
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = -size * 0.5
			c.size = size
	_aplicar_giro()

## Achata a carta ao longo do eixo inclinado: R(a) · escala(achatar, 1) · R(-a).
func _aplicar_giro() -> void:
	var a := deg_to_rad(angulo_diagonal)
	var r := Transform2D(a, Vector2.ZERO)
	var esc := Transform2D(Vector2(maxf(_achatar, 0.01), 0), Vector2(0, 1), Vector2.ZERO)
	var m := r * esc * r.affine_inverse()
	_giro.transform = Transform2D(m.x, m.y, size * 0.5)

func _set_achatar(v: float) -> void:
	_achatar = v
	_aplicar_giro()

## Uma face (ou outro filho) da carta pelo nome.
func face(nome: String) -> Node:
	return _giro.get_node_or_null(nome) if _giro else get_node_or_null(nome)

## Abre (vira para face_aberta) ou fecha (verso) por código.
func abrir() -> void:
	_alvo_manual = face_aberta
	_ocioso = 0.0

func fechar() -> void:
	_alvo_manual = VERSO

func face_atual() -> String:
	return _atual

# =============================================================================
# ESTADO
# =============================================================================
func _process(delta: float) -> void:
	if _atual == face_aberta and _alvo_manual == face_aberta and not segurar and not _virando:
		_ocioso += delta
		if _ocioso >= tempo_aberta:
			_alvo_manual = VERSO
	var alvo := _face_desejada(delta)
	if alvo != _atual and not _virando:
		_virar(alvo)

func _face_desejada(delta: float) -> String:
	if _quer_prioridade():
		_sem_prioridade = 0.0
		return face_prioridade
	if _atual == face_prioridade:
		_sem_prioridade += delta
		if _sem_prioridade < ESPERA_VOLTAR:
			return face_prioridade
	if not ativa:
		return NADA
	return _alvo_manual

func _quer_prioridade() -> bool:
	var f := face(face_prioridade)
	if f == null:
		return false
	for c in f.get_children():
		if c is CanvasItem and c.visible:
			return true
	return false

# =============================================================================
# VIRAR: achata na diagonal, troca a face, abre de novo
# =============================================================================
func _virar(alvo: String) -> void:
	_virando = true
	var tw := create_tween()
	if _atual == NADA:
		_mostrar(alvo)          # vinha escondida: só abre
		_set_achatar(0.0)
	else:
		tw.tween_method(_set_achatar, _achatar, 0.0, tempo_virar * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(_mostrar.bind(alvo))
	if alvo != NADA:
		tw.tween_method(_set_achatar, 0.0, 1.0, tempo_virar * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_callback(_set_achatar.bind(1.0))
	tw.tween_callback(_fim_virar)

func _mostrar(nome_face: String) -> void:
	_atual = nome_face
	visible = nome_face != NADA
	var prioridade := nome_face == face_prioridade
	z_as_relative = not prioridade
	z_index = Z_CARTA if prioridade else 0
	for nome in [VERSO, face_aberta, face_prioridade]:
		var n := face(nome)
		if n is CanvasItem:
			n.visible = nome == nome_face

func _fim_virar() -> void:
	_virando = false
	_ocioso = 0.0
	_set_achatar(1.0)
	# o diálogo posiciona nome/foto pela posição global: refaz com a carta já aberta
	var f := face(face_prioridade)
	if f and _atual == face_prioridade:
		for c in f.get_children():
			if c.has_method("_posicionar_falante"):
				c._posicionar_falante()

# =============================================================================
# TOQUES: qualquer toque/arraste na carta conta como interação
# =============================================================================
func _input(event: InputEvent) -> void:
	if not visible or _atual == NADA or _atual == face_prioridade:
		return
	var pos: Vector2
	if event is InputEventMouseButton and event.pressed:
		pos = event.position
	elif event is InputEventMouseMotion and event.button_mask != 0:
		pos = event.position
	elif event is InputEventScreenDrag:
		pos = event.position
	else:
		return
	if not get_global_rect().has_point(pos):
		return
	_ocioso = 0.0
	if event is InputEventMouseButton and _atual == VERSO and not _virando and ativa:
		abrir()
		get_viewport().set_input_as_handled()
