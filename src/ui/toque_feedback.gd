# toque_feedback.gd
# Feedback de toque no mapa: um anel que abre e some no ponto tocado.
# Uso: ToqueFeedback.mostrar(no_pai, posicao_global)
class_name ToqueFeedback
extends Node2D

const RAIO_INI: float = 6.0
const RAIO_FIM: float = 26.0
const DURACAO: float = 0.35
const COR := Color(1.0, 1.0, 1.0, 0.8)
const LARGURA: float = 2.5

var raio: float = RAIO_INI:
	set(v):
		raio = v
		queue_redraw()

static func mostrar(pai: Node, pos_global: Vector2) -> void:
	if pai == null:
		return
	var f := ToqueFeedback.new()
	f.z_index = 50
	pai.add_child(f)
	f.global_position = pos_global
	f._animar()

func _animar() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "raio", RAIO_FIM, DURACAO).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, DURACAO).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _draw() -> void:
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 32, COR, LARGURA, true)
