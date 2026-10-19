# fluxo_dialogo.gd
# Liga o Interpreter à caixa de diálogo e à caixa de opções:
#   Interpreter.dialog_requested  -> DialogBox.show_dialog (pausa o jogo)
#   Interpreter.option_requested  -> mostra a pergunta e, junto com ela, as opções
#                                    (a caixa da pergunta fica aberta até escolher)
#   OptionBox.option_selected     -> avança o diálogo ou devolve a escolha ao Interpreter
class_name FluxoDialogo
extends Node

var gm   # GameManager
var dialog_box = null
var option_box = null
var _opcoes_pendentes: Array = []   # opções que aparecem quando a pergunta terminar
var _processando_opcoes: bool = false
var _pergunta_aberta: bool = false   # caixa de diálogo mostrando a pergunta junto com as opções


func configurar(p_gm) -> void:
	gm = p_gm
	dialog_box = gm.get_node_or_null("/root/Main/CanvasLayer/DialogBox")
	option_box = gm.get_node_or_null("/root/Main/CanvasLayer/OptionBox")
	if not option_box:
		# cena sem OptionBox: cria uma por script
		var canvas = gm.get_node_or_null("/root/Main/CanvasLayer")
		var classe = load("res://src/ui/option_box.gd")
		if canvas and classe:
			option_box = classe.new()
			option_box.name = "OptionBox"
			canvas.add_child(option_box)
	if not dialog_box:
		push_warning("[FluxoDialogo] DialogBox não encontrado")
	if dialog_box:
		if dialog_box.has_signal("dialog_finished") and not dialog_box.dialog_finished.is_connected(_on_dialog_box_finished):
			dialog_box.dialog_finished.connect(_on_dialog_box_finished)
		if dialog_box.has_signal("advance_requested") and not dialog_box.advance_requested.is_connected(_on_advance_requested):
			dialog_box.advance_requested.connect(_on_advance_requested)
	if option_box and option_box.has_signal("option_selected") and not option_box.option_selected.is_connected(_on_option_selected):
		option_box.option_selected.connect(_on_option_selected)

func conectar_interpreter(interp) -> void:
	if not interp.dialog_requested.is_connected(_on_dialog_requested):
		interp.dialog_requested.connect(_on_dialog_requested)
	if not interp.option_requested.is_connected(_on_option_requested):
		interp.option_requested.connect(_on_option_requested)

# =============================================================================
# INTERPRETER -> TELA
# =============================================================================
func _on_dialog_requested(msgs: Array, falante = null) -> void:
	if dialog_box:
		gm._pause_game_with_reset()
		dialog_box.show_dialog(msgs, falante)
	elif gm.interpeter:
		gm.interpeter.dialog_finished.emit()   # sem caixa: não trava o evento

func _on_option_requested(pergunta: String, opcoes: Array, falante = null) -> void:
	if _processando_opcoes:
		return   # evita chamadas duplicadas
	_processando_opcoes = true
	_opcoes_pendentes = opcoes
	# com texto: a pergunta fica na caixa de diálogo e as opções aparecem junto
	# (o advance_requested que o show_dialog emite vira "mostrar opções", ver _on_advance_requested)
	var tem_texto: bool = Falante.do_texto(pergunta)["texto"].strip_edges() != ""
	if tem_texto and dialog_box and dialog_box.has_method("show_dialog"):
		_pergunta_aberta = true
		gm._pause_game_with_reset()
		dialog_box.show_dialog([pergunta], falante)
	else:
		_mostrar_opcoes_pendentes()

func _mostrar_opcoes_pendentes() -> void:
	if _opcoes_pendentes.is_empty():
		return
	gm._pause_game_with_reset()
	if option_box and option_box.has_method("show_options"):
		option_box.show_options(_opcoes_pendentes)
	_opcoes_pendentes = []
	_processando_opcoes = false

# =============================================================================
# TELA -> INTERPRETER
# =============================================================================
func _on_dialog_box_finished() -> void:
	if not _opcoes_pendentes.is_empty():
		_mostrar_opcoes_pendentes()   # era a pergunta: agora as opções
		return
	_processando_opcoes = false
	if option_box and option_box.has_method("hide_options"):
		option_box.hide_options()
	gm._unpause_game_with_reset()
	if gm.interpeter:
		gm.interpeter.dialog_finished.emit()

func _on_option_selected(idx: int, txt: String) -> void:
	# botão "avançar" do diálogo
	if idx == -1 and txt == "avancar":
		if dialog_box and dialog_box.is_dialog_visible():
			dialog_box.advance()
		return
	# opção de verdade
	_processando_opcoes = false
	_opcoes_pendentes = []
	_fechar_pergunta()
	gm._unpause_game_with_reset()
	if option_box and option_box.has_method("hide_options"):
		option_box.hide_options()
	if gm.interpeter and gm.interpeter.has_method("on_option_selected"):
		gm.interpeter.on_option_selected(idx)

func _on_advance_requested() -> void:
	if _pergunta_aberta:
		# é a pergunta: no lugar do botão de avançar, as opções
		_mostrar_opcoes_pendentes()
		return
	if option_box and option_box.has_method("show_advance"):
		option_box.show_advance()

## Fecha a caixa da pergunta sem emitir dialog_finished (quem continua é a opção escolhida).
func _fechar_pergunta() -> void:
	if not _pergunta_aberta:
		return
	_pergunta_aberta = false
	if dialog_box:
		if dialog_box.has_method("fechar_sem_sinal"):
			dialog_box.fechar_sem_sinal()
		else:
			dialog_box.visible = false
