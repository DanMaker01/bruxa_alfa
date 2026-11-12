# layout_preparo.gd
# Layout da cena de preparo para celular (640x960). Reaproveita os nós da cena
# (BotaoFogo = Abanar, Poção, lista de ingredientes) e acrescenta:
#   carrossel de ingredientes embaixo do caldeirão
#   Abaixar (polegar esquerdo) e Abanar (polegar direito), Acender/Apagar embaixo
#   Poção (Finalizar) no canto superior direito; receita memorizada (GuiaReceita) abaixo dela
#   com o debug do caldeirão aberto: arco de T acima do caldeirão, arco de F em volta do
#   fogo (ArcosDebug), régua de cor do caldeirão e selo "estável" (ReguaCaldeirao)
# (Os layouts de teste Original, A, B e C foram removidos; ficou o D.)
class_name LayoutPreparo
extends Control

var cena = null
var regua_caldeirao: ReguaCaldeirao
var arcos: ArcosDebug
var guia: GuiaReceita
var _painel: Control          # PainelIngredientes
var _painel_bg: Control
var _scroll: Control
var _b_fogo: Button
var _b_pocao: Button
var _b_abaixar: Button
var _b_acender: Button


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

	arcos = ArcosDebug.new()
	arcos.cena = cena
	arcos.z_index = 6
	add_child(arcos)
	regua_caldeirao = ReguaCaldeirao.new()
	regua_caldeirao.cena = cena
	regua_caldeirao.z_index = 6
	regua_caldeirao.so_debug = true
	add_child(regua_caldeirao)
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
	_montar()


func _montar() -> void:
	# painel de ingredientes ocupa a tela toda (só os filhos recebem toque)
	_painel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_painel.position = Vector2.ZERO
	_painel.size = Vector2(640, 960)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _painel_bg:   # faixa escura atrás dos controles de baixo
		_painel_bg.visible = true
		_painel_bg.position = Vector2(0, 640)
		_painel_bg.size = Vector2(640, 320)
	_por(_b_pocao, Vector2(536, 12), Vector2(96, 96))
	guia.position = Vector2(640 - GuiaReceita.LARG - 12, 116)
	_por(arcos, Vector2.ZERO, Vector2(640, 640))
	_por(regua_caldeirao, Vector2(500, 196), Vector2(136, 400))
	_por(_scroll, Vector2(16, 650), Vector2(608, 136))
	_por(_b_abaixar, Vector2(16, 798), Vector2(296, 112))
	_por(_b_fogo, Vector2(328, 798), Vector2(296, 112))
	_por(_b_acender, Vector2(220, 914), Vector2(200, 42))
	_atualizar_acender()


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
	_atualizar_acender()


# =============================================================================
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
