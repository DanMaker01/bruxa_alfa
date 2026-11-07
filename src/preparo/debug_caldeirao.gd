# debug_caldeirao.gd
# Camada de debug da cena de preparo, em duas colunas:
#   direita:  "Itens" (GabaritoCaldeirao): eixo de T da panela + um card por ingrediente
#             (T, tempo, cozimento, com números). Rola.
#   esquerda: abas
#             Sistema = cards ao vivo (agora, equilíbrio, depois de abanar, depois de
#                       ingrediente, constantes)
#             Testes  = testes automáticos do sistema térmico, em cards
#   (os modos M / P / T / C / K continuam só nas teclas)
# Fica por cima da bruxa chibi (z_index acima do dela).
#   embaixo:  gráfico T(t)
# O "Na panela" antigo e o texto antigo dos indicadores ficam escondidos aqui dentro.
class_name DebugCaldeirao
extends Control

const COR_FUNDO := Color(0.04, 0.04, 0.08, 0.85)
const COR_TITULO := Color(1.0, 0.85, 0.45)
const COR_TEXTO := Color(0.85, 0.85, 0.9)
const COR_SUAVE := Color(0.6, 0.6, 0.7)

const CAIXA_ESQ := Rect2(4, 108, 168, 444)
const CAIXA_DIR := Rect2(466, 6, 170, 546)
const LARG_CONTEUDO: float = 156.0

var cena = null
var gabarito: GabaritoCaldeirao
var _sistema: PainelSistema
var _testes: VBoxContainer
var _cards_testes: CardsTestes
var _status_testes: Label
var _paginas: Array = []      # [sistema, testes] (ScrollContainers)
var _botoes_aba: Array = []
var _rodando: bool = false


func _ready() -> void:
	name = "DebugCaldeirao"
	z_index = 7   # bruxa chibi (ReacaoBruxa) usa 6
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Recebe os nós que já existem na cena e reorganiza dentro desta camada.
func configurar(indicadores_label: Label, grafico: Control, painel: Control, p_cena = null) -> void:
	cena = p_cena
	# ---- antigos: guardados e escondidos ----
	for velho in [indicadores_label, painel]:
		if velho:
			velho.get_parent().remove_child(velho)
			add_child(velho)
			velho.visible = false
	if painel and "oculto" in painel:
		painel.oculto = true

	# ---- direita: itens ----
	var dir := _caixa(CAIXA_DIR)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	dir.add_child(sc)
	gabarito = GabaritoCaldeirao.new()
	gabarito.configurar(cena)
	sc.add_child(gabarito)

	# ---- esquerda: abas ----
	var esq := _caixa(CAIXA_ESQ)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	esq.add_child(col)
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 2)
	col.add_child(barra)
	for i in 2:
		var b := Button.new()
		b.text = ["Sistema", "Testes"][i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_stylebox_override("normal", _estilo(Color(1, 1, 1, 0.05)))
		b.add_theme_stylebox_override("hover", _estilo(Color(1, 1, 1, 0.1)))
		b.add_theme_stylebox_override("pressed", _estilo(Color(COR_TITULO, 0.3)))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_mostrar_aba.bind(i))
		barra.add_child(b)
		_botoes_aba.append(b)

	# Sistema
	_sistema = PainelSistema.new()
	_sistema.cena = cena
	_paginas.append(_pagina(col, _sistema))
	# Testes
	_testes = VBoxContainer.new()
	_testes.add_theme_constant_override("separation", 4)
	_testes.custom_minimum_size.x = LARG_CONTEUDO
	var b_sis := _botao("Testar sistema térmico")
	b_sis.pressed.connect(_rodar_testes.bind(false))
	# (botão "Testar ingredientes" tirado por enquanto: demorava muito. TestesCaldeirao.ingrediente() continua lá)
	_status_testes = Label.new()
	_status_testes.add_theme_font_size_override("font_size", 11)
	_status_testes.add_theme_color_override("font_color", COR_SUAVE)
	_status_testes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_testes.custom_minimum_size.x = LARG_CONTEUDO
	_status_testes.text = "Simulação separada: não mexe no caldeirão."
	_cards_testes = CardsTestes.new()
	for n in [b_sis, _status_testes, _cards_testes]:
		_testes.add_child(n)
	_paginas.append(_pagina(col, _testes))
	_mostrar_aba(0)

	# ---- embaixo: gráfico (mantém a posição da cena) ----
	if grafico:
		var pos: Vector2 = grafico.position
		grafico.get_parent().remove_child(grafico)
		add_child(grafico)
		grafico.position = pos
		grafico.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pagina(col: VBoxContainer, conteudo: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(conteudo)
	col.add_child(sc)
	return sc

func _mostrar_aba(i: int) -> void:
	for k in _paginas.size():
		_paginas[k].visible = k == i
		_botoes_aba[k].set_pressed_no_signal(k == i)


## (a CenaPreparo chama ao trocar modo; os modos saíram do debug)
func atualizar_modos() -> void:
	pass


# =============================================================================
# TESTES
# =============================================================================
func _rodar_testes(ingredientes: bool) -> void:
	if _rodando:
		return
	_rodando = true
	var res: Array = []
	if not ingredientes:
		_status_testes.text = "rodando sistema..."
		await get_tree().process_frame
		res = TestesCaldeirao.sistema()
	else:
		var db = cena.get("database") if cena else null
		var itens: Array = []
		if db and db.has_method("get_items"):
			var todos: Dictionary = db.get_items()
			var ids: Array = todos.keys()
			ids.sort()
			for id in ids:
				if TestesCaldeirao.eh_ingrediente(todos[id]):
					itens.append(todos[id])
		for k in itens.size():
			_status_testes.text = "ingrediente %d/%d: %s" % [k + 1, itens.size(), itens[k].get_nome()]
			await get_tree().process_frame
			res.append(TestesCaldeirao.ingrediente(itens[k]))
	var ok := 0
	var falha := 0
	for r in res:
		if r["ok"] == true:
			ok += 1
		elif r["ok"] == false:
			falha += 1
	_status_testes.text = "%d testes: %d ok, %d falharam, %d só info" % [res.size(), ok, falha, res.size() - ok - falha]
	_cards_testes.mostrar(res)
	_rodando = false


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
	var st := _estilo(COR_FUNDO)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", st)
	add_child(p)
	return p

func _estilo(cor: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = cor
	st.border_color = Color(1, 1, 1, 0.08)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(4)
	return st

func _botao(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(LARG_CONTEUDO, 30)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", _estilo(Color(1, 1, 1, 0.06)))
	b.add_theme_stylebox_override("hover", _estilo(Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("pressed", _estilo(Color(COR_TITULO, 0.3)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


# =============================================================================
# Base dos cards desenhados (leve: tudo em _draw)
# =============================================================================
class Cards extends Control:
	const L: float = 156.0
	const COR_CARD := Color(1, 1, 1, 0.05)
	const COR_T := Color(1.0, 0.85, 0.45)
	const COR_X := Color(0.85, 0.85, 0.9)
	const COR_S := Color(0.6, 0.6, 0.7)
	const COR_OK := Color(0.3, 0.9, 0.45)
	const COR_RUIM := Color(1.0, 0.35, 0.3)
	const COR_AZUL := Color(0.4, 0.65, 1.0)
	var _f: Font
	var _y: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_f = get_theme_default_font()
		custom_minimum_size = Vector2(L, 10)

	func txt(x: float, y: float, s: String, tam: int, cor: Color) -> void:
		draw_string(_f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, L - x - 4, tam, cor)

	func txt_dir(y: float, s: String, tam: int, cor: Color) -> void:
		var w := _f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_f, Vector2(L - 6 - w, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)

	## Desenha o fundo de um card com título; devolve o y do topo.
	func card(titulo: String, linhas: int, extra: float = 0.0, cor_titulo: Color = COR_T) -> float:
		var h := 22.0 + linhas * 13.0 + extra + 4.0
		draw_rect(Rect2(0, _y, L, h), COR_CARD)
		txt(5, _y + 14, titulo, 12, cor_titulo)
		var topo := _y
		_y += h + 5.0
		return topo

	## Barra horizontal com valor (0..1) e marca opcional (0..1).
	func barra(x: float, y: float, w: float, v: float, cor: Color, marca: float = -1.0) -> void:
		draw_rect(Rect2(x, y, w, 5), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(x, y, w * clampf(v, 0.0, 1.0), 5), cor)
		if marca >= 0.0:
			draw_line(Vector2(x + w * marca, y - 2), Vector2(x + w * marca, y + 7), Color(1, 1, 1, 0.7), 1.0)

	func fim() -> void:
		if absf(custom_minimum_size.y - _y) > 0.5:
			custom_minimum_size = Vector2(L, _y)


# =============================================================================
# SISTEMA: cards ao vivo
# =============================================================================
class PainelSistema extends Cards:
	var cena = null

	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		_y = 0.0
		var s = cena.get("sistema") if cena else null
		var ind = cena.get("indicadores") if cena else null
		if s == null:
			txt(4, 14, "sem sistema", 12, COR_S)
			return
		# ---- agora ----
		var y := card("Agora   t %.1f s" % s.t_sim, 4, 16)
		txt(5, y + 32, "T %.1f °C" % s.T, 12, COR_X)
		barra(70, y + 25, L - 76, s.T / 250.0, COR_RUIM if s.T > SistemaTermico.T_EQ + 1.0 else COR_OK, SistemaTermico.T_EQ / 250.0)
		txt(5, y + 50, "F %d °C" % roundi(s.F), 12, COR_X)
		var cf: Color = s.get_cor_fogo()
		cf.a = 1.0
		barra(70, y + 43, L - 76, s.F / 2000.0, cf if s.fogo_ligado else COR_S, SistemaTermico.F_EQ / 2000.0)
		txt(5, y + 66, "fogo %s   %d%%" % ["ligado" if s.fogo_ligado else "apagado", roundi(s.get_intensidade_fogo() * 100.0)], 11, cf if s.fogo_ligado else COR_S)
		txt(5, y + 80, "equilíbrio  T %s   F %s" % [_v(s.esta_em_equilibrio_T()), _v(s.esta_em_equilibrio_F())], 11, COR_X)
		if ind == null:
			fim()
			return
		# ---- equilíbrio (desde o último acender) ----
		y = card("Equilíbrio (desde acender)", 2)
		var desde: float = s.t_sim - s.t_fogo_ligado
		txt(5, y + 32, "T 100 °C:  " + _tempo(ind.t_star_T, s.fogo_ligado and not ind.t_star_T_done, desde), 11, COR_X)
		txt(5, y + 45, "F 800 °C:  " + _tempo(ind.t_star_F, s.fogo_ligado and not ind.t_star_F_done, desde), 11, COR_X)
		# ---- depois de abanar (A) ----
		y = card("Depois de abanar (A)", 4)
		if ind.t_A0 < 0.0:
			txt(5, y + 32, "abane o fogo para medir", 11, COR_S)
		else:
			var dA: float = ind.t_A_star - ind.t_A0 if ind.t_A_star >= 0.0 else -1.0
			var t_pico: float = ind.T_max_A_t - ind.t_A0 if ind.T_max_A_t >= 0.0 else -1.0
			txt(5, y + 32, "F volta: " + _tempo(dA, dA < 0.0, s.t_sim - ind.t_A0), 11, COR_X)
			txt(5, y + 45, "pico T %s (%s)" % [ind.fmt_C(ind.T_max_A), ind.fmt_d(ind.T_base_A, ind.T_max_A)], 11, COR_RUIM)
			txt(5, y + 58, "  em " + ind.fmt_t(t_pico), 11, COR_S)
			txt(5, y + 71, "pico F %s (%s)" % [ind.fmt_C(ind.F_max_A), ind.fmt_d(ind.F_base_A, ind.F_max_A)], 11, COR_X)
		# ---- depois de ingrediente (I) ----
		y = card("Depois de ingrediente (I)", 3)
		if ind.t_I0 < 0.0:
			txt(5, y + 32, "coloque um ingrediente", 11, COR_S)
		else:
			var dI: float = ind.t_I_star - ind.t_I0 if ind.t_I_star >= 0.0 else -1.0
			txt(5, y + 32, "T volta a 100: " + _tempo(dI, dI < 0.0, s.t_sim - ind.t_I0), 11, COR_X)
			txt(5, y + 45, "vale T %s (%s)" % [ind.fmt_C(ind.T_min_I), ind.fmt_d(ind.T_base_I, ind.T_min_I)], 11, COR_AZUL)
			txt(5, y + 58, "vale F %s (%s)" % [ind.fmt_C(ind.F_min_I), ind.fmt_d(ind.F_base_I, ind.F_min_I)], 11, COR_X)
		# ---- constantes ----
		var cs := [
			["T_EQ", SistemaTermico.T_EQ], ["F_EQ", SistemaTermico.F_EQ], ["T_AMB", SistemaTermico.T_AMB],
			["K", SistemaTermico.K], ["HF", SistemaTermico.HF], ["C", SistemaTermico.C], ["C_F", SistemaTermico.C_F],
			["h", s.h], ["P_comb", s.P_comb], ["abanar+", SistemaTermico.CONST_A],
			["abafar-", SistemaTermico.CONST_C], ["ingred-", SistemaTermico.CONST_B], ["apaga<", SistemaTermico.F_LIMIT_MIN],
		]
		var linhas: int = ceili(cs.size() / 2.0)
		y = card("Constantes", linhas)
		for k in cs.size():
			var cx: float = 5.0 if k % 2 == 0 else L * 0.5 + 2.0
			var cy: float = y + 32 + (k / 2) * 13.0
			txt(cx, cy, "%s %s" % [cs[k][0], _num(cs[k][1])], 10, COR_X)
		fim()

	func _v(b: bool) -> String:
		return "✓" if b else "✗"

	func _num(v: float) -> String:
		return str(snappedf(v, 0.001)).trim_suffix(".0")

	## Tempo medido; "medindo… Ns" enquanto não chegou.
	func _tempo(v: float, medindo: bool, decorrido: float) -> String:
		if v >= 0.0:
			return "%.1f s" % v
		return ("medindo… %.0f s" % decorrido) if medindo else "—"


# =============================================================================
# TESTES: cards de resultado
# =============================================================================
class CardsTestes extends Cards:
	var _res: Array = []

	func mostrar(res: Array) -> void:
		_res = res
		queue_redraw()

	func _draw() -> void:
		_y = 0.0
		for r in _res:
			var ok = r.get("ok")
			var cor: Color = COR_OK if ok == true else (COR_RUIM if ok == false else COR_S)
			var linhas: Array = r.get("linhas", [])
			var y := card(str(r.get("titulo", "")), linhas.size())
			txt_dir(y + 14, "✓" if ok == true else ("✗" if ok == false else "•"), 13, cor)
			draw_rect(Rect2(0, y, 3, 26.0 + linhas.size() * 13.0), cor)
			for k in linhas.size():
				var l: String = str(linhas[k])
				txt(8, y + 32 + k * 13.0, l, 10, COR_RUIM if l.begins_with("!") else COR_X)
		fim()
