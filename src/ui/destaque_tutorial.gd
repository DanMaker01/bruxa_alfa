# destaque_tutorial.gd
# Peça dos tutoriais (fora do caldeirão): escurece a tela deixando um "buraco" no alvo,
# desenha uma moldura pulsando com uma setinha e mostra uma dica (com botão opcional).
#   alvo(getter, bloquear, passa_toque)  getter devolve um Rect2 em coordenadas de tela
#                                        (Rect2() = sem alvo). bloquear: escurece e só o
#                                        buraco recebe toque. passa_toque = false: o toque no
#                                        buraco não passa para baixo, emite tocou_alvo.
#   dica(texto, botao, acao)            painel de dica (botao "" = sem botão)
#   esconder()
class_name DestaqueTutorial
extends Control

signal tocou_alvo

const ALFA_ESCURO: float = 0.55
const COR_MOLDURA := Color(1.0, 0.85, 0.3)
const COR_FUNDO_DICA := Color(0.08, 0.07, 0.11, 0.96)
const COR_BORDA_DICA := Color(0.85, 0.7, 0.35)

## Onde fica o painel de dica (coordenadas de tela).
var rect_dica := Rect2(20, 650, 600, 140)
var _alvo: Callable = Callable()
var _bloquear: bool = false
var _passa: bool = true
var _escuros: Array[ColorRect] = []
var _cheio: ColorRect                # escuro na tela toda (bloquear sem alvo / alvo que não passa toque)
var _moldura: Control
var _painel: PanelContainer
var _texto: Label
var _botao: Button
var _acao: Callable = Callable()
var _t: float = 0.0
var _ret := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 50
	top_level = true   # coordenadas de tela, mesmo dentro de outra cena (ex.: o livro)
	position = Vector2.ZERO
	_cheio = ColorRect.new()
	_cheio.color = Color(0, 0, 0, 0.0)
	_cheio.mouse_filter = Control.MOUSE_FILTER_STOP
	_cheio.visible = false
	_cheio.gui_input.connect(_toque_cheio)
	add_child(_cheio)
	for k in 4:
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, ALFA_ESCURO)
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		r.visible = false
		r.gui_input.connect(_engolir)
		add_child(r)
		_escuros.append(r)
	_moldura = Control.new()
	_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.visible = false
	_moldura.draw.connect(_desenhar_moldura)
	add_child(_moldura)
	_painel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = COR_FUNDO_DICA
	st.border_color = COR_BORDA_DICA
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.set_content_margin_all(14)
	_painel.add_theme_stylebox_override("panel", st)
	_painel.mouse_filter = Control.MOUSE_FILTER_STOP
	_painel.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_painel.add_child(col)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 24)
	_texto.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	col.add_child(_texto)
	_botao = Button.new()
	_botao.focus_mode = Control.FOCUS_NONE
	_botao.custom_minimum_size = Vector2(0, 56)
	_botao.add_theme_font_size_override("font_size", 22)
	_botao.visible = false
	_botao.pressed.connect(func():
		Vibrar.leve()
		if _acao.is_valid():
			_acao.call())
	col.add_child(_botao)
	add_child(_painel)

func alvo(getter: Callable, bloquear: bool, passa_toque: bool = true) -> void:
	_alvo = getter
	_bloquear = bloquear
	_passa = passa_toque
	_atualizar()

func dica(texto: String, botao: String = "", acao: Callable = Callable()) -> void:
	_texto.text = texto
	_botao.text = botao
	_botao.visible = botao != ""
	_acao = acao
	_painel.visible = texto != ""
	_painel.position = rect_dica.position
	_painel.size = Vector2(rect_dica.size.x, 0)
	_painel.custom_minimum_size = Vector2(rect_dica.size.x, 0)

func esconder() -> void:
	_alvo = Callable()
	_bloquear = false
	_painel.visible = false
	_atualizar()

func _process(delta: float) -> void:
	_t += delta
	_atualizar()

func _atualizar() -> void:
	var tela := get_viewport_rect().size
	_ret = _alvo.call() if _alvo.is_valid() else Rect2()
	var tem_alvo: bool = _ret.size.x > 1.0
	# sem alvo e bloqueando: escuro na tela toda
	_cheio.position = Vector2.ZERO
	_cheio.size = tela
	_cheio.visible = (_bloquear and not tem_alvo) or (tem_alvo and not _passa)
	_cheio.color = Color(0, 0, 0, ALFA_ESCURO if (_bloquear and not tem_alvo) else 0.0)
	var faixas := [
		Rect2(0, 0, tela.x, _ret.position.y),
		Rect2(0, _ret.end.y, tela.x, tela.y - _ret.end.y),
		Rect2(0, _ret.position.y, _ret.position.x, _ret.size.y),
		Rect2(_ret.end.x, _ret.position.y, tela.x - _ret.end.x, _ret.size.y),
	]
	for k in 4:
		_escuros[k].visible = _bloquear and tem_alvo
		_escuros[k].position = faixas[k].position
		_escuros[k].size = faixas[k].size.max(Vector2.ZERO)
	_moldura.visible = tem_alvo
	if tem_alvo:
		_moldura.position = _ret.position
		_moldura.size = _ret.size
		_moldura.queue_redraw()

func _desenhar_moldura() -> void:
	var pulso: float = 0.5 + 0.5 * sin(_t * 6.0)
	_moldura.draw_rect(Rect2(Vector2.ZERO, _moldura.size), Color(COR_MOLDURA, 0.5 + 0.5 * pulso), false, 4.0 + 3.0 * pulso)
	var cx: float = _moldura.size.x * 0.5
	var y: float = -14.0 - 8.0 * pulso
	_moldura.draw_colored_polygon(PackedVector2Array([Vector2(cx - 16, y - 22), Vector2(cx + 16, y - 22), Vector2(cx, y)]), COR_MOLDURA)

## Toque em área escura: não faz nada (só não deixa passar).
func _engolir(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
		accept_event()

## Camada da tela toda: com alvo que não passa toque, o toque no buraco vira tocou_alvo.
func _toque_cheio(ev: InputEvent) -> void:
	if not ((ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed):
		return
	accept_event()
	if _ret.size.x > 1.0 and not _passa and _ret.has_point(_cheio.get_global_transform() * ev.position):
		Vibrar.leve()
		tocou_alvo.emit()
