# debug_comandos.gd
# Aba "Comandos" do menu de debug:
#   1. RODANDO AGORA: todos os eventos que o Interpreter está executando (comando atual,
#      posição na lista, pausa/espera), com botão para parar. Atualiza sozinha.
#   2. RODAR COMANDO: atalhos (mensagem, teleporte, mover evento, tremor, caldeirão...) e
#      a lista de todos os comandos. Cada um abre uma ficha com os parâmetros (montada a
#      partir dos @export do comando); "Executar" fecha o menu e roda o comando como um
#      evento temporário ("debug_N").
class_name DebugComandos
extends VBoxContainer

const PASTA_COMANDOS := "res://src/dados/comandos/"
const PASTA_MAPAS := "res://mapas/"
const CAMINHO_INTERP := "/root/Main/GameManager/Interpeter"
## Atalhos: [texto do botão, arquivo do comando].
const ATALHOS := [
	["Mensagem", "cmd_mostrar_msg"], ["Opções", "cmd_mostrar_opcoes"],
	["Teleporte", "cmd_teleportar"], ["Mover", "cmd_mover"],
	["Efeito", "cmd_mostrar_efeito"], ["Câmera", "cmd_camera"], ["Balão", "cmd_balao"],
	["Caldeirão", "cmd_preparo"], ["Variável", "cmd_variavel"],
	["Item", "cmd_item"], ["Fade", "cmd_fade"], ["Som", "cmd_som"],
	["Aplicar poção", "cmd_aplicar_pocao"], ["Player", "cmd_player"],
]
## Comandos de controle de fluxo: não fazem sentido sozinhos.
const ESCONDER := ["comando", "cmd_if", "cmd_else", "cmd_end", "cmd_while", "cmd_break", "cmd_label", "cmd_goto"]
const INTERVALO_LISTA: float = 0.5

var menu: DebugMenu
var _rodando: VBoxContainer
var _todos: OptionButton
var _t: float = 0.0
var _contador: int = 0
var _assinatura: String = ""      # evita remontar a lista "rodando" sem mudança
# ficha de parâmetros (abre por cima do menu)
var _ficha: Control
var _ficha_titulo: Label
var _ficha_campos: VBoxContainer
var _cmd: Comando
var _leitores: Array = []         # [nome da propriedade, Callable que devolve o valor]


func _init(p_menu: DebugMenu) -> void:
	menu = p_menu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_montar()

func _interp():
	return get_node_or_null(CAMINHO_INTERP)

func _process(delta: float) -> void:
	_t += delta
	if _t >= INTERVALO_LISTA and is_visible_in_tree():
		_t = 0.0
		_atualizar_rodando()

func atualizar() -> void:
	_assinatura = ""
	_atualizar_rodando()

# =============================================================================
# MONTAGEM
# =============================================================================
func _montar() -> void:
	add_child(menu._secao("Rodando agora"))
	_rodando = VBoxContainer.new()
	_rodando.add_theme_constant_override("separation", 4)
	add_child(_rodando)
	add_child(HSeparator.new())

	add_child(menu._secao("Rodar comando"))
	var atalhos := HFlowContainer.new()
	atalhos.add_theme_constant_override("h_separation", 6)
	atalhos.add_theme_constant_override("v_separation", 6)
	for a in ATALHOS:
		var arq: String = PASTA_COMANDOS + a[1] + ".gd"
		if not ResourceLoader.exists(arq):
			continue
		var b := Button.new()
		b.text = a[0]
		b.pressed.connect(_abrir_ficha.bind(arq, a[0]))
		atalhos.add_child(b)
	add_child(atalhos)

	var linha := HBoxContainer.new()
	_todos = OptionButton.new()
	_todos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for arq in _scripts_comandos():
		_todos.add_item(arq.get_file().get_basename())
		_todos.set_item_metadata(_todos.item_count - 1, arq)
	var abrir := Button.new()
	abrir.text = "Abrir"
	abrir.pressed.connect(func():
		if _todos.selected >= 0:
			var arq: String = _todos.get_item_metadata(_todos.selected)
			_abrir_ficha(arq, arq.get_file().get_basename()))
	linha.add_child(_todos)
	linha.add_child(abrir)
	add_child(linha)
	_montar_ficha()
	menu._ajustar_toque(self)

func _scripts_comandos() -> Array:
	var lista: Array = []
	for f in DirAccess.get_files_at(PASTA_COMANDOS):
		var nome := f.trim_suffix(".remap")          # no jogo exportado os .gd viram .remap
		if not nome.ends_with(".gd") or nome.get_basename() in ESCONDER:
			continue
		lista.append(PASTA_COMANDOS + nome)
	lista.sort()
	return lista

# =============================================================================
# RODANDO AGORA
# =============================================================================
func _atualizar_rodando() -> void:
	var interp = _interp()
	var eventos: Array = []
	if interp:
		eventos = interp.running_events.filter(func(e): return not e.finished)
	var linhas: Array = []
	for ev in eventos:
		linhas.append(_descrever(ev))
	var assinatura := "|".join(linhas)
	if assinatura == _assinatura:
		return
	_assinatura = assinatura
	menu._limpar(_rodando)
	if interp == null:
		_rodando.add_child(menu._rotulo("Interpreter não encontrado"))
		return
	if eventos.is_empty():
		_rodando.add_child(menu._rotulo("(nenhum evento rodando)"))
		return
	for i in eventos.size():
		var ev = eventos[i]
		var linha := HBoxContainer.new()
		var l := Label.new()
		l.text = linhas[i]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", DebugMenu.FONTE - 3)
		linha.add_child(l)
		var parar := Button.new()
		parar.text = "Parar"
		parar.pressed.connect(func():
			if not ev.finished:
				interp.abortar(ev, "parado pelo menu de debug")
			atualizar())
		linha.add_child(parar)
		_rodando.add_child(linha)
	menu._ajustar_toque(_rodando)

## "#3 bruxa_in_auto  p1 · 5/12 mostrar_msg · esperando: dialog"
func _descrever(ev) -> String:
	var cmd = ev.comando_atual()
	var nome_cmd: String = cmd.nome_cmd() if cmd else "(fim)"
	var estado := ""
	if ev.is_waiting:
		estado = " · esperando %.1f s" % ev.wait_timer
	elif ev.pause_reason != "":
		estado = " · esperando: " + ev.pause_reason
	return "#%d %s  p%d · %d/%d %s%s" % [ev.id, ev.name, ev.page_index + 1,
		ev.current_index + 1, ev.commands.size(), nome_cmd, estado]

# =============================================================================
# FICHA DE PARÂMETROS
# =============================================================================
func _montar_ficha() -> void:
	_ficha = Control.new()
	_ficha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ficha.mouse_filter = Control.MOUSE_FILTER_STOP
	_ficha.visible = false
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.5)
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ficha.add_child(escuro)
	var painel := PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	painel.offset_left = 30
	painel.offset_right = -30
	painel.offset_top = 120
	painel.offset_bottom = -120
	var st := StyleBoxFlat.new()
	st.bg_color = DebugMenu.COR_FUNDO_FICHA
	st.border_color = Color(0.5, 0.8, 1.0)
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(14)
	painel.add_theme_stylebox_override("panel", st)
	_ficha.add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	painel.add_child(col)
	_ficha_titulo = Label.new()
	_ficha_titulo.add_theme_font_size_override("font_size", DebugMenu.FONTE + 2)
	_ficha_titulo.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	col.add_child(_ficha_titulo)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ficha_campos = VBoxContainer.new()
	_ficha_campos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ficha_campos.add_theme_constant_override("separation", 6)
	scroll.add_child(_ficha_campos)
	col.add_child(scroll)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_END
	botoes.add_theme_constant_override("separation", 10)
	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(func(): _ficha.visible = false)
	var executar := Button.new()
	executar.text = "Executar"
	executar.pressed.connect(_executar)
	botoes.add_child(cancelar)
	botoes.add_child(executar)
	col.add_child(botoes)
	menu._ajustar_toque(_ficha)
	# por cima de todo o menu (não só da aba)
	menu.add_child.call_deferred(_ficha)

func fechar_ficha() -> void:
	if _ficha:
		_ficha.visible = false

func _abrir_ficha(arq: String, titulo: String) -> void:
	var script = load(arq)
	if script == null:
		return
	_cmd = script.new()
	_leitores.clear()
	menu._limpar(_ficha_campos)
	_ficha_titulo.text = "%s  (%s)" % [titulo, arq.get_file().get_basename()]
	var algum := false
	for p in _cmd.get_property_list():
		var uso: int = p["usage"]
		if not (uso & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (uso & PROPERTY_USAGE_EDITOR):
			continue
		var campo := _campo(p)
		if campo:
			_ficha_campos.add_child(campo)
			algum = true
	if not algum:
		_ficha_campos.add_child(menu._rotulo("(sem parâmetros)"))
	menu._ajustar_toque(_ficha_campos)
	_ficha.visible = true

## Uma linha "nome: [campo]" para a propriedade. Registra o leitor do valor.
func _campo(p: Dictionary) -> Control:
	var nome: String = p["name"]
	var tipo: int = p["type"]
	var dica: int = p["hint"]
	var dica_txt: String = p["hint_string"]
	var atual = _cmd.get(nome)
	var linha := VBoxContainer.new()
	var rot := Label.new()
	rot.text = nome
	rot.add_theme_font_size_override("font_size", DebugMenu.FONTE - 4)
	rot.add_theme_color_override("font_color", DebugMenu.COR_TEXTO.darkened(0.25))
	linha.add_child(rot)
	var w: Control = null
	match tipo:
		TYPE_BOOL:
			var cb := CheckBox.new()
			cb.button_pressed = bool(atual)
			w = cb
			_leitores.append([nome, func(): return cb.button_pressed])
		TYPE_INT, TYPE_FLOAT:
			if tipo == TYPE_INT and dica == PROPERTY_HINT_ENUM:
				w = _enum(nome, dica_txt, int(atual))
			else:
				var v = atual
				if nome == "x" and _cmd is CmdMover:
					v = _pos_bruxa().x
				w = _numero(nome, float(v), tipo == TYPE_INT)
		TYPE_STRING:
			w = _texto(nome, str(atual), dica)
		TYPE_VECTOR2:
			var v: Vector2 = atual
			if nome == "posicao" and v == Vector2.ZERO:
				v = _pos_bruxa()
			w = _vetor(nome, v)
		TYPE_ARRAY:
			if dica_txt.ends_with(":String") or dica_txt == "String" or dica_txt.begins_with("4"):
				var le := LineEdit.new()
				le.placeholder_text = "itens separados por ;"
				le.text = "; ".join(PackedStringArray(atual))
				w = le
				_leitores.append([nome, func():
					var a: Array[String] = []
					for s in le.text.split(";", false):
						a.append(s.strip_edges())
					return a])
		TYPE_OBJECT:
			w = _objeto(nome, dica_txt)
	if w == null:
		var l := Label.new()
		l.text = "(não editável aqui)"
		w = l
	linha.add_child(w)
	return linha

func _numero(nome: String, v: float, inteiro: bool) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = -100000
	sb.max_value = 100000
	sb.step = 1.0 if inteiro else 0.01
	sb.allow_greater = true
	sb.allow_lesser = true
	sb.value = v
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leitores.append([nome, func(): return int(sb.value) if inteiro else sb.value])
	return sb

## Enum: hint_string "A,B,C" ou "A:0,B:5".
func _enum(nome: String, dica_txt: String, atual: int) -> OptionButton:
	var ob := OptionButton.new()
	var proximo := 0
	for parte in dica_txt.split(","):
		var nv := parte.split(":")
		var valor: int = int(nv[1]) if nv.size() > 1 else proximo
		ob.add_item(nv[0].strip_edges(), valor)
		proximo = valor + 1
	ob.select(maxi(ob.get_item_index(atual), 0))
	_leitores.append([nome, func(): return ob.get_item_id(ob.selected)])
	return ob

func _texto(nome: String, atual: String, dica: int) -> Control:
	# evento do mapa / mapa do jogo: lista para escolher
	if nome == "evento" or nome == "evento_alvo":
		var ids: Array = [""] if nome == "evento_alvo" else []
		if menu.ferramentas:
			for ev in menu.ferramentas.eventos_do_mapa():
				var id: String = ev.evento.id if ev.get("evento") else ""
				if id != "" and not id in ids:
					ids.append(id)
		if not ids.is_empty():
			return _lista_textos(nome, ids, atual)
	if nome == "mapa" or dica == PROPERTY_HINT_FILE:
		var mapas: Array = []
		for f in DirAccess.get_files_at(PASTA_MAPAS):
			var n := f.trim_suffix(".remap")
			if n.ends_with(".tscn"):
				mapas.append(PASTA_MAPAS + n)
		mapas.sort()
		if not mapas.is_empty():
			return _lista_textos(nome, mapas, atual)
	if dica == PROPERTY_HINT_MULTILINE_TEXT:
		var te := TextEdit.new()
		te.text = atual
		te.custom_minimum_size.y = 120
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_leitores.append([nome, func(): return te.text])
		return te
	var le := LineEdit.new()
	le.text = atual
	_leitores.append([nome, func(): return le.text])
	return le

func _lista_textos(nome: String, valores: Array, atual: String) -> OptionButton:
	var ob := OptionButton.new()
	for v in valores:
		ob.add_item(v if v != "" else "(nenhum)")
		ob.set_item_metadata(ob.item_count - 1, v)
	var i := valores.find(atual)
	ob.select(maxi(i, 0))
	_leitores.append([nome, func(): return ob.get_item_metadata(ob.selected)])
	return ob

func _vetor(nome: String, v: Vector2) -> Control:
	var h := HBoxContainer.new()
	var sx := SpinBox.new()
	var sy := SpinBox.new()
	for sb in [sx, sy]:
		sb.min_value = -100000
		sb.max_value = 100000
		sb.allow_greater = true
		sb.allow_lesser = true
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sb)
	sx.value = v.x
	sy.value = v.y
	var aqui := Button.new()
	aqui.text = "bruxa"
	aqui.tooltip_text = "posição atual da bruxa"
	aqui.pressed.connect(func():
		var p := _pos_bruxa()
		sx.value = p.x
		sy.value = p.y)
	h.add_child(aqui)
	_leitores.append([nome, func(): return Vector2(sx.value, sy.value)])
	return h

## Recursos: ItemData (itens do banco) e PersonalidadeData (personalidades do banco).
func _objeto(nome: String, classe: String) -> Control:
	var db = menu.database
	if db == null:
		return null
	var ob := OptionButton.new()
	var recursos: Array = []
	if classe == "ItemData" and db.has_method("get_items"):
		var itens: Dictionary = db.get_items()
		var ids := itens.keys()
		ids.sort()
		for id in ids:
			recursos.append(itens[id])
			ob.add_item(str(id))
	elif classe == "PersonalidadeData":
		var banco = load("res://dados/banco.tres")
		if banco and banco.get("personalidades"):
			for pd in banco.personalidades:
				recursos.append(pd)
				ob.add_item(pd.id)
	else:
		return null
	if recursos.is_empty():
		return null
	_leitores.append([nome, func(): return recursos[ob.selected] if ob.selected >= 0 else null])
	return ob

func _pos_bruxa() -> Vector2:
	var gm = menu.ferramentas.gm if menu.ferramentas else null
	var p = gm.get_player() if gm else null
	return p.global_position if p else Vector2.ZERO

# =============================================================================
# EXECUTAR: vira um evento temporário de uma página com este comando
# =============================================================================
func _executar() -> void:
	var interp = _interp()
	if interp == null or _cmd == null:
		return
	for l in _leitores:
		_cmd.set(l[0], l[1].call())
	var pag := PaginaData.new()
	var cmds: Array[Comando] = [_cmd]
	pag.comandos = cmds
	var ev := EventoData.new()
	_contador += 1
	ev.id = "debug_%d" % _contador
	var pags: Array[PaginaData] = [pag]
	ev.paginas = pags
	_ficha.visible = false
	menu.fechar()            # despausa o jogo para o comando rodar
	interp.trigger_event(ev, null)
	print("[DebugComandos] ▶ ", ev.id, ": ", _cmd.to_dict())
	_cmd = null
