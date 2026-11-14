# receita_memorizada.gd
# Com uma receita memorizada no livro, um ícone fica abaixo do botão DEBUG.
#   tocar no ícone  mostra só a página da receita e o botão "Tirar da memória"
#   tocar fora (tela ou HUD) fecha a página e o ícone volta
# No caldeirão o ícone some (lá a GuiaReceita já mostra a página).
# Criado pelo pause_menu na camada de cima (CamadaPausa).
class_name ReceitaMemorizada
extends Control

const ICONE := "res://assets/eventos/livro_receita/livro_receita.png"
const POS_ICONE := Vector2(16, 70)
const TAM_ICONE := Vector2(64, 64)
const LARG: float = 460.0
const ALT_LINHA: float = 30.0
const COR_FUNDO := Color(0.96, 0.91, 0.8, 0.97)
const COR_TINTA := Color(0.2, 0.14, 0.1)
const COR_SUAVE := Color(0.45, 0.38, 0.3)

var pausa = null            # pause_menu (diz quando o jogo normal está na tela)
var gm = null
var _icone: Button
var _papel: Control
var _tirar: Button
var _pagina: Dictionary = {}


func _ready() -> void:
	name = "ReceitaMemorizada"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(640, 960)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_to_group(UiModal.GRUPO)
	gui_input.connect(_fora)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.45)
	fundo.size = Vector2(640, 960)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_papel = Control.new()
	_papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_papel.draw.connect(_desenhar_papel)
	add_child(_papel)
	_tirar = PainelMenu.botao("Tirar da memória", _tirar_da_memoria)
	_tirar.size = Vector2(300, PainelMenu.ALTURA_BOTAO)
	add_child(_tirar)
	# ícone (fora deste Control, que só aparece com a página aberta)
	_icone = Button.new()
	_icone.name = "IconeReceita"
	_icone.focus_mode = Control.FOCUS_NONE
	_icone.position = POS_ICONE
	_icone.size = TAM_ICONE
	_icone.custom_minimum_size = TAM_ICONE
	_icone.process_mode = Node.PROCESS_MODE_ALWAYS
	_icone.flat = true
	if ResourceLoader.exists(ICONE):
		_icone.icon = load(ICONE)
		_icone.expand_icon = true
		_icone.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_icone.text = "📖"
	_icone.tooltip_text = "Receita memorizada"
	_icone.pressed.connect(abrir)
	_icone.add_to_group(UiModal.GRUPO_BOTOES)
	_icone.visible = false
	add_sibling.call_deferred(_icone)


func _livro() -> Dictionary:
	var gt = gm.get_node_or_null("GameTemp") if gm else null
	if gt == null or not ("livro" in gt) or gt.livro.is_empty():
		return {}
	return gt.livro

func _memorizada() -> Dictionary:
	var l := _livro()
	if l.is_empty() or int(l.get("memorizada", -1)) < 0:
		return {}
	return LivroReceitas.pagina_memorizada(l)

func _process(_d: float) -> void:
	if not is_instance_valid(_icone) or not _icone.is_inside_tree():
		return
	var pode: bool = pausa == null or pausa._pode_pausar()
	if visible and ((pausa != null and pausa.visible) or _memorizada().is_empty()):
		fechar()
	_icone.visible = not visible and pode and not _memorizada().is_empty()


func abrir() -> void:
	_pagina = _memorizada()
	if _pagina.is_empty():
		return
	var alt: float = 70.0 + _pagina["passos"].size() * ALT_LINHA + ALT_LINHA + 20.0
	_papel.size = Vector2(LARG, alt)
	_papel.position = Vector2((640 - LARG) * 0.5, maxf(60.0, (960 - alt - 90) * 0.5))
	_tirar.position = Vector2(170, _papel.position.y + alt + 18)
	_papel.queue_redraw()
	visible = true

func fechar() -> void:
	visible = false

func _fora(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		accept_event()
		fechar()

func _tirar_da_memoria() -> void:
	var l := _livro()
	if not l.is_empty():
		l["memorizada"] = -1
	fechar()


func _desenhar_papel() -> void:
	if _pagina.is_empty():
		return
	var f := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, _papel.size)
	_papel.draw_rect(r, COR_FUNDO)
	_papel.draw_rect(r, Color(COR_TINTA, 0.5), false, 2.0)
	_papel.draw_string(f, Vector2(18, 40), str(_pagina.get("nome", "")), HORIZONTAL_ALIGNMENT_LEFT, LARG - 36, 26, COR_TINTA)
	var db = gm.get_node_or_null("DatabaseManager") if gm else null
	var y := 84.0
	for s in _pagina["passos"]:
		var x := 22.0
		if s.get("tipo") == "chama":
			_papel.draw_rect(Rect2(x, y - 16, 16, 16), EstadosChama.cor(s["estado"]))
			x += 26.0
		_papel.draw_string(f, Vector2(x, y), LivroReceitas.texto_passo(s, db), HORIZONTAL_ALIGNMENT_LEFT, LARG - x - 16, 20, COR_TINTA)
		y += ALT_LINHA
	_papel.draw_string(f, Vector2(22, y), "Finalizar", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COR_SUAVE)
