# poeira_dash.gd
# Poeira transparente do dash: nuvenzinhas saem do chão onde a bruxa estava, vão para
# trás (contra o movimento), sobem um pouco, crescem e somem.
#   PoeiraDash.soltar(pai, pos_pe, direcao)
class_name PoeiraDash
extends Node2D

const N_NUVENS: int = 7
const DURACAO: float = 0.5
const COR := Color(0.85, 0.8, 0.7, 0.5)
const RAIO_INI: float = 7.0
const RAIO_FIM: float = 24.0
const DISTANCIA: float = 70.0     # px que a poeira anda para trás
const SUBIDA: float = 26.0

var _dir: float = 1.0
var _t: float = 0.0
var _nuvens: Array = []   # [deslocamento final, atraso, escala]


static func soltar(pai: Node, pos_pe: Vector2, direcao: int) -> void:
	if pai == null:
		return
	var p := PoeiraDash.new()
	p._dir = -1.0 if direcao < 0 else 1.0
	pai.add_child(p)
	p.global_position = pos_pe

func _ready() -> void:
	z_index = 0   # atrás da bruxa (z 1)
	for k in N_NUVENS:
		var f := float(k) / float(N_NUVENS - 1)
		var alvo := Vector2(-_dir * DISTANCIA * lerpf(0.3, 1.0, f) * randf_range(0.8, 1.1),
				-SUBIDA * randf_range(0.2, 1.0))
		_nuvens.append([alvo, f * 0.12, randf_range(0.7, 1.2)])

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURACAO + 0.12:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for n in _nuvens:
		var u: float = clampf((_t - float(n[1])) / DURACAO, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			continue
		var e: float = 1.0 - pow(1.0 - u, 2.0)   # sai rápido e freia
		var r: float = lerpf(RAIO_INI, RAIO_FIM, e) * float(n[2])
		draw_circle(Vector2(n[0]) * e + Vector2(0, -r * 0.6), r, Color(COR, COR.a * (1.0 - u)))
