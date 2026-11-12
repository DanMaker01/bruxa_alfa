# resultado_vistas.gd
# Tela de informações da poção pronta (dentro da JanelaResultado), em 3 cartas no estilo
# do HUD (Carta.criar), duas em cima e uma embaixo, que aparecem de verso e viram abertas, uma de cada vez:
#   1. nome + matriz (a matriz do produtório pousa nela);
#   2. pentágono O-C-E-A-N (efeito numa pessoa neutra);
#   3. ingredientes com o anel de aproveitamento (tocar num ícone abre os detalhes).
# Ao confirmar, as cartas 2 e 3 fecham, a matriz vira a poção e a carta 1 fecha.
class_name ResultadoVistas
extends Control


const COR_TITULO := Color(1.0, 0.88, 0.55)
const COR_TEXTO := Color(0.95, 0.95, 0.9)
const COR_SUAVE := Color(1, 1, 1, 0.5)
const TELA := Vector2(640, 960)

# --- cartas (tudo em coordenadas da tela): duas em cima, uma embaixo
const C_CARTA1 := Rect2(16, 40, 296, 400)     # nome + matriz
const C_CARTA2 := Rect2(328, 40, 296, 400)    # pentágono
const C_CARTA3 := Rect2(16, 456, 608, 420)    # ingredientes
const C_GRADE := Rect2(64, 124, 200, 200)     # com margem dentro da carta 1
const C_PENT := Rect2(371, 116, 210, 210)     # com margem dentro da carta 2
const C_CEL_MAX: float = 96.0
const C_ICONES_FIM: float = 650.0             # ícones acima disto; o detalhe abre embaixo
const C_DETALHE := Rect2(30, 656, 580, 210)
var cartas: Array = []          # [Carta x3], no estilo das cartas do HUD
const TITULOS_VERSO := ["Poção", "Efeito", "Ingredientes"]
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
	cartas.clear()
	_detalhe = null
	grade = null
	pentagono = null


## Monta o visual atual (escondido: entrar() mostra). res: o resultado do preparo.
func montar(res: Dictionary, A: Array) -> void:
	limpar()
	_res = res
	_A = A
	visible = true
	cartas = [_carta(C_CARTA1, TITULOS_VERSO[0]), _carta(C_CARTA2, TITULOS_VERSO[1]), _carta(C_CARTA3, TITULOS_VERSO[2])]
	_titulo = _label(26, HORIZONTAL_ALIGNMENT_CENTER, COR_TITULO)
	_titulo.position = Vector2(16, 14)
	_titulo.size = Vector2(C_CARTA1.size.x - 32, 68)
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cartas[0].face("Frente").add_child(_titulo)
	_montar_coluna()
	for c in cartas:
		c.modulate.a = 0.0

## Carta igual às do HUD (Carta.criar: sprite da carta, verso com pentagrama, virada na
## diagonal). O conteúdo vai na face "Frente".
func _carta(r: Rect2, titulo_verso: String) -> Carta:
	var c := Carta.criar(r.size, titulo_verso)
	c.position = r.position
	add_child(c)          # o _ready da Carta põe tudo no Giro
	return c

## Aparece de verso e vira aberta.
func _abrir_carta(c: Carta) -> void:
	c.fechar()
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.25)
	await tw.finished
	c.abrir()
	await get_tree().create_timer(c.tempo_virar + 0.1, true).timeout

## Vira para o verso e some.
func _fechar_carta(c: Carta) -> void:
	if c.modulate.a <= 0.01:
		return
	c.fechar()
	await get_tree().create_timer(c.tempo_virar + 0.15, true).timeout
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 0.0, 0.25)
	await tw.finished

## Coloca um nó numa carta, com a posição dada na tela.
func _na_carta(k: int, no: Control, pos_tela: Vector2) -> void:
	cartas[k].face("Frente").add_child(no)
	no.position = pos_tela - cartas[k].position


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
	grade.size = C_GRADE.size
	_na_carta(0, grade, C_GRADE.position)
	grade.modulate.a = 0.0
	_na_carta(0, _legenda("matriz", Vector2.ZERO), Vector2(C_GRADE.get_center().x - 150, C_GRADE.end.y + 8))
	pentagono = PentagonoOcean.new()
	pentagono.size = C_PENT.size
	_na_carta(1, pentagono, C_PENT.position)
	pentagono.modulate.a = 0.0
	_na_carta(1, _legenda("efeito numa pessoa neutra", Vector2.ZERO), Vector2(C_PENT.get_center().x - 150, C_PENT.end.y + 4))
	# ícones na ordem em que entraram (até 2 linhas; encolhem se forem muitos)
	var diags := _diags()
	var cab := _label(18, HORIZONTAL_ALIGNMENT_CENTER, COR_SUAVE)
	cab.text = "ingredientes  ·  toque para ver"
	cab.size = Vector2(C_CARTA3.size.x, 26)
	_na_carta(2, cab, C_CARTA3.position + Vector2(0, 14))
	var n: int = diags.size()
	var linhas: int = 1 if n <= 6 else 2
	var por_linha: int = maxi(1, ceili(n / float(linhas)))
	var y0: float = C_CARTA3.position.y + 48.0
	var cel: float = minf(C_CEL_MAX, minf((C_CARTA3.size.x - 40.0) / por_linha, (C_ICONES_FIM - y0) / linhas - 10.0))
	for i in n:
		var lin: int = floori(i / float(por_linha))
		var col: int = i % por_linha
		var n_lin: int = mini(por_linha, n - lin * por_linha)
		var x0: float = (640.0 - n_lin * cel) * 0.5
		var r := Rect2(x0 + col * cel, y0 + lin * (cel + 10), cel, cel + 10)
		var ic := IconeIngRes.new()
		ic.d = diags[i]
		ic.vistas = self
		ic.size = r.size
		_na_carta(2, ic, r.position)
		ic.modulate.a = 0.0
		_icones.append({"no": ic, "rect": r, "d": diags[i]})
	_detalhe = Control.new()
	_detalhe.position = C_DETALHE.position
	_detalhe.z_index = 10   # acima da moldura das cartas (z 3)
	_detalhe.size = C_DETALHE.size
	_detalhe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detalhe)


# =============================================================================
# ANIMAÇÃO (a JanelaResultado chama na ordem)
# =============================================================================
## Carta 1 (nome + matriz) aparece de verso e vira; a grade ainda espera a matriz.
func entrar() -> void:
	await _abrir_carta(cartas[0])


## A grade troca de lugar com a matriz do produtório (mesma posição e tamanho).
func mostrar_grade() -> void:
	if grade:
		grade.mostrar(_A)
		grade.modulate.a = 1.0


func mostrar_pentagono() -> void:
	if not pentagono:
		return
	await _abrir_carta(cartas[1])
	var tw := create_tween()
	tw.tween_property(pentagono, "modulate:a", 1.0, 0.4)
	await tw.finished
	pentagono.mostrar(_A)
	await get_tree().create_timer(0.8, true).timeout


## Coluna: os ícones aparecem um a um e o anel enche até o aproveitamento.
func mostrar_ingredientes() -> void:
	await _abrir_carta(cartas[2])
	# todos juntos: os ícones aparecem e os anéis enchem ao mesmo tempo
	for ic in _icones:
		var no = ic["no"]
		no.scale = Vector2(0.6, 0.6)
		no.pivot_offset = no.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(no, "modulate:a", 1.0, 0.2)
		tw.tween_property(no, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(no.set_anel, 0.0, 1.0, 0.5)
	await get_tree().create_timer(0.6, true).timeout


## Tudo pronto de uma vez (ao trocar de visual com a janela já aberta).
func mostrar_tudo() -> void:
	for c in cartas:
		c.modulate.a = 1.0
		c.abrir()
	for no in [grade, pentagono] + _nos_icones():
		if no:
			no.modulate.a = 1.0
	if grade:
		grade.mostrar(_A)
	if pentagono:
		pentagono.mostrar(_A, 0.01)
	for ic in _icones:
		ic["no"].set_anel(1.0)


## Confirmou: fecham as cartas 2 e 3 (a 1 fecha depois que a matriz vira poção).
func fechar_cartas_menores() -> void:
	_fechar_detalhe()
	_fechar_carta(cartas[2])
	await _fechar_carta(cartas[1])

func fechar_carta_nome() -> void:
	await _fechar_carta(cartas[0])


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
	for c in cartas:
		if c.get_global_rect().has_point(pos) and c != cartas[0]:
			return true   # toque dentro das cartas 2 e 3 não fecha
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
