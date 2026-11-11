# cena_livro.gd
# Cena do livro de receitas: livro aberto, duas páginas (uma receita por página),
# na parte de cima da tela (640x640; embaixo fica o HUD).
#   passar página: setas ‹ › ou arrastar o dedo para o lado
#   página efetiva: Editar, Memorizar, Apagar
#   página de NPC:  Memorizar (não edita)
#   rascunho:       Passar a limpo, Apagar (todo preparo cria um; ficam no fim do
#                   livro, do mais antigo ao mais novo)
#   poção sem nome (feita no preparo): "Dar nome à poção" na página; o nome vale para o
#                   item no inventário e para as próximas iguais. Poção com nome não muda.
#   + Nova receita: botão no rodapé (não há página em branco para avançar até ela)
# Editar: a própria página vira editável e a página ao lado vira a paleta (EditorReceita,
# arrastar e soltar); Pronto / Cancelar voltam ao normal. Tocar numa página já feita
# abre o DetalheReceita (gráfico do melhor preparo).
# Tipos marcados no papel: ensinada = fitinha dourada; rascunho = papel cinza e carimbo.
# Animações: abrir/fechar o livro, virar folha, ir até uma página (várias folhas),
# página nova aparecendo, página apagada sumindo.
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

var _editor: EditorReceita
var _editando_lado: int = -1        # lado da receita em edição (o outro vira paleta)
var _detalhe: DetalheReceita
var _corpo: Control                 # o livro todo (para abrir/fechar)
var _folhas_no: Array = []          # [Control esquerda, Control direita] (viram)
var _fitas: Array = []              # fitinha das ensinadas, por lado
var _carimbos: Array = []           # carimbo "rascunho", por lado
var _animando: bool = false
const T_FOLHA: float = 0.14         # meia virada (s)
const T_FOLHA_RAPIDA: float = 0.05
const COR_FITA := Color(0.85, 0.65, 0.15)

var _toque_ini := Vector2(-1, -1)


func _ready() -> void:
	theme = _tema()
	size = AREA
	mouse_filter = Control.MOUSE_FILTER_STOP
	_carregar_dados()
	_montar()
	_atualizar()
	_animar_abrir()


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

	_corpo = Control.new()
	_corpo.size = AREA
	_corpo.pivot_offset = AREA * 0.5
	_corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corpo)
	var capa := Panel.new()
	capa.position = RECT_LIVRO.position
	capa.size = RECT_LIVRO.size
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_theme_stylebox_override("panel", _caixa(COR_CAPA, 10, Color(0, 0, 0, 0.4), 2))
	_corpo.add_child(capa)

	for i in 2:
		var r: Rect2 = RECT_PAG[i]
		var folha := Control.new()
		folha.position = r.position
		folha.size = r.size
		folha.pivot_offset = Vector2(r.size.x if i == 0 else 0.0, r.size.y * 0.5)   # gira na lombada
		folha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_corpo.add_child(folha)
		_folhas_no.append(folha)
		var papel := Panel.new()
		papel.size = r.size
		papel.mouse_filter = Control.MOUSE_FILTER_STOP
		papel.gui_input.connect(_papel_input.bind(i))
		folha.add_child(papel)
		_papeis.append(papel)
		var carimbo := _rotulo("RASCUNHO", 30, Color(0.65, 0.12, 0.1, 0.22), false)
		carimbo.position = Vector2(40, r.size.y * 0.42)
		carimbo.rotation = deg_to_rad(-14)
		folha.add_child(carimbo)
		_carimbos.append(carimbo)
		var caixa := VBoxContainer.new()
		caixa.position = Vector2(MARGEM, MARGEM)
		caixa.size = Vector2(r.size.x - 2 * MARGEM, r.size.y - 2 * MARGEM - ALT_RODAPE)
		caixa.add_theme_constant_override("separation", 6)
		caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		folha.add_child(caixa)
		_caixas.append(caixa)
		# fitinha das ensinadas: pendurada no alto da página
		var fita := Control.new()
		fita.position = Vector2(r.size.x - 42, -8)
		fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var faixa := ColorRect.new()
		faixa.color = COR_FITA
		faixa.size = Vector2(18, 70)
		faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fita.add_child(faixa)
		var ponta := Polygon2D.new()
		ponta.polygon = PackedVector2Array([Vector2(0, 70), Vector2(18, 70), Vector2(18, 82), Vector2(9, 74), Vector2(0, 82)])
		ponta.color = COR_FITA
		fita.add_child(ponta)
		var estrela := _rotulo("★", 13, Color(0.45, 0.25, 0.05), false)
		estrela.position = Vector2(2, 44)
		fita.add_child(estrela)
		folha.add_child(fita)
		_fitas.append(fita)

	# lombada
	var lombada := ColorRect.new()
	lombada.color = Color(0, 0, 0, 0.25)
	lombada.position = Vector2(316, 22)
	lombada.size = Vector2(8, 596)
	lombada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corpo.add_child(lombada)

	# rodapé: setas e número
	var y_rod: float = RECT_PAG[0].end.y - ALT_RODAPE + 4
	_seta_esq = _botao("‹", _passar.bind(-1))
	_seta_esq.position = Vector2(RECT_PAG[0].position.x + 8, y_rod)
	_seta_esq.size = Vector2(56, 40)
	_seta_esq.add_theme_font_size_override("font_size", 24)
	_corpo.add_child(_seta_esq)
	_seta_dir = _botao("›", _passar.bind(1))
	_seta_dir.position = Vector2(RECT_PAG[1].end.x - 64, y_rod)
	_seta_dir.size = Vector2(56, 40)
	_seta_dir.add_theme_font_size_override("font_size", 24)
	_corpo.add_child(_seta_dir)
	_b_nova = _botao("+ Nova receita", _nova)
	_b_nova.position = Vector2(RECT_PAG[0].position.x + 72, y_rod)
	_b_nova.size = Vector2(150, 40)
	_corpo.add_child(_b_nova)
	_indicador = _rotulo("", 12, COR_SUAVE, false)
	_indicador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicador.position = Vector2(RECT_PAG[1].position.x + 10, y_rod + 10)
	_indicador.size = Vector2(200, 24)
	_indicador.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_corpo.add_child(_indicador)

	# fechar
	var x := _botao("✕", fechar)
	x.position = Vector2(RECT_LIVRO.end.x - 44, RECT_LIVRO.position.y - 6)
	x.size = Vector2(44, 40)
	x.add_theme_stylebox_override("normal", _caixa(COR_CAPA, 8, Color(1, 1, 1, 0.3), 1))
	x.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_corpo.add_child(x)

	_editor = EditorReceita.new()
	add_child(_editor)
	_editor.montar(livro, database, _vistos)
	_editor.terminou.connect(_editor_terminou)
	_detalhe = DetalheReceita.new()
	_detalhe.position = RECT_LIVRO.position + Vector2(6, 6)
	_detalhe.size = RECT_LIVRO.size - Vector2(12, 12)
	add_child(_detalhe)
	_detalhe.montar(database)
	_montar_nomear()


# =============================================================================
# PÁGINAS
# =============================================================================
func _atualizar() -> void:
	_folhas = livro["paginas"].duplicate()
	_folhas.append_array(livro["rascunhos"])   # rascunhos no fim do livro
	_spread = clampi(_spread, 0, maxi(0, ((_folhas.size() - 1) / 2) * 2))
	if _editando_lado >= 0:
		_montar_edicao()
		return
	for lado in 2:
		var k := _spread + lado
		var folha = _folhas[k] if k < _folhas.size() else null
		_montar_pagina(lado, folha, k + 1)
	_seta_esq.disabled = _spread <= 0
	_seta_dir.disabled = _spread + 2 >= _folhas.size()   # nunca avança para duas páginas vazias
	_b_nova.disabled = LivroReceitas.cheio(livro)
	_indicador.text = "%d-%d de %d   ·   %d/%d páginas" % [_spread + 1, mini(_spread + 2, _folhas.size()), _folhas.size(),
		livro["paginas"].size(), int(livro["max"])]

func _ultimo_spread() -> int:
	return maxi(0, ((_folhas.size() - 1) / 2) * 2)

func _passar(d: int) -> void:
	if _animando:
		return
	_confirmar_apagar = -1
	var alvo := clampi(_spread + 2 * d, 0, _ultimo_spread())
	if alvo == _spread:
		return
	_animando = true
	await _virar(d, T_FOLHA)
	_animando = false

## Vira uma folha: a página do lado que vira fecha na lombada, troca, a outra abre.
func _virar(d: int, t: float) -> void:
	var sai: Control = _folhas_no[1] if d > 0 else _folhas_no[0]
	var entra: Control = _folhas_no[0] if d > 0 else _folhas_no[1]
	var tw := create_tween()
	tw.tween_property(sai, "scale:x", 0.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	sai.scale.x = 1.0
	_spread = clampi(_spread + 2 * d, 0, _ultimo_spread())
	_atualizar()
	entra.scale.x = 0.0
	tw = create_tween()
	tw.tween_property(entra, "scale:x", 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

## Vai até a página de uma receita (por id), virando as folhas no caminho.
func ir_para(id: int) -> void:
	_folhas = livro["paginas"].duplicate()
	_folhas.append_array(livro["rascunhos"])
	var alvo := -1
	for k in _folhas.size():
		if int(_folhas[k].get("id", -1)) == id:
			alvo = (k / 2) * 2
	if alvo < 0:
		_atualizar()
		return
	_animando = true
	while _spread != alvo:
		await _virar(1 if alvo > _spread else -1, T_FOLHA_RAPIDA)
	_animando = false
	_atualizar()

## Lado (0/1) em que a página está agora, ou -1.
func _lado_de(id: int) -> int:
	for lado in 2:
		var k := _spread + lado
		if k < _folhas.size() and int(_folhas[k].get("id", -1)) == id:
			return lado
	return -1

func _montar_pagina(lado: int, folha, numero: int) -> void:
	var caixa: VBoxContainer = _caixas[lado]
	for c in caixa.get_children():
		caixa.remove_child(c)
		c.queue_free()
	var rascunho: bool = folha is Dictionary and folha.get("tipo") == "rascunho"
	_papeis[lado].add_theme_stylebox_override("panel", _caixa(COR_PAPEL_RASCUNHO if rascunho else COR_PAPEL, 4, Color(0, 0, 0, 0.15), 1))
	_carimbos[lado].visible = rascunho
	_fitas[lado].visible = folha is Dictionary and folha.get("tipo") == "npc"
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
			g.add_child(_botao("Esquecer" if LivroReceitas.esta_memorizada(livro, p) else "Memorizar", _memorizar.bind(p)))
			g.add_child(_botao_apagar(p))
		"npc":
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
	if _animando:
		return
	var p := LivroReceitas.nova_pagina(livro)
	if p.is_empty():
		return
	await ir_para(int(p["id"]))
	await _aparecer_pagina(int(p["id"]))
	_editar(p)

## Página nova: a tinta aparece de cima para baixo.
func _aparecer_pagina(id: int) -> void:
	var lado := _lado_de(id)
	if lado < 0:
		return
	var caixa: Control = _caixas[lado]
	caixa.modulate.a = 0.0
	caixa.scale = Vector2(1.0, 0.85)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(caixa, "modulate:a", 1.0, 0.35)
	tw.tween_property(caixa, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

func _memorizar(p: Dictionary) -> void:
	LivroReceitas.memorizar(livro, p)
	_atualizar()

func _apagar(p: Dictionary) -> void:
	if _animando:
		return
	if _confirmar_apagar != int(p["id"]):
		_confirmar_apagar = int(p["id"])   # 1º toque pede confirmação
		_atualizar()
		return
	_confirmar_apagar = -1
	# a página some e as outras se ajeitam
	var lado := _lado_de(int(p["id"]))
	if lado >= 0:
		_animando = true
		var folha: Control = _folhas_no[lado]
		var tw := create_tween().set_parallel(true)
		tw.tween_property(folha, "modulate:a", 0.0, 0.3)
		tw.tween_property(folha, "position:y", folha.position.y + 24, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		folha.modulate.a = 1.0
		folha.position = RECT_PAG[lado].position
		_animando = false
	LivroReceitas.apagar(livro, p)
	_atualizar()

func _passar_a_limpo(p: Dictionary) -> void:
	if _animando:
		return
	if LivroReceitas.passar_a_limpo(livro, p):
		await ir_para(int(p["id"]))
		await _aparecer_pagina(int(p["id"]))
		_editar(p)

## Tocar no papel (fora dos botões) de uma página já feita abre o detalhe.
func _papel_input(ev: InputEvent, lado: int) -> void:
	if _editor.ativo or not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed):
		return
	if _toque_ini.x >= 0.0 and ev.global_position.distance_to(_toque_ini) > 12.0:
		return   # foi um arrasto (virar página)
	var k := _spread + lado
	if k < _folhas.size() and DetalheReceita.tem_detalhe(_folhas[k]):
		_detalhe.abrir(_folhas[k])


# =============================================================================
# EDITOR
# =============================================================================
func _editar(p: Dictionary) -> void:
	if p.get("tipo") == "npc":
		return
	var lado := _lado_de(int(p["id"]))
	if lado < 0:
		return
	_confirmar_apagar = -1
	_editor.abrir(p)
	_editando_lado = lado
	_atualizar()

## As duas páginas durante a edição: a receita (editável) e a paleta ao lado.
func _montar_edicao() -> void:
	var outro := 1 - _editando_lado
	for lado in 2:
		var caixa: VBoxContainer = _caixas[lado]
		for c in caixa.get_children():
			caixa.remove_child(c)
			c.queue_free()
		_papeis[lado].add_theme_stylebox_override("panel", _caixa(COR_PAPEL, 4, Color(0, 0, 0, 0.15), 1))
		_carimbos[lado].visible = false
		_fitas[lado].visible = false
	_editor.montar_pagina(_caixas[_editando_lado])
	_editor.montar_paleta(_caixas[outro])
	_seta_esq.disabled = true
	_seta_dir.disabled = true
	_b_nova.disabled = true
	_indicador.text = "editando receita"

func _editor_terminou(_salvou: bool) -> void:
	_editando_lado = -1
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
func _animar_abrir() -> void:
	_corpo.scale = Vector2(0.15, 0.9)
	_corpo.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_corpo, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_corpo, "modulate:a", 1.0, 0.2)

func fechar() -> void:
	if _animando:
		return
	_animando = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_corpo, "scale", Vector2(0.15, 0.9), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_corpo, "modulate:a", 0.0, 0.22)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	fechou.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		if _nomear.visible:
			_fechar_nomear()
		elif _detalhe.visible:
			_detalhe.fechar()
		elif _editor.ativo:
			_editor._fim(false)
		else:
			fechar()
		get_viewport().set_input_as_handled()
		return
	if _editor.ativo or _nomear.visible or _detalhe.visible:
		return
	# arrastar para o lado passa a página
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and RECT_LIVRO.has_point(event.position):
			_toque_ini = event.position
		elif not event.pressed and _toque_ini.x >= 0.0:
			var d: Vector2 = event.position - _toque_ini
			if absf(d.x) > SWIPE_MIN and absf(d.y) < absf(d.x):
				_passar(-1 if d.x > 0 else 1)
			_limpar_toque.call_deferred()   # o papel ainda lê _toque_ini neste mesmo toque


func _limpar_toque() -> void:
	_toque_ini = Vector2(-1, -1)


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
