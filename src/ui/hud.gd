# =============================================================================
# hud.gd - HUD do jogo: duas cartas que viram (ver carta.gd)
#   CartaInventario: Verso / Inventario / Dialogo (DialogBox)
#   CartaStatus:     Verso / Status     / Opcoes  (OptionBox)
# mostrar_hud/sumir_hud só ativam/desativam as cartas: no diálogo elas aparecem mesmo assim.
# =============================================================================
extends Control

# =============================================================================
# CONSTANTES
# =============================================================================
const POPUP_SIZE = Vector2(570, 200)
const BUTTON_FONT_SIZE = 22
const EMPTY_FONT_SIZE = 18
const MARGIN = 10
const POPUP_AREA_BOTTOM = 640.0  # o popup fica acima do HUD (inventário/status começam em y=640)
const POPUP_ANCHOR_Y = 540.0     # altura preferida do centro do popup (sobe se não couber)

# =============================================================================
# REFERÊNCIAS UI
# =============================================================================
@onready var inventory_container = $CartaInventario/Giro/Inventario/MarginContainer/ScrollContainer/VBoxContainer
@onready var status_node = $CartaStatus/Giro/Status/Status
@onready var carta_inventario: Carta = $CartaInventario
@onready var carta_status: Carta = $CartaStatus
@onready var fundo_hud: ColorRect = $FundoHUD

# =============================================================================
# DEPENDÊNCIAS
# =============================================================================
var game_manager = null
var game_temp = null
var database = null

# =============================================================================
# POPUP
# =============================================================================
@export var popup_scene = preload("res://scenes/core/popup_item.tscn")
var popup_instance = null

# =============================================================================
# CICLO DE VIDA
# =============================================================================

func _ready():
	var lista = get_node_or_null("CartaInventario/Giro/Inventario/MarginContainer/ScrollContainer")
	if lista and lista.has_signal("linha_tocada"):
		lista.linha_tocada.connect(_on_linha_tocada)
	print("[HUD] Inicializando...")
	# o nó fica sempre visível; "visible" da cena vira ativo/inativo das cartas
	var comecar_ativo := visible
	visible = true
	set_ativo(comecar_ativo)
	_montar_dialogo()
	_find_dependencies()
	_connect_signals()
	_create_popup()
	_refresh_inventory()
	_update_status()
	print("[HUD] Inicializado!")

# =============================================================================
# CARTAS
# =============================================================================

## Ativo = cartas aparecem (verso/abertas). Inativo = somem, menos para o diálogo.
func set_ativo(v: bool) -> void:
	fundo_hud.visible = v
	carta_inventario.ativa = v
	carta_status.ativa = v

## Põe a DialogBox e a OptionBox (de main.tscn) dentro das cartas, como faces.
## Espera um frame: a DialogBox cria a tela escura no pai original antes de mudar de lugar.
func _montar_dialogo() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var canvas := get_parent()
	_colocar_na_carta(canvas.get_node_or_null("DialogBox"), carta_inventario.face("Dialogo"))
	_colocar_na_carta(canvas.get_node_or_null("OptionBox"), carta_status.face("Opcoes"))

## Margem (px) entre a borda da carta e o conteúdo (texto, lista, botões... o texto dos botões).
const MARGEM_CONTEUDO: float = 20.0

func _colocar_na_carta(caixa: Control, face: Control) -> void:
	if caixa == null or face == null:
		push_warning("[HUD] caixa de diálogo/opções não encontrada")
		return
	caixa.reparent(face, false)
	caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caixa.scale = Vector2.ONE
	# a carta é o fundo: o painel da caixa fica transparente (só o conteúdo aparece)
	var painel = caixa.get("panel")
	if painel is CanvasItem:
		painel.self_modulate.a = 0.0
	if caixa.get("margem_texto") != null:
		# opções: os botões ocupam a carta toda; a margem fica no texto deles
		caixa.margem = 0.0
		caixa.margem_texto = MARGEM_CONTEUDO
		if caixa.has_method("_setup_ui"):
			caixa._setup_ui()
		var adv = caixa.get("advance_button")
		if adv and caixa.has_method("_estilizar_botao"):
			caixa._estilizar_botao(adv)
	else:
		# diálogo: margem em volta do texto
		var m := caixa.get_node_or_null("Panel/MarginContainer") as Control
		if m:
			m.offset_left = MARGEM_CONTEUDO
			m.offset_top = MARGEM_CONTEUDO
			m.offset_right = -MARGEM_CONTEUDO
			m.offset_bottom = -MARGEM_CONTEUDO

# =============================================================================
# INICIALIZAÇÃO
# =============================================================================

func _find_dependencies():
	"""Busca referências ao GameManager, GameTemp e Database"""
	var main = get_tree().current_scene
	if not main:
		return
	
	game_manager = main.get_node_or_null("GameManager")
	if not game_manager:
		return
	
	game_temp = game_manager.get_node_or_null("GameTemp")
	database = game_manager.get_node_or_null("DatabaseManager")

func _connect_signals():
	"""Conecta os sinais do GameTemp"""
	if not game_temp:
		return
	
	if game_temp.has_signal("inventory_changed"):
		game_temp.inventory_changed.connect(_on_inventory_changed)
	
	if game_temp.has_signal("personality_changed"):
		game_temp.personality_changed.connect(_on_personality_changed)
	
	print("[HUD] Conectado ao GameTemp!")

func _create_popup():
	"""Cria o popup de itens (invisível inicialmente)"""
	if not popup_scene:
		return
	
	popup_instance = popup_scene.instantiate()
	add_child(popup_instance)
	popup_instance.visible = false
	popup_instance.popup_closed.connect(_on_popup_closed)
	print("[HUD] Popup criado!")

# =============================================================================
# INVENTÁRIO
# =============================================================================

func _refresh_inventory():
	"""Atualiza a lista de itens no inventário"""
	if not game_temp:
		return
	
	_clear_inventory()
	
	var inventory = game_temp.get_inventory()
	
	if inventory.is_empty():
		_show_empty_inventory()
		return
	
	_populate_inventory(inventory)
	print("[HUD] Inventário atualizado: ", inventory.size(), " itens")

func _clear_inventory():
	"""Remove todos os filhos do container de inventário"""
	for child in inventory_container.get_children():
		child.queue_free()

func _show_empty_inventory():
	"""Mostra mensagem de inventário vazio"""
	var label = Label.new()
	label.text = "(Inventário vazio)"
	label.add_theme_font_size_override("font_size", EMPTY_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_container.add_child(label)

func _populate_inventory(inventory: Dictionary):
	"""Cria botões para cada item do inventário"""
	for item_name in inventory:
		var quantity = inventory[item_name]
		var item: ItemData = database.get_item(item_name) if database else null
		
		var button = _create_item_button(item.get_nome() if item else item_name, quantity)
		button.set_meta("item", item_name)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE   # quem decide toque x arraste é a ListaRolavel
		inventory_container.add_child(button)

# =============================================================================
# ITEM NOVO (poção chegando no inventário)
# =============================================================================
func _linha_do_item(id: String) -> Control:
	for c in inventory_container.get_children():
		if c.has_meta("item") and c.get_meta("item") == id and not c.is_queued_for_deletion():
			return c
	return null

## Rola a lista até a linha do item e devolve o centro dela na tela (ou da carta, se não achar).
## esconder = true deixa a linha invisível até destacar_item().
func preparar_item_chegando(id: String, esconder: bool = true) -> Vector2:
	var linha := _linha_do_item(id)
	if linha == null:
		return carta_inventario.global_position + carta_inventario.size * 0.5
	var lista = inventory_container.get_parent()
	if lista is ScrollContainer:
		lista.ensure_control_visible(linha)
	if esconder:
		linha.modulate.a = 0.0
	return linha.global_position + linha.size * 0.5

## A linha do item aparece com um brilho dourado.
func destacar_item(id: String) -> void:
	var linha := _linha_do_item(id)
	if linha == null:
		return
	linha.modulate = Color(1.6, 1.3, 0.6, 0.0)
	var tw := linha.create_tween()
	tw.tween_property(linha, "modulate", Color(1.6, 1.3, 0.6, 1.0), 0.2)
	tw.tween_property(linha, "modulate", Color.WHITE, 0.6)

func _create_item_button(item_name: String, quantity: int) -> Button:
	"""Cria um botão para um item do inventário"""
	var button = Button.new()
	button.text = item_name + " (x" + str(quantity) + ")"
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	button.add_theme_stylebox_override("normal", _button_style_normal())
	button.add_theme_stylebox_override("hover", _button_style_hover())
	button.add_theme_stylebox_override("pressed", _button_style_pressed())
	button.custom_minimum_size = Vector2(0, 56)   # linhas altas: fácil de tocar e de arrastar
	return button

# =============================================================================
# ESTILOS DOS BOTÕES
# =============================================================================

func _button_style_normal():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.25, 0.0)
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.5, 0.3)
	return style

func _button_style_hover():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5, 0.3)
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 0.9, 0.5)
	return style

func _button_style_pressed():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.4, 0.6, 0.4)
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.7, 1.0, 0.6)
	return style

# =============================================================================
# INTERAÇÃO COM ITENS
# =============================================================================

func _on_item_button_pressed(item_name: String):
	"""Abre o popup com informações do item"""
	print("[HUD] Item clicado: ", item_name)
	
	if not game_temp or not popup_instance:
		return
	
	var quantity = game_temp.get_item_quantity(item_name)
	var item: ItemData = database.get_item(item_name) if database else null
	var titulo = item.get_nome() if item else item_name
	var item_data = {"descricao": item.descricao} if item and item.descricao != "" else {}
	if item:
		item_data["A"] = CalculadoraPocao.matriz_do_item(item)
	
	# 🔥 O POPUP SE POSICIONA SOZINHO depois de saber o próprio tamanho:
	# centralizado no clique (x) e sempre inteiro dentro da área acima do HUD.
	var screen_size = get_viewport().get_visible_rect().size
	var anchor = Vector2(get_global_mouse_position().x, POPUP_ANCHOR_Y)
	var area = Rect2(0, 0, screen_size.x, POPUP_AREA_BOTTOM)
	carta_inventario.segurar = true   # não desvira com o popup aberto
	popup_instance.show_item(titulo, item_data, quantity, anchor, area)

func _on_linha_tocada(linha: Control) -> void:
	if linha.has_meta("item"):
		_on_item_button_pressed(linha.get_meta("item"))

func _on_popup_closed():
	"""Fecha o popup"""
	if popup_instance:
		popup_instance.visible = false
	carta_inventario.segurar = false

# =============================================================================
# STATUS
# =============================================================================

func _update_status():
	"""Atualiza o status da bruxa chamando a cena Status"""
	if status_node and status_node.has_method("atualizar"):
		status_node.atualizar()
		print("[HUD] Status atualizado via HUD")
	else:
		print("[HUD] ⚠️ Status node não encontrado ou sem método atualizar")

# =============================================================================
# SINAIS
# =============================================================================

func _on_inventory_changed():
	"""Atualiza o inventário quando ele muda"""
	print("[HUD] Inventário mudou!")
	_refresh_inventory()

func _on_personality_changed(_name: String):
	"""Atualiza o status quando uma personalidade muda"""
	print("[HUD] Personalidade mudou: ", _name)
	_update_status()

# =============================================================================
# NOTIFICAÇÕES
# =============================================================================

func _show_notification(text: String):
	"""Mostra uma notificação via GameManager"""
	if game_manager and game_manager.has_method("_show_notification"):
		game_manager._show_notification(text)
