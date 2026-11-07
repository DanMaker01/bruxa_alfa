# debug_menu.gd
# Menu de debug (tecla ' ): edita variáveis, personalidades e inventário do GameTemp
# e roda comandos de evento na hora (aba "Comandos", ver debug_comandos.gd)
# em tempo de jogo. Construído todo por código; o GameManager cria na primeira vez.
# Também abre/fecha pelo botão "DBG" no canto (0,0) da tela.
# Visual leve (escuro translúcido, linhas finas). Só monta a aba que está aberta
# (as outras ficam "sujas" e montam quando forem abertas). Busca no topo filtra a aba atual.
# Aba "Estados": salva/carrega variáveis, personalidades, inventário e self-vars em slots
# de teste (user://debug_estados.json).
extends Control
class_name DebugMenu

const TRACOS := ["O", "C", "E", "A", "N"]
const FONTE: int = 18            # fonte do menu
## Altura mínima de botões, campos e caixas de marcar (bom para o dedo no celular).
const ALTURA_TOQUE: float = 56.0
const COR_TEXTO := Color(0.95, 0.93, 0.88)
const BOTAO_DBG := Vector2(96, 64)
const COR_FUNDO := Color(0.07, 0.07, 0.09, 0.93)       # painel escuro translúcido
const COR_FUNDO_FICHA := Color(0.1, 0.1, 0.12, 0.98)
const COR_CELULA := Color(0.17, 0.17, 0.19)
const COR_LINHA := Color(1, 1, 1, 0.08)                 # bordas finas
const COR_DESTAQUE := Color(1.0, 0.8, 0.3)
const ARQ_ESTADOS := "user://debug_estados.json"
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
var _titulo: Label
var _filtro_vars: String = ""
var _so_alteradas: bool = false
static var _ultima_aba: int = 0   # reabre na aba onde parou
var _busca: LineEdit               # busca geral (filtra a aba atual)
var _pronto: bool = false          # _ready terminou (antes disso a janela ainda está visível)
var _sujas: Dictionary = {}        # nome da aba -> precisa remontar
var _lista_estados: VBoxContainer
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
	_pronto = true

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
	# estilos planos e finos
	for tipo in ["Button", "OptionButton"]:
		t.set_stylebox("normal", tipo, _caixa_estilo(Color(1, 1, 1, 0.06)))
		t.set_stylebox("hover", tipo, _caixa_estilo(Color(1, 1, 1, 0.12)))
		t.set_stylebox("pressed", tipo, _caixa_estilo(Color(COR_DESTAQUE, 0.25)))
		t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
		t.set_stylebox("disabled", tipo, _caixa_estilo(Color(1, 1, 1, 0.02)))
	t.set_stylebox("normal", "LineEdit", _caixa_estilo(Color(0, 0, 0, 0.35)))
	t.set_stylebox("focus", "LineEdit", _caixa_estilo(Color(0, 0, 0, 0.35), Color(COR_DESTAQUE, 0.5)))
	t.set_stylebox("panel", "TabContainer", _caixa_estilo(Color(0, 0, 0, 0.0)))
	t.set_stylebox("tab_selected", "TabContainer", _aba_estilo(true))
	t.set_stylebox("tab_unselected", "TabContainer", _aba_estilo(false))
	t.set_stylebox("tab_hovered", "TabContainer", _aba_estilo(false))
	return t

static func _caixa_estilo(fundo: Color, borda: Color = COR_LINHA) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fundo
	st.border_color = borda
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	return st

## Aba: só um traço dourado embaixo da selecionada.
static func _aba_estilo(selecionada: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)
	st.border_color = COR_DESTAQUE if selecionada else Color(0, 0, 0, 0)
	st.border_width_bottom = 2
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	return st

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
	_marcar_todas_sujas()
	_atualizar_titulo()
	_abas.set_block_signals(true)
	_abas.current_tab = clampi(_ultima_aba, 0, _abas.get_tab_count() - 1)
	_abas.set_block_signals(false)
	_janela.show()
	_ao_trocar_aba(_abas.current_tab)
	_conectar_sinais()

## Título com o mapa atual e a posição da bruxa.
func _atualizar_titulo() -> void:
	var mapa := "?"
	var pos := ""
	if ferramentas:
		var m = ferramentas.mundo()
		if m:
			for c in m.get_children():
				if c.name != "Player" and c.scene_file_path != "":
					mapa = c.scene_file_path.get_file().get_basename()
		var p = ferramentas.gm.get_player() if ferramentas.gm else null
		if p:
			pos = "   x %d  y %d" % [int(p.global_position.x), int(p.global_position.y)]
	_titulo.text = "DEBUG   %s%s" % [mapa, pos]

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
	_sujas["Itens"] = true
	if aberto() and _aba_atual() == "Itens":
		_atualizar_aba("Itens")

# ---- abas montadas só quando abertas ----
func _aba_atual() -> String:
	var c := _abas.get_current_tab_control()
	return str(c.name) if c else ""

func _marcar_todas_sujas() -> void:
	for c in _abas.get_children():
		_sujas[str(c.name)] = true

func _ao_trocar_aba(i: int) -> void:
	if not _pronto or not aberto():
		return   # montando ou fechado: abrir() chama de novo
	_ultima_aba = i
	var nome := _aba_atual()
	if _sujas.get(nome, true):
		_atualizar_aba(nome)
	_aplicar_busca()

func _atualizar_aba(nome: String) -> void:
	_sujas[nome] = false
	match nome:
		"Variáveis": _atualizar_vars()
		"Personalidade": _atualizar_pers()
		"Itens": _atualizar_itens()
		"Mapa": _atualizar_mapa()
		"Comandos":
			if _comandos:
				_comandos.atualizar()
		"Estados": _atualizar_estados()

## Lista (VBox) da aba atual, para a busca.
func _lista_da_aba(nome: String) -> Container:
	match nome:
		"Variáveis": return _lista_vars
		"Personalidade": return _lista_pers
		"Itens": return _lista_itens
		"Mapa": return _lista_mapa
		"Comandos": return _comandos
		"Estados": return _lista_estados
	return null

## Busca geral: esconde as linhas da aba atual que não têm o texto (títulos de seção
## ficam se algo abaixo deles ficou). Em Variáveis usa o filtro próprio (grupos).
func _aplicar_busca() -> void:
	var q := _busca.text.strip_edges().to_lower() if _busca else ""
	var nome := _aba_atual()
	if nome == "Variáveis":
		_filtro_vars = q
		_filtrar_vars()
		return
	var lista := _lista_da_aba(nome)
	if lista == null:
		return
	var secao: Control = null
	var secao_tem := false
	for c in lista.get_children():
		if not (c is Control):
			continue
		if c.has_meta("secao"):
			if secao:
				secao.visible = secao_tem or q == ""
			secao = c
			secao_tem = false
			continue
		if c.has_meta("fixo"):
			continue
		var ok: bool = q == "" or _texto_de(c).to_lower().contains(q)
		c.visible = ok
		if ok:
			secao_tem = true
	if secao:
		secao.visible = secao_tem or q == ""

func _texto_de(no: Node) -> String:
	var t := ""
	if no is Label or no is Button:
		t = no.text
	elif no is LineEdit:
		t = no.text + " " + no.placeholder_text
	elif no is OptionButton:
		t = no.text
	for c in no.get_children():
		t += " " + _texto_de(c)
	return t

# =============================================================================
# MONTAGEM
# =============================================================================
func _montar() -> void:
	_janela = Control.new()
	_janela.name = "Janela"
	_janela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_janela.add_to_group(UiModal.GRUPO)   # aberto: as cartas do HUD não recebem toques
	add_child(_janela)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.3)
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
	estilo.border_color = COR_LINHA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(10)
	painel.add_theme_stylebox_override("panel", estilo)
	_janela.add_child(painel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	painel.add_child(col)

	var topo := HBoxContainer.new()
	var titulo := Label.new()
	_titulo = titulo
	titulo.text = "DEBUG"
	titulo.tooltip_text = "tecla ' abre/fecha"
	titulo.clip_text = true
	titulo.add_theme_font_size_override("font_size", FONTE + 2)
	titulo.add_theme_color_override("font_color", COR_DESTAQUE)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fechar_btn := Button.new()
	fechar_btn.text = "  X  "
	fechar_btn.pressed.connect(fechar)
	topo.add_child(titulo)
	topo.add_child(fechar_btn)
	col.add_child(topo)

	_busca = LineEdit.new()
	_busca.placeholder_text = "buscar na aba..."
	_busca.clear_button_enabled = true
	_busca.text_changed.connect(func(_t: String): _aplicar_busca())
	col.add_child(_busca)

	_abas = TabContainer.new()
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_abas.tab_changed.connect(_ao_trocar_aba)
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
	_lista_estados = _criar_aba("Estados")
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
	if caixa == null:
		return
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
	_marcar_todas_sujas()
	if aberto():
		_atualizar_aba(_aba_atual())
		_aplicar_busca()

# =============================================================================
# VARIÁVEIS
# =============================================================================
func _atualizar_vars() -> void:
	_limpar(_lista_vars)
	if not game_temp:
		_lista_vars.add_child(_rotulo("GameTemp não encontrado"))
		return
	# barra: só alteradas (a busca é a geral, no topo)
	var barra := HBoxContainer.new()
	var so := CheckBox.new()
	so.text = "só alteradas"
	so.button_pressed = _so_alteradas
	so.toggled.connect(func(v: bool):
		_so_alteradas = v
		_filtrar_vars())
	barra.add_child(so)
	_lista_vars.add_child(barra)

	var vars: Dictionary = game_temp.get_all_vars()
	var nomes: Array = vars.keys()
	nomes.sort()
	var grupo_atual := ""
	for nome in nomes:
		var g := _grupo_var(str(nome))
		if g != grupo_atual:
			grupo_atual = g
			var cab := _secao(g)
			cab.set_meta("grupo_cab", g)
			_lista_vars.add_child(cab)
		_lista_vars.add_child(_linha_var(str(nome), g))
	_ajustar_toque(_lista_vars)
	_filtrar_vars()

## Grupo da variável = prefixo antes do primeiro "_" (missao01, castelo, ponte...).
func _grupo_var(nome: String) -> String:
	var i := nome.find("_")
	return nome.substr(0, i) if i > 0 else "geral"

func _valor_inicial(nome: String) -> float:
	if database and database.has_method("get_initial_vars"):
		return float(database.get_initial_vars().get(nome, 0.0))
	return 0.0

func _linha_var(nome: String, grupo: String) -> Control:
	var caixa := VBoxContainer.new()
	caixa.set_meta("var", nome)
	caixa.set_meta("grupo", grupo)
	caixa.add_theme_constant_override("separation", 0)
	var linha := HBoxContainer.new()
	var rot := _rotulo(nome)
	var desc: String = database.get_var_descricao(nome) if database and database.has_method("get_var_descricao") else ""
	rot.tooltip_text = desc
	rot.mouse_filter = Control.MOUSE_FILTER_PASS
	linha.add_child(rot)
	var campo := LineEdit.new()
	campo.custom_minimum_size.x = 110
	campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mostrar := func():
		var v = game_temp.get_var(nome)
		campo.text = str(v)
		var alterada: bool = absf(float(v if v != null else 0.0) - _valor_inicial(nome)) > 0.0001
		rot.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3) if alterada else COR_TEXTO)
		caixa.set_meta("alterada", alterada)
	var definir := func(v: float):
		game_temp.set_var(nome, v)
		mostrar.call()
	var aplicar := func(_t = ""):
		if campo.text.is_valid_float():
			definir.call(float(campo.text))
		else:
			mostrar.call()
	campo.text_submitted.connect(aplicar)
	campo.focus_exited.connect(aplicar)
	var menos := Button.new()
	menos.text = " − "
	menos.pressed.connect(func():
		var atual = game_temp.get_var(nome)
		definir.call(float(atual if atual != null else 0.0) - 1.0))
	var mais := Button.new()
	mais.text = " + "
	mais.pressed.connect(func():
		var atual = game_temp.get_var(nome)
		definir.call(float(atual if atual != null else 0.0) + 1.0))
	linha.add_child(menos)
	linha.add_child(campo)
	linha.add_child(mais)
	var volta := Button.new()
	volta.text = " ↺ "
	volta.tooltip_text = "valor inicial (%s)" % _n(_valor_inicial(nome))
	volta.pressed.connect(func(): definir.call(_valor_inicial(nome)))
	linha.add_child(volta)
	caixa.add_child(linha)
	if desc != "":
		var d := _rotulo(desc)
		d.add_theme_font_size_override("font_size", FONTE - 5)
		d.add_theme_color_override("font_color", COR_TEXTO.darkened(0.4))
		caixa.add_child(d)
	mostrar.call()
	return caixa

## Mostra só as linhas que batem com a busca (e só as alteradas, se marcado).
func _filtrar_vars() -> void:
	var busca := _filtro_vars.strip_edges().to_lower()
	var grupos_visiveis := {}
	for c in _lista_vars.get_children():
		if c.has_meta("var"):
			var nome: String = c.get_meta("var")
			var ok := busca == "" or nome.to_lower().contains(busca)
			if _so_alteradas and not c.get_meta("alterada", false):
				ok = false
			c.visible = ok
			if ok:
				grupos_visiveis[c.get_meta("grupo")] = true
	for c in _lista_vars.get_children():
		if c.has_meta("grupo_cab"):
			c.visible = grupos_visiveis.has(c.get_meta("grupo_cab"))


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
		var cab_p := HBoxContainer.new()
		cab_p.add_child(_secao(str(nome)))   # nome em cima, valores embaixo
		var volta := Button.new()
		volta.text = " ↺ inicial "
		volta.pressed.connect(func():
			var ini: Array = database.get_personality(nome) if database and database.has_method("get_personality") else []
			if not ini.is_empty():
				game_temp.set_personality(nome, ini.duplicate())
				_atualizar_pers())
		cab_p.add_child(volta)
		_lista_pers.add_child(cab_p)
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
	# ingredientes de uma receita de uma vez (para testar o caldeirão)
	var receitas := _receitas()
	if not receitas.is_empty():
		var lr := HFlowContainer.new()
		lr.add_child(_rotulo("Ingredientes de:", 190))
		for r in receitas:
			var b := Button.new()
			b.text = r.nome
			b.pressed.connect(func():
				for ing in r.ingredientes:
					if ing and ing.item:
						game_temp.add_item(ing.item.id, maxi(ing.quantidade, 1)))
			lr.add_child(b)
		_lista_itens.add_child(lr)
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


## Todas as ReceitaData de res://dados/receitas/.
func _receitas() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://dados/receitas/")
	if dir == null:
		return out
	for arq in dir.get_files():
		var nome := arq.trim_suffix(".remap")
		if nome.ends_with(".tres"):
			var r = load("res://dados/receitas/" + nome)
			if r is ReceitaData:
				out.append(r)
	return out

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
	estilo.border_color = Color(0.5, 0.8, 1.0, 0.4)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
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
	l.add_theme_color_override("font_color", COR_DESTAQUE)
	l.set_meta("secao", true)
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

	# ---- ir para outro mapa ----
	var ir := HBoxContainer.new()
	var mapas := OptionButton.new()
	mapas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mapas.clip_text = true
	mapas.fit_to_longest_item = false
	var dir := DirAccess.open("res://mapas/")
	if dir:
		var arqs: Array = []
		for a in dir.get_files():
			var n := a.trim_suffix(".remap")
			if n.ends_with(".tscn"):
				arqs.append(n)
		arqs.sort()
		for n in arqs:
			mapas.add_item(n.get_basename())
			mapas.set_item_metadata(mapas.item_count - 1, "res://mapas/" + n)
	var px := SpinBox.new()
	px.min_value = 0
	px.max_value = 10000
	px.value = 120
	px.prefix = "x"
	var ir_btn := Button.new()
	ir_btn.text = "Ir"
	ir_btn.pressed.connect(func():
		if mapas.item_count == 0 or not ferramentas.gm or not ferramentas.gm.get("teleporte"):
			return
		var caminho: String = mapas.get_selected_metadata()
		fechar()
		ferramentas.gm.teleporte.teleportar(caminho, px.value, 505.0, "dir"))
	ir.add_child(mapas)
	ir.add_child(px)
	ir.add_child(ir_btn)
	_lista_mapa.add_child(_secao("Ir para"))
	_lista_mapa.add_child(ir)

	# ---- velocidade do jogo ----
	var vel := HBoxContainer.new()
	vel.add_child(_rotulo("Velocidade do jogo"))
	for k in [0.5, 1.0, 2.0, 4.0]:
		var b := Button.new()
		b.text = ("%sx" % _n(k))
		b.toggle_mode = true
		b.button_pressed = is_equal_approx(Engine.time_scale, k)
		b.pressed.connect(func():
			Engine.time_scale = k
			_atualizar_mapa())
		vel.add_child(b)
	_lista_mapa.add_child(vel)
	_lista_mapa.add_child(HSeparator.new())

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
	cald.text = "Caldeirão: debug (também pelo botão na cena)"
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
		var ate := Button.new()
		ate.text = "Ir até"
		ate.tooltip_text = "leva a bruxa para perto do evento"
		ate.pressed.connect(func():
			var p = ferramentas.gm.get_player() if ferramentas.gm else null
			if p and is_instance_valid(ev):
				p.global_position.x = ev.global_position.x - 60.0
				_atualizar_titulo())
		linha.add_child(ate)
		if ev.get("evento"):
			var rodar := Button.new()
			rodar.text = "Rodar"
			rodar.tooltip_text = "roda a página ativa deste evento"
			rodar.pressed.connect(func():
				var interp = ferramentas.gm.get_node_or_null("Interpeter") if ferramentas.gm else null
				if interp and is_instance_valid(ev):
					fechar()
					interp.trigger_event(ev.evento, ev))
			linha.add_child(rodar)
		_lista_mapa.add_child(linha)
	_ajustar_toque(_lista_mapa)


# =============================================================================
# ESTADOS SALVOS (slots de teste)
# =============================================================================
func _ler_estados() -> Dictionary:
	if not FileAccess.file_exists(ARQ_ESTADOS):
		return {}
	var f := FileAccess.open(ARQ_ESTADOS, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func _gravar_estados(d: Dictionary) -> void:
	var f := FileAccess.open(ARQ_ESTADOS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))

func _atualizar_estados() -> void:
	_limpar(_lista_estados)
	if not game_temp:
		_lista_estados.add_child(_rotulo("GameTemp não encontrado"))
		return
	var linha := HBoxContainer.new()
	linha.set_meta("fixo", true)
	var nome := LineEdit.new()
	nome.placeholder_text = "nome do estado (ex.: antes do casamento)"
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var salvar := Button.new()
	salvar.text = "Salvar"
	salvar.pressed.connect(func(): _salvar_estado(nome.text))
	linha.add_child(nome)
	linha.add_child(salvar)
	_lista_estados.add_child(linha)
	var dica := _rotulo("Guarda variáveis, personalidades, inventário e self-vars. Mesmo nome = substitui.")
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.clip_text = false
	dica.add_theme_color_override("font_color", COR_TEXTO.darkened(0.35))
	dica.set_meta("fixo", true)
	_lista_estados.add_child(dica)
	var estados := _ler_estados()
	var nomes: Array = estados.keys()
	nomes.sort()
	if nomes.is_empty():
		_lista_estados.add_child(_rotulo("(nenhum estado salvo)"))
	for n in nomes:
		var e: Dictionary = estados[n]
		var h := HBoxContainer.new()
		var r := _rotulo("%s   %s" % [n, str(e.get("quando", ""))])
		var carregar := Button.new()
		carregar.text = "Carregar"
		carregar.pressed.connect(_carregar_estado.bind(str(n)))
		var apagar := Button.new()
		apagar.text = "Apagar"
		apagar.pressed.connect(_apagar_estado.bind(str(n)))
		h.add_child(r)
		h.add_child(carregar)
		h.add_child(apagar)
		_lista_estados.add_child(h)
	_ajustar_toque(_lista_estados)

func _salvar_estado(nome: String) -> void:
	nome = nome.strip_edges()
	if nome == "" or not game_temp:
		return
	var estados := _ler_estados()
	estados[nome] = {
		"quando": Time.get_datetime_string_from_system(false, true),
		"variaveis": game_temp.variaveis.duplicate(true),
		"personalidades": game_temp.personalidades.duplicate(true),
		"inventario": game_temp.inventario.duplicate(true),
		"self_vars": game_temp.self_vars.duplicate(true),
	}
	_gravar_estados(estados)
	_atualizar_estados()

func _carregar_estado(nome: String) -> void:
	var e: Dictionary = _ler_estados().get(nome, {})
	if e.is_empty() or not game_temp:
		return
	game_temp.variaveis = (e.get("variaveis", {}) as Dictionary).duplicate(true)
	var pers := {}
	var p_salvas: Dictionary = e.get("personalidades", {})
	for k in p_salvas:
		pers[k] = Array(p_salvas[k])   # JSON volta como Array de floats
	game_temp.personalidades = pers
	var inv := {}
	var i_salvo: Dictionary = e.get("inventario", {})
	for k in i_salvo:
		inv[k] = int(i_salvo[k])     # JSON guarda número como float
	game_temp.inventario = inv
	game_temp.self_vars = (e.get("self_vars", {}) as Dictionary).duplicate(true)
	game_temp.variables_changed.emit()
	game_temp.inventory_changed.emit()
	for k in pers:
		game_temp.personality_changed.emit(k)
	_marcar_todas_sujas()
	_sujas["Estados"] = false
	_atualizar_titulo()

func _apagar_estado(nome: String) -> void:
	var estados := _ler_estados()
	estados.erase(nome)
	_gravar_estados(estados)
	_atualizar_estados()

## Deixa tudo que se toca com altura mínima confortável para o dedo.
func _ajustar_toque(no: Node) -> void:
	for c in no.get_children():
		if c is BaseButton or c is LineEdit or c is SpinBox:
			(c as Control).custom_minimum_size.y = maxf((c as Control).custom_minimum_size.y, ALTURA_TOQUE)
		_ajustar_toque(c)
