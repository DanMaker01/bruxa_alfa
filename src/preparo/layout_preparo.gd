# layout_preparo.gd
# Layouts da cena de preparo para celular (640x960). Um botão alterna entre eles
# (fica guardado em LayoutPreparo.atual):
#   0 Original    o de antes (lista embaixo, Poção à esquerda, Fogo à direita)
#   1 A Bancada   cena em cima, régua horizontal no meio, embaixo: fogo à esquerda
#                 (Abanar grande, Abaixar, Acender/Apagar) e grade de ingredientes à direita
#   2 B Polegares cena em cima com termômetro vertical, carrossel de ingredientes,
#                 embaixo Abaixar (polegar esquerdo) e Abanar (polegar direito)
#   3 C Prateleira ingredientes numa prateleira em cima, caldeirão no meio com a régua
#                 em arco, embaixo uma área de fogo grande (toque abana, arrastar para
#                 baixo abaixa) e Acender/Apagar
# Em todos: Finalizar no canto superior direito e a receita memorizada (GuiaReceita)
# no canto superior esquerdo. Reaproveita os nós da cena (BotaoFogo, Poção, lista).
class_name LayoutPreparo
extends Control

const NOMES := ["Original", "A: Bancada", "B: Polegares", "C: Prateleira"]
const ITENS_POR_PAGINA: int = 4
const ARRASTO_ABAIXAR: float = 28.0   # C: px arrastados para baixo por "abaixar"

static var atual: int = 2   # B (Polegares) é o padrão

var cena = null
var regua: ReguaChama
var guia: GuiaReceita
var _painel: Control          # PainelIngredientes
var _painel_bg: Control
var _scroll: Control
var _b_fogo: Button
var _b_pocao: Button
var _anim: Node2D
var _b_abaixar: Button
var _b_acender: Button
var _b_layout: Button
var _grade: GridContainer
var _grade_nav: HBoxContainer
var _grade_pagina: int = 0
var _grade_rotulo: Label
var _orig: Dictionary = {}
# C: arrastar no fogo
var _arrasto_y: float = -1.0
var _arrastou: bool = false


func configurar(p_cena) -> void:
	cena = p_cena
	name = "LayoutPreparo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_painel = cena.get_node("PainelIngredientes")
	_painel_bg = _painel.get_node_or_null("Panel")
	_scroll = _painel.get_node("ScrollContainer")
	_b_fogo = cena.botao_fogo
	_b_pocao = cena.botao_pocao
	_anim = cena.get_node("Animações")
	_guardar_original()

	regua = ReguaChama.new()
	regua.cena = cena
	regua.z_index = 6
	add_child(regua)
	guia = GuiaReceita.new()
	guia.cena = cena
	guia.z_index = 6
	add_child(guia)

	_b_abaixar = _botao("Abaixar", 22)
	var seg := BotaoSegurar.anexar(_b_abaixar, 0.3)
	seg.intervalo_repeticao = 0.3
	seg.toque_curto.connect(_abaixar)
	seg.segurou.connect(_abaixar)
	seg.repetiu.connect(_abaixar)
	_painel.add_child(_b_abaixar)
	_b_acender = _botao("Acender", 18)
	_b_acender.pressed.connect(_acender_apagar)
	_painel.add_child(_b_acender)

	_grade = GridContainer.new()
	_grade.columns = 2
	_grade.add_theme_constant_override("h_separation", 10)
	_grade.add_theme_constant_override("v_separation", 10)
	_painel.add_child(_grade)
	_grade_nav = HBoxContainer.new()
	_grade_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	var ant := _botao("‹", 24)
	ant.custom_minimum_size = Vector2(64, 44)
	ant.pressed.connect(_grade_passar.bind(-1))
	_grade_rotulo = Label.new()
	_grade_rotulo.custom_minimum_size.x = 70
	_grade_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var prox := _botao("›", 24)
	prox.custom_minimum_size = Vector2(64, 44)
	prox.pressed.connect(_grade_passar.bind(1))
	for n in [ant, _grade_rotulo, prox]:
		_grade_nav.add_child(n)
	_painel.add_child(_grade_nav)

	_b_layout = _botao("", 13)
	_b_layout.pressed.connect(_proximo)
	add_child(_b_layout)

	_b_fogo.gui_input.connect(_fogo_input)
	aplicar(atual)


# =============================================================================
func _proximo() -> void:
	aplicar((atual + 1) % NOMES.size())

func aplicar(n: int) -> void:
	atual = n
	_restaurar()
	_b_layout.text = "Layout " + NOMES[n]
	_b_layout.position = Vector2(470, 112)
	_b_layout.size = Vector2(160, 36)
	var novo: bool = n != 0
	regua.visible = novo
	_b_abaixar.visible = n == 1 or n == 2
	_b_acender.visible = novo
	_grade.visible = n == 1
	_grade_nav.visible = n == 1
	_scroll.visible = n != 1
	guia.position = Vector2(12, 112)
	if novo:
		# painel de ingredientes ocupa a tela toda (só os filhos recebem toque)
		_painel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_painel.position = Vector2.ZERO
		_painel.size = Vector2(640, 960)
		_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _painel_bg:
			_painel_bg.visible = false
		_por(_b_pocao, Vector2(536, 12), Vector2(96, 96))
	match n:
		1: _layout_a()
		2: _layout_b()
		3: _layout_c()
	_atualizar_acender()
	inventario_mudou()

func _layout_a() -> void:
	regua.formato = ReguaChama.Formato.HORIZONTAL
	_por(regua, Vector2(0, 566), Vector2(640, 70))
	_fundo_controles(640)
	_por(_b_fogo, Vector2(20, 652), Vector2(270, 170))
	_por(_b_abaixar, Vector2(20, 834), Vector2(130, 110))
	_por(_b_acender, Vector2(160, 834), Vector2(130, 110))
	_por(_grade, Vector2(318, 652), Vector2(300, 240))
	_por(_grade_nav, Vector2(318, 900), Vector2(300, 48))

func _layout_b() -> void:
	regua.formato = ReguaChama.Formato.VERTICAL
	_por(regua, Vector2(520, 150), Vector2(116, 440))
	_fundo_controles(640)
	_por(_scroll, Vector2(16, 650), Vector2(608, 136))
	_por(_b_abaixar, Vector2(16, 798), Vector2(296, 112))
	_por(_b_fogo, Vector2(328, 798), Vector2(296, 112))
	_por(_b_acender, Vector2(220, 914), Vector2(200, 42))

func _layout_c() -> void:
	_anim.position = Vector2(0, 150)   # caldeirão (e a bruxa chibi) descem para a prateleira caber
	regua.formato = ReguaChama.Formato.ARCO
	regua.centro_arco = Vector2(320, 440)
	regua.raio_arco = 190.0
	_por(regua, Vector2.ZERO, Vector2(640, 660))
	_por(_scroll, Vector2(16, 104), Vector2(440, 136))
	guia.position = Vector2(12, 250)
	_fundo_controles(668)
	_por(_b_fogo, Vector2(16, 676), Vector2(608, 216))
	_por(_b_acender, Vector2(220, 904), Vector2(200, 48))

## Faixa escura atrás dos controles de baixo.
func _fundo_controles(y: float) -> void:
	if _painel_bg:
		_painel_bg.visible = true
		_painel_bg.position = Vector2(0, y)
		_painel_bg.size = Vector2(640, 960 - y)


# =============================================================================
# INGREDIENTES (grade do layout A; B e C usam a lista da cena)
# =============================================================================
func inventario_mudou() -> void:
	if atual != 1 or cena == null:
		return
	for c in _grade.get_children():
		_grade.remove_child(c)
		c.queue_free()
	var gt = cena.game_temp
	var db = cena.database
	if gt == null or db == null:
		return
	var inv: Dictionary = gt.get_inventory()
	var ids: Array = inv.keys()
	var paginas: int = maxi(1, ceili(ids.size() / float(ITENS_POR_PAGINA)))
	_grade_pagina = clampi(_grade_pagina, 0, paginas - 1)
	_grade_rotulo.text = "%d/%d" % [_grade_pagina + 1, paginas]
	if ids.is_empty():
		var l := Label.new()
		l.text = "(inventário vazio)"
		_grade.add_child(l)
		return
	for k in range(_grade_pagina * ITENS_POR_PAGINA, mini(ids.size(), (_grade_pagina + 1) * ITENS_POR_PAGINA)):
		var b: Button = cena._criar_botao_item(ids[k], db.get_item(ids[k]), inv[ids[k]])
		b.custom_minimum_size = Vector2(145, 115)
		_grade.add_child(b)

func _grade_passar(d: int) -> void:
	_grade_pagina += d
	inventario_mudou()


# =============================================================================
# FOGO
# =============================================================================
func _abaixar() -> void:
	if cena:
		cena._abafar_fogo()
	_atualizar_acender()

func _acender_apagar() -> void:
	if cena and cena.has_method("alternar_fogo"):
		cena.alternar_fogo()
	_atualizar_acender()

func _atualizar_acender() -> void:
	var lig: bool = cena != null and cena.sistema != null and cena.sistema.fogo_ligado
	_b_acender.text = "Apagar" if lig else "Acender"

func _process(_d: float) -> void:
	if _b_acender.visible:
		_atualizar_acender()

## C: arrastar para baixo no fogo = abaixar (o toque curto continua abanando).
func _fogo_input(ev: InputEvent) -> void:
	if atual != 3:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_arrasto_y = ev.position.y
			_arrastou = false
		else:
			_arrasto_y = -1.0
	elif ev is InputEventMouseMotion and _arrasto_y >= 0.0:
		while ev.position.y - _arrasto_y >= ARRASTO_ABAIXAR:
			_arrasto_y += ARRASTO_ABAIXAR
			_arrastou = true
			_abaixar()

## A cena pergunta antes de abanar: no C, um arrasto não conta como toque.
func ignorar_toque_fogo() -> bool:
	if _arrastou:
		_arrastou = false
		return true
	return false


# =============================================================================
# ORIGINAL (guardar / restaurar)
# =============================================================================
func _guardar_original() -> void:
	_orig = {
		"painel": [_painel.anchor_left, _painel.anchor_top, _painel.anchor_right, _painel.anchor_bottom,
			_painel.offset_left, _painel.offset_top, _painel.offset_right, _painel.offset_bottom, _painel.mouse_filter],
		"anim": _anim.position,
	}
	for n in [_painel_bg, _scroll, _b_fogo, _b_pocao]:
		if n:
			_orig[n.name] = [n.position, n.size, n.visible]

func _restaurar() -> void:
	var p: Array = _orig["painel"]
	_painel.anchor_left = p[0]
	_painel.anchor_top = p[1]
	_painel.anchor_right = p[2]
	_painel.anchor_bottom = p[3]
	_painel.offset_left = p[4]
	_painel.offset_top = p[5]
	_painel.offset_right = p[6]
	_painel.offset_bottom = p[7]
	_painel.mouse_filter = p[8]
	_anim.position = _orig["anim"]
	for n in [_painel_bg, _scroll, _b_fogo, _b_pocao]:
		if n and _orig.has(n.name):
			n.position = _orig[n.name][0]
			n.size = _orig[n.name][1]
			n.visible = _orig[n.name][2]


func _por(n: Control, pos: Vector2, tam: Vector2) -> void:
	n.position = pos
	n.custom_minimum_size = Vector2.ZERO
	n.size = tam

func _botao(t: String, fonte: int) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fonte)
	return b
