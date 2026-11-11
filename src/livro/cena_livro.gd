# cena_livro.gd
# Cena do livro de receitas: livro aberto, duas páginas (uma receita por página),
# na parte de cima da tela (640x640; embaixo fica o HUD).
#   passar página: setas ‹ › ou arrastar o dedo para o lado
#   página efetiva: Editar, Copiar, Memorizar, Apagar
#   página de NPC:  Copiar, Memorizar (não edita)
#   rascunho:       Passar a limpo, Apagar (todo preparo cria um; são as primeiras
#                   páginas do livro, o mais novo primeiro)
#   poção sem nome (feita no preparo): "Dar nome à poção" na página; o nome vale para o
#                   item no inventário e para as próximas iguais. Poção com nome não muda.
#   + Nova receita: botão no rodapé (não há página em branco para avançar até ela)
# Editar abre um editor por cima do livro: nome, passos (+ chama, + ingrediente,
# subir/descer/apagar); "Finalizar" é sempre o último passo.
# Os dados ficam em GameTemp.livro (LivroReceitas). Aberta sozinha (F6), usa um livro de teste.
class_name CenaLivro
extends Control

signal fechou

const AREA := Vector2(640, 640)
const RECT_LIVRO := Rect2(6, 10, 628, 620)
const RECT_PAG := [Rect2(18, 22, 298, 596), Rect2(324, 22, 298, 596)]
const MARGEM: float = 14.0
const ALT_RODAPE: float = 48.0      # setas e número das páginas
const SWIPE_MIN: float = 70.0

const COR_FUNDO := Color(0, 0, 0, 0.55)
const COR_CAPA := Color(0.3, 0.17, 0.1)
const COR_PAPEL := Color(0.96, 0.91, 0.8)
const COR_PAPEL_RASCUNHO := Color(0.9, 0.89, 0.85)
const COR_TINTA := Color(0.2, 0.14, 0.1)
const COR_SUAVE := Color(0.47, 0.4, 0.32)
const COR_DESTAQUE := Color(0.5, 0.18, 0.45)
const COR_NPC := Color(0.15, 0.3, 0.45)

var livro: Dictionary = {}
var database = null
var _gt = null                      # GameTemp (null com a cena aberta sozinha)
var _nomear: PanelContainer
var _nomear_campo: LineEdit
var _nomeando: Dictionary = {}
var _vistos: Array = []             # ingredientes que dá para escolher no editor

var _folhas: Array = []             # páginas na ordem do livro: rascunhos (mais novo primeiro) e depois as efetivas
var _spread: int = 0                # índice da folha da esquerda (par)
var _caixas: Array = []             # [VBox esquerda, VBox direita]
var _papeis: Array = []             # [Panel esquerda, Panel direita]
var _seta_esq: Button
var _seta_dir: Button
var _indicador: Label
var _b_nova: Button
var _confirmar_apagar: int = -1     # id que pediu "Apagar" uma vez

# editor
var _editor: PanelContainer
var _editando: Dictionary = {}      # a página sendo editada (original)
var _ed_passos: Array = []          # cópia de trabalho dos passos
var _ed_nome: LineEdit
var _ed_lista: VBoxContainer
var _ed_chama: OptionButton
var _ed_item: OptionButton
var _ed_qtd: SpinBox
var _ed_seg: SpinBox

var _toque_ini := Vector2(-1, -1)


func _ready() -> void:
	theme = _tema()
	size = AREA
	mouse_filter = Control.MOUSE_FILTER_STOP
	_carregar_dados()
	_montar()
	_atualizar()


## GameTemp do jogo, ou um livro de teste quando a cena roda sozinha.
func _carregar_dados() -> void:
	var gt = get_node_or_null("/root/Main/GameManager/GameTemp")
	if gt and "livro" in gt:
		_gt = gt
		database = gt.database
		if gt.livro.is_empty():
			gt.livro = LivroReceitas.novo(LivroReceitas.receitas_conhecidas())
		livro = gt.livro
		for id in gt.itens_vistos:
			if LivroReceitas.eh_ingrediente(LivroReceitas.item(id, database)):
				_vistos.append(id)
		_vistos.sort()
	else:
		livro = LivroReceitas.novo(LivroReceitas.receitas_conhecidas())
		_vistos = LivroReceitas.todos_ingredientes()
		var r := LivroReceitas.adicionar_rascunho(livro, [
			{"tipo": "chama", "estado": "laranja"},
			{"tipo": "ingrediente", "item": "erva", "qtd": 3, "seg": 25.0}], {"pocao": "Poção de Erva Fraca", "a": 0.62, "vezes": 1})
		r["quando"] = "teste"


# =============================================================================
# MONTAGEM
# =============================================================================
func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.size = AREA
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var capa := Panel.new()
	capa.position = RECT_LIVRO.position
	capa.size = RECT_LIVRO.size
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_theme_stylebox_override("panel", _caixa(COR_CAPA, 10, Color(0, 0, 0, 0.4), 2))
	add_child(capa)

	for i in 2:
		var r: Rect2 = RECT_PAG[i]
		var papel := Panel.new()
		papel.position = r.position
		papel.size = r.size
		papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(papel)
		_papeis.append(papel)
		var caixa := VBoxContainer.new()
		caixa.position = r.position + Vector2(MARGEM, MARGEM)
		caixa.size = Vector2(r.size.x - 2 * MARGEM, r.size.y - 2 * MARGEM - ALT_RODAPE)
		caixa.add_theme_constant_override("separation", 6)
		caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caixa)
		_caixas.append(caixa)

	# lombada
	var lombada := ColorRect.new()
	lombada.color = Color(0, 0, 0, 0.25)
	lombada.position = Vector2(316, 22)
	lombada.size = Vector2(8, 596)
	lombada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lombada)

	# rodapé: setas e número
	var y_rod: float = RECT_PAG[0].end.y - ALT_RODAPE + 4
	_seta_esq = _botao("‹", _passar.bind(-1))
	_seta_esq.position = Vector2(RECT_PAG[0].position.x + 8, y_rod)
	_seta_esq.size = Vector2(56, 40)
	_seta_esq.add_theme_font_size_override("font_size", 24)
	add_child(_seta_esq)
	_seta_dir = _botao("›", _passar.bind(1))
	_seta_dir.position = Vector2(RECT_PAG[1].end.x - 64, y_rod)
	_seta_dir.size = Vector2(56, 40)
	_seta_dir.add_theme_font_size_override("font_size", 24)
	add_child(_seta_dir)
	_b_nova = _botao("+ Nova receita", _nova)
	_b_nova.position = Vector2(RECT_PAG[0].position.x + 72, y_rod)
	_b_nova.size = Vector2(150, 40)
	add_child(_b_nova)
	_indicador = _rotulo("", 12, COR_SUAVE, false)
	_indicador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicador.position = Vector2(RECT_PAG[1].position.x + 10, y_rod + 10)
	_indicador.size = Vector2(200, 24)
	_indicador.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_indicador)

	# fechar
	var x := _botao("✕", fechar)
	x.position = Vector2(RECT_LIVRO.end.x - 44, RECT_LIVRO.position.y - 6)
	x.size = Vector2(44, 40)
	x.add_theme_stylebox_override("normal", _caixa(COR_CAPA, 8, Color(1, 1, 1, 0.3), 1))
	x.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	add_child(x)

	_montar_editor()
	_montar_nomear()


# =============================================================================
# PÁGINAS
# =============================================================================
func _atualizar() -> void:
	_folhas = livro["rascunhos"].duplicate()
	_folhas.reverse()   # rascunho mais novo primeiro
	_folhas.append_array(livro["paginas"])
	_spread = clampi(_spread, 0, maxi(0, ((_folhas.size() - 1) / 2) * 2))
	for lado in 2:
		var k := _spread + lado
		var folha = _folhas[k] if k < _folhas.size() else null
		_montar_pagina(lado, folha, k + 1)
	_seta_esq.disabled = _spread <= 0
	_seta_dir.disabled = _spread + 2 >= _folhas.size()   # nunca avança para duas páginas vazias
	_b_nova.disabled = LivroReceitas.cheio(livro)
	_indicador.text = "%d-%d de %d   ·   %d/%d páginas" % [_spread + 1, mini(_spread + 2, _folhas.size()), _folhas.size(),
		livro["paginas"].size(), int(livro["max"])]

func _passar(d: int) -> void:
	_confirmar_apagar = -1
	_spread = clampi(_spread + 2 * d, 0, maxi(0, ((_folhas.size() - 1) / 2) * 2))
	_atualizar()

## Abre o livro na página de uma receita (por id).
func ir_para(id: int) -> void:
	for k in _folhas.size():
		if _folhas[k] is Dictionary and int(_folhas[k].get("id", -1)) == id:
			_spread = (k / 2) * 2
	_atualizar()

func _montar_pagina(lado: int, folha, numero: int) -> void:
	var caixa: VBoxContainer = _caixas[lado]
	for c in caixa.get_children():
		caixa.remove_child(c)
		c.queue_free()
	var rascunho: bool = folha is Dictionary and folha.get("tipo") == "rascunho"
	_papeis[lado].add_theme_stylebox_override("panel", _caixa(COR_PAPEL_RASCUNHO if rascunho else COR_PAPEL, 4, Color(0, 0, 0, 0.15), 1))
	if folha == null:
		return
	if folha.get("slot") == "nova":
		caixa.add_child(_espaco())
		var t := _rotulo("Página em branco", 14, COR_SUAVE)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caixa.add_child(t)
		var b := _botao("+ Nova receita", _nova)
		caixa.add_child(b)
		caixa.add_child(_espaco())
		return

	var p: Dictionary = folha
	# cabeçalho: tipo e número
	var topo := HBoxContainer.new()
	var tipo := ""
	match p.get("tipo"):
		"rascunho": tipo = "rascunho · " + str(p.get("quando", ""))
		"npc": tipo = "receita ensinada"
	var lt := _rotulo(tipo, 11, COR_NPC if p.get("tipo") == "npc" else COR_SUAVE, false)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.clip_text = true
	topo.add_child(lt)
	topo.add_child(_rotulo(str(numero), 11, COR_SUAVE, false))
	caixa.add_child(topo)
	# nome
	var nome := _rotulo(str(p["nome"]), 19, COR_NPC if p.get("tipo") == "npc" else COR_TINTA)
	caixa.add_child(nome)
	if LivroReceitas.esta_memorizada(livro, p):
		caixa.add_child(_rotulo("★ memorizada para o próximo preparo", 11, COR_DESTAQUE))
	# ingredientes
	var ings := LivroReceitas.ingredientes(p)
	var partes: Array = []
	for par in ings:
		partes.append("%d %s" % [par[1], LivroReceitas.nome_item(par[0], database)])
	caixa.add_child(_rotulo("Ingredientes", 11, COR_SUAVE))
	caixa.add_child(_rotulo(", ".join(partes) if not partes.is_empty() else "nenhum ainda", 13, COR_DESTAQUE if not partes.is_empty() else COR_SUAVE))
	caixa.add_child(_linha())
	# passos (rolam se forem muitos)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	sc.add_child(lista)
	caixa.add_child(sc)
	var n := 1
	for s in p["passos"]:
		lista.add_child(_linha_passo(n, s))
		n += 1
	lista.add_child(_linha_passo(n, {"tipo": "finalizar"}))
	# resultado
	var res: Dictionary = p.get("resultado", {})
	var txt_res := "Nunca feita"
	if not res.is_empty():
		txt_res = "Feita %dx · %s · %d%%" % [int(res.get("vezes", 1)), str(res.get("pocao", "?")), roundi(float(res.get("a", 0.0)) * 100.0)]
	caixa.add_child(_linha())
	caixa.add_child(_rotulo(txt_res, 12, COR_TINTA if not res.is_empty() else COR_SUAVE))
	if res.get("nomeavel", false):
		var bn := _botao("Dar nome à poção", _abrir_nomear.bind(p))
		bn.add_theme_color_override("font_color", COR_DESTAQUE)
		caixa.add_child(bn)
	# botões
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	match p.get("tipo"):
		"efetiva":
			g.add_child(_botao("Editar", _editar.bind(p)))
			g.add_child(_botao("Copiar", _copiar.bind(p)))
			g.add_child(_botao("Esquecer" if LivroReceitas.esta_memorizada(livro, p) else "Memorizar", _memorizar.bind(p)))
			g.add_child(_botao_apagar(p))
		"npc":
			g.add_child(_botao("Copiar", _copiar.bind(p)))
			g.add_child(_botao("Esquecer" if LivroReceitas.esta_memorizada(livro, p) else "Memorizar", _memorizar.bind(p)))
		"rascunho":
			var pl := _botao("Passar a limpo", _passar_a_limpo.bind(p))
			pl.disabled = LivroReceitas.cheio(livro)
			g.add_child(pl)
			g.add_child(_botao_apagar(p))
	for b in g.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_child(g)

func _linha_passo(n: int, s: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(_rotulo("%d." % n, 13, COR_SUAVE, false))
	if s.get("tipo") == "chama":
		var bola := ColorRect.new()
		bola.color = EstadosChama.cor(s["estado"])
		bola.custom_minimum_size = Vector2(12, 12)
		bola.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bola)
	var txt := "Finalizar" if s.get("tipo") == "finalizar" else LivroReceitas.texto_passo(s, database)
	var l := _rotulo(txt, 14, COR_TINTA)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h

func _botao_apagar(p: Dictionary) -> Button:
	var confirmar: bool = _confirmar_apagar == int(p["id"])
	var b := _botao("Confirmar?" if confirmar else "Apagar", _apagar.bind(p))
	if confirmar:
		b.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
	return b


# ---- ações ----
func _nova() -> void:
	var p := LivroReceitas.nova_pagina(livro)
	if not p.is_empty():
		_atualizar()
		ir_para(int(p["id"]))
		_editar(p)

func _copiar(p: Dictionary) -> void:
	var c := LivroReceitas.copiar(livro, p)
	if c.is_empty():
		return   # livro cheio
	_atualizar()
	ir_para(int(c["id"]))

func _memorizar(p: Dictionary) -> void:
	LivroReceitas.memorizar(livro, p)
	_atualizar()

func _apagar(p: Dictionary) -> void:
	if _confirmar_apagar != int(p["id"]):
		_confirmar_apagar = int(p["id"])   # 1º toque pede confirmação
		_atualizar()
		return
	_confirmar_apagar = -1
	LivroReceitas.apagar(livro, p)
	_atualizar()

func _passar_a_limpo(p: Dictionary) -> void:
	if LivroReceitas.passar_a_limpo(livro, p):
		_atualizar()
		ir_para(int(p["id"]))
		_editar(p)


# =============================================================================
# EDITOR
# =============================================================================
func _montar_editor() -> void:
	_editor = PanelContainer.new()
	_editor.position = RECT_LIVRO.position + Vector2(8, 8)
	_editor.size = RECT_LIVRO.size - Vector2(16, 16)
	var st := _caixa(COR_PAPEL, 6, Color(0, 0, 0, 0.3), 1)
	st.set_content_margin_all(14)
	_editor.add_theme_stylebox_override("panel", st)
	add_child(_editor)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_editor.add_child(col)
	col.add_child(_rotulo("Editar receita", 18, COR_TINTA))
	_ed_nome = LineEdit.new()
	_ed_nome.placeholder_text = "nome da receita"
	_ed_nome.custom_minimum_size.y = 44
	col.add_child(_ed_nome)
	col.add_child(_rotulo("Passos", 12, COR_SUAVE))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ed_lista = VBoxContainer.new()
	_ed_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ed_lista.add_theme_constant_override("separation", 4)
	sc.add_child(_ed_lista)
	col.add_child(sc)
	col.add_child(_linha())
	# + chama
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 6)
	_ed_chama = OptionButton.new()
	_ed_chama.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ed_chama.custom_minimum_size.y = 44
	for e in EstadosChama.LISTA:
		_ed_chama.add_item("Chama " + str(e["nome"]).to_lower())
	_ed_chama.select(EstadosChama.indice("normal"))
	h1.add_child(_ed_chama)
	h1.add_child(_botao("+ Chama", _ed_add_chama))
	col.add_child(h1)
	# + ingrediente
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 6)
	_ed_item = OptionButton.new()
	_ed_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ed_item.custom_minimum_size.y = 44
	_ed_item.clip_text = true
	h2.add_child(_ed_item)
	_ed_qtd = _spin(1, 20, 1, 1, "×", "")
	h2.add_child(_ed_qtd)
	_ed_seg = _spin(0, 300, 5, 10, "", " s")
	h2.add_child(_ed_seg)
	h2.add_child(_botao("+", _ed_add_ingrediente))
	col.add_child(h2)
	# cancelar / salvar
	var h3 := HBoxContainer.new()
	h3.add_theme_constant_override("separation", 8)
	var cancelar := _botao("Cancelar", _ed_fechar.bind(false))
	cancelar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var salvar := _botao("Salvar", _ed_fechar.bind(true))
	salvar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h3.add_child(cancelar)
	h3.add_child(salvar)
	col.add_child(h3)
	_editor.hide()

func _editar(p: Dictionary) -> void:
	if p.get("tipo") == "npc":
		return
	_confirmar_apagar = -1
	_editando = p
	_ed_passos = p["passos"].duplicate(true)
	_ed_nome.text = str(p["nome"])
	_ed_item.clear()
	for id in _vistos:
		_ed_item.add_item(LivroReceitas.nome_item(id, database))
		_ed_item.set_item_metadata(_ed_item.item_count - 1, id)
	_ed_item.disabled = _vistos.is_empty()
	if _vistos.is_empty():
		_ed_item.add_item("(nenhum ingrediente visto)")
	_ed_lista_atualizar()
	_editor.show()

func _ed_lista_atualizar() -> void:
	for c in _ed_lista.get_children():
		_ed_lista.remove_child(c)
		c.queue_free()
	for i in _ed_passos.size():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var linha := _linha_passo(i + 1, _ed_passos[i])
		linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(linha)
		var sobe := _botao("↑", _ed_mover.bind(i, -1))
		sobe.disabled = i == 0
		var desce := _botao("↓", _ed_mover.bind(i, 1))
		desce.disabled = i == _ed_passos.size() - 1
		for b in [sobe, desce, _botao("✕", _ed_remover.bind(i))]:
			b.custom_minimum_size = Vector2(44, 40)
			h.add_child(b)
		_ed_lista.add_child(h)
	_ed_lista.add_child(_linha_passo(_ed_passos.size() + 1, {"tipo": "finalizar"}))

func _ed_add_chama() -> void:
	_ed_passos.append({"tipo": "chama", "estado": EstadosChama.LISTA[_ed_chama.selected]["id"]})
	_ed_lista_atualizar()

func _ed_add_ingrediente() -> void:
	if _vistos.is_empty() or _ed_item.selected < 0:
		return
	_ed_passos.append({"tipo": "ingrediente", "item": str(_ed_item.get_item_metadata(_ed_item.selected)),
		"qtd": int(_ed_qtd.value), "seg": float(_ed_seg.value)})
	_ed_lista_atualizar()

func _ed_mover(i: int, d: int) -> void:
	var j := i + d
	if j < 0 or j >= _ed_passos.size():
		return
	var tmp = _ed_passos[i]
	_ed_passos[i] = _ed_passos[j]
	_ed_passos[j] = tmp
	_ed_lista_atualizar()

func _ed_remover(i: int) -> void:
	_ed_passos.remove_at(i)
	_ed_lista_atualizar()

func _ed_fechar(salvar: bool) -> void:
	if salvar and not _editando.is_empty():
		var nome := _ed_nome.text.strip_edges()
		_editando["nome"] = nome if nome != "" else "Receita sem nome"
		if _editando["passos"] != _ed_passos:
			_editando["resultado"] = {}   # receita mudou: o resultado anotado não vale mais
		_editando["passos"] = _ed_passos
	_editando = {}
	_editor.hide()
	_atualizar()


# =============================================================================
# NOMEAR A POÇÃO
# =============================================================================
func _montar_nomear() -> void:
	_nomear = PanelContainer.new()
	_nomear.position = Vector2(60, 220)
	_nomear.size = Vector2(520, 200)
	var st := _caixa(COR_PAPEL, 6, COR_DESTAQUE, 2)
	st.set_content_margin_all(16)
	_nomear.add_theme_stylebox_override("panel", st)
	add_child(_nomear)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_nomear.add_child(col)
	col.add_child(_rotulo("Que nome essa poção vai ter?", 16, COR_TINTA))
	_nomear_campo = LineEdit.new()
	_nomear_campo.max_length = 32
	_nomear_campo.placeholder_text = "nome da poção"
	_nomear_campo.custom_minimum_size.y = 48
	_nomear_campo.text_submitted.connect(_salvar_nome)
	col.add_child(_nomear_campo)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var c := _botao("Cancelar", _fechar_nomear)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := _botao("Dar nome", _salvar_nome_botao)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	h.add_child(ok)
	col.add_child(h)
	_nomear.hide()

func _abrir_nomear(p: Dictionary) -> void:
	_nomeando = p
	_nomear_campo.text = ""
	_nomear.show()
	_nomear_campo.grab_focus()

func _salvar_nome_botao() -> void:
	_salvar_nome(_nomear_campo.text)

func _salvar_nome(nome: String) -> void:
	if _nomeando.is_empty():
		return
	if LivroReceitas.nomear_pocao(livro, _nomeando, nome, database, _gt):
		_fechar_nomear()

func _fechar_nomear() -> void:
	_nomeando = {}
	_nomear.hide()
	_atualizar()


# =============================================================================
# ABRIR / FECHAR / ARRASTAR
# =============================================================================
func fechar() -> void:
	fechou.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		if _nomear.visible:
			_fechar_nomear()
		elif _editor.visible:
			_ed_fechar(false)
		else:
			fechar()
		get_viewport().set_input_as_handled()
		return
	if _editor.visible or _nomear.visible:
		return
	# arrastar para o lado passa a página
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and RECT_LIVRO.has_point(event.position):
			_toque_ini = event.position
		elif not event.pressed and _toque_ini.x >= 0.0:
			var d: Vector2 = event.position - _toque_ini
			_toque_ini = Vector2(-1, -1)
			if absf(d.x) > SWIPE_MIN and absf(d.y) < absf(d.x):
				_passar(-1 if d.x > 0 else 1)


# =============================================================================
# PEÇAS
# =============================================================================
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
	b.custom_minimum_size.y = 40
	b.pressed.connect(acao)
	return b

func _spin(mn: float, mx: float, passo: float, v: float, prefixo: String, sufixo: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = passo
	s.value = v
	s.prefix = prefixo
	s.suffix = sufixo
	s.custom_minimum_size = Vector2(96, 44)
	return s

func _linha() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = Color(COR_SUAVE, 0.6)
	return s

func _espaco() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func _caixa(fundo: Color, raio: int, borda: Color, largura: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fundo
	st.border_color = borda
	st.set_border_width_all(largura)
	st.set_corner_radius_all(raio)
	st.set_content_margin_all(6)
	return st

## Tema de papel: tinta escura, botões finos (o tema do jogo tem fonte 24).
func _tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	for tipo in ["Label", "Button", "LineEdit", "OptionButton", "SpinBox", "PopupMenu"]:
		t.set_font_size("font_size", tipo, 14)
		t.set_color("font_color", tipo, COR_TINTA)
	for tipo in ["Button", "OptionButton"]:
		t.set_color("font_hover_color", tipo, COR_TINTA)
		t.set_color("font_pressed_color", tipo, COR_DESTAQUE)
		t.set_color("font_focus_color", tipo, COR_TINTA)
		t.set_color("font_disabled_color", tipo, Color(COR_SUAVE, 0.5))
		t.set_stylebox("normal", tipo, _caixa(Color(0, 0, 0, 0.04), 4, Color(COR_TINTA, 0.45), 1))
		t.set_stylebox("hover", tipo, _caixa(Color(0, 0, 0, 0.09), 4, Color(COR_TINTA, 0.6), 1))
		t.set_stylebox("pressed", tipo, _caixa(Color(COR_DESTAQUE, 0.18), 4, COR_DESTAQUE, 1))
		t.set_stylebox("disabled", tipo, _caixa(Color(0, 0, 0, 0.02), 4, Color(COR_TINTA, 0.15), 1))
		t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", _caixa(Color(1, 1, 1, 0.55), 4, Color(COR_TINTA, 0.45), 1))
	t.set_stylebox("focus", "LineEdit", _caixa(Color(1, 1, 1, 0.7), 4, COR_DESTAQUE, 1))
	t.set_color("caret_color", "LineEdit", COR_TINTA)
	t.set_color("font_placeholder_color", "LineEdit", Color(COR_SUAVE, 0.7))
	t.set_stylebox("panel", "PopupMenu", _caixa(COR_PAPEL, 4, Color(COR_TINTA, 0.5), 1))
	t.set_color("font_hover_color", "PopupMenu", COR_DESTAQUE)
	t.set_stylebox("hover", "PopupMenu", _caixa(Color(COR_DESTAQUE, 0.15), 2, Color(0, 0, 0, 0), 0))
	return t
