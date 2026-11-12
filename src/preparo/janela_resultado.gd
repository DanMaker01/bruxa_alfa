# janela_resultado.gd
# Janela que aparece quando a poção fica pronta (por cima da cena de preparo):
#   1. ENTRADA: a tela escurece e o produtório (AnimacaoProdutorio): os ingredientes viram a
#               matriz da poção, que fica no lugar da grade. A poção só aparece ao confirmar.
#   2. MEIO:    as informações (ResultadoVistas) em 3 cartas que viram uma a uma:
#               nome + matriz, pentágono O-C-E-A-N, ingredientes com o anel.
#               Ao confirmar: cartas 2 e 3 fecham, a matriz vira a poção, a carta 1 fecha.
#   3. NOME:    1) parecida com uma conhecida (CatalogoPocoes) → esse nome;
#               2) feita de um item só → "Poção de [item] [adjetivo]" (qualidade);
#               3) senão aparece "Poção desconhecida" e, depois das informações, pede um
#                  nome; ele entra na hora no título e fica registrado para as próximas.
#   4. SAÍDA:   toque em qualquer lugar → fade e fecha (emite "fechou").
class_name JanelaResultado
extends Control

signal fechou(resultado: Dictionary)
signal _nome_definido

# ---- ajuste aqui ----
const ICONE_POCAO := "res://assets/game_caldeirao/pocao.png"
const ALFA_FUNDO: float = 1.0   # preto puro: a cena do caldeirão some por trás
const TAM_POCAO := Vector2(160, 160)
const CENTRO_POCAO := Vector2(320, 220)       # posição inicial da poção (ela surge no lugar da matriz)
## Para onde a poção voa ao sair (fallback, se a carta do inventário não for achada).
const DESTINO_INVENTARIO := Vector2(192, 800)
const NOME_DESCONHECIDO := "Poção desconhecida"
## Poção que não muda nada (matriz identidade, ou sem ingredientes): sempre este nome.
const NOME_AGUA := "Água de Caldeirão"
const FAIXA_NOME := Rect2(0, 0, 640, 200)  # faixa escura onde aparece a pergunta do nome (no topo, sobre o título)
const BRILHOS: int = 28
## z_index absoluto da janela (acima da CenaPreparo, do Fade e das notificações).
const Z_JANELA: int = 1000

enum Estado { FECHADA, ENTRANDO, NOMEANDO, MOSTRANDO, PRONTA, SAINDO, PRODUTORIO }
## De onde os ingredientes saem na animação do produtório (boca do caldeirão).
const ORIGEM_PRODUTORIO := Vector2(320, 300)

var _estado: int = Estado.FECHADA
var _res: Dictionary = {}
var _pocao_item: ItemData = null

var _fundo: ColorRect
var _pocao: TextureRect
var _halo: TextureRect
var _texto: Label
var _faixa_nome: ColorRect
var _caixa_nome: VBoxContainer
var _campo_nome: LineEdit
## Nome mostrado no título (a tela em si é o ResultadoVistas).
var _nome_atual: String = ""
var _dica: Label
var _t: float = 0.0
var _produtorio: AnimacaoProdutorio
## A tela de informações (nome, nota, matriz, pentágono, ingredientes).
var _vistas: ResultadoVistas
var _aperto_pos := Vector2.ZERO
## Durante as animações (produtório, cartas): segurar acelera; um toque pula até o fim.
const TEMPO_TOQUE: float = 0.2         # soltar antes disto = toque (pula)
const VEL_SEGURAR: float = 3.0
const VEL_PULAR: float = 40.0
var _apertou_em: float = -1.0
var _pulando: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	# z absoluto bem alto: a CenaPreparo está em z 200 e top_level não herda o z do pai
	z_as_relative = false
	z_index = Z_JANELA
	visible = false
	_construir()

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _pocao and _estado != Estado.SAINDO and _pocao.modulate.a > 0.01:
		_pocao.rotation = sin(_t * 1.6) * 0.04          # balança de leve
		_halo.modulate.a = 0.35 + 0.2 * sin(_t * 3.0)   # brilho pulsando
	if _dica.visible:
		_dica.modulate.a = 0.45 + 0.45 * sin(_t * 4.0)
	# segurando durante a animação: acelera
	if _apertou_em >= 0.0 and not _pulando and _animando() \
			and Time.get_ticks_msec() / 1000.0 - _apertou_em >= TEMPO_TOQUE:
		Engine.time_scale = VEL_SEGURAR

func _exit_tree() -> void:
	Engine.time_scale = 1.0   # nunca deixa o jogo acelerado

func _animando() -> bool:
	return _estado in [Estado.ENTRANDO, Estado.PRODUTORIO, Estado.MOSTRANDO]

## Volta a velocidade normal do jogo.
func _velocidade_normal() -> void:
	_pulando = false
	_apertou_em = -1.0
	Engine.time_scale = 1.0

# =============================================================================
# CONSTRUÇÃO
# =============================================================================
func _construir() -> void:
	var tela := Vector2(640, 960)
	position = Vector2.ZERO
	size = tela
	mouse_filter = Control.MOUSE_FILTER_STOP

	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0)
	_fundo.size = tela
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	_produtorio = AnimacaoProdutorio.new()
	_produtorio.name = "Produtorio"
	add_child(_produtorio)

	var tex: Texture2D = load(ICONE_POCAO) if ResourceLoader.exists(ICONE_POCAO) else null
	_halo = TextureRect.new()
	_halo.texture = tex
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = mat
	_halo.modulate = Color(1.0, 0.85, 0.4, 0.0)
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_halo)

	_pocao = TextureRect.new()
	_pocao.texture = tex
	_pocao.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pocao.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pocao.size = TAM_POCAO
	_pocao.pivot_offset = TAM_POCAO * 0.5
	_pocao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pocao)

	# faixa da pergunta do nome (aparece no topo, por cima do título, depois das informações)
	_faixa_nome = ColorRect.new()
	_faixa_nome.color = Color(0.04, 0.04, 0.07, 0.95)
	_faixa_nome.position = FAIXA_NOME.position
	_faixa_nome.size = FAIXA_NOME.size
	_faixa_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa_nome.visible = false

	_texto = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_texto.position = Vector2(40, FAIXA_NOME.position.y + 16)
	_texto.size = Vector2(560, 40)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD

	# caixa para dar nome
	_caixa_nome = VBoxContainer.new()
	_caixa_nome.position = Vector2(110, FAIXA_NOME.position.y + 70)
	_caixa_nome.size = Vector2(420, 120)
	_caixa_nome.add_theme_constant_override("separation", 10)
	_campo_nome = LineEdit.new()
	_campo_nome.placeholder_text = "Nome da poção"
	_campo_nome.max_length = 32
	_campo_nome.add_theme_font_size_override("font_size", 26)
	_campo_nome.custom_minimum_size = Vector2(420, 56)
	_campo_nome.text_submitted.connect(func(_txt): _confirmar_nome())
	_caixa_nome.add_child(_campo_nome)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 12)
	var ok := _botao("Dar nome")
	ok.pressed.connect(_confirmar_nome)
	var pular := _botao("Agora não")
	pular.pressed.connect(func(): _nome_definido.emit())
	botoes.add_child(ok)
	botoes.add_child(pular)
	_caixa_nome.add_child(botoes)
	_caixa_nome.visible = false

	_vistas = ResultadoVistas.new()
	_vistas.name = "Vistas"
	_vistas.visible = false
	add_child(_vistas)
	move_child(_vistas, 1)   # cartas logo acima do fundo: a matriz do produtório e a poção ficam por cima
	for n in [_produtorio, _halo, _pocao]:
		n.z_index = 10   # acima da moldura das cartas (z 3)

	add_child(_faixa_nome)
	add_child(_texto)
	add_child(_caixa_nome)

	_dica = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_dica.text = "toque para continuar"
	_dica.position = Vector2(0, 900)
	_dica.size = Vector2(640, 40)
	_dica.visible = false
	add_child(_dica)

func _label(tam: int, alinhamento: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = alinhamento
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _botao(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(204, 56)
	b.add_theme_font_size_override("font_size", 22)
	return b

# =============================================================================
# SEQUÊNCIA
# =============================================================================
## resultado: o que a CenaPreparo montou (com "pocao": ItemData e "A").
func abrir(resultado: Dictionary) -> void:
	_res = resultado
	_pocao_item = resultado.get("pocao")
	var A: Array = resultado.get("A", [])
	_resetar()
	visible = true
	_estado = Estado.ENTRANDO

	# 1. entrada: escurece e o produtório: os ingredientes se alinham, o aproveitamento
	#    vira B_i e os B_i se combinam até a matriz final, que fica no lugar da grade
	#    (a poção só aparece quando confirma, em _fechar)
	#    os cartões saem dos ícones do caldeirão; a cena escurece até o preto e some
	#    (fica escondida e parada, mais leve)
	var cena = get_parent()
	var icones = cena.get("icones") if cena else null
	var saidas: Array = icones.saidas_para_resultado() if icones and icones.has_method("saidas_para_resultado") else []
	if icones and icones.has_method("esconder_icones"):
		icones.esconder_icones()
	var tw := create_tween()
	tw.tween_property(_fundo, "color:a", ALFA_FUNDO, 1.2).set_delay(0.3)
	tw.tween_callback(_cobrir_cena.bind(cena))
	var diags: Array = resultado.get("diagnosticos", [])
	_vistas.montar(resultado, A)
	var destino: Rect2 = _vistas.rect_grade()
	_estado = Estado.PRODUTORIO
	await _produtorio.tocar(diags, ORIGEM_PRODUTORIO, destino.get_center(), destino.size.x, saidas)
	if tw.is_running():
		await tw.finished
	_estado = Estado.ENTRANDO

	# 2. meio: poção para a esquerda, informações à direita
	var achada := CatalogoPocoes.procurar(A)
	var nome_unico := CalculadoraPocao.nome_item_unico(_res.get("diagnosticos", []))
	var pedir_nome: bool = false
	if CatalogoPocoes.distancia(A, CalculadoraPocao.identidade()) <= 0.0001:
		_definir_nome(NOME_AGUA)
	elif nome_unico != "":
		_definir_nome(nome_unico)   # um item só: "Poção de [item] [qualidade]" (antes do catálogo)
	elif achada["perto"]:
		_definir_nome(achada["nome"])
	elif _nome_ingrediente(A) != "":
		_definir_nome(_nome_ingrediente(A))   # matriz parecida com um ingrediente puro
	else:
		# poção nova: o nome NÃO é pedido aqui; fica "Poção desconhecida" e a bruxa
		# dá o nome depois, no livro de receitas (página do preparo)
		_definir_nome(NOME_DESCONHECIDO)
		_res["nomeavel"] = true
	_estado = Estado.MOSTRANDO
	_nome_atual = NOME_DESCONHECIDO if pedir_nome else (_pocao_item.get_nome() if _pocao_item else "Poção")
	# moldura → matriz troca → pentágono → ingredientes
	_vistas.titulo(_nome_atual)
	await _vistas.entrar()
	_vistas.mostrar_grade()
	_produtorio.limpar()
	await _vistas.mostrar_pentagono()
	await _vistas.mostrar_ingredientes()
	await get_tree().create_timer(0.5, true).timeout
	await _depois_das_informacoes(pedir_nome)

func _cobrir_cena(cena) -> void:
	if is_instance_valid(cena) and cena.has_method("cobrir_cena"):
		cena.cobrir_cena(true)

func _depois_das_informacoes(pedir_nome: bool) -> void:
	var tw: Tween

	# 3. nome: poção nova → pergunta o nome e já coloca nas informações
	if pedir_nome:
		_texto.text = "Uma poção nova! Que nome ela vai ter?"
		_estado = Estado.NOMEANDO
		for c in [_faixa_nome, _texto, _caixa_nome]:
			c.visible = true
			c.modulate.a = 0.0
		tw = create_tween().set_parallel(true)
		for c in [_faixa_nome, _texto, _caixa_nome]:
			tw.tween_property(c, "modulate:a", 1.0, 0.3)
		_campo_nome.grab_focus()
		await _nome_definido
		_estado = Estado.MOSTRANDO
		tw = create_tween().set_parallel(true)
		for c in [_faixa_nome, _texto, _caixa_nome]:
			tw.tween_property(c, "modulate:a", 0.0, 0.25)
		await tw.finished
		for c in [_faixa_nome, _texto, _caixa_nome]:
			c.visible = false
		await _atualizar_titulo(_pocao_item.get_nome() if _pocao_item else NOME_DESCONHECIDO)

	# 4. pronto: qualquer toque fecha
	_velocidade_normal()
	_dica.visible = true
	_estado = Estado.PRONTA

func _nome_ingrediente(A: Array) -> String:
	var db = get_node_or_null("/root/Main/GameManager/DatabaseManager")
	return CalculadoraPocao.nome_por_ingrediente(A, db)

func _resetar() -> void:
	_t = 0.0
	modulate.a = 1.0
	_fundo.color.a = 0.0
	_pocao.position = CENTRO_POCAO - TAM_POCAO * 0.5
	_pocao.scale = Vector2(0.05, 0.05)
	_pocao.modulate.a = 0.0
	_halo.size = TAM_POCAO * 1.3
	_halo.position = _pocao.position - TAM_POCAO * 0.15
	_halo.modulate.a = 0.0
	_texto.modulate.a = 0.0
	_texto.text = ""
	_texto.visible = false
	_faixa_nome.visible = false
	_caixa_nome.visible = false
	_campo_nome.text = ""
	_nome_atual = ""
	_produtorio.limpar()
	_vistas.limpar()
	_vistas.visible = false
	_dica.visible = false

## Troca o título com um "pop" (o nome acabou de ser dado).
func _atualizar_titulo(nome: String) -> void:
	_nome_atual = nome
	await _vistas.titulo_pop(nome)

func _aparecer(c: CanvasItem) -> void:
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.35)
	await tw.finished

func _confirmar_nome() -> void:
	if _estado != Estado.NOMEANDO:
		return
	var nome := _campo_nome.text.strip_edges()
	if nome == "":
		return
	_definir_nome(nome)
	CatalogoPocoes.registrar(nome, _res.get("A", []), _pocao_item.descricao if _pocao_item else "")
	_nome_definido.emit()

func _definir_nome(nome: String) -> void:
	if _pocao_item:
		_pocao_item.nome = nome
		_pocao_item.efeito = CatalogoPocoes.efeito_de(nome)

## Estouro de brilhinhos saindo do centro (entrada da poção).
func _estourar_brilhos(centro: Vector2) -> void:
	for k in BRILHOS:
		var b := ColorRect.new()
		var tam := randf_range(3.0, 7.0)
		b.size = Vector2(tam, tam)
		b.pivot_offset = b.size * 0.5
		b.rotation = PI * 0.25
		b.color = Color(1.0, randf_range(0.8, 0.95), randf_range(0.4, 0.8))
		b.position = centro - b.size * 0.5
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		var destino := centro + Vector2.from_angle(randf() * TAU) * randf_range(90.0, 230.0)
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "position", destino, randf_range(0.5, 0.9)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate:a", 0.0, 0.9).set_delay(0.2)
		tw.chain().tween_callback(b.queue_free)

# =============================================================================
# SAÍDA
# =============================================================================
func _input(event: InputEvent) -> void:
	if visible and _animando():
		# segurar acelera (ver _process); um toque curto pula tudo até o resultado pronto
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			if event.pressed:
				_apertou_em = Time.get_ticks_msec() / 1000.0
			elif _apertou_em >= 0.0:
				var curto: bool = Time.get_ticks_msec() / 1000.0 - _apertou_em < TEMPO_TOQUE
				_apertou_em = -1.0
				if curto and not _pulando:
					_pulando = true
					Engine.time_scale = VEL_PULAR
				elif not _pulando:
					Engine.time_scale = 1.0
		return
	if not visible or _estado != Estado.PRONTA:
		return
	var aperto2: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if aperto2:
		_aperto_pos = event.position
		return
	# fecha ao SOLTAR o toque, em qualquer lugar. Se arrastou a lista de ingredientes,
	# a ListaRolavel já marcou o evento como tratado e ele não chega aqui.
	var toque: bool = (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed)
	if toque:
		var pos: Vector2 = event.position
		# arrastou, ou tocou em algo da tela (ícone, detalhe, grade): não fecha
		if pos.distance_to(_aperto_pos) > 40.0:
			return
		if _vistas.consumir_toque(pos):
			return
		get_viewport().set_input_as_handled()
		_fechar()

## Saída (jogo pausado). Tudo que anima fica em CanvasLayers próprias, ACIMA da janela,
## então nada da janela (pentágono, textos) aparece por cima:
##   camada 10: escuro por cima da janela (escurece as informações)
##   camada 11: carta do inventário (emprestada do HUD)
##   camada 12: a poção
## Sequência: escurece + poção ao meio → carta abre → poção desce → nome dourado →
## carta fecha → escuro total → preparo e janela fecham por baixo → escuro some (mapa).
func _fechar() -> void:
	_velocidade_normal()
	_estado = Estado.SAINDO
	_dica.visible = false
	await _vistas.fechar_cartas_menores()
	await _matriz_vira_pocao()
	await _vistas.fechar_carta_nome()
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	var carta = hud.get("carta_inventario") if hud else null
	var gt = get_node_or_null("/root/Main/GameManager/GameTemp")
	var id: String = str(_res.get("item", _pocao_item.id if _pocao_item else ""))

	var escuro_camada := _camada(10)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0)
	escuro.size = Vector2(640, 960)
	escuro.mouse_filter = Control.MOUSE_FILTER_STOP
	escuro_camada.add_child(escuro)
	var voo := _copia_pocao(12)
	_pocao.visible = false
	_halo.visible = false

	# 1. escurece a janela e a poção vai para o meio
	var tw := create_tween().set_parallel(true)
	tw.tween_property(escuro, "color:a", 0.7, 0.6)
	tw.tween_property(voo, "position", CENTRO_POCAO - TAM_POCAO * 0.5, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if gt and id != "":
		gt.add_item(id, int(_res.get("quantidade", 1)))
		_res["item_ja_adicionado"] = true

	# 2. a carta do inventário vem para a camada 11 e abre
	var carta_camada := _camada(11)
	var pai_carta: Node = carta.get_parent() if carta else null
	var idx_carta: int = carta.get_index() if carta else 0
	# o evento do caldeirão esconde o HUD (cartas inativas não aparecem): ativa só esta
	var ativa_antes: bool = carta.ativa if carta else true
	if carta:
		carta.reparent(carta_camada, true)
		carta.fechar()          # primeiro aparece de verso...
		carta.ativa = true
		carta.segurar = true
		await _esperar(1.5)     # verso fica um tempo na tela
		carta.abrir()           # ...depois vira e abre
	await _esperar(1.0)

	# 3. a poção desce até a linha dela
	var destino := DESTINO_INVENTARIO
	if hud and hud.has_method("preparar_item_chegando") and id != "":
		destino = hud.preparar_item_chegando(id, true)
	tw = create_tween().set_parallel(true)
	tw.tween_property(voo, "position", destino - TAM_POCAO * 0.5, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(voo, "scale", Vector2(0.22, 0.22), 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	tw = create_tween()
	tw.tween_property(voo, "modulate:a", 0.0, 0.2)
	await tw.finished
	voo.get_parent().queue_free()

	# 4. nome dourado, espera, carta fecha e volta para o HUD
	if hud and hud.has_method("destacar_item") and id != "":
		hud.destacar_item(id)
	await _esperar(1.6)
	if carta:
		carta.segurar = false
		carta.fechar()
	await _esperar(0.6)
	# o inventário (já de verso) some com fade
	if carta:
		var tw_c: Tween = carta.create_tween()
		tw_c.tween_property(carta, "modulate:a", 0.0, 0.5)
		await tw_c.finished
		carta.ativa = ativa_antes
		carta.modulate.a = 1.0
	if carta and pai_carta:
		carta.reparent(pai_carta, true)
		pai_carta.move_child(carta, idx_carta)
	carta_camada.queue_free()

	# 5. janela, preparo e escuro somem juntos (fade simples), revelando o mapa
	var cena := get_parent() as CanvasItem
	tw = create_tween().set_parallel(true)
	tw.tween_property(escuro, "color:a", 0.0, 0.8)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	if cena:
		tw.tween_property(cena, "modulate:a", 0.0, 0.8)
	await tw.finished
	escuro_camada.queue_free()
	visible = false
	modulate.a = 1.0
	_pocao.visible = true
	_halo.visible = true
	_estado = Estado.FECHADA
	fechou.emit(_res)   # o preparo fecha (já invisível) e o jogo despausa

func _camada(n: int) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = n
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(c)
	return c

## Cópia da poção (mesma posição/tamanho) numa CanvasLayer acima de tudo.
func _copia_pocao(camada_n: int) -> TextureRect:
	var camada := _camada(camada_n)
	var p := TextureRect.new()
	p.texture = _pocao.texture
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.size = TAM_POCAO
	p.pivot_offset = TAM_POCAO * 0.5
	p.position = _pocao.position
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(p)
	return p

## Confirmou: a matriz final encolhe até o lugar da poção e a poção surge ali.
func _matriz_vira_pocao() -> void:
	var g: GradeMatriz = _vistas.grade
	# encolhe para o centro dos pontos da matriz (não para o canto): só a escala anima,
	# em volta do pivô no centro; a posição não muda
	var meio_local: Vector2 = g.centro_pontos()
	var centro: Vector2 = g.get_global_transform() * meio_local
	if "pivot_offset_ratio" in g:
		g.set("pivot_offset_ratio", Vector2.ZERO)
	g.position += (meio_local - g.pivot_offset) * (Vector2.ONE - g.scale)   # troca o pivô sem pular
	g.pivot_offset = meio_local
	# a poção surge no lugar da própria matriz
	_pocao.position = centro - TAM_POCAO * 0.5
	_halo.position = _pocao.position - TAM_POCAO * 0.15
	var tw := create_tween().set_parallel(true)
	tw.tween_property(g, "scale", Vector2(0.05, 0.05), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(g, "modulate:a", 0.0, 0.2).set_delay(0.3)
	await tw.finished
	_estourar_brilhos(centro)
	tw = create_tween().set_parallel(true)
	tw.tween_property(_pocao, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pocao, "modulate:a", 1.0, 0.2)
	await tw.finished
	await _esperar(0.4)

## Espera que roda mesmo com o jogo pausado.
func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true).timeout

func esta_aberta() -> bool:
	return _estado != Estado.FECHADA
