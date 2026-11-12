# menu_principal.gd
# Menu principal (aparece ao abrir o jogo): Iniciar, Carregar, Opções, Sair.
# Enquanto está aberto, o jogo fica pausado e o Interpreter parado (a intro espera).
#   Iniciar   fecha o menu e a intro começa
#   Carregar  lista os saves; escolhe um e vai para o mapa salvo
#   Opções    volumes
#   Sair      fecha o jogo
# Usa os nós da cena (VBoxContainer com os botões, Label do título).
extends Control

const TITULO := "Jogo da Bruxa"

var gm = null
var _painel: PainelMenu = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(UiModal.GRUPO)
	gm = get_node_or_null("/root/Main/GameManager")
	_montar()
	abrir()
	_aplicar_opcoes.call_deferred()   # volumes salvos (o AudioManager pode ainda não estar pronto)


func _aplicar_opcoes() -> void:
	PainelMenu.aplicar_opcoes(gm)

func _montar() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.04, 0.08, 1.0)
	fundo.size = Vector2(640, 960)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	move_child(fundo, 0)
	var titulo: Label = get_node_or_null("Label")
	if titulo:
		titulo.text = TITULO
		titulo.position = Vector2(0, 170)
		titulo.size = Vector2(640, 120)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		titulo.add_theme_font_size_override("font_size", 64)
		titulo.add_theme_color_override("font_color", PainelMenu.COR_BORDA)
	var l2 = get_node_or_null("Label2")
	if l2:
		l2.visible = false
	var caixa: VBoxContainer = get_node("VBoxContainer")
	caixa.position = Vector2(170, 420)
	caixa.size = Vector2(300, 0)
	caixa.add_theme_constant_override("separation", 18)
	for b in caixa.get_children():
		if b is Button:
			b.custom_minimum_size = Vector2(300, PainelMenu.ALTURA_BOTAO)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 28)
			PainelMenu.estilo_carta(b)
	caixa.get_node("Iniciar").pressed.connect(_iniciar)
	caixa.get_node("Carregar").pressed.connect(_carregar)
	caixa.get_node("Opções").pressed.connect(_opcoes)
	caixa.get_node("Sair").pressed.connect(func(): get_tree().quit())

func abrir() -> void:
	visible = true
	get_tree().paused = true
	_interpreter_ligado(false)
	var b: Button = get_node("VBoxContainer/Carregar")
	b.disabled = not SaveJogo.existe_algum()

func _fechar_menu() -> void:
	visible = false
	if _painel:
		_painel.queue_free()
		_painel = null
	_interpreter_ligado(true)
	get_tree().paused = false

func _interpreter_ligado(v: bool) -> void:
	var it = gm.get_node_or_null("Interpeter") if gm else null
	if it:
		it.process_mode = Node.PROCESS_MODE_ALWAYS if v else Node.PROCESS_MODE_DISABLED


func _iniciar() -> void:
	_fechar_menu()

func _carregar() -> void:
	_abrir_painel(PainelMenu.saves(_carregar_save))

func _carregar_save(nome: String) -> void:
	# a intro (eventos já disparados) não continua: o jogo vai direto para o save
	var it = gm.get_node_or_null("Interpeter") if gm else null
	if it and "running_events" in it:
		for ev in it.running_events:
			ev.finished = true
	_fechar_menu()
	SaveJogo.carregar(gm, nome)

func _opcoes() -> void:
	_abrir_painel(PainelMenu.opcoes(gm))

func _abrir_painel(p: PainelMenu) -> void:
	if _painel:
		_painel.queue_free()
	_painel = p
	add_child(p)
	p.fechou.connect(func(): _painel = null)
