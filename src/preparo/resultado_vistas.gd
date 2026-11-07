# resultado_vistas.gd
# Tela de informações da poção pronta (dentro da JanelaResultado), em uma coluna:
#   nome e nota (1 a 5 estrelas pela média do aproveitamento);
#   matriz e pentágono O-C-E-A-N lado a lado;
#   fileira de ícones dos ingredientes com o anel de aproveitamento.
#   Tocar num ícone abre os detalhes (problemas e curva de temperatura).
class_name ResultadoVistas
extends Control


const COR_TITULO := Color(1.0, 0.88, 0.55)
const COR_TEXTO := Color(0.95, 0.95, 0.9)
const COR_SUAVE := Color(1, 1, 1, 0.5)
const TELA := Vector2(640, 960)

# --- coluna
const C_GRADE := Rect2(56, 190, 230, 230)
const C_PENT := Rect2(320, 170, 280, 270)
const C_ICONES_Y: float = 500.0
const C_CEL: float = 96.0
const C_DETALHE := Rect2(30, 620, 580, 230)
var grade: GradeMatriz
var pentagono: PentagonoOcean
var _titulo: Label
var _nota: Label
var _res: Dictionary = {}
var _A: Array = []
var _icones: Array = []         # coluna: [{no, rect, d}]
var _detalhe: Control


func _ready() -> void:
	size = TELA
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func media_aproveitamento(diags: Array) -> float:
	if diags.is_empty():
		return 0.0
	var s := 0.0
	for d in diags:
		s += clampf(float(d.get("a", 0.0)), 0.0, 1.0)
	return s / diags.size()


## Nota oficial: 1 a 5 estrelas pela média do aproveitamento.
static func texto_nota(a: float) -> String:
	var n: int = clampi(roundi(a * 5.0), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)


# =============================================================================
# MONTAGEM
# =============================================================================
func limpar() -> void:
	for c in get_children():
		c.queue_free()
	_icones.clear()
	_detalhe = null
	grade = null
	pentagono = null


## Monta o visual atual (escondido: entrar() mostra). res: o resultado do preparo.
func montar(res: Dictionary, A: Array) -> void:
	limpar()
	_res = res
	_A = A
	visible = true
	_titulo = _label(32, HORIZONTAL_ALIGNMENT_CENTER, COR_TITULO)
	_titulo.position = Vector2(20, 30)
	_titulo.size = Vector2(600, 60)
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_titulo)
	_nota = _label(24, HORIZONTAL_ALIGNMENT_CENTER, IconesCaldeirao.cor_aproveitamento(media_aproveitamento(_diags())))
	_nota.position = Vector2(20, 92)
	_nota.size = Vector2(600, 34)
	add_child(_nota)
	atualizar_nota()
	_montar_coluna()
	for c in get_children():
		if c is CanvasItem:
			c.modulate.a = 0.0


func _diags() -> Array:
	return _res.get("diagnosticos", [])


func titulo(texto: String) -> void:
	if _titulo:
		_titulo.text = texto


## Troca o título com um "pop" (o nome acabou de ser dado).
func titulo_pop(texto: String) -> void:
	if not _titulo:
		return
	_titulo.pivot_offset = _titulo.size * 0.5
	var tw := create_tween()
	tw.tween_property(_titulo, "scale", Vector2(0.6, 0.6), 0.12)
	tw.tween_callback(titulo.bind(texto))
	tw.tween_property(_titulo, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func atualizar_nota() -> void:
	if _nota:
		_nota.text = texto_nota(media_aproveitamento(_diags()))


## Onde a matriz final do produtório deve parar (global, na tela).
func rect_grade() -> Rect2:
	return C_GRADE


func _montar_coluna() -> void:
	grade = GradeMatriz.new()
	grade.position = C_GRADE.position
	grade.size = C_GRADE.size
	add_child(grade)
	pentagono = PentagonoOcean.new()
	pentagono.position = C_PENT.position
	pentagono.size = C_PENT.size
	add_child(pentagono)
	add_child(_legenda("matriz", Vector2(C_GRADE.get_center().x, C_GRADE.end.y + 8)))
	add_child(_legenda("efeito numa pessoa neutra", Vector2(C_PENT.get_center().x, C_PENT.end.y - 4)))
	# fileira de ícones (quebra a cada 6), na ordem em que entraram
	var diags := _diags()
	var cab := _label(18, HORIZONTAL_ALIGNMENT_CENTER, COR_SUAVE)
	cab.text = "ingredientes  ·  toque para ver"
	cab.position = Vector2(0, C_ICONES_Y - 34)
	cab.size = Vector2(640, 26)
	add_child(cab)
	for i in diags.size():
		var lin: int = floori(i / 6.0)
		var col: int = i % 6
		var n_lin: int = mini(6, diags.size() - lin * 6)
		var x0: float = (640.0 - n_lin * C_CEL) * 0.5
		var r := Rect2(x0 + col * C_CEL, C_ICONES_Y + lin * (C_CEL + 14), C_CEL, C_CEL + 10)
		var ic := IconeIngRes.new()
		ic.d = diags[i]
		ic.vistas = self
		ic.position = r.position
		ic.size = r.size
		add_child(ic)
		_icones.append({"no": ic, "rect": r, "d": diags[i]})
	_detalhe = Control.new()
	_detalhe.position = C_DETALHE.position
	_detalhe.size = C_DETALHE.size
	_detalhe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detalhe)


# =============================================================================
# ANIMAÇÃO (a JanelaResultado chama na ordem)
# =============================================================================
## Moldura (título, nota, legendas, páginas) aparece; grade, pentágono e ícones esperam.
func entrar() -> void:
	if grade:
		grade.modulate.a = 0.0
	if pentagono:
		pentagono.modulate.a = 0.0
	var fora: Array = _nos_icones() + [grade, pentagono]
	var tw := create_tween().set_parallel(true)
	for c in get_children():
		if c is CanvasItem and not (c in fora):
			tw.tween_property(c, "modulate:a", 1.0, 0.5)
	await tw.finished


## A grade troca de lugar com a matriz do produtório (mesma posição e tamanho).
func mostrar_grade() -> void:
	if grade:
		grade.mostrar(_A)
		grade.modulate.a = 1.0


func mostrar_pentagono() -> void:
	if not pentagono:
		return
	var tw := create_tween()
	tw.tween_property(pentagono, "modulate:a", 1.0, 0.4)
	await tw.finished
	pentagono.mostrar(_A)
	await get_tree().create_timer(0.8, true).timeout


## Coluna: os ícones aparecem um a um e o anel enche até o aproveitamento.
func mostrar_ingredientes() -> void:
	for ic in _icones:
		var no = ic["no"]
		no.scale = Vector2(0.6, 0.6)
		no.pivot_offset = no.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(no, "modulate:a", 1.0, 0.2)
		tw.tween_property(no, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(no.set_anel, 0.0, 1.0, 0.5)
		await get_tree().create_timer(0.15, true).timeout
	await get_tree().create_timer(0.5, true).timeout


## Tudo pronto de uma vez (ao trocar de visual com a janela já aberta).
func mostrar_tudo() -> void:
	for c in get_children():
		if c is CanvasItem:
			c.modulate.a = 1.0
	if grade:
		grade.mostrar(_A)
	if pentagono:
		pentagono.mostrar(_A, 0.01)
	for ic in _icones:
		ic["no"].set_anel(1.0)


func _nos_icones() -> Array:
	var out: Array = []
	for ic in _icones:
		out.append(ic["no"])
	return out


# =============================================================================
# TOQUES
# =============================================================================
## A janela pergunta antes de fechar: true = o toque era daqui (não fecha).
func consumir_toque(pos: Vector2) -> bool:
	if not visible:
		return false
	for ic in _icones:
		if ic["rect"].has_point(pos):
			_abrir_detalhe(ic["d"])
			return true
	if _detalhe and _detalhe.get_child_count() > 0:
		_fechar_detalhe()
		return true
	if grade and grade.is_visible_in_tree() and grade.get_global_rect().has_point(pos):
		return true
	return false


func _abrir_detalhe(d: Dictionary) -> void:
	_fechar_detalhe()
	var fundo := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	st.set_corner_radius_all(14)
	st.border_color = Color(1, 1, 1, 0.12)
	st.set_border_width_all(1)
	fundo.add_theme_stylebox_override("panel", st)
	fundo.size = C_DETALHE.size
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detalhe.add_child(fundo)
	var col := VBoxContainer.new()
	col.position = Vector2(18, 14)
	col.size = C_DETALHE.size - Vector2(36, 28)
	col.add_theme_constant_override("separation", 8)
	col.add_child(_linha_ing(d, true))
	_detalhe.add_child(col)
	_detalhe.modulate.a = 0.0
	_detalhe.create_tween().tween_property(_detalhe, "modulate:a", 1.0, 0.15)


func _fechar_detalhe() -> void:
	if _detalhe:
		for c in _detalhe.get_children():
			c.queue_free()


# =============================================================================
# PEÇAS
# =============================================================================
## Nome | barra + % | tags (problemas) e, se com_curva, a curva de temperatura.
func _linha_ing(d: Dictionary, com_curva: bool) -> Control:
	var a: float = clampf(float(d.get("a", 0.0)), 0.0, 1.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 10)
	var item: ItemData = d.get("item")
	if item and item.icone:
		var ic := TextureRect.new()
		ic.texture = item.icone
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(40, 40)
		topo.add_child(ic)
	var nome := _label(20, HORIZONTAL_ALIGNMENT_LEFT, COR_TEXTO)
	nome.text = str(d.get("nome_exibicao", d.get("nome", "?")))
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(nome)
	var barra := ColorRect.new()
	barra.color = Color(1, 1, 1, 0.12)
	barra.custom_minimum_size = Vector2(130, 10)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cheio := ColorRect.new()
	cheio.color = IconesCaldeirao.cor_aproveitamento(a)
	cheio.size = Vector2(130 * a, 10)
	barra.add_child(cheio)
	topo.add_child(barra)
	var pct := _label(18, HORIZONTAL_ALIGNMENT_RIGHT, IconesCaldeirao.cor_aproveitamento(a))
	pct.text = "%d%%" % roundi(a * 100.0)
	pct.custom_minimum_size = Vector2(56, 0)
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(pct)
	v.add_child(topo)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_theme_constant_override("v_separation", 4)
	var problemas: Array = d.get("problemas", [])
	if problemas.is_empty():
		tags.add_child(_tag("no ponto ✓", Color(0.85, 0.7, 0.25)))
	else:
		for t in problemas:
			var perda: float = float(t.get("perda", 0.0))
			tags.add_child(_tag("%s  −%d%%" % [t.get("texto", "?"), roundi(100.0 * perda)],
				Color(0.8, 0.25, 0.2) if perda >= 0.5 else Color(0.85, 0.5, 0.15)))
	v.add_child(tags)
	if com_curva:
		var lt := LinhaTempo.new()
		lt.configurar(_res.get("historico_T", []), float(d.get("t0", 0.0)), float(_res.get("t_final", 1.0)), _inicio())
		v.add_child(lt)
	return v


func _tag(texto: String, cor: Color) -> Control:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(cor, 0.85)
	st.set_corner_radius_all(10)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	var l := _label(15, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))
	l.text = texto
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _legenda(texto: String, centro_topo: Vector2) -> Label:
	var l := _label(15, HORIZONTAL_ALIGNMENT_CENTER, COR_SUAVE)
	l.text = texto
	l.size = Vector2(300, 22)
	l.position = centro_topo - Vector2(150, 0)
	return l


func _label(tam: int, alinhamento: int, cor: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = alinhamento
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _inicio() -> float:
	var t := INF
	for d in _diags():
		t = minf(t, float(d.get("t0", 0.0)))
	return 0.0 if t == INF else t


# -----------------------------------------------------------------------------
## Ícone de um ingrediente com o anel de aproveitamento (coluna).
class IconeIngRes extends Control:
	var d: Dictionary
	var vistas: Control
	var _f: float = 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_anel(f: float) -> void:
		_f = f
		queue_redraw()

	func _draw() -> void:
		var a: float = clampf(float(d.get("a", 0.0)), 0.0, 1.0)
		var c := Vector2(size.x * 0.5, size.x * 0.42)
		var r: float = size.x * 0.36
		var item: ItemData = d.get("item")
		if item and item.icone:
			var lado: float = r * 1.35
			draw_texture_rect(item.icone, Rect2(c - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false)
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 5.0, true)
		var v: float = a * _f
		if v > 0.001:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * v, 48, IconesCaldeirao.cor_aproveitamento(a), 5.0, true)
		var fonte := get_theme_default_font()
		var txt := "%d%%" % roundi(v * 100.0)
		draw_string(fonte, Vector2(0, size.y - 4), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, IconesCaldeirao.cor_aproveitamento(a))
