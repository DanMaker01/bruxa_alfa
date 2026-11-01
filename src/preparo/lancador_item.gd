# lancador_item.gd
# Arremessa o visual de um item do inventário até o caldeirão (lançamento oblíquo).
# Emite `caiu(item_id)` quando o item chega; quem decide o que fazer é a cena.
class_name LancadorItem
extends Node

signal caiu(item_id: String)

const DURACAO: float = 0.35   # voo do item até o caldeirão (era 0.6)
## Altura extra do arco acima do ponto mais alto entre origem e destino (px).
const ALTURA: float = 140.0
const TAMANHO := Vector2(56, 56)

var voando: int = 0


## pai: onde o visual é desenhado (a própria cena). origem/destino em coordenadas globais.
func lancar(pai: Control, item_id: String, item: ItemData, nome_exibicao: String, origem: Vector2, destino: Vector2) -> void:
	var visual := _criar_visual(item, nome_exibicao)
	pai.add_child(visual)
	visual.global_position = origem - TAMANHO * 0.5
	voando += 1

	var y_pico: float = minf(origem.y, destino.y) - ALTURA
	var giro: float = randf_range(-1.0, 1.0) * TAU * 0.75
	# Trajetória: x anda linear; y é uma parábola que passa pela origem e pelo destino,
	# com o pico ALTURA acima do ponto mais alto dos dois (como um arremesso).
	var h0: float = origem.y - y_pico
	var h1: float = destino.y - y_pico
	var t_pico: float = sqrt(h0) / (sqrt(h0) + sqrt(h1))
	var trajetoria := func(t: float):
		var y: float
		if t <= t_pico:
			var u: float = t / t_pico
			y = origem.y - h0 * (1.0 - (1.0 - u) * (1.0 - u))
		else:
			var v: float = (t - t_pico) / (1.0 - t_pico)
			y = y_pico + h1 * v * v
		visual.global_position = Vector2(lerpf(origem.x, destino.x, t), y) - TAMANHO * 0.5
		visual.rotation = giro * t
		var s: float = lerpf(1.0, 0.55, t * t)
		visual.scale = Vector2(s, s)
		visual.modulate.a = 1.0 if t < 0.85 else lerpf(1.0, 0.0, (t - 0.85) / 0.15)

	var tw := visual.create_tween()
	tw.tween_method(trajetoria, 0.0, 1.0, DURACAO)
	tw.finished.connect(_on_chegou.bind(item_id, visual))

func _on_chegou(item_id: String, visual: Control) -> void:
	voando = maxi(0, voando - 1)
	if is_instance_valid(visual):
		visual.queue_free()
	caiu.emit(item_id)

## Visual do item voando: o ícone, ou uma "pedrinha" com a inicial se não tiver ícone.
func _criar_visual(item: ItemData, nome_exibicao: String) -> Control:
	var visual: Control
	if item and item.icone:
		var tex := TextureRect.new()
		tex.texture = item.icone
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visual = tex
	else:
		var bolinha := PanelContainer.new()
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.35, 0.3, 0.5, 0.95)
		estilo.border_color = Color(0.9, 0.85, 1.0)
		estilo.set_border_width_all(2)
		estilo.set_corner_radius_all(28)
		bolinha.add_theme_stylebox_override("panel", estilo)
		var letra := Label.new()
		letra.text = nome_exibicao.left(1).to_upper()
		letra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letra.add_theme_font_size_override("font_size", 24)
		bolinha.add_child(letra)
		visual = bolinha
	visual.size = TAMANHO
	visual.custom_minimum_size = TAMANHO
	visual.pivot_offset = TAMANHO * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.z_index = 50
	return visual
