# janela_resultado.gd
# Janela que aparece quando a poção fica pronta (por cima da cena de preparo):
#   1. ENTRADA: a tela escurece e a poção surge no meio com um estouro de brilhos.
#   2. MEIO:    a poção desliza para a esquerda e à direita aparecem as informações:
#               nome, pentágono O-C-E-A-N (efeito numa personalidade neutra), a matriz
#               em miniatura e os ingredientes (com o aproveitamento de cada um).
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
const ALFA_FUNDO: float = 0.85
const TAM_POCAO := Vector2(200, 200)
const CENTRO_POCAO := Vector2(320, 360)       # onde a poção surge
const POCAO_ESQUERDA_X: float = 30.0          # para onde ela desliza (posição x)
const PAINEL_RECT := Rect2(240, 110, 385, 760)  # coluna dos parâmetros (direita)
const NOME_DESCONHECIDO := "Poção desconhecida"
const TAM_PENTAGONO: float = 340.0
const TAM_GRADE: float = 200.0
const FAIXA_NOME := Rect2(0, 680, 640, 230)  # faixa escura onde aparece a pergunta do nome
const BRILHOS: int = 28
## z_index absoluto da janela (acima da CenaPreparo, do Fade e das notificações).
const Z_JANELA: int = 1000

enum Estado { FECHADA, ENTRANDO, NOMEANDO, MOSTRANDO, PRONTA, SAINDO }

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
var _painel: VBoxContainer
var _titulo: Label
var _pentagono: PentagonoOcean
var _grade: GradeMatriz
var _ingredientes: Label
var _dica: Label
var _t: float = 0.0


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
	if _pocao and _estado != Estado.SAINDO:
		_pocao.rotation = sin(_t * 1.6) * 0.04          # balança de leve
		_halo.modulate.a = 0.35 + 0.2 * sin(_t * 3.0)   # brilho pulsando
	if _dica.visible:
		_dica.modulate.a = 0.45 + 0.45 * sin(_t * 4.0)

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

	# faixa da pergunta do nome (aparece por cima da parte de baixo, depois das informações)
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

	# painel dos parâmetros (direita)
	_painel = VBoxContainer.new()
	_painel.position = PAINEL_RECT.position
	_painel.size = PAINEL_RECT.size
	_painel.add_theme_constant_override("separation", 10)
	_painel.modulate.a = 0.0
	_titulo = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	_titulo.custom_minimum_size = Vector2(PAINEL_RECT.size.x, 0)
	_painel.add_child(_titulo)
	_pentagono = PentagonoOcean.new()
	_pentagono.custom_minimum_size = Vector2(PAINEL_RECT.size.x, TAM_PENTAGONO)
	_painel.add_child(_pentagono)
	var centro_grade := CenterContainer.new()
	centro_grade.custom_minimum_size = Vector2(PAINEL_RECT.size.x, TAM_GRADE)
	_grade = GradeMatriz.new()
	_grade.custom_minimum_size = Vector2(TAM_GRADE, TAM_GRADE)
	centro_grade.add_child(_grade)
	_painel.add_child(centro_grade)
	_ingredientes = _label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_ingredientes.autowrap_mode = TextServer.AUTOWRAP_WORD
	_ingredientes.custom_minimum_size = Vector2(PAINEL_RECT.size.x, 0)
	_painel.add_child(_ingredientes)
	add_child(_painel)

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

	# 1. entrada: escurece e a poção surge com um estouro de brilhos
	var tw := create_tween()
	tw.tween_property(_fundo, "color:a", ALFA_FUNDO, 0.35)
	await tw.finished
	_estourar_brilhos(CENTRO_POCAO)
	tw = create_tween().set_parallel(true)
	tw.tween_property(_pocao, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pocao, "modulate:a", 1.0, 0.25)
	await tw.finished

	# 2. meio: poção para a esquerda, informações à direita
	var achada := CatalogoPocoes.procurar(A)
	var nome_unico := CalculadoraPocao.nome_item_unico(_res.get("diagnosticos", []))
	var pedir_nome: bool = false
	if achada["perto"]:
		_definir_nome(achada["nome"])
	elif nome_unico != "":
		_definir_nome(nome_unico)   # um item só: nome automático, não pergunta
	elif _nome_ingrediente(A) != "":
		_definir_nome(_nome_ingrediente(A))   # matriz parecida com um ingrediente puro
	else:
		pedir_nome = true
	_estado = Estado.MOSTRANDO
	_preencher_parametros(A)
	if pedir_nome:
		_titulo.text = NOME_DESCONHECIDO
	tw = create_tween().set_parallel(true)
	tw.tween_property(_pocao, "position:x", POCAO_ESQUERDA_X, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_halo, "position:x", POCAO_ESQUERDA_X - TAM_POCAO.x * 0.15, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_painel.position.x = PAINEL_RECT.position.x + 40.0
	tw = create_tween().set_parallel(true)
	tw.tween_property(_painel, "modulate:a", 1.0, 0.4)
	tw.tween_property(_painel, "position:x", PAINEL_RECT.position.x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_pentagono.mostrar(A)
	_grade.mostrar(A)
	await get_tree().create_timer(0.9, true).timeout

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
	_titulo.scale = Vector2.ONE
	_campo_nome.text = ""
	_painel.modulate.a = 0.0
	_dica.visible = false

## Troca o título com um "pop" (o nome acabou de ser dado).
func _atualizar_titulo(nome: String) -> void:
	_titulo.pivot_offset = _titulo.size * 0.5
	var tw := create_tween()
	tw.tween_property(_titulo, "scale", Vector2(0.6, 0.6), 0.12)
	tw.tween_callback(func(): _titulo.text = nome)
	tw.tween_property(_titulo, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

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

func _preencher_parametros(A: Array) -> void:
	_titulo.text = _pocao_item.get_nome() if _pocao_item else "Poção"
	var partes: Array = []
	for d in _res.get("diagnosticos", []):
		partes.append("%s  %d%%" % [d.get("nome_exibicao", d.get("nome", "?")), roundi(100.0 * float(d.get("a", 0.0)))])
	_ingredientes.text = "Ingredientes:\n" + ("\n".join(partes) if not partes.is_empty() else "—")

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
	if not visible or _estado != Estado.PRONTA:
		return
	var toque: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if toque:
		get_viewport().set_input_as_handled()
		_fechar()

func _fechar() -> void:
	_estado = Estado.SAINDO
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_property(_pocao, "scale", Vector2(0.6, 0.6), 0.45)
	await tw.finished
	visible = false
	_estado = Estado.FECHADA
	fechou.emit(_res)

func esta_aberta() -> bool:
	return _estado != Estado.FECHADA
