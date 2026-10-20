# option_box.gd - BOTÕES DE OPÇÕES (e o botão de avançar do diálogo)
# Os botões dividem a caixa inteira: 1 opção = um botão gigante, 2 = metade cada, etc.
extends Control
class_name OptionBox

signal option_selected(index, text)
signal options_finished

# ===== ESTADO =====
var options: Array = []
var is_advance_mode: bool = false

# ===== REFERÊNCIAS UI =====
@onready var panel: Panel = $Panel
@onready var options_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/OptionsContainer
@onready var cancel_button: Button = get_node_or_null("Panel/MarginContainer/VBoxContainer/CancelButton")
@onready var advance_button: Button = get_node_or_null("Panel/MarginContainer/VBoxContainer/AdvanceButton")

func _ready():
	print("[OptionBox] ===== READY =====")
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	
	# Cria botão Avançar se não existir
	if not advance_button:
		print("[OptionBox] Criando advance_button...")
		advance_button = Button.new()
		advance_button.name = "AdvanceButton"
		var vbox = $Panel/MarginContainer/VBoxContainer
		vbox.add_child(advance_button)
	
	if advance_button:
		advance_button.text = "▼"
		advance_button.add_theme_font_size_override("font_size", 72)
		_estilizar_botao(advance_button)
		advance_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		advance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		advance_button.pressed.connect(_on_advance_pressed)
		advance_button.visible = false
		BotaoSegurar.efeito_clique(advance_button)
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	_setup_ui()
	visible = false
	print("[OptionBox] ===== FIM READY =====")

func _setup_ui():
	if panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.6, 0.6, 0.8, 0.8)
		style.corner_radius_top_left = 15
		style.corner_radius_top_right = 15
		style.corner_radius_bottom_left = 15
		style.corner_radius_bottom_right = 15
		panel.add_theme_stylebox_override("panel", style)
	
	# layout: a margem ocupa o painel todo e os botões dividem o espaço
	if panel:
		panel.clip_contents = true   # nada desenha fora do molde
	var margem_no: MarginContainer = $Panel/MarginContainer
	if margem_no:
		margem_no.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for lado in ["left", "top", "right", "bottom"]:
			margem_no.add_theme_constant_override("margin_" + lado, int(margem))
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
	if vbox:
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pergunta = get_node_or_null("Panel/MarginContainer/VBoxContainer/QuestionLabel")
	if pergunta:
		pergunta.visible = false   # a pergunta aparece na caixa de diálogo
	if options_container:
		options_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		options_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		options_container.add_theme_constant_override("separation", SEPARACAO)

# ===== MODO AVANÇAR =====

func show_advance():
	print("[OptionBox] ===== SHOW_ADVANCE =====")
	
	is_advance_mode = true
	options = []
	
	# 🔥 LIMPA O CONTAINER DE OPÇÕES
	if options_container:
		options_container.visible = false
		_limpar_opcoes()
	
	if cancel_button:
		cancel_button.visible = false
	
	# 🔥 MOSTRA O BOTÃO AVANÇAR
	if advance_button:
		advance_button.visible = true
	
	visible = true
	print("[OptionBox] visible: ", visible)

func hide_advance():
	print("[OptionBox] ===== HIDE_ADVANCE =====")
	
	if advance_button:
		advance_button.visible = false
	
	visible = false
	options_finished.emit()

# ===== MODO OPÇÕES =====

func show_options(options_list: Array):
	"""Mostra opções para o jogador (sem pergunta)"""
	if options_list.is_empty():
		print("[OptionBox] ⚠️ Lista de opções vazia")
		return
	
	print("[OptionBox] 📝 Mostrando opções: ", options_list)
	
	is_advance_mode = false
	options = options_list
	
	# 🔥 ESCONDE O BOTÃO AVANÇAR
	if advance_button:
		advance_button.visible = false
	
	if cancel_button:
		cancel_button.visible = true
	
	# 🔥 CRIA OS BOTÕES DE OPÇÃO
	_create_option_buttons(options_list)
	
	if options_container:
		options_container.visible = true
	
	visible = true

func hide_options():
	"""Esconde as opções"""
	visible = false
	options_finished.emit()

## Fonte das opções conforme quantas são (menos opções = botões maiores = letra maior).
const FONTE_POR_QTD := [34, 30, 26, 22, 20]
const SEPARACAO: int = 8
## Margem entre a borda da caixa e os botões (0 = botões ocupam a caixa toda).
var margem: float = 10.0
## Margem entre a borda do botão e o texto dele.
var margem_texto: float = 8.0

func _create_option_buttons(options_list: Array):
	if not options_container:
		return
	_limpar_opcoes()
	var n: int = options_list.size()
	# a altura de cada botão é a caixa dividida por n; a fonte nunca passa disso
	var altura_util: float = size.y - 2.0 * margem - SEPARACAO * (n - 1)
	var altura_botao: float = altura_util / n
	var fonte: int = FONTE_POR_QTD[mini(n, FONTE_POR_QTD.size()) - 1]
	fonte = clampi(mini(fonte, int((altura_botao - 2.0 * margem_texto) / 1.35)), 12, 72)
	for i in range(options_list.size()):
		var btn := Button.new()
		btn.text = ""
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL   # divide a altura igualmente
		btn.custom_minimum_size = Vector2.ZERO
		# o texto vai num Label FILHO (fora do layout do botão): quebra linha à vontade
		# sem aumentar a altura mínima do botão, então nunca estoura a caixa.
		var lbl := Label.new()
		lbl.text = str(options_list[i])
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", fonte)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		btn.add_child(lbl)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.offset_left = margem_texto
		lbl.offset_right = -margem_texto
		lbl.offset_top = margem_texto
		lbl.offset_bottom = -margem_texto
		_estilizar_botao(btn)
		btn.pressed.connect(_on_option_pressed.bind(i))
		options_container.add_child(btn)
		BotaoSegurar.efeito_clique(btn)
		# entrada: um depois do outro
		btn.modulate.a = 0.0
		var tw := btn.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(btn, "modulate:a", 1.0, 0.18)

func _limpar_opcoes() -> void:
	for child in options_container.get_children():
		options_container.remove_child(child)   # sai do layout já (queue_free só no fim do frame)
		child.queue_free()

## Visual dos botões (opções e avançar): fundo escuro com borda, claro ao apertar.
func _estilizar_botao(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.45))
	# botões pretos (claros só ao passar/apertar)
	var cores := {"normal": Color(0, 0, 0), "hover": Color(0.12, 0.12, 0.12), "pressed": Color(0.22, 0.22, 0.22)}
	for estado in cores:
		var st := StyleBoxFlat.new()
		st.bg_color = cores[estado]
		st.border_color = Color(0.4, 0.4, 0.4, 0.8)
		st.set_border_width_all(2)
		st.set_corner_radius_all(12)
		st.set_content_margin_all(margem_texto)
		btn.add_theme_stylebox_override(estado, st)

# ===== SINAIS =====

func _on_advance_pressed():
	print("[OptionBox] ▶️ Avançar pressionado")
	hide_advance()
	option_selected.emit(-1, "avancar")

func _on_option_pressed(index: int):
	print("[OptionBox] Opção selecionada: ", index, " - ", options[index])
	visible = false
	option_selected.emit(index, options[index])

func _on_cancel_pressed():
	print("[OptionBox] Opção cancelada")
	visible = false
	option_selected.emit(-1, "")

# ===== CONTROLES POR TECLADO =====

func _unhandled_input(event):
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if is_advance_mode:
					_on_advance_pressed()
				else:
					_on_cancel_pressed()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				if not is_advance_mode:
					var num = event.keycode - KEY_1
					if num < options.size():
						_on_option_pressed(num)
			KEY_SPACE, KEY_ENTER:
				if is_advance_mode:
					_on_advance_pressed()
