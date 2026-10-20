# dialogue_box.gd
extends Control
class_name DialogueBox

signal dialog_finished
signal advance_requested  # 🔥 NOVO SINAL

# ===== ESTADO =====
var messages: Array = []
var current_index: int = 0

# ===== MÁQUINA DE ESCREVER (suave) =====
# Cada letra aparece com um fade curto e sobe um pouquinho até o lugar, em vez de
# "estalar" na tela. O layout do texto é calculado uma vez (texto inteiro, invisível),
# então as palavras não pulam de linha nem a linha centralizada escorrega.
## Letras por segundo. 0 = mostra o texto inteiro de uma vez.
@export var letras_por_segundo: float = 32.0
## Quantas letras o fade "arrasta" atrás do cursor (maior = rastro mais macio).
@export var largura_fade: float = 4.0
## Quanto a letra sobe enquanto aparece (px).
@export var subida_px: float = 5.0
## Pausa extra (em "letras") depois de cada caractere, para o texto respirar.
const PAUSA_PONTUACAO := {
	" ": 1.0,
	",": 3.0,
	";": 5.0, ":": 5.0,
	".": 7.0, "!": 7.0, "?": 7.0, "…": 7.0,
}
var _escrevendo: bool = false
var _cursor: float = 0.0        # posição do "cursor" em letras (pode ser fracionária)
var _pausa: float = 0.0         # quanto ainda falta esperar na pontuação atual (em letras)
var _texto_puro: String = ""
var _efeito: EfeitoEscrita

# ===== QUEM FALA (nome + foto) =====
## Quanto da foto fica escondido atrás da caixa de diálogo (px).
const SOBREPOSICAO_FOTO: float = 80.0
## Distância mínima do nome até a borda da tela (px).
const MARGEM_NOME: float = 16.0
## z_index absoluto da plaquinha do nome (fica por cima da caixa e das opções).
const Z_NOME: int = 600
## z absoluto da foto: acima da tela escura (150), atrás da carta do diálogo (160).
const Z_FOTO: int = 155
# ===== TELA ESCURA (fade atrás do diálogo) =====
## Alfa máximo da tela preta enquanto o diálogo está aberto.
const ALFA_MAX: float = 0.3
## Duração do fade de entrada/saída (s).
const DURACAO_ESCURECER: float = 0.25
## z_index absoluto da tela preta: acima do mapa e do HUD, abaixo da foto e da caixa.
const Z_ESCURECER: int = 150
var _escurecer: ColorRect
var _tw_escurecer: Tween

var _falante_fixo: Falante = null     # veio do comando (vale para todas as mensagens)
var _nome_painel: PanelContainer
var _nome_label: Label
var _foto: TextureRect
var _foto_atual: Texture2D = null

# ===== REFERÊNCIAS UI =====
@onready var _label_original: Label = $Panel/MarginContainer/VBoxContainer/TextLabel
@onready var panel: Panel = $Panel
var text_label: RichTextLabel


## Efeito de texto: letras depois do cursor ficam invisíveis; perto do cursor, fade + subida.
class EfeitoEscrita extends RichTextEffect:
	var bbcode := "escrita"
	var cursor: float = 1.0e9
	var largura: float = 4.0
	var subida: float = 5.0

	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var idx: float = float(char_fx.relative_index)
		var t: float = clampf((cursor - idx) / maxf(largura, 0.001), 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)   # smoothstep: entra e sai devagar
		char_fx.color.a *= t
		char_fx.offset.y += (1.0 - t) * subida
		return true


func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_criar_texto()
	_setup_ui()
	_criar_falante_ui()
	_criar_escurecer.call_deferred()

## Troca o Label da cena por um RichTextLabel no mesmo lugar (o fade por letra precisa dele).
func _criar_texto():
	text_label = RichTextLabel.new()
	text_label.name = "TextoRico"
	text_label.bbcode_enabled = true
	text_label.scroll_active = false
	text_label.fit_content = false
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_label.z_index = 101
	_efeito = EfeitoEscrita.new()
	_efeito.largura = largura_fade
	_efeito.subida = subida_px
	text_label.install_effect(_efeito)
	if _label_original:
		_label_original.get_parent().add_child(text_label)
		_label_original.get_parent().move_child(text_label, _label_original.get_index())
		_label_original.hide()
	else:
		add_child(text_label)

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

	if text_label:
		text_label.add_theme_font_size_override("normal_font_size", 28)
		text_label.add_theme_color_override("default_color", Color.WHITE)
		text_label.text = ""



func _show_current_message():
	if current_index >= messages.size():
		_finish_dialog()
		return

	if text_label:
		var fala := _resolver_fala(str(messages[current_index]))
		_aplicar_falante(fala["falante"], fala["nome"])
		_texto_puro = fala["texto"]
		# "[" vira "[lb]" para o texto do diálogo nunca ser lido como bbcode
		text_label.text = "[escrita]" + _texto_puro.replace("[", "[lb]") + "[/escrita]"
		_iniciar_escrita()

func _iniciar_escrita() -> void:
	_pausa = 0.0
	if letras_por_segundo <= 0.0:
		_terminar_escrita()
		return
	_cursor = 0.0
	_escrevendo = true
	_efeito.cursor = _cursor

func _process(delta: float) -> void:
	if not _escrevendo:
		return
	var avanco: float = delta * letras_por_segundo
	# pausa da pontuação: o cursor espera, mas o fade das últimas letras continua
	if _pausa > 0.0:
		var gasto: float = minf(_pausa, avanco)
		_pausa -= gasto
		avanco -= gasto
	var antes: int = int(floor(_cursor))
	_cursor += avanco
	# passou por uma pontuação? para o cursor logo depois dela e pausa
	for i in range(antes, mini(int(floor(_cursor)), _texto_puro.length())):
		var c: String = _texto_puro[i]
		if PAUSA_PONTUACAO.has(c) and i + 1 < _texto_puro.length():
			_cursor = float(i + 1)
			_pausa = PAUSA_PONTUACAO[c]
			break
	_efeito.cursor = _cursor
	if _cursor >= _texto_puro.length() + largura_fade:
		_terminar_escrita()

func _terminar_escrita() -> void:
	_escrevendo = false
	_pausa = 0.0
	_cursor = float(_texto_puro.length()) + largura_fade + 1.0
	if _efeito:
		_efeito.cursor = 1.0e9

func esta_escrevendo() -> bool:
	return _escrevendo

func _finish_dialog():
	_escrevendo = false
	_fade_escurecer(false)
	print("[DialogueBox] ===== FINISH_DIALOG =====")
	visible = false
	print("[DialogueBox] visible = false")
	print("[DialogueBox] Emitindo dialog_finished...")
	dialog_finished.emit()
	print("[DialogueBox] dialog_finished emitido!")
	print("[DialogueBox] ===== FIM FINISH_DIALOG =====")

## Esconde a caixa sem emitir dialog_finished (usado quando a pergunta fecha por uma opção).
func fechar_sem_sinal() -> void:
	_escrevendo = false
	visible = false
	_fade_escurecer(false)

func show_dialog(messages_array: Array, falante = null):
	print("[DialogueBox] ===== SHOW_DIALOG =====")
	print("[DialogueBox] messages_array: ", messages_array)

	if messages_array.is_empty():
		print("[DialogueBox] ⚠️ Lista vazia")
		return

	messages = messages_array
	current_index = 0
	_falante_fixo = falante if falante is Falante else null
	visible = true
	_fade_escurecer(true)
	print("[DialogueBox] visible: ", visible)
	print("[DialogueBox] messages: ", messages)
	print("[DialogueBox] current_index: ", current_index)

	_show_current_message()

	print("[DialogueBox] Emitindo advance_requested...")
	advance_requested.emit()
	print("[DialogueBox] advance_requested emitido!")
	print("[DialogueBox] ===== FIM SHOW_DIALOG =====")



func advance():
	print("[DialogueBox] ===== ADVANCE CHAMADO =====")
	print("[DialogueBox] visible: ", visible)
	print("[DialogueBox] current_index ANTES: ", current_index)
	print("[DialogueBox] messages.size(): ", messages.size())

	if not visible:
		print("[DialogueBox] ⚠️ Invisível, ignorando")
		return

	# Ainda escrevendo: o toque completa o texto em vez de pular para a próxima.
	if _escrevendo:
		_terminar_escrita()
		advance_requested.emit()   # o botão de avançar volta a aparecer
		print("[DialogueBox] Texto completado (máquina de escrever)")
		return

	current_index += 1
	print("[DialogueBox] current_index DEPOIS: ", current_index)

	if current_index >= messages.size():
		print("[DialogueBox] Fim das mensagens! Finalizando...")
		_finish_dialog()
		print("[DialogueBox] _finish_dialog() chamado")
	else:
		print("[DialogueBox] Próxima mensagem: ", messages[current_index])
		_show_current_message()
		print("[DialogueBox] _show_current_message() chamado")
		print("[DialogueBox] Emitindo advance_requested...")
		advance_requested.emit()
		print("[DialogueBox] advance_requested emitido!")

	print("[DialogueBox] ===== FIM ADVANCE =====")

func is_dialog_visible() -> bool:
	return visible


# =============================================================================
# NOME E FOTO
# =============================================================================
func _criar_falante_ui() -> void:
	# foto: atrás da caixa
	_foto = TextureRect.new()
	_foto.name = "Foto"
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_foto.z_as_relative = false
	_foto.z_index = Z_FOTO
	_foto.process_mode = Node.PROCESS_MODE_ALWAYS   # o fade roda com o jogo pausado
	_foto.visible = false
	add_child(_foto)
	move_child(_foto, 0)
	# plaquinha do nome: em cima da borda da caixa
	_nome_painel = PanelContainer.new()
	_nome_painel.name = "Nome"
	_nome_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# z absoluto: acima da caixa, do texto e dos botões de opção (os z da cena se somam até ~505)
	_nome_painel.z_as_relative = false
	_nome_painel.z_index = Z_NOME
	_nome_painel.process_mode = Node.PROCESS_MODE_ALWAYS
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.16, 0.16, 0.22, 1.0)
	st.border_color = Color(0.6, 0.6, 0.8, 0.9)
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	_nome_painel.add_theme_stylebox_override("panel", st)
	_nome_label = Label.new()
	_nome_label.add_theme_font_size_override("font_size", 24)
	_nome_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_nome_painel.add_child(_nome_label)
	_nome_painel.visible = false
	add_child(_nome_painel)
	resized.connect(_posicionar_falante)
	visibility_changed.connect(_on_caixa_visibilidade)

## Separa "[nome;pos_nome;foto;pos_foto] texto" (ver falante.gd).
func _resolver_fala(msg: String) -> Dictionary:
	var r := Falante.do_texto(msg)
	var fal: Falante = r["falante"]
	if fal == null and _falante_fixo:
		fal = _falante_fixo
	return {"falante": fal, "nome": fal.nome if fal else "", "texto": r["texto"]}

func _aplicar_falante(fal: Falante, nome: String) -> void:
	if not _nome_painel:
		return
	if _tw_falante and _tw_falante.is_valid():
		_tw_falante.kill()   # cancela um fade de saída em andamento
		_foto.modulate.a = 1.0
		_nome_painel.modulate.a = 1.0
	_nome_label.text = nome
	_nome_painel.visible = nome != ""
	if nome != "" and nome != _nome_atual:
		# nome novo: entra com fade
		_nome_painel.modulate.a = 0.0
		_nome_painel.create_tween().tween_property(_nome_painel, "modulate:a", 1.0, 0.25)
	_nome_atual = nome
	var tex: Texture2D = fal.foto if fal else null
	_foto.visible = tex != null
	if tex:
		_foto.texture = tex
		_foto.flip_h = fal.espelhar_foto
		if tex != _foto_atual:
			# foto nova: entra com fade
			_foto.modulate.a = 0.0
			var tw := _foto.create_tween()
			tw.tween_property(_foto, "modulate:a", 1.0, 0.25)
	_foto_atual = tex
	_falante_ui = fal
	_posicionar_falante.call_deferred()

var _falante_ui: Falante = null
var _nome_atual: String = ""
var _tw_falante: Tween
var _esconder_id: int = 0

## Topo da caixa na tela. Dentro de uma carta usa a carta (que não gira), para a foto e o
## nome não se mexerem enquanto ela vira.
func _topo_caixa() -> float:
	var n := get_parent()
	while n:
		if n is Carta:
			return n.global_position.y
		n = n.get_parent()
	return panel.global_position.y

## Caixa fechou: espera um instante (outra fala pode vir em seguida, com a mesma foto/nome,
## e aí eles só continuam); se não vier, foto e nome saem com fade.
func _on_caixa_visibilidade() -> void:
	_esconder_id += 1
	if visible:
		return
	var meu_id := _esconder_id
	await get_tree().create_timer(0.2, true).timeout
	if meu_id != _esconder_id or visible:
		return
	_foto_atual = null
	_nome_atual = ""
	_tw_falante = _foto.create_tween().set_parallel(true)
	_tw_falante.tween_property(_foto, "modulate:a", 0.0, 0.2)
	_tw_falante.tween_property(_nome_painel, "modulate:a", 0.0, 0.2)
	_tw_falante.chain().tween_callback(func():
		_foto.visible = false
		_nome_painel.visible = false
		_foto.modulate.a = 1.0
		_nome_painel.modulate.a = 1.0)

func _posicionar_falante() -> void:
	if not _nome_painel or not panel:
		return
	var fal: Falante = _falante_ui
	# nome: em cima da borda superior da caixa. Posição na TELA (igual à foto):
	# 0% = encostado à esquerda, 100% = à direita.
	if _nome_painel.visible:
		var tam := _nome_painel.get_combined_minimum_size()
		_nome_painel.size = tam
		var largura_tela: float = get_viewport_rect().size.x
		var x_max: float = maxf(MARGEM_NOME, largura_tela - tam.x - MARGEM_NOME)
		var p_nome: float = (fal.posicao_nome if fal else 0.0) / 100.0
		var x_nome: float = lerpf(MARGEM_NOME, x_max, p_nome)
		# padrão: com foto, o nome fica centralizado embaixo dela (pos_nome só vale sem foto)
		if fal and _foto.visible and _foto.texture:
			var centro_foto: float = _x_foto(fal) + _largura_foto(fal) / 2.0
			x_nome = clampf(centro_foto - tam.x / 2.0, MARGEM_NOME, x_max)
		_nome_painel.global_position = Vector2(x_nome, _topo_caixa() - tam.y + 6.0)
	# foto: na tela inteira, de 0% (encostada à esq) a 100% (encostada à dir),
	# com a parte de baixo escondida atrás da caixa
	if _foto.visible and _foto.texture:
		var h: float = fal.altura_foto if fal else 420.0
		var w: float = _largura_foto(fal)
		var x_global := _x_foto(fal)
		var topo_caixa: float = _topo_caixa()
		_foto.size = Vector2(w, h)
		_foto.global_position = Vector2(x_global, topo_caixa + SOBREPOSICAO_FOTO - h)


## Largura da foto na tela (mantém a proporção da imagem na altura do falante).
func _largura_foto(fal: Falante) -> float:
	if not _foto.texture:
		return 0.0
	var h: float = fal.altura_foto if fal else 420.0
	var tex_tam := _foto.texture.get_size()
	return h * tex_tam.x / maxf(tex_tam.y, 1.0)

## X global da foto: 0% encostada à esquerda da tela, 100% à direita.
func _x_foto(fal: Falante) -> float:
	var largura_tela: float = get_viewport_rect().size.x
	var p_foto: float = (fal.posicao_foto if fal else 0.0) / 100.0
	return lerpf(0.0, largura_tela - _largura_foto(fal), p_foto)


# =============================================================================
# TELA ESCURA
# =============================================================================
## A tela preta é irmã da caixa (no CanvasLayer), não filha: a caixa some na hora
## (visible = false) e o fade de saída continua rodando.
func _criar_escurecer() -> void:
	_escurecer = ColorRect.new()
	_escurecer.name = "EscurecerDialogo"
	_escurecer.color = Color(0, 0, 0, 1)
	_escurecer.modulate.a = 0.0
	_escurecer.visible = false
	_escurecer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escurecer.z_as_relative = false
	_escurecer.z_index = Z_ESCURECER
	_escurecer.process_mode = Node.PROCESS_MODE_ALWAYS
	var pai := get_parent()
	if pai:
		pai.add_child(_escurecer)
		# foto e nome também ficam fora da caixa: não giram com a carta nem piscam entre falas
		if _foto:
			_foto.reparent(pai, false)
		if _nome_painel:
			_nome_painel.reparent(pai, false)
	else:
		add_child(_escurecer)
	_ajustar_escurecer()
	get_viewport().size_changed.connect(_ajustar_escurecer)
	if visible:
		_fade_escurecer(true)

func _ajustar_escurecer() -> void:
	if _escurecer:
		_escurecer.global_position = Vector2.ZERO
		_escurecer.size = get_viewport_rect().size

## true = escurece até ALFA_MAX; false = clareia até sumir.
## A saída espera um instante: se outro diálogo abrir logo em seguida, a tela não pisca.
func _fade_escurecer(entrar: bool) -> void:
	if not _escurecer:
		return
	if _tw_escurecer and _tw_escurecer.is_valid():
		_tw_escurecer.kill()
	_tw_escurecer = _escurecer.create_tween()
	if entrar:
		_ajustar_escurecer()
		_escurecer.visible = true
		_tw_escurecer.tween_property(_escurecer, "modulate:a", ALFA_MAX, DURACAO_ESCURECER)
	else:
		_tw_escurecer.tween_interval(0.08)
		_tw_escurecer.tween_property(_escurecer, "modulate:a", 0.0, DURACAO_ESCURECER)
		_tw_escurecer.tween_callback(_escurecer.hide)
