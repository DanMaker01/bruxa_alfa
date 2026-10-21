# linha_tempo.gd
# Gráfico da temperatura do caldo na janela da poção pronta.
#
# Curva principal (configurar_principal): uma curva grande T(t), da entrada do 1º
# ingrediente até o fim. Ela se desenha (revelar) e fica um tempo sozinha na tela.
#
# Linha de ingrediente (configurar): mini gráfico embaixo do nome do ingrediente.
#   área colorida = ∫T dt deste ingrediente (da entrada dele até o fim), na cor da chama
#                   no momento em que entrou (laranja ~100 °C, branco ~120 °C, azul = demais)
#   bolinha       = quando ele entrou;  texto: "entrou aos 12 s · 98 °C"
# Com sair_da_principal(), a área nasce em cima da curva principal e desce até o lugar.
class_name LinhaTempo
extends Control

const ALTURA: float = 34.0
const ALTURA_PRINCIPAL: float = 90.0
const T_MIN: float = 20.0
const T_MAX: float = 160.0
const COR_LINHA := Color(1, 1, 1, 0.35)
const COR_PRINCIPAL := Color(1, 0.9, 0.7, 0.95)
const COR_TRECHO := Color(1, 1, 1, 0.9)
const COR_FUNDO := Color(1, 1, 1, 0.06)
const LARGURA_TEXTO: float = 190.0

var principal: bool = false
var _hist: Array = []
var _t0: float = 0.0
var _tf: float = 1.0
var _ti: float = 0.0
var _T_entrada: float = 20.0
var _cor_entrada := Color.WHITE
## principal: 0..1 quanto da curva já foi desenhado (da esquerda para a direita).
var _revelado: float = 1.0
## ingrediente: 0..1 da viagem da área (0 = em cima da curva principal, 1 = no lugar).
var _prog: float = 1.0
var _dy0: float = 0.0     # deslocamento (y) até a curva principal, no começo da viagem
var _h0: float = ALTURA   # altura da curva principal

## historico: [{"t", "T"}...] do preparo; t0: entrada do ingrediente; tf: fim do preparo.
## t_inicio: começo da receita (entrada do 1º ingrediente); o gráfico vai de t_inicio a tf.
func configurar(historico: Array, t0: float, tf: float, t_inicio: float = 0.0) -> void:
	_hist = historico
	_ti = t_inicio
	_t0 = t0
	_tf = maxf(tf, t_inicio + 0.001)
	_T_entrada = _T_em(t0)
	_cor_entrada = cor_da_temperatura(_T_entrada)
	custom_minimum_size = Vector2(0, ALTURA)
	queue_redraw()

func configurar_principal(historico: Array, tf: float, t_inicio: float) -> void:
	principal = true
	configurar(historico, t_inicio, tf, t_inicio)
	custom_minimum_size = Vector2(0, ALTURA_PRINCIPAL)

## Principal: some e depois se desenha da esquerda para a direita.
func esconder() -> void:
	if principal:
		_revelado = 0.0
	else:
		_prog = 0.0
	queue_redraw()

func revelar(tempo: float) -> Tween:
	var tw := create_tween()
	tw.tween_method(func(v): _revelado = v; queue_redraw(), 0.0, 1.0, tempo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## Ingrediente: a área sai de trás da curva principal e desce até este gráfico.
func sair_da_principal(p: LinhaTempo, tempo: float) -> Tween:
	_dy0 = p.global_position.y - global_position.y
	_h0 = p.size.y
	var tw := create_tween()
	tw.tween_method(func(v): _prog = v; queue_redraw(), 0.0, 1.0, tempo).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tw

func _T_em(t: float) -> float:
	var melhor := T_MIN
	for p in _hist:
		if float(p.get("t", 0.0)) > t:
			break
		melhor = float(p.get("T", T_MIN))
	return melhor

## Mesma cor da chama do caldeirão para essa temperatura do caldo.
static func cor_da_temperatura(T: float) -> Color:
	var s := SistemaTermico.new()
	s.F = 9.75 * T - 175.0   # fogo que deixaria o caldo nessa temperatura
	s.fogo_ligado = true
	var c: Color = s.get_cor_fogo()
	c.a = 1.0
	return c

## Ponto do gráfico (x em 0..w; y numa faixa de altura h começando em y_topo).
func _ponto(t: float, T: float, w: float, h: float, y_topo: float) -> Vector2:
	return Vector2(w * (t - _ti) / (_tf - _ti), y_topo + h - h * clampf((T - T_MIN) / (T_MAX - T_MIN), 0.0, 1.0))

func _draw() -> void:
	var w: float = size.x - LARGURA_TEXTO
	if w <= 10.0 or _hist.is_empty():
		return
	if principal:
		_desenhar_principal(w)
	else:
		_desenhar_ingrediente(w)

func _desenhar_principal(w: float) -> void:
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), COR_FUNDO)
	var y100: float = _ponto(0, 100.0, w, h, 0).y
	draw_dashed_line(Vector2(0, y100), Vector2(w, y100), Color(1, 1, 1, 0.2), 1.0, 4.0)
	var pts := PackedVector2Array()
	var t_lim: float = lerpf(_ti, _tf, _revelado)
	for p in _hist:
		var t: float = float(p.get("t", 0.0))
		if t < _ti:
			continue
		if t > t_lim:
			break
		pts.append(_ponto(t, float(p.get("T", T_MIN)), w, h, 0))
	if pts.size() >= 2:
		draw_polyline(pts, COR_PRINCIPAL, 3.0, true)
		draw_circle(pts[-1], 4.0, COR_PRINCIPAL)
	var fonte := get_theme_default_font()
	var a: float = clampf(_revelado * 2.0, 0.0, 1.0)
	draw_string(fonte, Vector2(w + 10.0, 22.0), "temperatura do caldo", HORIZONTAL_ALIGNMENT_LEFT, LARGURA_TEXTO - 10.0, 16, Color(1, 1, 1, 0.75 * a))
	draw_string(fonte, Vector2(w + 10.0, y100 + 5.0), "100 °C", HORIZONTAL_ALIGNMENT_LEFT, LARGURA_TEXTO - 10.0, 14, Color(1, 1, 1, 0.45 * a))
	draw_string(fonte, Vector2(w + 10.0, h - 4.0), "%d s" % roundi(_tf - _ti), HORIZONTAL_ALIGNMENT_LEFT, LARGURA_TEXTO - 10.0, 14, Color(1, 1, 1, 0.45 * a))

func _desenhar_ingrediente(w: float) -> void:
	var h: float = size.y
	var a: float = clampf((_prog - 0.6) / 0.4, 0.0, 1.0)   # o resto aparece quando a área chega
	draw_rect(Rect2(0, 0, w, h), Color(COR_FUNDO, COR_FUNDO.a * a))
	# área: viaja da curva principal (altura _h0, deslocada _dy0) até aqui (altura h)
	var hh: float = lerpf(_h0, h, _prog)
	var topo: float = lerpf(_dy0, 0.0, _prog)
	var area := PackedVector2Array()
	var pts := PackedVector2Array()
	for p in _hist:
		var t: float = float(p.get("t", 0.0))
		if t < _ti:
			continue
		var T: float = float(p.get("T", T_MIN))
		pts.append(_ponto(t, T, w, h, 0))
		if t >= _t0:
			area.append(_ponto(t, T, w, hh, topo))
	if area.size() >= 2:
		var borda := PackedVector2Array(area)
		area.append(Vector2(area[-1].x, topo + hh))
		area.append(Vector2(area[0].x, topo + hh))
		var surgir: float = clampf(_prog * 5.0, 0.0, 1.0)
		draw_colored_polygon(area, Color(_cor_entrada, 0.4 * surgir))
		draw_polyline(borda, Color(COR_TRECHO, COR_TRECHO.a * surgir), 2.0, true)
	if a <= 0.0:
		return
	if pts.size() >= 2:
		draw_polyline(pts, Color(COR_LINHA, COR_LINHA.a * a), 1.5, true)
	var y100: float = _ponto(0, 100.0, w, h, 0).y
	draw_dashed_line(Vector2(0, y100), Vector2(w, y100), Color(1, 1, 1, 0.15 * a), 1.0, 4.0)
	var e := _ponto(_t0, _T_entrada, w, h, 0)
	draw_circle(e, 6.0, Color(0, 0, 0, 0.6 * a))
	draw_circle(e, 4.5, Color(_cor_entrada, a))
	var fonte := get_theme_default_font()
	var txt := "entrou aos %d s · %d °C" % [roundi(_t0 - _ti), roundi(_T_entrada)]
	draw_string(fonte, Vector2(w + 10.0, h * 0.5 + 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, LARGURA_TEXTO - 10.0, 16, Color(1, 1, 1, 0.75 * a))
