# detalhe_receita.gd
# Detalhe de uma receita já feita (tocar na página): o melhor preparo anotado.
#   gráfico T(t) com as faixas de cor da chama e a entrada de cada ingrediente
#   aproveitamento de cada ingrediente
#   matriz da poção
# Usa o que o preparo guardou em resultado: "curva" [[t, T]], "entradas" [[t, id]],
# "itens_a" [[id, a]], "A".
class_name DetalheReceita
extends PanelContainer

signal fechou

const COR_PAPEL := Color(0.96, 0.91, 0.8)
const COR_TINTA := Color(0.2, 0.14, 0.1)
const COR_SUAVE := Color(0.47, 0.4, 0.32)

var database = null
var _titulo: Label
var _sub: Label
var _grafico: GraficoPreparo
var _itens: VBoxContainer
var _grade: GradeMatriz


func montar(p_db) -> void:
	database = p_db
	var st := StyleBoxFlat.new()
	st.bg_color = COR_PAPEL
	st.border_color = Color(0, 0, 0, 0.3)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(14)
	add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	var topo := HBoxContainer.new()
	_titulo = _rotulo("", 18, COR_TINTA)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_titulo)
	var x := Button.new()
	x.text = "✕"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(44, 40)
	x.pressed.connect(fechar)
	topo.add_child(x)
	col.add_child(topo)
	_sub = _rotulo("", 13, COR_SUAVE)
	col.add_child(_sub)
	_grafico = GraficoPreparo.new()
	_grafico.custom_minimum_size = Vector2(0, 220)
	_grafico.database = database
	col.add_child(_grafico)
	var baixo := HBoxContainer.new()
	baixo.add_theme_constant_override("separation", 12)
	baixo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_itens = VBoxContainer.new()
	_itens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_itens)
	baixo.add_child(sc)
	var fundo_grade := PanelContainer.new()   # a grade foi feita para fundo escuro
	var stg := StyleBoxFlat.new()
	stg.bg_color = Color(0.08, 0.07, 0.1)
	stg.set_corner_radius_all(6)
	stg.set_content_margin_all(6)
	fundo_grade.add_theme_stylebox_override("panel", stg)
	_grade = GradeMatriz.new()
	_grade.custom_minimum_size = Vector2(220, 220)
	fundo_grade.add_child(_grade)
	baixo.add_child(fundo_grade)
	col.add_child(baixo)
	hide()

static func tem_detalhe(p: Dictionary) -> bool:
	return p.get("resultado", {}).has("curva")

func abrir(p: Dictionary) -> void:
	var r: Dictionary = p.get("resultado", {})
	_titulo.text = str(p["nome"])
	_sub.text = "Melhor preparo: %s · %d%% · feita %dx" % [r.get("pocao", "?"), roundi(float(r.get("a", 0.0)) * 100.0), int(r.get("vezes", 1))]
	_grafico.curva = r.get("curva", [])
	_grafico.entradas = r.get("entradas", [])
	_grafico.queue_redraw()
	for c in _itens.get_children():
		c.queue_free()
	_itens.add_child(_rotulo("Aproveitamento", 12, COR_SUAVE))
	for par in r.get("itens_a", []):
		var a: float = float(par[1])
		var l := _rotulo("%s  %d%%" % [LivroReceitas.nome_item(str(par[0]), database), roundi(a * 100.0)], 14, COR_TINTA)
		l.add_theme_color_override("font_color", IconesCaldeirao.cor_aproveitamento(a).darkened(0.35))
		_itens.add_child(l)
	_grade.mostrar(r.get("A", []))
	show()

func fechar() -> void:
	hide()
	fechou.emit()

func _rotulo(t: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Gráfico T(t) do preparo anotado, com faixas de cor dos estados da chama.
class GraficoPreparo extends Control:
	const T_MAX: float = 220.0
	var curva: Array = []
	var entradas: Array = []
	var database = null
	var _f: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_f = get_theme_default_font()

	func _draw() -> void:
		var tinta := Color(0.2, 0.14, 0.1)
		var r := Rect2(Vector2(30, 4), size - Vector2(36, 26))
		# faixas dos estados
		for e in EstadosChama.LISTA:
			var a: float = clampf(e["T_min"], 20.0, T_MAX)
			var b: float = clampf(e["T_max"], 20.0, T_MAX)
			if b <= a:
				continue
			draw_rect(Rect2(r.position.x, _y(b, r), r.size.x, _y(a, r) - _y(b, r)), Color(e["cor"], 0.18))
		draw_rect(r, Color(tinta, 0.4), false, 1.0)
		for T in [50, 100, 150, 200]:
			draw_string(_f, Vector2(2, _y(T, r) + 4), str(T), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(tinta, 0.6))
		if curva.size() < 2:
			return
		var t_fim: float = maxf(float(curva[-1][0]), 1.0)
		var pts := PackedVector2Array()
		for p in curva:
			pts.append(Vector2(r.position.x + r.size.x * float(p[0]) / t_fim, _y(float(p[1]), r)))
		draw_polyline(pts, Color(0.75, 0.15, 0.1), 2.0, true)
		for e in entradas:
			var x: float = r.position.x + r.size.x * float(e[0]) / t_fim
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.5, 0.18, 0.45, 0.6), 1.0)
		draw_string(_f, Vector2(r.position.x, r.end.y + 16), "0 s", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(tinta, 0.6))
		draw_string(_f, Vector2(r.end.x - 40, r.end.y + 16), "%d s" % roundi(t_fim), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(tinta, 0.6))

	func _y(T: float, r: Rect2) -> float:
		return r.end.y - r.size.y * clampf((T - 20.0) / (T_MAX - 20.0), 0.0, 1.0)
