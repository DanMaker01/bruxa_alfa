# layout_preparo.gd
# Layout da cena de preparo para celular (640x960). Reaproveita os nós da cena
# (BotaoFogo = Abanar, Poção, lista de ingredientes) e acrescenta:
#   carrossel de ingredientes embaixo do caldeirão
#   fogo apagado: um botão só, Acender; aceso: Abaixar (−Fogo, polegar esquerdo) e
#   Abanar (+Fogo, polegar direito), independentes
#   Poção (Finalizar) no canto superior direito; receita memorizada (GuiaReceita) abaixo dela
#   Voltar (Sair, perde os ingredientes) no canto superior esquerdo
#   com o debug do caldeirão aberto: arco de T acima do caldeirão, arco de F em volta do
#   fogo (ArcosDebug), régua de cor do caldeirão e selo "estável" (ReguaCaldeirao)
# (Os layouts de teste Original, A, B e C foram removidos; ficou o D.)
class_name LayoutPreparo
extends Control

## Teste: Abaixar, Abanar e Acender com o sprite de carta do HUD (false = botões normais).
const BOTOES_CARTA: bool = true
## Margem (px) dos cantos do sprite que não esticam (9 fatias).
const MARGEM_CARTA: float = 26.0
## Layout do preparo (caldeirão 1,0×, um pouco mais baixo; controles na faixa de baixo).
##   anim:   escala e deslocamento do caldeirão (nó Animações, com a bruxinha e os ícones)
##   item:   lado (px) dos botões de ingrediente
##   bg:     faixa escura de baixo; scroll: carrossel de ingredientes
##   menos / mais / acender: −Fogo, +Fogo e Acender (Rect2)
##   bruxa:  pé da bruxinha; guia_y: altura da receita memorizada
const LAYOUT := {"anim": [1.0, Vector2(0, 30)], "item": 100.0, "bg": Rect2(0, 700, 640, 260),
		"scroll": Rect2(16, 708, 608, 114), "menos": Rect2(16, 832, 296, 118), "mais": Rect2(328, 832, 296, 118),
		"acender": Rect2(16, 832, 608, 118), "bruxa": Vector2(80, 500), "guia_y": 130.0}
## Centro do caldeirão (escala do layout em volta dele).
const PIVO_CALDEIRAO := Vector2(320, 300)

## Ícone do Abaixar (−Fogo), centralizado como o do +Fogo.
const ICONE_ABAIXAR := "res://assets/game_caldeirao/botao_fogo_menos.png"

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
var _b_sair: Button
const ICONE_SAIR := "res://assets/game_caldeirao/botao_voltar.png"


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
	_b_acender = _botao("Acender", 30)
	_b_acender.button_down.connect(func(): Vibrar.leve())
	_b_acender.pressed.connect(_acender)
	_painel.add_child(_b_acender)
	# Sair (menor, acima do Finalizar): perde os ingredientes, com confirmação
	_b_sair = _botao("", 14)
	_b_sair.button_down.connect(func(): Vibrar.leve())
	if ResourceLoader.exists(ICONE_SAIR):
		_b_sair.icon = load(ICONE_SAIR)
		_b_sair.expand_icon = true
		_b_sair.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_b_sair.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		_b_sair.text = "Sair"
	_b_sair.tooltip_text = "Sair do preparo"
	_b_sair.pressed.connect(func(): cena.confirmar_sair())
	_painel.add_child(_b_sair)
	_montar()
	if BOTOES_CARTA:
		for b in [_b_abaixar, _b_fogo, _b_acender, _b_pocao, _b_sair]:
			_estilo_carta(b)


## Lado dos botões de ingrediente.
func tam_item() -> float:
	return float(_layout()["item"])

func _layout() -> Dictionary:
	return LAYOUT

func _montar() -> void:
	var L := _layout()
	# caldeirão (com a bruxinha, os ícones e as bolhas): escala em volta do centro dele
	var anim: Node2D = cena.get_node_or_null("Animações")
	if anim:
		var s: float = L["anim"][0]
		anim.scale = Vector2(s, s)
		anim.position = PIVO_CALDEIRAO - PIVO_CALDEIRAO * s + L["anim"][1]
	if cena.get("reacao"):
		cena.reacao.position = L["bruxa"]
	# painel de ingredientes ocupa a tela toda (só os filhos recebem toque)
	_painel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_painel.position = Vector2.ZERO
	_painel.size = Vector2(640, 960)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _painel_bg:   # faixa escura atrás dos controles de baixo
		_painel_bg.visible = true
		_painel_bg.position = L["bg"].position
		_painel_bg.size = L["bg"].size
	# Voltar (Sair): canto superior esquerdo, no tamanho do ícone
	var tam_sair := Vector2(100, 88)
	if _b_sair.icon:
		tam_sair = _b_sair.icon.get_size()
	_por(_b_sair, Vector2(8, 8), tam_sair)
	_por(_b_pocao, Vector2(520, 8), Vector2(112, 100))      # Finalizar: canto superior direito (só com itens no caldeirão)
	guia.position = Vector2(640 - GuiaReceita.LARG - 12, L["guia_y"])
	_por(arcos, Vector2.ZERO, Vector2(640, 640))
	_por(regua_caldeirao, Vector2(500, 196), Vector2(136, 400))
	_por(_scroll, L["scroll"].position, L["scroll"].size)
	_por(_b_abaixar, L["menos"].position, L["menos"].size)
	_por(_b_fogo, L["mais"].position, L["mais"].size)
	_b_fogo.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER   # ícone do +Fogo no meio do botão
	_b_fogo.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_b_fogo.expand_icon = true
	if ResourceLoader.exists(ICONE_ABAIXAR):
		_b_abaixar.icon = load(ICONE_ABAIXAR)
		_b_abaixar.text = ""
		_b_abaixar.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_b_abaixar.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		_b_abaixar.expand_icon = true
	_por(_b_acender, L["acender"].position, L["acender"].size)   # no lugar dos dois botões de fogo
	if _b_fogo.icon:
		_b_acender.icon = _b_fogo.icon
		_b_acender.expand_icon = false
		_b_acender.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_atualizar_acender()


# =============================================================================
# FOGO
# =============================================================================
func _abaixar() -> void:
	if cena:
		cena._abafar_fogo(_b_abaixar)   # a animação fica no próprio −Fogo (não mexe no +Fogo)
	_atualizar_acender()

func _acender() -> void:
	if cena and cena.sistema and not cena.sistema.fogo_ligado:
		cena._fogo_segurar(_b_acender)
	_atualizar_acender()

## Apagado: só o Acender. Aceso: −Fogo e +Fogo (o Acender some).
func _atualizar_acender() -> void:
	var lig: bool = cena != null and cena.sistema != null and cena.sistema.fogo_ligado
	if lig and not _b_abaixar.visible:   # acabou de acender: −Fogo e +Fogo na cor normal
		for b in [_b_abaixar, _b_fogo]:
			b.modulate = Color.WHITE
			b.scale = Vector2.ONE
	if not lig and not _b_acender.visible:
		_b_acender.modulate = Color.WHITE
		_b_acender.scale = Vector2.ONE
	_b_acender.visible = not lig
	_b_abaixar.visible = lig
	_b_fogo.visible = lig

func _process(_d: float) -> void:
	_atualizar_acender()


# =============================================================================
## Botão com o sprite de carta (Carta.SPRITE_CARTA) em 9 fatias: os cantos não deformam.
func _estilo_carta(b: Button) -> void:
	var tex: Texture2D = load(Carta.SPRITE_CARTA) if ResourceLoader.exists(Carta.SPRITE_CARTA) else null
	if tex == null:
		return
	for estado in [["normal", Color.WHITE], ["hover", Color(1.15, 1.15, 1.15)], ["pressed", Color(0.8, 0.8, 0.85)],
			["disabled", Color(0.6, 0.6, 0.6)]]:
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.set_texture_margin_all(MARGEM_CARTA)
		st.set_content_margin_all(10)
		st.modulate_color = estado[1]
		b.add_theme_stylebox_override(estado[0], st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.6))

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
