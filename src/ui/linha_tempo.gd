# linha_tempo.gd
# Mini gráfico de um ingrediente na janela da poção pronta:
#   linha fina = temperatura do caldo durante todo o preparo
#   trecho claro = o tempo em que ESTE ingrediente ficou no caldeirão
#   bolinha = quando ele entrou, colorida como a chama naquela temperatura
#             (laranja = fervendo ~100 °C, branco = fritando ~120 °C, azul = quente demais)
# Texto ao lado: "entrou aos 12 s · 98 °C".
class_name LinhaTempo
extends Control

const ALTURA: float = 34.0
const T_MIN: float = 20.0
const T_MAX: float = 160.0
const COR_LINHA := Color(1, 1, 1, 0.35)
const COR_TRECHO := Color(1, 1, 1, 0.9)
const COR_FUNDO := Color(1, 1, 1, 0.06)
const LARGURA_TEXTO: float = 190.0

var _hist: Array = []
var _t0: float = 0.0
var _tf: float = 1.0
var _T_entrada: float = 20.0
var _cor_entrada := Color.WHITE

## historico: [{"t", "T"}...] do preparo; t0: entrada do ingrediente; tf: fim do preparo.
func configurar(historico: Array, t0: float, tf: float) -> void:
	_hist = historico
	_t0 = t0
	_tf = maxf(tf, 0.001)
	_T_entrada = _T_em(t0)
	_cor_entrada = cor_da_temperatura(_T_entrada)
	custom_minimum_size = Vector2(0, ALTURA)
	queue_redraw()

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

func _draw() -> void:
	var w: float = size.x - LARGURA_TEXTO
	if w <= 10.0 or _hist.is_empty():
		return
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), COR_FUNDO)
	var pts := PackedVector2Array()
	var trecho := PackedVector2Array()
	for p in _hist:
		var t: float = float(p.get("t", 0.0))
		var T: float = float(p.get("T", T_MIN))
		var v := Vector2(w * t / _tf, h - h * clampf((T - T_MIN) / (T_MAX - T_MIN), 0.0, 1.0))
		pts.append(v)
		if t >= _t0:
			trecho.append(v)
	if pts.size() >= 2:
		draw_polyline(pts, COR_LINHA, 1.5, true)
	if trecho.size() >= 2:
		draw_polyline(trecho, COR_TRECHO, 2.5, true)
	# marca de 100 °C (fervura)
	var y100: float = h - h * (100.0 - T_MIN) / (T_MAX - T_MIN)
	draw_dashed_line(Vector2(0, y100), Vector2(w, y100), Color(1, 1, 1, 0.15), 1.0, 4.0)
	# bolinha da entrada
	var x0: float = w * _t0 / _tf
	var y0: float = h - h * clampf((_T_entrada - T_MIN) / (T_MAX - T_MIN), 0.0, 1.0)
	draw_circle(Vector2(x0, y0), 6.0, Color(0, 0, 0, 0.6))
	draw_circle(Vector2(x0, y0), 4.5, _cor_entrada)
	# texto
	var fonte := get_theme_default_font()
	var txt := "entrou aos %d s · %d °C" % [roundi(_t0), roundi(_T_entrada)]
	draw_string(fonte, Vector2(w + 10.0, h * 0.5 + 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, LARGURA_TEXTO - 10.0, 16, Color(1, 1, 1, 0.75))
