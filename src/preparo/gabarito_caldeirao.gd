# gabarito_caldeirao.gd
# Debug do caldeirão: o gabarito de cada ingrediente na panela, ao vivo.
#   em cima: eixo de T da panela (ponto = T agora; marcas Tmin azul / Tmax vermelho de
#            cada item; faixa verde = onde todos estão bem)
#   embaixo: um cartão por ingrediente com 3 eixos + números:
#            T  (ponto = T agora; Tmin/Tmax e as folgas; tracinhos = menor/maior T que ele já pegou)
#            t  (ponto = tempo no caldeirão; janela t_min..t_max e as folgas)
#            Q  (ponto = cozimento acumulado; curva do aproveitamento com pico em m)
# Tudo desenhado em _draw (leve). Lê os dados da CenaPreparo (configurar(cena)).
class_name GabaritoCaldeirao
extends Control

const LARG: float = 154.0
const ESQ: float = 14.0                 # espaço do rótulo (T, t, Q)
const EIXO_W: float = LARG - ESQ - 6.0
const T_ESCALA: float = 250.0           # °C no fim do eixo de T
const ALT_PANELA: float = 46.0
const ALT_CARTAO: float = 102.0
const FONTE_P: int = 10
const FONTE_M: int = 11

const COR_EIXO := Color(1, 1, 1, 0.25)
const COR_TEXTO := Color(0.85, 0.85, 0.9)
const COR_SUAVE := Color(0.6, 0.6, 0.7)
const COR_MIN := Color(0.4, 0.65, 1.0)
const COR_MAX := Color(1.0, 0.35, 0.3)
const COR_OK := Color(0.3, 0.9, 0.45)
const COR_PONTO := Color(1, 1, 1)
const COR_TITULO := Color(1.0, 0.85, 0.45)

var cena = null
var _fonte: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(LARG, ALT_PANELA)
	_fonte = get_theme_default_font()


func configurar(p_cena) -> void:
	cena = p_cena


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		var n: int = _itens().size()
		var h: float = ALT_PANELA + n * ALT_CARTAO + 4.0
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(LARG, h)
		queue_redraw()


## [{item, est, nome, perdido}] na ordem da panela.
func _itens() -> Array:
	var r := []
	if cena == null:
		return r
	var ativos: Array = cena.get("ingredientes_ativos") if cena.get("ingredientes_ativos") != null else []
	var estados: Array = cena.get("_estados") if cena.get("_estados") != null else []
	for i in ativos.size():
		var acc: Dictionary = ativos[i]
		var est: Dictionary = estados[i] if i < estados.size() and estados[i] is Dictionary else {}
		var item: ItemData = cena._item_de(acc["nome"]) if cena.has_method("_item_de") else null
		var nome: String = item.get_nome() if item and item.has_method("get_nome") else str(acc["nome"])
		r.append({"item": item, "est": est, "nome": nome, "perdido": acc.get("perdido", false)})
	return r


func _T_agora() -> float:
	var s = cena.get("sistema") if cena else null
	return float(s.T) if s else 20.0


# =============================================================================
func _draw() -> void:
	var itens := _itens()
	var T := _T_agora()
	_desenhar_panela(Vector2(0, 0), itens, T)
	var y := ALT_PANELA
	if itens.is_empty():
		_txt(Vector2(0, y + 12), "panela vazia", FONTE_M, COR_SUAVE)
	for d in itens:
		_desenhar_cartao(Vector2(0, y), d, T)
		y += ALT_CARTAO


## Eixo da panela: marcas de todos, faixa verde onde todos estão bem.
func _desenhar_panela(o: Vector2, itens: Array, T: float) -> void:
	_txt(o + Vector2(0, 11), "Panela  %d °C" % roundi(T), FONTE_M, COR_TITULO)
	var y: float = o.y + 28.0
	var x0: float = o.x + 2.0
	var w: float = LARG - 4.0
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), COR_EIXO, 2.0)
	var lo := 0.0
	var hi := T_ESCALA
	var abaixo := false
	var acima := false
	for d in itens:
		var it: ItemData = d["item"]
		if it == null or d["perdido"]:
			continue
		if it.T_min > 0.0:
			lo = maxf(lo, it.T_min)
			draw_line(Vector2(_xT(it.T_min, x0, w), y - 6), Vector2(_xT(it.T_min, x0, w), y + 6), COR_MIN, 2.0)
			abaixo = abaixo or T < it.T_min
		if it.T_max > 0.0:
			hi = minf(hi, it.T_max)
			draw_line(Vector2(_xT(it.T_max, x0, w), y - 6), Vector2(_xT(it.T_max, x0, w), y + 6), COR_MAX, 2.0)
			acima = acima or T > it.T_max
	if hi > lo and not itens.is_empty():
		draw_line(Vector2(_xT(lo, x0, w), y), Vector2(_xT(hi, x0, w), y), Color(COR_OK, 0.7), 3.0)
	var cor := COR_MAX if acima else (COR_MIN if abaixo else COR_PONTO)
	draw_circle(Vector2(_xT(T, x0, w), y), 4.5, cor)
	_txt(Vector2(x0, y + 15), "0", FONTE_P, COR_SUAVE)
	_txt(Vector2(x0 + w - 18, y + 15), str(int(T_ESCALA)), FONTE_P, COR_SUAVE)


func _desenhar_cartao(o: Vector2, d: Dictionary, T: float) -> void:
	var it: ItemData = d["item"]
	var est: Dictionary = d["est"]
	draw_rect(Rect2(o + Vector2(0, 2), Vector2(LARG, ALT_CARTAO - 6)), Color(1, 1, 1, 0.04))
	var a: float = float(est.get("perda", 1.0))
	var titulo: String = d["nome"]
	if d["perdido"]:
		titulo += "  (perdido)"
	elif it == null:
		titulo += "  (não serve)"
	_txt(o + Vector2(3, 14), titulo, FONTE_M, COR_SUAVE if d["perdido"] else COR_TITULO)
	if not d["perdido"] and it:
		var pct := "%d%%" % roundi(a * 100.0)
		_txt(o + Vector2(LARG - 4 - _largura(pct, FONTE_M), 14), pct, FONTE_M, IconesCaldeirao.cor_aproveitamento(a))
	if it == null:
		return
	var y: float = o.y + 30.0
	_linha_T(Vector2(o.x, y), it, est, T)
	_linha_t(Vector2(o.x, y + 24), it, est)
	_linha_Q(Vector2(o.x, y + 48), it, est)


## T: folgas em degradê, Tmin/Tmax, menor/maior que já pegou, ponto = agora.
func _linha_T(o: Vector2, it: ItemData, est: Dictionary, T: float) -> void:
	var x0: float = o.x + ESQ
	var w := EIXO_W
	_txt(o + Vector2(2, 4), "T", FONTE_M, COR_TEXTO)
	draw_line(Vector2(x0, o.y), Vector2(x0 + w, o.y), COR_EIXO, 2.0)
	if it.T_min > 0.0:
		_folga(_xT((1.0 - it.k_min) * it.T_min, x0, w), _xT(it.T_min, x0, w), o.y, COR_MIN, true)
		_marca(_xT(it.T_min, x0, w), o.y, COR_MIN)
	if it.T_max > 0.0:
		_folga(_xT(it.T_max, x0, w), _xT((1.0 + it.k_max) * it.T_max, x0, w), o.y, COR_MAX, false)
		_marca(_xT(it.T_max, x0, w), o.y, COR_MAX)
	if int(est.get("n_pontos", 0)) > 0:
		for v in [float(est.get("T_min", 0.0)), float(est.get("T_max", 0.0))]:
			draw_line(Vector2(_xT(v, x0, w), o.y + 3), Vector2(_xT(v, x0, w), o.y + 7), COR_SUAVE, 1.0)
	var fora := (it.T_max > 0.0 and T > it.T_max) or (it.T_min > 0.0 and T < it.T_min)
	draw_circle(Vector2(_xT(T, x0, w), o.y), 3.5, COR_MAX if fora else COR_PONTO)
	var lim := "%s-%s °C" % [_n0(it.T_min, "—"), _n0(it.T_max, "—")]
	_txt(Vector2(x0, o.y + 15), lim, FONTE_P, COR_SUAVE)
	if int(est.get("n_pontos", 0)) > 0:
		var ext := "%d/%d" % [roundi(float(est.get("T_min", 0.0))), roundi(float(est.get("T_max", 0.0)))]
		_txt(Vector2(x0 + w - _largura(ext, FONTE_P), o.y + 15), ext, FONTE_P, COR_SUAVE)


## t: janela t_min..t_max (verde), folgas, ponto = tempo no caldeirão.
func _linha_t(o: Vector2, it: ItemData, est: Dictionary) -> void:
	var x0: float = o.x + ESQ
	var w := EIXO_W
	var t: float = float(est.get("duracao", 0.0))
	var fim: float = maxf(maxf(it.t_max * (1.0 + it.h_max), it.t_min * 1.5), t) * 1.1
	if fim <= 0.0:
		fim = maxf(t * 1.2, 60.0)
	_txt(o + Vector2(2, 4), "t", FONTE_M, COR_TEXTO)
	draw_line(Vector2(x0, o.y), Vector2(x0 + w, o.y), COR_EIXO, 2.0)
	var a_ini: float = it.t_min if it.t_min > 0.0 else 0.0
	var a_fim: float = it.t_max if it.t_max > 0.0 else fim
	draw_line(Vector2(_x(a_ini, fim, x0, w), o.y), Vector2(_x(a_fim, fim, x0, w), o.y), Color(COR_OK, 0.7), 3.0)
	if it.t_min > 0.0:
		_folga(_x((1.0 - it.h_min) * it.t_min, fim, x0, w), _x(it.t_min, fim, x0, w), o.y, COR_MIN, true)
		_marca(_x(it.t_min, fim, x0, w), o.y, COR_MIN)
	if it.t_max > 0.0:
		_folga(_x(it.t_max, fim, x0, w), _x((1.0 + it.h_max) * it.t_max, fim, x0, w), o.y, COR_MAX, false)
		_marca(_x(it.t_max, fim, x0, w), o.y, COR_MAX)
	var passou := it.t_max > 0.0 and t > it.t_max
	draw_circle(Vector2(_x(t, fim, x0, w), o.y), 3.5, COR_MAX if passou else COR_PONTO)
	_txt(Vector2(x0, o.y + 15), "%s-%s s" % [_n0(it.t_min, "0"), _n0(it.t_max, "—")], FONTE_P, COR_SUAVE)
	var agora := "%ds" % roundi(t)
	_txt(Vector2(x0 + w - _largura(agora, FONTE_P), o.y + 15), agora, FONTE_P, COR_TEXTO)


## Q: curva do aproveitamento do cozimento (pico em m), ponto = Q acumulado.
func _linha_Q(o: Vector2, it: ItemData, est: Dictionary) -> void:
	var x0: float = o.x + ESQ
	var w := EIXO_W
	var Q: float = float(est.get("Q", 0.0))
	_txt(o + Vector2(2, 4), "Q", FONTE_M, COR_TEXTO)
	draw_line(Vector2(x0, o.y), Vector2(x0 + w, o.y), COR_EIXO, 2.0)
	if it.m <= 0.0:
		_txt(Vector2(x0, o.y + 15), "sem ponto  Q %d" % roundi(Q), FONTE_P, COR_SUAVE)
		return
	var fim: float = maxf(it.m + 3.0 * it.s_mais, Q * 1.05)
	var pts := PackedVector2Array()
	for k in 41:
		var q: float = fim * k / 40.0
		var a := CalculadoraPocao.a_cozimento(q, it.m, it.s_menos, it.s_mais)
		pts.append(Vector2(_x(q, fim, x0, w), o.y - a * 9.0))
	draw_polyline(pts, Color(COR_OK, 0.6), 1.5, true)
	_marca(_x(it.m, fim, x0, w), o.y, COR_OK)
	var a_agora := CalculadoraPocao.a_cozimento(Q, it.m, it.s_menos, it.s_mais)
	draw_circle(Vector2(_x(Q, fim, x0, w), o.y - a_agora * 9.0), 3.5, COR_MAX if Q > it.m and a_agora < 0.99 else COR_PONTO)
	_txt(Vector2(x0, o.y + 15), "m %d (-%d/+%d)" % [roundi(it.m), roundi(it.s_menos), roundi(it.s_mais)], FONTE_P, COR_SUAVE)
	var agora := "%d" % roundi(Q)
	_txt(Vector2(x0 + w - _largura(agora, FONTE_P), o.y + 15), agora, FONTE_P, COR_TEXTO)


# ---------------------------------------------------------------------------
func _xT(T: float, x0: float, w: float) -> float:
	return x0 + clampf(T / T_ESCALA, 0.0, 1.0) * w

func _x(v: float, fim: float, x0: float, w: float) -> float:
	return x0 + clampf(v / maxf(fim, 0.001), 0.0, 1.0) * w

func _marca(x: float, y: float, cor: Color) -> void:
	draw_line(Vector2(x, y - 5), Vector2(x, y + 5), cor, 2.0)

## Folga: faixa que esmaece (forte junto do limite).
func _folga(xa: float, xb: float, y: float, cor: Color, forte_na_direita: bool) -> void:
	var passos := 6
	for k in passos:
		var f: float = (k + 0.5) / passos
		var alfa: float = 0.5 * (f if forte_na_direita else 1.0 - f)
		var a: float = lerpf(xa, xb, float(k) / passos)
		var b: float = lerpf(xa, xb, float(k + 1) / passos)
		draw_rect(Rect2(a, y - 3, maxf(b - a, 0.5), 6), Color(cor, alfa))

func _txt(p: Vector2, s: String, tam: int, cor: Color) -> void:
	draw_string(_fonte, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)

func _largura(s: String, tam: int) -> float:
	return _fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x

func _n0(v: float, vazio: String) -> String:
	return vazio if v <= 0.0 else str(roundi(v))
