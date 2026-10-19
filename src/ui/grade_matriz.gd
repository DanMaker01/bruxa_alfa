# grade_matriz.gd
# A matriz A em miniatura (5x5): cada célula é um ponto que mostra o quanto ela se
# afasta da identidade (1 na diagonal, 0 fora).
#   dourado = aumenta   vermelho = diminui   pontinho cinza = sem efeito
#   tamanho = intensidade (DESVIO_CHEIO ou mais = ponto cheio)
class_name GradeMatriz
extends Control

const TRACOS := ["O", "C", "E", "A", "N"]
const DESVIO_CHEIO: float = 0.15
const COR_SOBE := Color(1.0, 0.82, 0.3)
const COR_DESCE := Color(1.0, 0.35, 0.3)
const COR_NADA := Color(1, 1, 1, 0.18)
const FONTE_TAM: int = 12

var _A: Array = []


func mostrar(A: Array) -> void:
	_A = A
	queue_redraw()

func _draw() -> void:
	var margem := 14.0   # espaço para as letras
	var lado: float = minf(size.x, size.y) - margem
	var cel: float = lado / 5.0
	var origem := Vector2(margem, margem)
	var fonte := get_theme_default_font()
	draw_rect(Rect2(origem, Vector2(lado, lado)), Color(1, 1, 1, 0.05))
	for k in 5:
		draw_string(fonte, Vector2(origem.x + cel * (k + 0.5) - 4, FONTE_TAM - 2), TRACOS[k], HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_TAM, Color(1, 1, 1, 0.6))
		draw_string(fonte, Vector2(0, origem.y + cel * (k + 0.5) + 4), TRACOS[k], HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_TAM, Color(1, 1, 1, 0.6))
	for i in 5:
		for j in 5:
			var v: float = float(_A[i][j]) if i < _A.size() and j < _A[i].size() else (1.0 if i == j else 0.0)
			var desvio: float = v - (1.0 if i == j else 0.0)
			var c := origem + Vector2(cel * (j + 0.5), cel * (i + 0.5))
			if absf(desvio) < 0.0005:
				draw_circle(c, 1.5, COR_NADA)
				continue
			var r: float = cel * 0.45 * clampf(sqrt(absf(desvio) / DESVIO_CHEIO), 0.2, 1.0)
			draw_circle(c, r, COR_SOBE if desvio > 0.0 else COR_DESCE)
