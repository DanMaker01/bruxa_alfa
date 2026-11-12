# editor_receita.gd
# Edição de uma receita NA PRÓPRIA PÁGINA do livro (sem janela extra).
#   página da receita: nome (campo), aviso de semelhança, passos em cartões, Cancelar / Pronto
#     arrastar um cartão reordena; tocar abre a edição dele (ingrediente: quantidade e
#     segundos; chama: troca a cor)
#   página ao lado:    paleta com as chamas e os ingredientes já vistos + lixeira
#     tocar adiciona no fim; arrastar coloca onde soltar; arrastar um passo para a lixeira apaga
# Números (quantidade e segundos): arrastar para o lado aumenta / diminui; tocar nas
# setinhas ‹ › soma ou tira 1.
# Poção sem nome (resultado "nomeavel"): o nome dado aqui vale também para a poção.
# A CenaLivro chama montar_pagina() e montar_paleta() nas caixas das duas páginas.
class_name EditorReceita
extends Node

signal terminou(salvou: bool)


const COR_TINTA := Color(0.2, 0.14, 0.1)
const COR_SUAVE := Color(0.47, 0.4, 0.32)
const COR_DESTAQUE := Color(0.5, 0.18, 0.45)
const COR_AVISO := Color(0.7, 0.35, 0.05)
const ALT_CARTAO: float = 44.0

var livro: Dictionary = {}
var database = null
var vistos: Array = []
var pagina: Dictionary = {}
var passos: Array = []
var ativo: bool = false
var _aberto: int = -1               # cartão com a edição aberta

var _nome: LineEdit
var _aviso: Label
var _lista: VBoxContainer
var game_temp = null                # para avisar o HUD quando a poção ganha nome


func montar(p_livro: Dictionary, p_db, p_vistos: Array) -> void:
	livro = p_livro
	database = p_db
	vistos = p_vistos

func abrir(p: Dictionary) -> void:
	pagina = p
	passos = p["passos"].duplicate(true)
	_aberto = -1
	ativo = true


## Página da receita em edição.
func montar_pagina(caixa: VBoxContainer) -> void:
	caixa.add_child(_rotulo("editando", 11, COR_DESTAQUE, false))
	_nome = LineEdit.new()
	_nome.placeholder_text = "nome da receita"
	_nome.text = str(pagina.get("nome", ""))
	_nome.custom_minimum_size.y = 42
	_nome.add_theme_font_size_override("font_size", 17)
	caixa.add_child(_nome)
	if pagina.get("resultado", {}).get("nomeavel", false):
		caixa.add_child(_rotulo("Poção sem nome: este nome vale para ela também.", 11, COR_DESTAQUE))
	_aviso = _rotulo("", 11, COR_AVISO)
	caixa.add_child(_aviso)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lista = ListaPassos.new()
	_lista.editor = self
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 4)
	sc.add_child(_lista)
	caixa.add_child(sc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var c := _botao("Cancelar", _fim.bind(false))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := _botao("Pronto", _fim.bind(true))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.add_theme_color_override("font_color", COR_DESTAQUE)
	h.add_child(c)
	h.add_child(ok)
	caixa.add_child(h)
	atualizar()

## Página ao lado: paleta (chamas, ingredientes), lixeira e o modo dos números.
func montar_paleta(caixa: VBoxContainer) -> void:
	caixa.add_child(_rotulo("Chamas", 13, COR_TINTA, false))
	var gc := GridContainer.new()
	gc.columns = 3
	gc.add_theme_constant_override("h_separation", 4)
	gc.add_theme_constant_override("v_separation", 4)
	for e in EstadosChama.LISTA:
		var ch := ChipPaleta.new()
		ch.editor = self
		ch.passo = {"tipo": "chama", "estado": e["id"]}
		ch.text = str(e["nome"]).replace(" grande", "+")
		ch.custom_minimum_size = Vector2(86, 40)
		ch.add_theme_font_size_override("font_size", 12)
		ch.add_theme_stylebox_override("normal", _chip_estilo(e["cor"]))
		ch.add_theme_stylebox_override("hover", _chip_estilo(Color(e["cor"]).lightened(0.15)))
		ch.add_theme_stylebox_override("pressed", _chip_estilo(Color(e["cor"]).darkened(0.15)))
		ch.add_theme_color_override("font_color", Color.WHITE if Color(e["cor"]).get_luminance() < 0.55 else COR_TINTA)
		gc.add_child(ch)
	caixa.add_child(gc)
	caixa.add_child(_rotulo("Ingredientes", 13, COR_TINTA, false))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var gi := GridContainer.new()
	gi.columns = 4
	gi.add_theme_constant_override("h_separation", 4)
	gi.add_theme_constant_override("v_separation", 4)
	sc.add_child(gi)
	caixa.add_child(sc)
	if vistos.is_empty():
		gi.add_child(_rotulo("(nenhum ainda)", 12, COR_SUAVE, false))
	for id in vistos:
		var it := LivroReceitas.item(id, database)
		var ch := ChipPaleta.new()
		ch.editor = self
		ch.passo = {"tipo": "ingrediente", "item": id, "qtd": 1, "seg": 10.0}
		ch.custom_minimum_size = Vector2(64, 64)
		ch.tooltip_text = LivroReceitas.nome_item(id, database)
		if it and it.icone:
			ch.icon = it.icone
			ch.expand_icon = true
			ch.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			ch.text = LivroReceitas.nome_item(id, database).left(6)
		gi.add_child(ch)
	caixa.add_child(_rotulo("Tocar adiciona no fim; arrastar coloca no lugar.", 11, COR_SUAVE))
	var lix := Lixeira.new()
	lix.editor = self
	lix.custom_minimum_size = Vector2(0, 46)
	caixa.add_child(lix)


# =============================================================================
# PASSOS
# =============================================================================
func atualizar() -> void:
	for c in _lista.get_children():
		_lista.remove_child(c)
		c.queue_free()
	for i in passos.size():
		var cartao := CartaoPasso.new()
		cartao.editor = self
		cartao.indice = i
		cartao.custom_minimum_size.y = ALT_CARTAO
		_lista.add_child(cartao)
		_montar_cartao(cartao, i)
		if i == _aberto:
			_lista.add_child(_edicao(i))
	var fim := _rotulo("%d. Finalizar" % (passos.size() + 1), 13, COR_SUAVE)
	fim.custom_minimum_size.y = 32
	_lista.add_child(fim)
	_verificar_semelhanca()

func _montar_cartao(cartao: CartaoPasso, i: int) -> void:
	var s: Dictionary = passos[i]
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	cartao.add_child(h)
	h.add_child(_rotulo("≡", 16, COR_SUAVE, false))
	if s.get("tipo") == "chama":
		var bola := ColorRect.new()
		bola.color = EstadosChama.cor(s["estado"])
		bola.custom_minimum_size = Vector2(16, 16)
		bola.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bola.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(bola)
	else:
		var it := LivroReceitas.item(str(s.get("item", "")), database)
		if it and it.icone:
			var ic := TextureRect.new()
			ic.texture = it.icone
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.custom_minimum_size = Vector2(28, 28)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(ic)
	var l := _rotulo("%d. %s" % [i + 1, LivroReceitas.texto_passo(s, database)], 13, COR_TINTA)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	h.add_child(l)

## Edição aberta embaixo do cartão.
func _edicao(i: int) -> Control:
	var s: Dictionary = passos[i]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if s.get("tipo") == "ingrediente":
		h.add_child(_numero(i, "qtd", 1, 20, "×%d"))
		h.add_child(_numero(i, "seg", 0, 300, "%d s"))
	else:
		h.add_theme_constant_override("separation", 3)
		for e in EstadosChama.LISTA:
			var b := Button.new()
			b.custom_minimum_size = Vector2(26, 30)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_stylebox_override("normal", _chip_estilo(e["cor"], 15 if e["id"] == s["estado"] else 4))
			b.tooltip_text = e["nome"]
			b.pressed.connect(_trocar_chama.bind(i, e["id"]))
			h.add_child(b)
	return h

func _numero(i: int, campo: String, mn: int, mx: int, formato: String) -> Control:
	var n: SeletorNumero = SeletorNumero.new()
	n.editor = self
	n.indice = i
	n.campo = campo
	n.minimo = mn
	n.maximo = mx
	n.formato = formato
	n.custom_minimum_size = Vector2(120, 44)
	return n

func valor(i: int, campo: String) -> int:
	return roundi(float(passos[i].get(campo, 0)))

func definir_valor(i: int, campo: String, v: int) -> void:
	passos[i][campo] = float(v) if campo == "seg" else v
	# só o texto do cartão muda (sem remontar: o seletor continua sendo arrastado)
	var cartao := _cartao(i)
	if cartao:
		for c in cartao.get_children():
			c.queue_free()
		_montar_cartao(cartao, i)
	_verificar_semelhanca()

func _cartao(i: int) -> CartaoPasso:
	for c in _lista.get_children():
		if c is CartaoPasso and c.indice == i:
			return c
	return null

func _trocar_chama(i: int, estado: String) -> void:
	passos[i]["estado"] = estado
	atualizar()

func tocar_cartao(i: int) -> void:
	_aberto = -1 if _aberto == i else i
	atualizar()

## Paleta: tocar adiciona no fim.
func adicionar(passo: Dictionary) -> void:
	passos.append(passo.duplicate(true))
	_aberto = passos.size() - 1 if passo.get("tipo") == "ingrediente" else -1
	atualizar()

## Soltar na lista: de onde veio (paleta ou outro cartão) e para que posição.
func soltar(dados: Dictionary, indice: int) -> void:
	indice = clampi(indice, 0, passos.size())
	if dados.has("novo"):
		passos.insert(indice, dados["novo"].duplicate(true))
		_aberto = indice if dados["novo"].get("tipo") == "ingrediente" else -1
	elif dados.has("mover"):
		var de: int = dados["mover"]
		var s = passos[de]
		passos.remove_at(de)
		if indice > de:
			indice -= 1
		passos.insert(indice, s)
		_aberto = -1
	atualizar()

func apagar(i: int) -> void:
	if i >= 0 and i < passos.size():
		passos.remove_at(i)
		_aberto = -1
		atualizar()

## Índice de inserção pela altura do ponto (local na lista).
func indice_no_ponto(y: float) -> int:
	var k := 0
	for c in _lista.get_children():
		if c is CartaoPasso:
			if y < c.position.y + c.size.y * 0.5:
				return k
			k += 1
	return passos.size()


# =============================================================================
# SEMELHANÇA
# =============================================================================
func _verificar_semelhanca() -> void:
	var todas: Array = livro.get("paginas", []) + livro.get("rascunhos", [])
	var n := 0
	var parecida := ""
	for p in todas:
		n += 1
		if p == pagina or (p.has("id") and pagina.has("id") and int(p["id"]) == int(pagina["id"])):
			continue
		if passos.is_empty():
			continue
		if TranscritorReceita.iguais(p["passos"], passos):
			_aviso.text = "Igual à página %d (%s)" % [n, p["nome"]]
			return
		if parecida == "" and _mesma_sequencia(p["passos"], passos):
			parecida = "Parecida com a página %d (%s): mesmos ingredientes e chamas, tempos diferentes" % [n, p["nome"]]
	_aviso.text = parecida

static func _mesma_sequencia(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Dictionary = a[i]
		var y: Dictionary = b[i]
		if x.get("tipo") != y.get("tipo"):
			return false
		if x.get("tipo") == "chama" and x.get("estado") != y.get("estado"):
			return false
		if x.get("tipo") == "ingrediente" and (x.get("item") != y.get("item") or int(x.get("qtd", 1)) != int(y.get("qtd", 1))):
			return false
	return true


# =============================================================================
## Mesmos passos (tipo, chama, item, quantidade e segundos inteiros)? int x float não conta.
static func mesmos_passos(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		var x: Dictionary = a[k]
		var y: Dictionary = b[k]
		if str(x.get("tipo")) != str(y.get("tipo")) or str(x.get("estado", "")) != str(y.get("estado", "")) \
				or str(x.get("item", "")) != str(y.get("item", "")) or int(x.get("qtd", 0)) != int(y.get("qtd", 0)) \
				or roundi(float(x.get("seg", 0.0))) != roundi(float(y.get("seg", 0.0))):
			return false
	return true

func _fim(salvar: bool) -> void:
	if not ativo:
		return
	if salvar:
		var nome := _nome.text.strip_edges() if is_instance_valid(_nome) else str(pagina["nome"])
		pagina["nome"] = nome if nome != "" else "Receita sem nome"
		if not mesmos_passos(pagina["passos"], passos):
			pagina["resultado"] = {}   # receita mudou: o resultado anotado não vale mais
		elif nome != "" and not (nome in LivroReceitas.NOMES_PADRAO):
			# poção sem nome: o nome da receita vira o nome da poção (item, catálogo)
			LivroReceitas.nomear_pocao(livro, pagina, nome, database, game_temp)
		pagina["passos"] = passos
	ativo = false
	terminou.emit(salvar)

func _rotulo(t: String, tam: int, cor: Color, quebra: bool = true) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _botao(t: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 48
	b.pressed.connect(acao)
	return b

static func _chip_estilo(cor: Color, raio: int = 26) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = cor
	st.border_color = Color(0, 0, 0, 0.35)
	st.set_border_width_all(1)
	st.set_corner_radius_all(raio)
	st.set_content_margin_all(2)
	return st


# =============================================================================
# PEÇAS DE ARRASTAR
# =============================================================================
## Item da paleta: tocar adiciona no fim; arrastar leva para a lista.
class ChipPaleta extends Button:
	var editor
	var passo: Dictionary = {}

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		pressed.connect(_tocado)

	func _tocado() -> void:
		editor.adicionar(passo)

	func _get_drag_data(_p: Vector2):
		var prev := Label.new()
		prev.text = LivroReceitas.texto_passo(passo, editor.database)
		prev.add_theme_color_override("font_color", Color(0.2, 0.14, 0.1))
		set_drag_preview(prev)
		return {"novo": passo}


## Um passo na lista: tocar abre a edição; arrastar reordena (ou leva à lixeira).
class CartaoPasso extends PanelContainer:
	var editor
	var indice: int = 0
	var _ini := Vector2(-1, -1)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 1, 1, 0.45)
		st.border_color = Color(0.2, 0.14, 0.1, 0.3)
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		st.set_content_margin_all(6)
		add_theme_stylebox_override("panel", st)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_ini = ev.position
			elif _ini.x >= 0.0 and ev.position.distance_to(_ini) < 10.0:
				_ini = Vector2(-1, -1)
				editor.tocar_cartao(indice)

	func _get_drag_data(_p: Vector2):
		_ini = Vector2(-1, -1)
		var prev := Label.new()
		prev.text = "≡ " + LivroReceitas.texto_passo(editor.passos[indice], editor.database)
		prev.add_theme_color_override("font_color", Color(0.2, 0.14, 0.1))
		set_drag_preview(prev)
		modulate.a = 0.4
		return {"mover": indice}

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			modulate.a = 1.0

	func _can_drop_data(_p: Vector2, dados) -> bool:
		return dados is Dictionary and (dados.has("novo") or dados.has("mover"))

	func _drop_data(p: Vector2, dados) -> void:
		editor.soltar(dados, indice + (1 if p.y > size.y * 0.5 else 0))


## A lista aceita soltar também no espaço vazio (vai para o fim / pela altura).
class ListaPassos extends VBoxContainer:
	var editor

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _can_drop_data(_p: Vector2, dados) -> bool:
		return dados is Dictionary and (dados.has("novo") or dados.has("mover"))

	func _drop_data(p: Vector2, dados) -> void:
		editor.soltar(dados, editor.indice_no_ponto(p.y))


class Lixeira extends PanelContainer:
	var editor
	var _l: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.6, 0.15, 0.1, 0.15)
		st.border_color = Color(0.6, 0.15, 0.1, 0.6)
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		add_theme_stylebox_override("panel", st)
		_l = Label.new()
		_l.text = "✕ lixeira"
		_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_l.add_theme_font_size_override("font_size", 12)
		_l.add_theme_color_override("font_color", Color(0.6, 0.15, 0.1))
		add_child(_l)

	func _can_drop_data(_p: Vector2, dados) -> bool:
		return dados is Dictionary and dados.has("mover")

	func _drop_data(_p: Vector2, dados) -> void:
		editor.apagar(int(dados["mover"]))


## Número editável: arrastar para o lado muda; tocar nas setinhas ‹ › soma ou tira 1.
class SeletorNumero extends Control:
	const PASSO_PX: float = 14.0
	const SETA: float = 30.0           # largura da área de toque de cada setinha
	const LIMIAR: float = 6.0          # px: menos que isto é toque, não arrasto
	var _arrastou: bool = false
	var editor
	var indice: int = 0
	var campo: String = "seg"
	var minimo: int = 0
	var maximo: int = 300
	var formato: String = "%d"
	var _ini := Vector2(-1, -1)
	var _v_ini: int = 0
	var _f: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_f = get_theme_default_font()

	func _v() -> int:
		return editor.valor(indice, campo)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_ini = ev.position
				_v_ini = _v()
				_arrastou = false
			else:
				if not _arrastou and _ini.x >= 0.0:
					# toque: setinha da esquerda tira 1, da direita soma 1
					var d := 0
					if ev.position.x <= SETA:
						d = -1
					elif ev.position.x >= size.x - SETA:
						d = 1
					var novo_t := clampi(_v() + d, minimo, maximo)
					if d != 0 and novo_t != _v():
						editor.definir_valor(indice, campo, novo_t)
						queue_redraw()
				_ini = Vector2(-1, -1)
			accept_event()
		elif ev is InputEventMouseMotion and _ini.x >= 0.0:
			var d: float = ev.position.x - _ini.x
			if absf(d) < LIMIAR and not _arrastou:
				return
			_arrastou = true
			var novo := clampi(_v_ini + int(d / PASSO_PX), minimo, maximo)
			if novo != _v():
				editor.definir_valor(indice, campo, novo)
				queue_redraw()
			accept_event()

	func _draw() -> void:
		var v := _v()
		var tinta := Color(0.2, 0.14, 0.1)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(Vector2.ZERO, size), Color(tinta, 0.4), false, 1.0)
		_centro(size * 0.5 + Vector2(0, 6), formato % v, 18, tinta)
		draw_rect(Rect2(0, 0, SETA, size.y), Color(tinta, 0.08))
		draw_rect(Rect2(size.x - SETA, 0, SETA, size.y), Color(tinta, 0.08))
		_centro(Vector2(SETA * 0.5, size.y * 0.5 + 7), "‹", 22, Color(tinta, 0.75 if v > minimo else 0.25))
		_centro(Vector2(size.x - SETA * 0.5, size.y * 0.5 + 7), "›", 22, Color(tinta, 0.75 if v < maximo else 0.25))

	func _centro(p: Vector2, s: String, tam: int, cor: Color) -> void:
		var w := _f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_f, Vector2(p.x - w * 0.5, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
