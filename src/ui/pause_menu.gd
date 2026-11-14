# pause_menu.gd
# Menu de pausa: botão ☰ no canto superior direito abre.
#   Continuar, Salvar, Carregar, Opções, Menu principal
# Pausa o jogo e o Interpreter (cutscene não anda por trás) e devolve tudo como estava.
# O botão some quando não faz sentido (menu principal, caldeirão, pausa já aberta).
extends Control

const TAM_BOTAO := Vector2(64, 64)

var gm = null
var _botao: Button
var _painel: PainelMenu = null
var _msg: Label
var _estava_pausado: bool = false
var _camada_pai: Node = null          # CanvasLayer original (onde ficam MenuPrincipal e CenaPreparo)
var _interp_modo: int = Node.PROCESS_MODE_ALWAYS


## Camada própria acima de tudo (HUD, caldeirão, livro, diálogo, fade): a pausa fica por
## cima e recebe o toque primeiro.
const CAMADA: int = 100

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(UiModal.GRUPO)
	gm = get_node_or_null("/root/Main/GameManager")
	_montar()
	visible = false
	_subir_para_camada.call_deferred()

func _subir_para_camada() -> void:
	var camada := CanvasLayer.new()
	camada.name = "CamadaPausa"
	camada.layer = CAMADA
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.get_node("Main").add_child(camada)
	_camada_pai = get_parent()
	reparent(camada, false)
	if _botao:
		if _botao.get_parent():
			_botao.reparent(camada, false)
		else:
			camada.add_child(_botao)
	# ícone da receita memorizada (abaixo do DEBUG)
	var rm := ReceitaMemorizada.new()
	rm.pausa = self
	rm.gm = gm
	camada.add_child(rm)


func _montar() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo: ColorRect = get_node_or_null("ColorRect")
	if fundo:
		fundo.color = Color(0, 0, 0, 0.6)
	var l = get_node_or_null("Label")
	if l:
		l.visible = false
	var caixa: VBoxContainer = get_node("VBoxContainer")
	for c in caixa.get_children():
		c.queue_free()
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", PainelMenu.estilo_painel())
	painel.position = Vector2(130, 220)
	painel.size = Vector2(380, 0)
	add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	painel.add_child(col)
	col.add_child(PainelMenu.rotulo("Pausa", 32, PainelMenu.COR_BORDA))
	col.add_child(PainelMenu.botao("Continuar", fechar))
	col.add_child(PainelMenu.botao("Salvar", _salvar))
	col.add_child(PainelMenu.botao("Carregar", _carregar))
	col.add_child(PainelMenu.botao("Opções", _opcoes))
	col.add_child(PainelMenu.botao("Menu principal", _menu_principal))
	_msg = PainelMenu.rotulo("", 20, PainelMenu.COR_SUAVE)
	col.add_child(_msg)
	caixa.visible = false
	# botão ☰ (fica fora deste Control, que some quando a pausa fecha)
	_botao = Button.new()
	_botao.name = "BotaoPausa"
	_botao.text = "☰"
	_botao.focus_mode = Control.FOCUS_NONE
	_botao.custom_minimum_size = TAM_BOTAO
	_botao.size = TAM_BOTAO
	_botao.position = Vector2(640 - TAM_BOTAO.x - 6, 6)
	_botao.add_theme_font_size_override("font_size", 32)
	_botao.modulate.a = 0.75
	_botao.process_mode = Node.PROCESS_MODE_ALWAYS
	_botao.pressed.connect(abrir)
	_botao.add_to_group(UiModal.GRUPO_BOTOES)


func _process(_d: float) -> void:
	if _botao and _botao.is_inside_tree():
		_botao.visible = _pode_pausar()

## O botão só aparece no jogo normal (não no menu principal, caldeirão ou com a pausa aberta).
func _pode_pausar() -> bool:
	if visible:
		return false
	if not get_tree().get_nodes_in_group("cena_livro").is_empty():
		return false   # livro aberto: o ☰ ficava por cima do fechar do livro
	var c = _camada_pai if _camada_pai else get_parent()
	for nome in ["MenuPrincipal", "CenaPreparo"]:
		var n = c.get_node_or_null(nome) if c else null
		if n and n.visible:
			return false
	return true


func abrir() -> void:
	if visible:
		return
	_estava_pausado = get_tree().paused
	get_tree().paused = true
	var it = gm.get_node_or_null("Interpeter") if gm else null
	if it:
		_interp_modo = it.process_mode
		it.process_mode = Node.PROCESS_MODE_DISABLED
	_msg.text = ""
	visible = true

func fechar() -> void:
	if _painel:
		_painel.queue_free()
		_painel = null
	visible = false
	var it = gm.get_node_or_null("Interpeter") if gm else null
	if it:
		it.process_mode = _interp_modo
	get_tree().paused = _estava_pausado


func _salvar() -> void:
	var nome := SaveJogo.salvar(gm)
	_msg.text = "Jogo salvo." if nome != "" else "Não deu para salvar."

func _carregar() -> void:
	_abrir_painel(PainelMenu.saves(_carregar_save))

func _carregar_save(nome: String) -> void:
	var it = gm.get_node_or_null("Interpeter") if gm else null
	if it and "running_events" in it:
		for ev in it.running_events:
			ev.finished = true   # cutscene em andamento não continua no save carregado
	_estava_pausado = false
	fechar()
	SaveJogo.carregar(gm, nome)

func _opcoes() -> void:
	_abrir_painel(PainelMenu.opcoes(gm))

func _abrir_painel(p: PainelMenu) -> void:
	if _painel:
		_painel.queue_free()
	_painel = p
	add_child(p)
	p.fechou.connect(func(): _painel = null)

## Volta ao menu principal: recarrega o jogo do zero (o que não foi salvo se perde).
func _menu_principal() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
