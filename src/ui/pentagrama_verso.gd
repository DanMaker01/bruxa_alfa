# pentagrama_verso.gd
# Placeholder do verso das cartas: um pentagrama desenhado (estrela de 5 pontas num
# círculo), centrado no nó. Troque por uma imagem quando a arte do verso existir.
extends Control

@export var cor: Color = Color(0.85, 0.7, 1.0, 0.45)
@export var espessura: float = 3.0
## Raio em fração do menor lado do nó (0.5 = encosta na borda).
@export_range(0.1, 0.5) var raio_rel: float = 0.42
## Gira bem devagar (graus/s). 0 = parado.
@export var giro_graus_s: float = 6.0

var _ang: float = 0.0

func _process(delta: float) -> void:
	if giro_graus_s != 0.0 and is_visible_in_tree():
		_ang += deg_to_rad(giro_graus_s) * delta
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * raio_rel
	draw_arc(c, r, 0.0, TAU, 64, cor, espessura, true)
	draw_arc(c, r * 0.86, 0.0, TAU, 64, Color(cor, cor.a * 0.5), espessura * 0.5, true)
	var pts := PackedVector2Array()
	for k in 5:
		# estrela: liga as pontas pulando uma (0 → 2 → 4 → 1 → 3 → 0)
		var a := -PI * 0.5 + _ang + TAU * float((k * 2) % 5) / 5.0
		pts.append(c + Vector2.from_angle(a) * r * 0.86)
	pts.append(pts[0])
	draw_polyline(pts, cor, espessura, true)
