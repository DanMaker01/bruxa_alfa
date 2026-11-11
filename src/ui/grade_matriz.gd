# grade_matriz.gd
# A matriz A em miniatura (5x5): cada célula é um ponto que mostra o quanto ela se
# afasta da identidade (1 na diagonal, 0 fora).
#   dourado = aumenta   vermelho = diminui   pontinho cinza = sem efeito
#   tamanho = intensidade (DESVIO_CHEIO ou mais = ponto cheio)
class_name GradeMatriz
extends Control

const TRACOS := ["O", "C", "E", "A", "N"]
const DESVIO_CHEIO: float = 0.15
## Tamanho das bolinhas em escala log: ponto cheio em DESVIO_CHEIO_LOG; ESCALA_LOG controla a curva.
const DESVIO_CHEIO_LOG: float = 1.0
const ESCALA_LOG: float = 0.02
const COR_SOBE := Color(1.0, 0.82, 0.3)
const COR_DESCE := Color(1.0, 0.35, 0.3)
const COR_NADA := Color(1, 1, 1, 0.18)
const FONTE_TAM: int = 12

var _A: Array = []
## Célula tocada (i, j) e por quanto tempo o balão fica.
var _sel := Vector2i(-1, -1)
var _sel_t: float = 0.0
const TEMPO_BALAO: float = 2.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

## Toque numa célula: mostra "C → N  +3%" (o traço da coluna influencia o da linha).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var margem := 14.0
		var lado: float = minf(size.x, size.y) - margem
		var cel: float = lado / 5.0
		var p: Vector2 = event.position - Vector2(margem, margem)
		if p.x >= 0 and p.y >= 0 and p.x < lado and p.y < lado:
			_sel = Vector2i(int(p.y / cel), int(p.x / cel))
			_sel_t = TEMPO_BALAO
			queue_redraw()
		accept_event()

func _process(delta: float) -> void:
	if _sel_t > 0.0:
		_sel_t -= delta
		if _sel_t <= 0.0:
			_sel = Vector2i(-1, -1)
		queue_redraw()


## Centro (local) da área dos pontos, sem as letras da margem.
func centro_pontos() -> Vector2:
	var margem := 14.0
	var lado: float = minf(size.x, size.y) - margem
	return Vector2(margem, margem) + Vector2(lado, lado) * 0.5

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
			# escala log: desvios pequenos ainda aparecem, grandes não estouram
			var r: float = cel * 0.45 * clampf(log(1.0 + absf(desvio) / ESCALA_LOG) / log(1.0 + DESVIO_CHEIO_LOG / ESCALA_LOG), 0.15, 1.0)
			draw_circle(c, r, COR_SOBE if desvio > 0.0 else COR_DESCE)
	# balão da célula tocada
	if _sel.x >= 0:
		var i: int = _sel.x
		var j: int = _sel.y
		var v: float = float(_A[i][j]) if i < _A.size() and j < _A[i].size() else (1.0 if i == j else 0.0)
		var desvio: float = v - (1.0 if i == j else 0.0)
		var txt: String
		if i == j:
			txt = "%s  %+d%%" % [TRACOS[i], roundi(desvio * 100.0)]
		else:
			txt = "%s → %s  %+d%%" % [TRACOS[j], TRACOS[i], roundi(desvio * 100.0)]
		var tam := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var c := origem + Vector2(cel * (j + 0.5), cel * i)
		var r := Rect2(c - Vector2(tam.x * 0.5 + 8, tam.y + 10), tam + Vector2(16, 8))
		r.position.x = clampf(r.position.x, 0.0, maxf(0.0, size.x - r.size.x))
		var a: float = clampf(_sel_t / 0.3, 0.0, 1.0)
		draw_rect(r, Color(0, 0, 0, 0.85 * a))
		draw_rect(Rect2(origem + Vector2(cel * j, cel * i), Vector2(cel, cel)), Color(1, 1, 1, 0.5 * a), false, 1.5)
		draw_string(fonte, r.position + Vector2(8, tam.y + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, a))
