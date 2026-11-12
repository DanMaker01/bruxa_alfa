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
## Se vem outro diálogo logo em seguida (Interpreter.dialogo_a_seguir), espera até isto.
const ESPERA_MAX_DIALOGO: float = 1.5

@export var face_aberta: String = "Inventario"
@export var face_prioridade: String = "Dialogo"
## Segundos sem interação até desvirar sozinha.
@export var tempo_aberta: float = 4.0
## Duração da virada inteira (s).
@export var tempo_virar: float = 0.35
## Inclinação do eixo da virada (graus). 0 = vira na horizontal; 45 = na diagonal.
@export_range(-90.0, 90.0) var angulo_diagonal: float = 45.0
## Sorteia um jeito de virar a cada virada (no mesmo tempo total):
##   eixo: diagonal (CHANCE_DIAGONAL) ou vertical (achata na largura)
##   voltas: 1, ou bem raro N_VOLTAS (CHANCE_N_VOLTAS)
@export var variar_virada: bool = true
const CHANCE_DIAGONAL: float = 0.8
const CHANCE_N_VOLTAS: float = 1.0 / 40.0   # (1/40 em inteiros dá 0: nunca girava)
const N_VOLTAS: int = 2

var ativa: bool = true:
	set(v):
		ativa = v
		# desativou com a carta em repouso: some na hora (sem animação)
		if not v and not _virando and _atual != face_prioridade and is_node_ready():
			_mostrar(NADA)
## z absoluto forçado (ex.: por cima da janela da poção). -1 = comportamento normal.
var z_forcado: int = -1:
	set(v):
		z_forcado = v
		if v >= 0:
			z_as_relative = false
			z_index = v
		else:
			var prio: bool = _atual == face_prioridade
			z_as_relative = not prio
			z_index = Z_CARTA if prio else 0
## false: toque não abre (a carta só vira por abrir()/fechar()).
var interativa: bool = true
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
var _ang_virada: float = 45.0      # eixo da virada atual (sorteado)


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
	var a := deg_to_rad(_ang_virada if _virando else angulo_diagonal)
	var r := Transform2D(a, Vector2.ZERO)
	var esc := Transform2D(Vector2(maxf(_achatar, 0.01), 0), Vector2(0, 1), Vector2.ZERO)
	var m := r * esc * r.affine_inverse()
	_giro.transform = Transform2D(m.x, m.y, size * 0.5)

func _set_achatar(v: float) -> void:
	_achatar = v
	_aplicar_giro()

# =============================================================================
# CARTA PRONTA (para reaproveitar fora do HUD)
# =============================================================================
const SPRITE_CARTA := "res://assets/ui/hud_frame2.png"
const SCRIPT_PENTAGRAMA := "res://src/ui/pentagrama_verso.gd"
const COR_FUNDO := Color(0.1, 0.1, 0.15, 1)

## Monta uma carta igual às do HUD, por código: fundo, verso (pentagrama + título),
## a face "Frente" (ponha o conteúdo em carta.face("Frente")) e o sprite da carta por cima.
## Por padrão não abre com toque nem desvira sozinha (controle com abrir()/fechar()).
## Ex.: var c := Carta.criar(Vector2(300, 400), "Poção"); add_child(c); c.abrir()
static func criar(tam: Vector2, titulo_verso: String = "", interativa: bool = false) -> Carta:
	var c := Carta.new()
	c.face_aberta = "Frente"
	c.face_prioridade = "Dialogo"   # vazia: nunca aparece
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = tam
	c.interativa = interativa
	c.segurar = not interativa
	var fundo := ColorRect.new()
	fundo.name = "Fundo"
	fundo.color = COR_FUNDO
	var verso := Control.new()
	verso.name = "Verso"
	verso.z_index = 1
	var simbolo := Control.new()
	simbolo.name = "Simbolo"
	simbolo.set_script(load(SCRIPT_PENTAGRAMA))
	simbolo.set("raio_rel", 0.28)
	simbolo.set("giro_graus_s", 1.0)
	simbolo.z_index = 2
	simbolo.size = tam
	simbolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	verso.add_child(simbolo)
	if titulo_verso != "":
		var tit := Label.new()
		tit.name = "Titulo"
		tit.text = titulo_verso
		tit.modulate.a = 0.6
		tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tit.add_theme_font_size_override("font_size", 24)
		tit.position = Vector2(0, tam.y - minf(96.0, tam.y * 0.3))
		tit.size = Vector2(tam.x, 40)
		tit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		verso.add_child(tit)
	var frente := Control.new()
	frente.name = "Frente"
	frente.z_index = 1
	frente.visible = false
	var dialogo := Control.new()
	dialogo.name = "Dialogo"
	dialogo.visible = false
	var moldura := TextureRect.new()
	moldura.name = "Moldura"
	moldura.texture = load(SPRITE_CARTA) if ResourceLoader.exists(SPRITE_CARTA) else null
	moldura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moldura.stretch_mode = TextureRect.STRETCH_SCALE
	moldura.z_index = 0   # o sprite é opaco: fica atrás (frente e verso em z 1)
	for n in [fundo, verso, frente, dialogo, moldura]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.size = tam
		c.add_child(n)
	return c

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
		if _sem_prioridade < ESPERA_MAX_DIALOGO and _vem_dialogo():
			return face_prioridade   # outro diálogo vem em seguida: não desvira
	if not ativa:
		return NADA
	return _alvo_manual

func _vem_dialogo() -> bool:
	var it = get_node_or_null("/root/Main/GameManager/Interpeter")
	return it != null and it.has_method("dialogo_a_seguir") and it.dialogo_a_seguir()

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
## Som ao virar uma carta: nome do arquivo em audio/se/ (sem .mp3). Vazio = sem som (ainda não há).
const SOM_VIRAR: String = ""

func _virar(alvo: String) -> void:
	_virando = true
	if SOM_VIRAR != "":
		var audio = get_node_or_null("/root/Main/GameManager/AudioManager")
		if audio and audio.has_method("play_se"):
			audio.play_se(SOM_VIRAR)
	var giros: Array = _sortear_virada()
	var tw := create_tween()
	if alvo == NADA:
		# sumir: só fecha uma vez
		tw.tween_method(_set_achatar, _achatar, 0.0, tempo_virar * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(_mostrar.bind(alvo))
		tw.tween_callback(_set_achatar.bind(1.0))
		tw.tween_callback(_fim_virar)
		return
	var soma := 0.0
	for g in giros:
		soma += g
	var veio_de_nada := _atual == NADA
	if veio_de_nada:
		_mostrar(alvo)          # vinha escondida: só abre
		_set_achatar(0.0)
	for k in giros.size():
		var d: float = tempo_virar * giros[k] / soma
		if not (k == 0 and veio_de_nada):
			tw.tween_method(_set_achatar, _achatar if k == 0 else 1.0, 0.0, d * 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if k == 0 and not veio_de_nada:
			tw.tween_callback(_mostrar.bind(alvo))   # troca de face na primeira volta
		tw.tween_method(_set_achatar, 0.0, 1.0, d * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_fim_virar)

## Sorteia eixo e número de voltas. Devolve o peso (duração relativa) de cada volta.
func _sortear_virada() -> Array:
	_ang_virada = angulo_diagonal
	if not variar_virada:
		return [1.0]
	if randf() >= CHANCE_DIAGONAL:
		_ang_virada = 0.0      # vertical: achata na largura
	var voltas: Array = []
	voltas.resize(N_VOLTAS if randf() < CHANCE_N_VOLTAS else 1)
	voltas.fill(1.0)       # voltas iguais, no mesmo tempo total
	return voltas

func _mostrar(nome_face: String) -> void:
	_atual = nome_face
	visible = nome_face != NADA
	var prioridade := nome_face == face_prioridade
	if z_forcado >= 0:
		z_as_relative = false
		z_index = z_forcado
	else:
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
	if not is_visible_in_tree() or _atual == NADA or _atual == face_prioridade:
		return
	if UiModal.bloqueia(self):   # caldeirão, menu de debug, popup... por cima
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
	if event is InputEventMouseButton and _atual == VERSO and not _virando and ativa and interativa:
		abrir()
		get_viewport().set_input_as_handled()
