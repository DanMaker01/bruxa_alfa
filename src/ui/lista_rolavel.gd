# lista_rolavel.gd
# ScrollContainer de toque: arrastar o dedo (ou o mouse) rola a lista, com inércia.
# Um toque sem arrastar "aperta" a linha que estiver embaixo do dedo (sinal linha_tocada).
# As linhas (filhos do VBox) devem ter mouse_filter = IGNORE: quem decide é esta lista,
# assim arrastar nunca dispara um botão por engano.
class_name ListaRolavel
extends ScrollContainer

signal linha_tocada(linha: Control)

## Quanto o dedo precisa andar (px) para virar arraste em vez de toque.
const LIMIAR_ARRASTE: float = 10.0
## Quanto a inércia perde por segundo (0..1 por frame a 60 fps ≈ atrito).
const ATRITO: float = 6.0

var _apertado: bool = false
var _arrastando: bool = false
var _inicio: Vector2
var _ultimo_y: float = 0.0
var _vel: float = 0.0          # px/s da inércia
var _rolagem: float = 0.0      # posição fracionária (scroll_vertical é int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # barra fininha some; arrasta-se a lista
	follow_focus = false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_apertado = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_global_rect().has_point(event.position):
				_apertado = true
				_arrastando = false
				_inicio = event.position
				_ultimo_y = event.position.y
				_vel = 0.0
				_rolagem = scroll_vertical
		elif _apertado:
			_apertado = false
			if not _arrastando:
				var linha := _linha_em(event.position)
				if linha:
					linha_tocada.emit(linha)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _apertado:
		if not _arrastando and event.position.distance_to(_inicio) > LIMIAR_ARRASTE:
			_arrastando = true
		if _arrastando:
			var dy: float = event.position.y - _ultimo_y
			_ultimo_y = event.position.y
			_rolagem -= dy
			scroll_vertical = int(_rolagem)
			var dt: float = maxf(get_process_delta_time(), 0.001)
			_vel = lerpf(_vel, -dy / dt, 0.5)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _apertado or absf(_vel) < 5.0:
		return
	_rolagem += _vel * delta
	_vel *= maxf(0.0, 1.0 - ATRITO * delta)
	var maximo: float = maxf(0.0, get_child(0).size.y - size.y) if get_child_count() > 0 else 0.0
	if _rolagem < 0.0 or _rolagem > maximo:
		_rolagem = clampf(_rolagem, 0.0, maximo)
		_vel = 0.0
	scroll_vertical = int(_rolagem)

## Linha (filho direto do conteúdo) embaixo do ponto da tela.
func _linha_em(pos: Vector2) -> Control:
	if get_child_count() == 0:
		return null
	for c in get_child(0).get_children():
		if c is Control and c.visible and c.get_global_rect().has_point(pos):
			return c
	return null
