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
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	
	# Cria botão Avançar se não existir
	if not advance_button:
		advance_button = Button.new()
		advance_button.name = "AdvanceButton"
		var vbox = $Panel/MarginContainer/VBoxContainer
		vbox.add_child(advance_button)
	
	if advance_button:
		advance_button.text = ""
		# seta ▼ num Label filho: ela balança em y = A·sin(2π·t/L) (ver _process)
		_seta = Label.new()
		_seta.text = "▼"
		_seta.add_theme_font_size_override("font_size", 64)
		_seta.add_theme_color_override("font_color", Color.WHITE)   # mesma cor do texto do diálogo
		_seta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_seta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		advance_button.add_child(_seta)
		_seta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_estilizar_botao(advance_button)
		advance_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		advance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		advance_button.pressed.connect(_on_advance_pressed)
		advance_button.visible = false
		BotaoSegurar.efeito_clique(advance_button, false)   # avançar a fala não vibra
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	_setup_ui()
	visible = false

func _setup_ui():
	if panel:
		var style := Estilo.caixa_popup()
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

## Botão de avançar um pouco menor que a carta: margem pequena em volta (só nele).
const MARGEM_AVANCAR: float = 14.0
## Seta do avançar: amplitude (px) e período (s) do balanço.
const SETA_AMPLITUDE: float = 7.0
const SETA_PERIODO: float = 1.1
## Tempo (s) da setinha aparecer quando a frase termina.
const SETA_FADE: float = 0.2
var _seta: Label
var _t_seta: float = 0.0

func _process(delta: float) -> void:
	if _seta and advance_button and advance_button.visible:
		_t_seta += delta
		var y: float = SETA_AMPLITUDE * sin(TAU * _t_seta / SETA_PERIODO)
		_seta.offset_top = y
		_seta.offset_bottom = y
		# a setinha só aparece quando a frase terminou de escrever (o botão já funciona antes:
		# o toque completa o texto)
		var db = get_tree().get_first_node_in_group(DialogueBox.GRUPO)
		var escrevendo: bool = db != null and db.has_method("esta_escrevendo") and db.esta_escrevendo()
		var alvo: float = 0.0 if escrevendo else 1.0
		_seta.modulate.a = alvo if alvo < _seta.modulate.a else move_toward(_seta.modulate.a, alvo, delta / SETA_FADE)

func _margens(v: float) -> void:
	var m = get_node_or_null("Panel/MarginContainer")
	if m:
		for lado in ["left", "top", "right", "bottom"]:
			m.add_theme_constant_override("margin_" + lado, int(v))

func show_advance():
	_margens(MARGEM_AVANCAR)
	
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

func hide_advance():
	
	if advance_button:
		advance_button.visible = false
	
	visible = false
	options_finished.emit()

# ===== MODO OPÇÕES =====

func show_options(options_list: Array):
	_margens(margem)
	"""Mostra opções para o jogador (sem pergunta)"""
	if options_list.is_empty():
		push_warning("[OptionBox] ⚠️ Lista de opções vazia")
		return
	
	
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
## Menor fonte das opções: abaixo disso o texto é cortado com "...".
const FONTE_MIN: int = 16
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
		var lbl := _rotulo_opcao(str(options_list[i]), fonte)
		btn.add_child(lbl)
		_caber.call_deferred(lbl, fonte)
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

## Texto da opção: Label; com tags de cor ([item]...), RichTextLabel com as cores.
func _rotulo_opcao(texto: String, fonte: int) -> Control:
	if DialogueBox.tem_tag(texto):
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.text = DialogueBox.tags_para_bbcode(texto)
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.clip_contents = true
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
			r.add_theme_font_size_override(k, fonte)
		r.add_theme_color_override("default_color", Color.WHITE)
		return r
	var lbl := Label.new()
	lbl.text = texto
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", fonte)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	return lbl

## Diminui a fonte do texto da opção até caber no botão (no mínimo FONTE_MIN).
func _caber(rotulo: Control, fonte: int) -> void:
	if rotulo is RichTextLabel:
		_caber_rico(rotulo, fonte)
		return
	var lbl: Label = rotulo
	await get_tree().process_frame   # espera o layout dar tamanho ao botão
	if not is_instance_valid(lbl) or lbl.size.x <= 1.0:
		return
	var f: Font = lbl.get_theme_font("font")
	var tam := fonte
	var alt: float = 0.0
	while tam > FONTE_MIN:
		alt = f.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, lbl.size.x, tam).y
		if alt <= lbl.size.y:
			break
		tam -= 1
	alt = f.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, lbl.size.x, tam).y
	if alt > lbl.size.y:
		# muitas opções (botões baixos): quebrando linha, o começo do texto era cortado
		# (sumia o nome do item). Uma linha só, com "..." no fim se não couber.
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.offset_top = 0.0
		lbl.offset_bottom = 0.0
		while tam > 10 and f.get_height(tam) > lbl.size.y + 2.0 * margem_texto:
			tam -= 1
	lbl.add_theme_font_size_override("font_size", tam)

## Mesmo que _caber, para o texto com cores (mede o texto sem as tags).
func _caber_rico(r: RichTextLabel, fonte: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(r) or r.size.x <= 1.0:
		return
	var f: Font = r.get_theme_font("normal_font")
	var puro: String = r.get_parsed_text()
	var tam := fonte
	while tam > FONTE_MIN and f.get_multiline_string_size(puro, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam).y > r.size.y:
		tam -= 1
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(k, tam)

func _limpar_opcoes() -> void:
	for child in options_container.get_children():
		options_container.remove_child(child)   # sai do layout já (queue_free só no fim do frame)
		child.queue_free()

## Visual dos botões (opções e avançar): fundo escuro com borda, claro ao apertar.
func _estilizar_botao(btn: Button) -> void:
	Estilo.botao_preto(btn, margem_texto)

# ===== SINAIS =====

func _on_advance_pressed():
	hide_advance()
	option_selected.emit(-1, "avancar")

func _on_option_pressed(index: int):
	visible = false
	option_selected.emit(index, options[index])

func _on_cancel_pressed():
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
