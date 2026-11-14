# resultado_vistas.gd
# Tela de informações da poção pronta (dentro da JanelaResultado), em 3 cartas no estilo
# do HUD (Carta.criar), duas em cima e uma embaixo, que aparecem de verso e viram abertas, uma de cada vez:
#   1. nome + matriz (a matriz do produtório pousa nela);
#   2. pentágono O-C-E-A-N (efeito numa pessoa neutra);
#   3. ingredientes com o anel de aproveitamento (tocar num ícone abre os detalhes).
# Gráfico da temperatura sempre visível (tocar num ingrediente destaca o trecho dele).
# Tecla G (teste) troca onde ele fica (ResultadoVistas.modo_grafico):
#   0 CARTA3   em cima na carta de ingredientes, ícones e detalhe embaixo
#   1 CARTA4   uma 4ª carta só com o gráfico (2 cartas em cima, 2 embaixo)
#   2 DETALHE  ícones em cima; embaixo o detalhe do item e o gráfico fixo
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
const C_GRADE := Rect2(64, 186, 200, 200)     # mais embaixo na carta 1 (título em cima)
const C_PENT := Rect2(371, 116, 210, 210)     # com margem dentro da carta 2
const C_CEL_MAX: float = 96.0
const C_ICONES_FIM: float = 650.0             # ícones acima disto; o detalhe abre embaixo
const C_DETALHE := Rect2(30, 656, 580, 210)
enum ModoGrafico { CARTA3, CARTA4, DETALHE }
const NOMES_MODO_GRAFICO := ["gráfico em cima da carta de ingredientes", "gráfico numa 4ª carta", "gráfico fixo embaixo, com o detalhe"]
static var modo_grafico: int = ModoGrafico.DETALHE
var grafico: GraficoResultado
var _r_detalhe: Rect2 = C_DETALHE

## G alterna entre os dois escolhidos: fixo embaixo com o detalhe / 4ª carta (o "em cima da carta 3" saiu).
static func proximo_modo_grafico() -> void:
	modo_grafico = ModoGrafico.CARTA4 if modo_grafico == ModoGrafico.DETALHE else ModoGrafico.DETALHE

## Retângulos (tela) da carta de ingredientes, do gráfico, da área dos ícones e do detalhe, pelo modo.
func _layout() -> Dictionary:
	match modo_grafico:
		ModoGrafico.CARTA4:
			return {"carta3": Rect2(16, 456, 296, 420), "carta4": Rect2(328, 456, 296, 420),
				"grafico": Rect2(342, 500, 268, 170), "icones": Rect2(16, 456, 296, 420),
				"icones_y0": 504.0, "icones_fim": 860.0, "detalhe": Rect2(338, 680, 276, 186), "carta_grafico": 3}
		_:   # DETALHE (padrão)
			# ícones pequenos em cima, gráfico grande, detalhe do item embaixo
			return {"carta3": C_CARTA3, "grafico": Rect2(40, 562, 560, 240), "icones": C_CARTA3,
				"icones_y0": 498.0, "icones_fim": 556.0, "detalhe": Rect2(46, 806, 548, 64), "carta_grafico": 2}
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
	var lay := _layout()
	cartas = [_carta(C_CARTA1, ""), _carta(C_CARTA2, ""), _carta(lay["carta3"], "")]   # verso só com o pentagrama
	if lay.has("carta4"):
		cartas.append(_carta(lay["carta4"], ""))
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
	pentagono = PentagonoOcean.new()
	pentagono.size = C_PENT.size
	_na_carta(1, pentagono, C_PENT.position)
	pentagono.modulate.a = 0.0
	# gráfico da temperatura (sempre visível)
	var lay := _layout()
	_r_detalhe = lay["detalhe"]
	var rg: Rect2 = lay["grafico"]
	grafico = GraficoResultado.new()
	grafico.size = rg.size
	grafico.configurar(_res.get("historico_T", []), _inicio(), float(_res.get("t_final", 1.0)), _diags())
	grafico.definir_receita(_res.get("receita", {}))
	_na_carta(int(lay["carta_grafico"]), grafico, rg.position)
	grafico.modulate.a = 0.0
	# ícones na ordem em que entraram (encolhem se forem muitos)
	var diags := _diags()
	var ri: Rect2 = lay["icones"]
	var cab := _label(18, HORIZONTAL_ALIGNMENT_CENTER, COR_SUAVE)
	cab.text = "ingredientes  ·  toque para ver"
	cab.size = Vector2(ri.size.x, 26)
	_na_carta(2, cab, Vector2(ri.position.x, float(lay["icones_y0"]) - 34.0))
	var n: int = diags.size()
	var max_linha: int = 12 if ri.size.x > 400.0 else 3
	var linhas: int = maxi(1, ceili(n / float(max_linha)))
	var por_linha: int = maxi(1, ceili(n / float(linhas)))
	var y0: float = float(lay["icones_y0"])
	var cel: float = minf(C_CEL_MAX, minf((ri.size.x - 40.0) / por_linha, (float(lay["icones_fim"]) - y0) / linhas - 10.0))
	for i in n:
		var lin: int = floori(i / float(por_linha))
		var col: int = i % por_linha
		var n_lin: int = mini(por_linha, n - lin * por_linha)
		var x0: float = ri.position.x + (ri.size.x - n_lin * cel) * 0.5
		var r := Rect2(x0 + col * cel, y0 + lin * (cel + 10), cel, cel + 10)
		var ic := IconeIngRes.new()
		ic.d = diags[i]
		ic.num = i + 1
		ic.vistas = self
		ic.size = r.size
		_na_carta(2, ic, r.position)
		ic.modulate.a = 0.0
		_icones.append({"no": ic, "rect": r, "d": diags[i]})
	_detalhe = Control.new()
	_detalhe.position = _r_detalhe.position
	_detalhe.z_index = 10   # acima da moldura das cartas (z 3)
	_detalhe.size = _r_detalhe.size
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
	if cartas.size() > 3:
		_abrir_carta(cartas[3])   # carta do gráfico junto
	await _abrir_carta(cartas[2])
	if grafico == null:
		return
	# 1. o gráfico aparece com a curva ideal (se fez com receita)
	grafico.set_ideal_a(0.0)
	grafico.set_progresso(0.0)
	var tw := create_tween()
	tw.tween_property(grafico, "modulate:a", 1.0, 0.3)
	await tw.finished
	if grafico.tem_ideal():
		tw = create_tween()
		tw.tween_method(grafico.set_ideal_a, 0.0, 1.0, DUR_IDEAL)
		await tw.finished
	# 2. o T(t) do preparo vai sendo desenhado; cada item entra quando a curva passa por ele
	_icones_mostrados = 0
	tw = create_tween()
	tw.tween_method(_progresso_curva, 0.0, 1.0, DUR_CURVA)
	await tw.finished
	await get_tree().create_timer(0.3, true).timeout

const DUR_IDEAL: float = 0.6     # s: a curva ideal aparece
const DUR_CURVA: float = 2.2     # s: o T(t) é desenhado do começo ao fim
var _icones_mostrados: int = 0

func _progresso_curva(v: float) -> void:
	grafico.set_progresso(v)
	var t_corte: float = grafico.t_do_progresso(v)
	for i in range(_icones_mostrados, _icones.size()):
		if float(_icones[i]["d"].get("t0", 0.0)) > t_corte:
			break
		_icones_mostrados = i + 1
		var no = _icones[i]["no"]
		no.scale = Vector2(0.6, 0.6)
		no.pivot_offset = no.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(no, "modulate:a", 1.0, 0.15)
		tw.tween_property(no, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(no.set_anel, 0.0, 1.0, 0.45)


## Tudo pronto de uma vez (ao trocar de visual com a janela já aberta).
func mostrar_tudo() -> void:
	for c in cartas:
		c.modulate.a = 1.0
		c.abrir()
	for no in [grade, pentagono, grafico] + _nos_icones():
		if no:
			no.modulate.a = 1.0
	if grade:
		grade.mostrar(_A)
	if pentagono:
		pentagono.mostrar(_A, 0.01)
	if grafico:
		grafico.set_ideal_a(1.0)
		grafico.set_progresso(1.0)
	for ic in _icones:
		ic["no"].set_anel(1.0)


## Confirmou: fecham as cartas 2 e 3 (a 1 fecha depois que a matriz vira poção).
func fechar_cartas_menores() -> void:
	_fechar_detalhe()
	for k in range(cartas.size() - 1, 1, -1):
		_fechar_carta(cartas[k])
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
	fundo.size = _r_detalhe.size
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detalhe.add_child(fundo)
	var col := VBoxContainer.new()
	col.position = Vector2(12, 8)
	col.size = _r_detalhe.size - Vector2(24, 16)
	col.add_theme_constant_override("separation", 6)
	col.add_child(_linha_ing(d, false))   # a curva agora fica no gráfico fixo (destacada)
	if grafico:
		grafico.selecionar(_diags().find(d))
	_detalhe.add_child(col)
	_detalhe.modulate.a = 0.0
	_detalhe.create_tween().tween_property(_detalhe, "modulate:a", 1.0, 0.15)


func _fechar_detalhe() -> void:
	if grafico:
		grafico.selecionar(-1)
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
## Ícone pequeno de um ingrediente com o anel de aproveitamento: número da entrada no gráfico, ícone e %.
class IconeIngRes extends Control:
	var d: Dictionary
	var vistas: Control
	var num: int = 0
	var _f: float = 1.0

	func set_anel(f: float) -> void:
		_f = f
		queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var a: float = clampf(float(d.get("a", 0.0)), 0.0, 1.0)
		var fonte := get_theme_default_font()
		var tam_txt: int = clampi(int(size.x * 0.28), 10, 17)
		var lado: float = minf(size.x, size.y - tam_txt - 2.0) * 0.85
		var c := Vector2(size.x * 0.5, lado * 0.5 + 2.0)
		var item: ItemData = d.get("item")
		var r: float = lado * 0.5
		if item and item.icone:
			var li: float = lado * 0.7
			draw_texture_rect(item.icone, Rect2(c - Vector2(li, li) * 0.5, Vector2(li, li)), false)
		var esp: float = maxf(2.0, lado * 0.08)
		draw_arc(c, r - esp * 0.5, 0.0, TAU, 40, Color(1, 1, 1, 0.15), esp, true)
		if a * _f > 0.001:
			draw_arc(c, r - esp * 0.5, -PI * 0.5, -PI * 0.5 + TAU * a * _f, 40, IconesCaldeirao.cor_aproveitamento(a), esp, true)
		if num > 0:
			draw_string(fonte, Vector2(1, tam_txt), str(num), HORIZONTAL_ALIGNMENT_LEFT, -1, tam_txt - 2, Color(1, 1, 1, 0.75))
		draw_string(fonte, Vector2(0, size.y - 2), "%d%%" % roundi(a * _f * 100.0), HORIZONTAL_ALIGNMENT_CENTER, size.x, tam_txt, IconesCaldeirao.cor_aproveitamento(a))


# -----------------------------------------------------------------------------
## Gráfico T(t) do preparo inteiro (da entrada do 1º ingrediente ao fim), com a entrada de
## cada ingrediente numerada. Selecionado: o trecho do ingrediente (da entrada dele ao fim)
## fica pintado na cor da chama em que ele entrou.
class GraficoResultado extends Control:
	const T_BAIXO: float = 20.0
	const T_ALTO: float = 180.0
	var _hist: Array = []
	var _ti: float = 0.0
	var _tf: float = 1.0
	var _diags: Array = []
	var _sel: int = -1
	var _f: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_f = get_theme_default_font()

	func configurar(hist: Array, ti: float, tf: float, diags: Array) -> void:
		_hist = hist
		_ti = ti
		_tf = maxf(tf, ti + 0.001)
		_diags = diags
		queue_redraw()

	## Receita memorizada: faixa de T ideal (estado da chama de cada passo) ao longo do tempo,
	## contando do 1º ingrediente; cada passo de ingrediente dura os seus "seg".
	var _ideal: Array = []   # [t0, t1, estado]
	func definir_receita(rec: Dictionary) -> void:
		_ideal.clear()
		var t := _ti
		var ini := _ti
		var est := ""
		for s in rec.get("passos", []):
			if s.get("tipo") == "chama":
				if est != "" and t > ini:
					_ideal.append([ini, t, est])
				est = str(s.get("estado", ""))
				ini = t
			elif s.get("tipo") == "ingrediente":
				t += float(s.get("seg", 0.0))
		if est != "" and t > ini:
			_ideal.append([ini, t, est])
		if not _ideal.is_empty():
			_tf = maxf(_tf, t)
		queue_redraw()

	func selecionar(i: int) -> void:
		_sel = i
		queue_redraw()

	# animação: alfa da curva ideal e quanto do T(t) já foi desenhado (0..1)
	var _ideal_a: float = 1.0
	var _prog: float = 1.0
	func set_ideal_a(v: float) -> void:
		_ideal_a = v
		queue_redraw()
	func set_progresso(v: float) -> void:
		_prog = v
		queue_redraw()
	func tem_ideal() -> bool:
		return not _ideal.is_empty()
	func t_do_progresso(v: float) -> float:
		return _ti + (_tf - _ti) * v

	func _p(t: float, T: float) -> Vector2:
		var x: float = 8.0 + (size.x - 16.0) * clampf((t - _ti) / (_tf - _ti), 0.0, 1.0)
		var y: float = size.y - 16.0 - (size.y - 30.0) * clampf((T - T_BAIXO) / (T_ALTO - T_BAIXO), 0.0, 1.0)
		return Vector2(x, y)

	func _T_em(t: float) -> float:
		var T := T_BAIXO
		for p in _hist:
			if float(p.get("t", 0.0)) > t:
				break
			T = float(p.get("T", T_BAIXO))
		return T

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
		var y100: float = _p(_ti, 100.0).y
		draw_line(Vector2(8, y100), Vector2(size.x - 8, y100), Color(1, 1, 1, 0.15), 1.0)
		draw_string(_f, Vector2(10, y100 - 3), "100 °C", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.4))
		# curva ideal da receita (atrás): faixa do estado da chama + linha tracejada no meio
		var prev := Vector2.INF
		for seg in _ideal:
			var e: Dictionary = EstadosChama.LISTA[maxi(0, EstadosChama.indice(seg[2]))]
			var lo: float = clampf(float(e["T_min"]), T_BAIXO, T_ALTO)
			var hi: float = clampf(float(e["T_max"]), T_BAIXO, T_ALTO)
			var a0 := _p(seg[0], hi)
			var a1 := _p(seg[1], lo)
			draw_rect(Rect2(a0, a1 - a0), Color(e["cor"], 0.22 * _ideal_a))
			var m0 := _p(seg[0], (lo + hi) * 0.5)
			var m1 := _p(seg[1], (lo + hi) * 0.5)
			if prev != Vector2.INF:
				draw_dashed_line(prev, m0, Color(1, 1, 1, 0.45 * _ideal_a), 1.5, 5.0)
			draw_dashed_line(m0, m1, Color(1, 1, 1, 0.55 * _ideal_a), 1.5, 5.0)
			prev = m1
		if not _ideal.is_empty():
			draw_string(_f, Vector2(size.x - 8 - _f.get_string_size("- - ideal", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, 12), "- - ideal", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6 * _ideal_a))
		var corte: float = t_do_progresso(_prog)
		var pts := PackedVector2Array()
		for p in _hist:
			var t: float = float(p.get("t", 0.0))
			if t < _ti or t > corte:
				continue
			pts.append(_p(t, float(p.get("T", T_BAIXO))))
		if _prog < 1.0 and pts.size() >= 1:
			draw_circle(pts[pts.size() - 1], 4.0, Color(1, 0.95, 0.8))   # ponta da caneta
		# trecho do ingrediente selecionado: área na cor da chama em que entrou
		if _sel >= 0 and _sel < _diags.size() and _prog >= 1.0:
			var t0: float = float(_diags[_sel].get("t0", _ti))
			var cor: Color = LinhaTempo.cor_da_temperatura(_T_em(t0))
			var area := PackedVector2Array()
			var base: float = size.y - 16.0
			area.append(Vector2(_p(t0, 0).x, base))
			for p in _hist:
				var t: float = float(p.get("t", 0.0))
				if t >= t0 and t <= _tf:
					area.append(_p(t, float(p.get("T", T_BAIXO))))
			area.append(Vector2(_p(_tf, 0).x, base))
			if area.size() >= 3:
				draw_colored_polygon(area, Color(cor, 0.35))
		if pts.size() >= 2:
			draw_polyline(pts, Color(1, 0.9, 0.7, 0.95), 2.0, true)
		# entradas numeradas
		for i in _diags.size():
			var t0: float = float(_diags[i].get("t0", _ti))
			if t0 > corte:
				continue   # a curva ainda não chegou neste item
			var q := _p(t0, _T_em(t0))
			var sel: bool = i == _sel
			draw_circle(q, 9.0 if sel else 7.0, Color(0.1, 0.08, 0.12, 0.9))
			draw_circle(q, 7.0 if sel else 5.5, Color(1, 0.85, 0.4) if sel else Color(1, 1, 1, 0.6))
			var txt := str(i + 1)
			var w := _f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(_f, q + Vector2(-w * 0.5, -11), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
		var fim := "%d s" % roundi(_tf - _ti)
		draw_string(_f, Vector2(size.x - 8 - _f.get_string_size(fim, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, size.y - 3), fim, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
		draw_string(_f, Vector2(8, size.y - 3), "0 s", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
		if _sel >= 0 and _sel < _diags.size():
			var t0s: float = float(_diags[_sel].get("t0", _ti))
			var info := "entrou aos %d s · %d °C" % [roundi(t0s - _ti), roundi(_T_em(t0s))]
			draw_string(_f, Vector2(size.x * 0.5 - _f.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5, 14), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.6))
