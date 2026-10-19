# =============================================================================
# hud.gd - HUD do jogo (Inventário + Status)
# =============================================================================
extends Control

# =============================================================================
# CONSTANTES
# =============================================================================
const POPUP_SIZE = Vector2(570, 200)
const BUTTON_FONT_SIZE = 18
const EMPTY_FONT_SIZE = 18
const MARGIN = 10
const POPUP_AREA_BOTTOM = 640.0  # o popup fica acima do HUD (inventário/status começam em y=640)
const POPUP_ANCHOR_Y = 540.0     # altura preferida do centro do popup (sobe se não couber)

# =============================================================================
# REFERÊNCIAS UI
# =============================================================================
@onready var inventory_container = $Inventario/MarginContainer/ScrollContainer/VBoxContainer
@onready var status_node = $Status/Status  # 🔥 Referência para a cena Status

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
	print("[HUD] Inicializando...")
	_find_dependencies()
	_connect_signals()
	_create_popup()
	_refresh_inventory()
	_update_status()
	print("[HUD] Inicializado!")

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
		button.pressed.connect(_on_item_button_pressed.bind(item_name))
		inventory_container.add_child(button)

func _create_item_button(item_name: String, quantity: int) -> Button:
	"""Cria um botão para um item do inventário"""
	var button = Button.new()
	button.text = item_name + " (x" + str(quantity) + ")"
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	button.add_theme_stylebox_override("normal", _button_style_normal())
	button.add_theme_stylebox_override("hover", _button_style_hover())
	button.add_theme_stylebox_override("pressed", _button_style_pressed())
	button.custom_minimum_size = Vector2(0, 40)
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
	
	# 🔥 O POPUP SE POSICIONA SOZINHO depois de saber o próprio tamanho:
	# centralizado no clique (x) e sempre inteiro dentro da área acima do HUD.
	var screen_size = get_viewport().get_visible_rect().size
	var anchor = Vector2(get_global_mouse_position().x, POPUP_ANCHOR_Y)
	var area = Rect2(0, 0, screen_size.x, POPUP_AREA_BOTTOM)
	popup_instance.show_item(titulo, item_data, quantity, anchor, area)

func _on_popup_closed():
	"""Fecha o popup"""
	if popup_instance:
		popup_instance.visible = false

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
