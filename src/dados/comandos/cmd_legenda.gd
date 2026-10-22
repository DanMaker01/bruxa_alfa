# Legenda de narração (intro, cenas): texto centralizado na tela, aparece com fade,
# espera um toque (ou alguns segundos) e some. O evento espera ela sumir.
# Fica numa CanvasLayer própria por cima do mapa (o cenário continua visível atrás).
class_name CmdLegenda
extends Comando

@export_multiline var texto: String = ""
## 0 = espera um toque. > 0 = some sozinha depois desses segundos (um toque adianta).
@export var segundos: float = 0.0
@export var tamanho_fonte: int = 30
## Altura do centro do texto na tela (0 = topo, 1 = base).
@export_range(0.0, 1.0) var altura: float = 0.5
@export var tempo_fade: float = 0.8

const CAMADA: int = 20
const GRUPO := "legenda"   # CmdPularComToque apaga as legendas deste grupo
const MARGEM: float = 48.0

func to_dict() -> Dictionary:
	return {"nome": "legenda", "args": [texto, segundos]}

func executar(interp, ev) -> int:
	ev.pause("legenda")
	_mostrar(interp, ev)
	return MANTER

func _mostrar(interp, ev) -> void:
	var tree: SceneTree = interp.get_tree()
	var camada := CanvasLayer.new()
	camada.layer = CAMADA
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	camada.add_to_group(GRUPO)
	tree.root.add_child(camada)
	var tela: Vector2 = tree.root.get_visible_rect().size
	# área de toque (tela toda)
	var toque := Control.new()
	toque.size = tela
	toque.mouse_filter = Control.MOUSE_FILTER_STOP
	camada.add_child(toque)
	var tocou := [false]
	toque.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			tocou[0] = true)
	# texto
	var label := Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamanho_fonte)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("line_spacing", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(tela.x - MARGEM * 2.0, tela.y * 0.5)
	label.position = Vector2(MARGEM, tela.y * altura - label.size.y * 0.5)
	label.modulate.a = 0.0
	camada.add_child(label)
	# dica pequena embaixo (só quando espera toque)
	var dica: Label = null
	if segundos <= 0.0:
		dica = Label.new()
		dica.text = "▼"
		dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dica.add_theme_font_size_override("font_size", 20)
		dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dica.size = Vector2(tela.x, 30)
		dica.position = Vector2(0, tela.y - 70)
		dica.modulate.a = 0.0
		camada.add_child(dica)

	# entra (um toque durante o fade completa na hora)
	var tw := camada.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, tempo_fade)
	while tw.is_running() and not tocou[0] and is_instance_valid(camada):
		await tree.process_frame
	if not is_instance_valid(camada):
		_fim(ev)
		return
	tw.kill()
	label.modulate.a = 1.0
	tocou[0] = false
	if dica:
		var tw_d := camada.create_tween().set_loops()
		tw_d.tween_property(dica, "modulate:a", 1.0, 0.6)
		tw_d.tween_property(dica, "modulate:a", 0.3, 0.6)
	# espera
	var t := 0.0
	while not tocou[0] and (segundos <= 0.0 or t < segundos) and is_instance_valid(camada):
		await tree.process_frame
		t += tree.root.get_process_delta_time()
	if not is_instance_valid(camada):
		_fim(ev)
		return
	# sai
	toque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw_s := camada.create_tween().set_parallel(true)
	tw_s.tween_property(label, "modulate:a", 0.0, tempo_fade * 0.6)
	if dica:
		tw_s.tween_property(dica, "modulate:a", 0.0, tempo_fade * 0.4)
	await tw_s.finished
	camada.queue_free()
	_fim(ev)

func _fim(ev) -> void:
	if not ev.finished and ev.pause_reason == "legenda":
		ev.resume_and_advance()
