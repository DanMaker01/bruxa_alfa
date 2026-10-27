# lista_rolavel.gd
# ScrollContainer de toque: arrastar o dedo (ou o mouse) rola a lista, com inércia.
# Um toque sem arrastar "aperta" a linha que estiver embaixo do dedo (sinal linha_tocada).
# As linhas (filhos do conteúdo) devem ter mouse_filter = IGNORE: quem decide é esta lista,
# assim arrastar nunca dispara um botão por engano.
# Setinhas (▲▼ ou ◀▶) aparecem nas bordas quando há itens escondidos daquele lado.
class_name ListaRolavel
extends ScrollContainer

signal linha_tocada(linha: Control)

## false = rola na vertical (inventário); true = na horizontal (ingredientes do preparo).
@export var horizontal: bool = false
## Quanto o dedo precisa andar (px) para virar arraste em vez de toque.
const LIMIAR_ARRASTE: float = 10.0
## Quanto a inércia perde por segundo.
const ATRITO: float = 6.0
const COR_SETA := Color(1, 1, 1, 0.75)
const TAM_SETA: float = 9.0

var _apertado: bool = false
var _arrastando: bool = false
var _inicio: Vector2
var _ultimo: float = 0.0
var _vel: float = 0.0          # px/s da inércia
var _rolagem: float = 0.0      # posição fracionária (scroll_* é int)
var _setas: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if horizontal:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	follow_focus = false
	# setas: Node2D (o container ignora filhos que não são Control) por cima das linhas
	_setas = Node2D.new()
	_setas.name = "Setas"
	_setas.z_index = 10
	_setas.draw.connect(_desenhar_setas)
	add_child(_setas, false, Node.INTERNAL_MODE_BACK)

## Volta para o começo da lista (sem inércia).
func ao_inicio() -> void:
	_vel = 0.0
	_rolagem = 0.0
	_apertado = false
	_arrastando = false
	_aplicar(0.0)

func _conteudo() -> Control:
	for c in get_children():
		if c is Control:
			return c
	return null

func _pos_atual() -> float:
	return float(scroll_horizontal if horizontal else scroll_vertical)

func _aplicar(v: float) -> void:
	if horizontal:
		scroll_horizontal = int(v)
	else:
		scroll_vertical = int(v)

func _maximo() -> float:
	var c := _conteudo()
	if c == null:
		return 0.0
	return maxf(0.0, (c.size.x - size.x) if horizontal else (c.size.y - size.y))

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_apertado = false
		return
	# janela por cima (caldeirão, menu de debug, popup do item): o toque não é desta lista
	if event is InputEventMouseButton and event.pressed and UiModal.bloqueia(self):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_global_rect().has_point(event.position):
				_apertado = true
				_arrastando = false
				_inicio = event.position
				_ultimo = event.position.x if horizontal else event.position.y
				_vel = 0.0
				_rolagem = _pos_atual()
		elif _apertado:
			_apertado = false
			if _arrastando:
				get_viewport().set_input_as_handled()   # arrastou: nenhum botão dispara
			else:
				# toque: linhas com mouse_filter IGNORE usam o sinal; botões normais recebem o clique
				var linha := _linha_em(event.position)
				if linha and linha.mouse_filter == Control.MOUSE_FILTER_IGNORE:
					linha_tocada.emit(linha)
	elif event is InputEventMouseMotion and _apertado:
		if not _arrastando and event.position.distance_to(_inicio) > LIMIAR_ARRASTE:
			_arrastando = true
		if _arrastando:
			var agora: float = event.position.x if horizontal else event.position.y
			var d: float = agora - _ultimo
			_ultimo = agora
			_rolagem = clampf(_rolagem - d, 0.0, _maximo())
			_aplicar(_rolagem)
			var dt: float = maxf(get_process_delta_time(), 0.001)
			_vel = lerpf(_vel, -d / dt, 0.5)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_setas.queue_redraw()
	if _apertado or absf(_vel) < 5.0:
		return
	_rolagem += _vel * delta
	_vel *= maxf(0.0, 1.0 - ATRITO * delta)
	var maximo := _maximo()
	if _rolagem < 0.0 or _rolagem > maximo:
		_rolagem = clampf(_rolagem, 0.0, maximo)
		_vel = 0.0
	_aplicar(_rolagem)

## Linha (filho direto do conteúdo) embaixo do ponto da tela.
func _linha_em(pos: Vector2) -> Control:
	var c := _conteudo()
	if c == null:
		return null
	for l in c.get_children():
		if l is Control and l.visible and l.get_global_rect().has_point(pos):
			return l
	return null

## Setas nas bordas onde ainda há conteúdo escondido.
func _desenhar_setas() -> void:
	var maximo := _maximo()
	if maximo <= 1.0:
		return
	var pos := _pos_atual()
	var t: float = TAM_SETA
	var pulsa: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 250.0)
	var cor := Color(COR_SETA, COR_SETA.a * pulsa)
	if horizontal:
		var y := size.y * 0.5
		if pos > 1.0:
			_setas.draw_colored_polygon(PackedVector2Array([Vector2(2, y), Vector2(2 + t, y - t), Vector2(2 + t, y + t)]), cor)
		if pos < maximo - 1.0:
			var x := size.x - 2.0
			_setas.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x - t, y - t), Vector2(x - t, y + t)]), cor)
	else:
		var x := size.x * 0.5
		if pos > 1.0:
			_setas.draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x - t, 2 + t), Vector2(x + t, 2 + t)]), cor)
		if pos < maximo - 1.0:
			var y := size.y - 2.0
			_setas.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x - t, y - t), Vector2(x + t, y - t)]), cor)
