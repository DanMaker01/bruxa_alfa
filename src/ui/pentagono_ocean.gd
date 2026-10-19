# pentagono_ocean.gd
# Pentágono O-C-E-A-N mostrando o efeito de uma matriz A numa personalidade NEUTRA:
#   contorno cinza = antes (todos os traços iguais a BASE)
#   área dourada   = depois de aplicar A
# Cada vértice ganha o nome do traço e a variação em % (↑ dourado / ↓ vermelho).
# A diferença no desenho é exagerada (EXAGERO) para ficar visível; o % é o valor real.
class_name PentagonoOcean
extends Control

const TRACOS := ["O", "C", "E", "A", "N"]
const NOMES := ["Abertura", "Consciência", "Extroversão", "Amabilidade", "Neuroticismo"]
## Valor de cada traço na personalidade neutra (0..1 = centro..borda do pentágono).
const BASE: float = 0.6
## Quanto a diferença é ampliada no desenho (o texto mostra o valor real).
const EXAGERO: float = 3.0
const COR_GRADE := Color(1, 1, 1, 0.12)
const COR_ANTES := Color(0.75, 0.75, 0.75, 0.8)
const COR_DEPOIS := Color(1.0, 0.82, 0.3)
const COR_SOBE := Color(1.0, 0.82, 0.3)
const COR_DESCE := Color(1.0, 0.35, 0.3)
const FONTE_TAM: int = 18

var _antes: Array = [BASE, BASE, BASE, BASE, BASE]
var _depois: Array = [BASE, BASE, BASE, BASE, BASE]
var _prog: float = 0.0   # 0..1, animação de "antes" virando "depois"


## Calcula o "depois" (A · neutro) e anima.
func mostrar(A: Array, duracao: float = 0.8) -> void:
	_depois = []
	for i in 5:
		var v := 0.0
		for j in 5:
			var aij: float = float(A[i][j]) if i < A.size() and j < A[i].size() else (1.0 if i == j else 0.0)
			v += aij * _antes[j]
		_depois.append(v)
	_prog = 0.0
	var tw := create_tween()
	tw.tween_method(func(p): _prog = p; queue_redraw(), 0.0, 1.0, duracao) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Variação real de cada traço em % (depois/antes − 1).
func variacoes() -> Array:
	var out: Array = []
	for i in 5:
		out.append((_depois[i] / _antes[i] - 1.0) * 100.0 if absf(_antes[i]) > 0.0001 else 0.0)
	return out

func _ponto(i: int, r: float, centro: Vector2, raio: float) -> Vector2:
	var ang := -PI * 0.5 + TAU * float(i) / 5.0
	return centro + Vector2.from_angle(ang) * raio * r

func _draw() -> void:
	var centro := size * 0.5
	var raio: float = minf(size.x, size.y) * 0.5 - 34.0
	if raio <= 0.0:
		return
	# grade e eixos
	for nivel in [0.25, 0.5, 0.75, 1.0]:
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(_ponto(i % 5, nivel, centro, raio))
		draw_polyline(pts, COR_GRADE, 1.0)
	for i in 5:
		draw_line(centro, _ponto(i, 1.0, centro, raio), COR_GRADE, 1.0)
	# antes (neutro)
	var antes := PackedVector2Array()
	for i in 6:
		antes.append(_ponto(i % 5, _antes[i % 5], centro, raio))
	draw_polyline(antes, COR_ANTES, 1.5)
	# depois (exagerado no desenho, animado)
	var depois := PackedVector2Array()
	for i in 5:
		var mostrado: float = _antes[i] + (_depois[i] - _antes[i]) * EXAGERO * _prog
		depois.append(_ponto(i, clampf(mostrado, 0.05, 1.0), centro, raio))
	draw_colored_polygon(depois, Color(COR_DEPOIS, 0.35))
	var contorno := depois.duplicate()
	contorno.append(depois[0])
	draw_polyline(contorno, COR_DEPOIS, 2.0)
	# rótulos: letra + variação
	var fonte := get_theme_default_font()
	var var_pct := variacoes()
	for i in 5:
		var p := _ponto(i, 1.0, centro, raio + 20.0)
		var pct: float = var_pct[i] * _prog
		var seta := ""
		var cor := Color(1, 1, 1, 0.85)
		if pct > 0.5:
			seta = " ↑%d%%" % roundi(pct)
			cor = COR_SOBE
		elif pct < -0.5:
			seta = " ↓%d%%" % roundi(-pct)
			cor = COR_DESCE
		var texto: String = TRACOS[i] + seta
		var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_TAM).x
		draw_string(fonte, p + Vector2(-largura * 0.5, FONTE_TAM * 0.35), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_TAM, cor)
