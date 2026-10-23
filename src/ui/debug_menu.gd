# debug_menu.gd
# Menu de debug (tecla ' ): edita variáveis, personalidades e inventário do GameTemp
# e roda comandos de evento na hora (aba "Comandos", ver debug_comandos.gd)
# em tempo de jogo. Construído todo por código; o GameManager cria na primeira vez.
# Também abre/fecha pelo botão "DBG" no canto (0,0) da tela.
extends Control
class_name DebugMenu

const TRACOS := ["O", "C", "E", "A", "N"]
const FONTE: int = 22            # fonte do menu
## Altura mínima de botões, campos e caixas de marcar (bom para o dedo no celular).
const ALTURA_TOQUE: float = 56.0
const COR_TEXTO := Color(0.95, 0.93, 0.88)
const BOTAO_DBG := Vector2(96, 64)
const COR_FUNDO := Color(0.32, 0.32, 0.34, 0.98)       # cinza do painel
const COR_FUNDO_FICHA := Color(0.26, 0.26, 0.28, 0.99)
const COR_CELULA := Color(0.38, 0.38, 0.4)
const TAM_CHECK: int = 40                              # caixa de marcar (px)
const COR_CHECK := Color(1.0, 0.8, 0.3)

var game_temp = null
var database = null
var ferramentas: FerramentasDebug = null   # ações da aba "Mapa"

var _abas: TabContainer
var _lista_vars: VBoxContainer
var _lista_pers: VBoxContainer
var _lista_itens: VBoxContainer
var _lista_mapa: VBoxContainer
var _comandos: DebugComandos
var _seletor_item: OptionButton
var _qtd_novo: SpinBox
var _info: PanelContainer      # ficha do item (abre por cima das abas)
var _info_conteudo: VBoxContainer
var _pausado_antes: bool = false
var _janela: Control        # fundo + painel (o que abre/fecha)
var _botao: Button          # botão fixo no canto (0,0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# o nó raiz fica sempre visível (por causa do botão) e não bloqueia cliques;
	# quem bloqueia é o fundo da janela, só quando aberta.
	# (set_anchors_AND_OFFSETS: só set_anchors_preset deixava tamanho 0 e o conteúdo sumia)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _criar_tema()
	_montar()
	_montar_botao()
	_janela.hide()

## Tema próprio do menu: o tema do jogo tem Label preto (some no fundo escuro) e fonte 24.
func _criar_tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONTE
	for tipo in ["Label", "Button", "LineEdit", "CheckBox", "OptionButton", "SpinBox", "PopupMenu", "TabBar", "TabContainer"]:
		t.set_font_size("font_size", tipo, FONTE)
		t.set_color("font_color", tipo, COR_TEXTO)
	for tipo in ["Button", "CheckBox", "OptionButton"]:
		t.set_color("font_hover_color", tipo, Color.WHITE)
		t.set_color("font_pressed_color", tipo, Color(1.0, 0.8, 0.3))
		t.set_color("font_focus_color", tipo, Color.WHITE)
	for tipo in ["TabBar", "TabContainer"]:
		t.set_color("font_selected_color", tipo, Color(1.0, 0.8, 0.3))
		t.set_color("font_unselected_color", tipo, COR_TEXTO.darkened(0.25))
		t.set_color("font_hovered_color", tipo, Color.WHITE)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	# caixas de marcar grandes e claras (as padrão somem no fundo)
	var vazio := _icone_check(false)
	var marcado := _icone_check(true)
	t.set_icon("unchecked", "CheckBox", vazio)
	t.set_icon("checked", "CheckBox", marcado)
	t.set_icon("unchecked_disabled", "CheckBox", vazio)
	t.set_icon("checked_disabled", "CheckBox", marcado)
	t.set_constant("h_separation", "CheckBox", 8)
	return t

## Desenha a caixa: borda branca; marcada = preenchida em dourado com um "v" escuro.
static func _icone_check(marcado: bool) -> ImageTexture:
	var n := TAM_CHECK
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var borda := 2
	for x in n:
		for y in n:
			var na_borda := x < borda or y < borda or x >= n - borda or y >= n - borda
			if na_borda:
				img.set_pixel(x, y, Color.WHITE)
			elif marcado:
				img.set_pixel(x, y, COR_CHECK)
			else:
				img.set_pixel(x, y, Color(0.15, 0.15, 0.17, 0.9))
	if marcado:
		# "v": desce de (5,12) até (10,17) e sobe até (19,6), com 3 px de espessura
		var pontos := [Vector2(5, 12), Vector2(10, 17), Vector2(19, 6)]
		for k in 2:
			var a: Vector2 = pontos[k] * (n / 24.0)
			var b: Vector2 = pontos[k + 1] * (n / 24.0)
			for i in 40:
				var p := a.lerp(b, i / 39.0)
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
						if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
							img.set_pixelv(q, Color(0.12, 0.1, 0.05))
	return ImageTexture.create_from_image(img)

func aberto() -> bool:
	return _janela != null and _janela.visible

# =============================================================================
# ABRIR / FECHAR  (tecla ')
# =============================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_APOSTROPHE or event.unicode == 39:
			alternar()
			get_viewport().set_input_as_handled()

func alternar() -> void:
	if aberto():
		fechar()
	else:
		abrir()

func abrir() -> void:
	_pausado_antes = get_tree().paused
	get_tree().paused = true
	_atualizar_tudo()
	_janela.show()
	_conectar_sinais()

func fechar() -> void:
	if _info:
		_info.hide()
	if _comandos:
		_comandos.fechar_ficha()
	_janela.hide()
	get_tree().paused = _pausado_antes

func _conectar_sinais() -> void:
	if game_temp and game_temp.has_signal("inventory_changed") \
			and not game_temp.inventory_changed.is_connected(_on_inventario_mudou):
		game_temp.inventory_changed.connect(_on_inventario_mudou)

func _on_inventario_mudou() -> void:
	if aberto():
		_atualizar_itens()

# =============================================================================
# MONTAGEM
# =============================================================================
func _montar() -> void:
	_janela = Control.new()
	_janela.name = "Janela"
	_janela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_janela)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_janela.add_child(fundo)

	var painel := PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	painel.offset_left = 10
	painel.offset_top = 24
	painel.offset_right = -10
	painel.offset_bottom = -24
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = Color(1.0, 0.75, 0.2)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(12)
	painel.add_theme_stylebox_override("panel", estilo)
	_janela.add_child(painel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	painel.add_child(col)

	var topo := HBoxContainer.new()
	var titulo := Label.new()
	titulo.text = "DEBUG  ( ' fecha )"
	titulo.add_theme_font_size_override("font_size", FONTE + 4)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fechar_btn := Button.new()
	fechar_btn.text = "  X  "
	fechar_btn.pressed.connect(fechar)
	topo.add_child(titulo)
	topo.add_child(fechar_btn)
	col.add_child(topo)

	_abas = TabContainer.new()
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_abas)

	_lista_vars = _criar_aba("Variáveis")
	_lista_pers = _criar_aba("Personalidade")
	_lista_itens = _criar_aba("Itens")
	_lista_mapa = _criar_aba("Mapa")
	var scroll_cmd := ScrollContainer.new()
	scroll_cmd.name = "Comandos"
	scroll_cmd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_comandos = DebugComandos.new(self)
	scroll_cmd.add_child(_comandos)
	_abas.add_child(scroll_cmd)
	_montar_info()
	_ajustar_toque(_janela)

func _montar_botao() -> void:
	_botao = Button.new()
	_botao.name = "BotaoDebug"
	_botao.text = "DEBUG"
	_botao.position = Vector2.ZERO
	_botao.custom_minimum_size = BOTAO_DBG
	_botao.focus_mode = Control.FOCUS_NONE
	_botao.modulate.a = 0.6
	_botao.add_theme_font_size_override("font_size", 24)
	_botao.pressed.connect(alternar)
	add_child(_botao)   # depois da janela: fica por cima e fecha o menu também

func _criar_aba(nome: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = nome
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	scroll.add_child(lista)
	_abas.add_child(scroll)
	return lista

func _limpar(caixa: Container) -> void:
	for c in caixa.get_children():
		caixa.remove_child(c)
		c.queue_free()

func _rotulo(texto: String, largura: float = 0.0) -> Label:
	var l := Label.new()
	l.text = texto
	if largura > 0.0:
		l.custom_minimum_size.x = largura
	else:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	return l

func _atualizar_tudo() -> void:
	_atualizar_vars()
	_atualizar_pers()
	_atualizar_itens()
	_atualizar_mapa()
	if _comandos:
		_comandos.atualizar()

# =============================================================================
# VARIÁVEIS
# =============================================================================
func _atualizar_vars() -> void:
	_limpar(_lista_vars)
	if not game_temp:
		_lista_vars.add_child(_rotulo("GameTemp não encontrado"))
		return
	var vars: Dictionary = game_temp.get_all_vars()
	var nomes: Array = vars.keys()
	nomes.sort()
	for nome in nomes:
		var linha := HBoxContainer.new()
		linha.add_child(_rotulo(str(nome)))
		var valor = vars[nome]
		if typeof(valor) == TYPE_BOOL:
			var cb := CheckBox.new()
			cb.button_pressed = valor
			cb.toggled.connect(func(v: bool): game_temp.set_var(nome, v))
			linha.add_child(cb)
		else:
			var campo := LineEdit.new()
			campo.text = str(valor)
			campo.custom_minimum_size.x = 130
			var aplicar := func(_t = ""):
				if campo.text.is_valid_float():
					game_temp.set_var(nome, float(campo.text))
				else:
					campo.text = str(game_temp.get_var(nome))
			campo.text_submitted.connect(aplicar)
			campo.focus_exited.connect(aplicar)
			linha.add_child(campo)
		_lista_vars.add_child(linha)
	_ajustar_toque(_lista_vars)


# =============================================================================
# PERSONALIDADES
# =============================================================================
func _atualizar_pers() -> void:
	_limpar(_lista_pers)
	if not game_temp:
		return
	var pers: Dictionary = game_temp.get_all_personalities()
	var cab := HBoxContainer.new()
	for t in TRACOS:
		var l := _rotulo(t)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cab.add_child(l)
	_lista_pers.add_child(cab)
	for nome in pers:
		_lista_pers.add_child(_secao(str(nome)))   # nome em cima, valores embaixo
		var linha := HBoxContainer.new()
		var valores: Array = pers[nome]
		for i in TRACOS.size():
			var sb := SpinBox.new()
			sb.min_value = -100.0
			sb.max_value = 100.0
			sb.step = 0.1
			sb.custom_minimum_size.x = 0
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.get_line_edit().custom_minimum_size.x = 0
			sb.get_line_edit().add_theme_constant_override("minimum_character_width", 0)
			sb.value = float(valores[i]) if i < valores.size() else 0.0
			sb.value_changed.connect(_on_traco_mudou.bind(nome, i))
			linha.add_child(sb)
		_lista_pers.add_child(linha)
	_ajustar_toque(_lista_pers)


func _on_traco_mudou(valor: float, nome: String, i: int) -> void:
	var atual: Array = game_temp.get_personality(nome).duplicate()
	while atual.size() < TRACOS.size():
		atual.append(0.0)
	atual[i] = valor
	game_temp.set_personality(nome, atual)

# =============================================================================
# ITENS
# =============================================================================
func _atualizar_itens() -> void:
	_limpar(_lista_itens)
	if not game_temp:
		return

	# ---- adicionar qualquer item do banco ----
	var add := HBoxContainer.new()
	_seletor_item = OptionButton.new()
	_seletor_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seletor_item.clip_text = true
	_seletor_item.custom_minimum_size.x = 0
	_seletor_item.fit_to_longest_item = false
	if database and database.has_method("get_items"):
		var itens: Dictionary = database.get_items()
		var ids: Array = itens.keys()
		ids.sort()
		for id in ids:
			_seletor_item.add_item("%s (%s)" % [itens[id].get_nome(), id])
			_seletor_item.set_item_metadata(_seletor_item.item_count - 1, id)
	_qtd_novo = SpinBox.new()
	_qtd_novo.min_value = 1
	_qtd_novo.max_value = 999
	_qtd_novo.value = 1
	var btn := Button.new()
	btn.text = "Adicionar"
	btn.pressed.connect(func():
		if _seletor_item.item_count > 0:
			game_temp.add_item(str(_seletor_item.get_selected_metadata()), int(_qtd_novo.value)))
	var ver := Button.new()
	ver.text = "Ver"
	ver.pressed.connect(func():
		if _seletor_item.item_count > 0:
			mostrar_item(str(_seletor_item.get_selected_metadata())))
	add.add_child(_seletor_item)
	add.add_child(ver)
	add.add_child(_qtd_novo)
	add.add_child(btn)
	_lista_itens.add_child(add)
	_lista_itens.add_child(HSeparator.new())

	# ---- inventário atual ----
	var inv: Dictionary = game_temp.get_inventory()
	if inv.is_empty():
		_lista_itens.add_child(_rotulo("(inventário vazio)"))
	for id in inv:
		var linha := HBoxContainer.new()
		var item = database.get_item(id) if database else null
		# nome clicável: abre a ficha do item
		var nome_btn := Button.new()
		nome_btn.text = "%s (%s)" % [item.get_nome() if item else id, id]
		nome_btn.flat = true
		nome_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nome_btn.clip_text = true
		nome_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome_btn.custom_minimum_size.x = 0
		nome_btn.tooltip_text = "ver informações"
		nome_btn.pressed.connect(mostrar_item.bind(str(id)))
		linha.add_child(nome_btn)
		var sb := SpinBox.new()
		sb.min_value = 0
		sb.max_value = 999
		sb.value = inv[id]
		sb.value_changed.connect(_on_qtd_mudou.bind(id))
		linha.add_child(sb)
		var rem := Button.new()
		rem.text = "Remover"
		rem.pressed.connect(func(): game_temp.remove_item(id, game_temp.get_item_quantity(id)))
		linha.add_child(rem)
		_lista_itens.add_child(linha)

	var limpar := Button.new()
	limpar.text = "Limpar inventário"
	limpar.pressed.connect(func(): game_temp.clear_inventory())
	_lista_itens.add_child(limpar)
	_ajustar_toque(_lista_itens)


func _on_qtd_mudou(valor: float, id: String) -> void:
	var atual: int = game_temp.get_item_quantity(id)
	var novo: int = int(valor)
	if novo > atual:
		game_temp.add_item(id, novo - atual)
	elif novo < atual:
		game_temp.remove_item(id, atual - novo)

# =============================================================================
# FICHA DO ITEM (clique no nome do item ou em "Ver")
# =============================================================================
func _montar_info() -> void:
	_info = PanelContainer.new()
	_info.name = "FichaItem"
	_info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info.offset_left = 16
	_info.offset_top = 50
	_info.offset_right = -16
	_info.offset_bottom = -50
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO_FICHA
	estilo.border_color = Color(0.5, 0.8, 1.0)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(10)
	_info.add_theme_stylebox_override("panel", estilo)
	_janela.add_child(_info)

	var col := VBoxContainer.new()
	_info.add_child(col)
	var topo := HBoxContainer.new()
	var titulo := _rotulo("Item")
	titulo.name = "Titulo"
	titulo.add_theme_font_size_override("font_size", FONTE + 3)
	titulo.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	var x := Button.new()
	x.text = "  X  "
	x.pressed.connect(func(): _info.hide())
	topo.add_child(titulo)
	topo.add_child(x)
	col.add_child(topo)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_conteudo = VBoxContainer.new()
	_info_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_conteudo.add_theme_constant_override("separation", 6)
	scroll.add_child(_info_conteudo)
	col.add_child(scroll)
	_info.hide()

func mostrar_item(id: String) -> void:
	var item: ItemData = database.get_item(id) if database and database.has_method("get_item") else null
	_limpar(_info_conteudo)
	(_info.find_child("Titulo", true, false) as Label).text = (item.get_nome() if item else id) + "  (" + id + ")"
	_info.show()
	_ajustar_toque.call_deferred(_info_conteudo)
	if item == null:
		_info_conteudo.add_child(_rotulo("Item não encontrado no banco."))
		return

	# ícone + descrição
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	if item.icone:
		var ic := TextureRect.new()
		ic.texture = item.icone
		ic.custom_minimum_size = Vector2(96, 96)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cab.add_child(ic)
	var desc := Label.new()
	desc.text = item.descricao if item.descricao != "" else "(sem descrição)"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(desc)
	_info_conteudo.add_child(cab)
	var qtd: int = game_temp.get_item_quantity(id) if game_temp else 0
	_info_conteudo.add_child(_rotulo("No inventário: %d" % qtd))

	# matriz A
	_info_conteudo.add_child(_secao("Matriz A (linha = traço afetado)"))
	_info_conteudo.add_child(_grade_matriz(item.A))

	# cozimento / limites
	_info_conteudo.add_child(_secao("Cozimento  Q = ∫T dt"))
	if item.m > 0.0:
		_info_conteudo.add_child(_rotulo("m = %s    s− = %s    s+ = %s" % [_n(item.m), _n(item.s_menos), _n(item.s_mais)]))
	else:
		_info_conteudo.add_child(_rotulo("sem exigência (m = 0)"))
	_info_conteudo.add_child(_secao("Limites"))
	_info_conteudo.add_child(_rotulo(_limite("T mín", item.T_min, item.k_min, "°C")))
	_info_conteudo.add_child(_rotulo(_limite("T máx", item.T_max, item.k_max, "°C")))
	_info_conteudo.add_child(_rotulo(_limite("t mín", item.t_min, item.h_min, "s")))
	_info_conteudo.add_child(_rotulo(_limite("t máx", item.t_max, item.h_max, "s")))
	if item.resource_path != "":
		var cam := _rotulo(item.resource_path)
		cam.add_theme_color_override("font_color", COR_TEXTO.darkened(0.4))
		_info_conteudo.add_child(cam)

func _secao(texto: String) -> Label:
	var l := _rotulo(texto)
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	return l

func _limite(nome: String, x0: float, h: float, unidade: String) -> String:
	if x0 <= 0.0:
		return "%s: sem limite" % nome
	return "%s: %s %s   (h = %s%s)" % [nome, _n(x0), unidade, _n(h), "  corte duro" if h <= 0.0 else ""]

func _n(v: float) -> String:
	return str(snappedf(v, 0.001))

## Grade 5x5 com cabeçalhos O C E A N. Verde = positivo, vermelho = negativo,
## diagonal = 1 e fora = 0 (identidade) ficam apagados.
func _grade_matriz(A: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = TRACOS.size() + 1
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 2)
	g.add_child(_celula("", Color.TRANSPARENT))
	for t in TRACOS:
		g.add_child(_celula(t, Color.TRANSPARENT, Color(0.6, 0.85, 1.0)))
	for i in TRACOS.size():
		g.add_child(_celula(TRACOS[i], Color.TRANSPARENT, Color(0.6, 0.85, 1.0)))
		for j in TRACOS.size():
			var v: float = float(A[i][j]) if i < A.size() and j < A[i].size() else 0.0
			var neutro: float = 1.0 if i == j else 0.0
			var desvio: float = v - neutro
			var fundo := COR_CELULA
			if absf(desvio) > 0.0001:
				var k: float = clampf(absf(desvio), 0.15, 1.0)
				fundo = Color(0.1, 0.25 + 0.4 * k, 0.12) if desvio > 0 else Color(0.25 + 0.4 * k, 0.1, 0.1)
			var cor_txt: Color = COR_TEXTO if absf(desvio) > 0.0001 else COR_TEXTO.darkened(0.45)
			g.add_child(_celula(_n(v), fundo, cor_txt))
	return g

func _celula(texto: String, fundo: Color, cor: Color = COR_TEXTO) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = fundo
	st.set_corner_radius_all(3)
	st.set_content_margin_all(3)
	p.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", cor)
	p.add_child(l)
	return p

# =============================================================================
# MAPA (colisões/áreas, atravessar, eventos passáveis)
# =============================================================================
func _atualizar_mapa() -> void:
	_limpar(_lista_mapa)
	if not ferramentas:
		_lista_mapa.add_child(_rotulo("FerramentasDebug não encontrada"))
		return

	var areas := CheckBox.new()
	areas.text = "Mostrar colisões e áreas de interação"
	areas.button_pressed = ferramentas.areas_visiveis()
	areas.toggled.connect(func(v: bool): ferramentas.mostrar_areas(v))
	_lista_mapa.add_child(areas)
	var legenda := Label.new()
	legenda.text = "vermelho = sólido · cinza = passável · azul = click · verde = touch · roxo = parallel · amarelo = bruxa"
	legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legenda.custom_minimum_size.x = 100
	legenda.add_theme_font_size_override("font_size", FONTE - 3)
	legenda.add_theme_color_override("font_color", COR_TEXTO.darkened(0.3))
	_lista_mapa.add_child(legenda)

	var atravessa := CheckBox.new()
	atravessa.text = "Bruxa atravessa tudo"
	atravessa.button_pressed = ferramentas.player_atravessando()
	atravessa.toggled.connect(func(v: bool): ferramentas.player_atravessa(v))
	_lista_mapa.add_child(atravessa)

	var cald := CheckBox.new()
	cald.text = "Caldeirão: gráfico e painel (debug)"
	cald.button_pressed = ferramentas.caldeirao_debug
	cald.toggled.connect(func(v: bool): ferramentas.caldeirao_debug = v)
	_lista_mapa.add_child(cald)

	var rapido := CheckBox.new()
	rapido.text = "Bruxa com o dobro de velocidade"
	rapido.button_pressed = ferramentas.player_rapido_ligado()
	rapido.toggled.connect(func(v: bool): ferramentas.player_rapido(v))
	_lista_mapa.add_child(rapido)

	_lista_mapa.add_child(HSeparator.new())
	var cab := HBoxContainer.new()
	cab.add_child(_secao("Eventos do mapa"))
	var atualizar := Button.new()
	atualizar.text = "Atualizar"
	atualizar.pressed.connect(_atualizar_mapa)
	cab.add_child(atualizar)
	_lista_mapa.add_child(cab)

	var eventos: Array = ferramentas.eventos_do_mapa()
	if eventos.is_empty():
		_lista_mapa.add_child(_rotulo("(nenhum evento no mapa)"))
	for ev in eventos:
		var pagina = ev._get_active_page_node()
		var linha := HBoxContainer.new()
		var nome: String = ev.evento.id if ev.get("evento") else str(ev.name)
		var info: String = "%s  (sem página ativa)" % nome
		if pagina:
			info = "%s  p%d  %s" % [nome, ev.get_active_page_index() + 1, ev.get_trigger()]
		linha.add_child(_rotulo(info))
		if pagina and pagina.has_method("is_passavel"):
			var cb := CheckBox.new()
			cb.text = "passável"
			cb.button_pressed = pagina.is_passavel()
			cb.toggled.connect(func(v: bool): ferramentas.evento_passavel(ev, v))
			linha.add_child(cb)
		_lista_mapa.add_child(linha)
	_ajustar_toque(_lista_mapa)


## Deixa tudo que se toca com altura mínima confortável para o dedo.
func _ajustar_toque(no: Node) -> void:
	for c in no.get_children():
		if c is BaseButton or c is LineEdit or c is SpinBox:
			(c as Control).custom_minimum_size.y = maxf((c as Control).custom_minimum_size.y, ALTURA_TOQUE)
		_ajustar_toque(c)
