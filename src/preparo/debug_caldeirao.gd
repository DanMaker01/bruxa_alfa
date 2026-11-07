# debug_caldeirao.gd
# Camada de debug da cena de preparo. Junta tudo num lugar só, cada coisa na sua
# caixa com fundo, sem ficar solta por cima do caldeirão:
#   direita, em cima: modos de teste (M / P / T / C) + indicadores do sistema térmico
#   direita, embaixo: "Na panela" (PainelPanela)
#   embaixo:  gráfico T(t)
# Nada aqui recebe toque (mouse_filter IGNORE), para não atrapalhar o preparo.
class_name DebugCaldeirao
extends Control

const COR_FUNDO := Color(0.04, 0.04, 0.08, 0.82)
const COR_TITULO := Color(1.0, 0.85, 0.45)
const COR_TEXTO := Color(0.85, 0.85, 0.9)
const COR_SUAVE := Color(0.6, 0.6, 0.7)

## Tudo na direita: info em cima, "Na panela" embaixo.
const CAIXA_INFO := Rect2(470, 6, 166, 400)
const CAIXA_PANELA := Rect2(470, 412, 166, 140)

var _modos: Label
var _indicadores: Label


func _ready() -> void:
	name = "DebugCaldeirao"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Recebe os nós que já existem na cena e reorganiza dentro desta camada.
func configurar(indicadores_label: Label, grafico: Control, painel: Control) -> void:
	# ---- direita, em cima: modos + indicadores ----
	var esq := _caixa(CAIXA_INFO)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	esq.add_child(col)
	col.add_child(_titulo("Caldeirão (debug)"))
	_modos = _texto(12, COR_TEXTO)
	col.add_child(_modos)
	col.add_child(_linha())
	col.add_child(_titulo("Sistema"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(scroll)
	if indicadores_label:
		_indicadores = indicadores_label
		indicadores_label.get_parent().remove_child(indicadores_label)
		indicadores_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		indicadores_label.position = Vector2.ZERO
		indicadores_label.size = Vector2.ZERO
		indicadores_label.z_index = 0
		indicadores_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indicadores_label.clip_text = true
		indicadores_label.custom_minimum_size.x = 150
		indicadores_label.add_theme_font_size_override("font_size", 13)
		indicadores_label.add_theme_color_override("font_color", COR_TEXTO)
		indicadores_label.add_theme_constant_override("line_spacing", -2)
		scroll.add_child(indicadores_label)

	# ---- direita, embaixo: Na panela ----
	if painel:
		painel.get_parent().remove_child(painel)
		add_child(painel)
		painel.position = CAIXA_PANELA.position
		painel.custom_minimum_size = CAIXA_PANELA.size
		painel.size = CAIXA_PANELA.size

	# ---- embaixo: gráfico (mantém a posição da cena, entre o caldeirão e os botões) ----
	if grafico:
		var pos: Vector2 = grafico.position
		grafico.get_parent().remove_child(grafico)
		add_child(grafico)
		grafico.position = pos
		grafico.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Texto dos modos de teste (teclas M / P / T / C).
func atualizar_modos() -> void:
	if not _modos or not visible:
		return
	_modos.text = "M régua: %s\nP cores: %s\nT quente/frio: %s\nC anel já pintado: %s\nK %s" % [
		_curto(IconesCaldeirao.NOMES_MODO[IconesCaldeirao.modo]),
		_curto(IconesCaldeirao.NOMES_PALETA[IconesCaldeirao.paleta]),
		_curto(IconesCaldeirao.NOMES_MODO_TEMP[IconesCaldeirao.modo_temp]),
		"sim" if IconesCaldeirao.precolorido else "não",
		AnimacaoProdutorio.NOMES_TOQUE[AnimacaoProdutorio.toque]]


# ---------------------------------------------------------------------------
func _curto(s: String) -> String:
	var i := s.find(" (")
	return s.left(i) if i > 0 else s

func _caixa(r: Rect2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = r.position
	p.size = r.size
	p.custom_minimum_size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = COR_FUNDO
	st.set_corner_radius_all(8)
	st.set_content_margin_all(6)
	st.border_color = Color(1, 1, 1, 0.08)
	st.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", st)
	add_child(p)
	return p

func _titulo(t: String) -> Label:
	var l := _texto(14, COR_TITULO)
	l.text = t
	return l

func _texto(tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 150
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _linha() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = COR_SUAVE
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
