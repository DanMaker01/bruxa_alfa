# regua_caldeirao.gd
# Régua vertical da cor do caldeirão (pela temperatura do caldo T), com as categorias
# de cor do próprio caldeirão (o mesmo gradiente de vermelho do VisualCaldeirao),
# e o selo "estável": acende quando |T'| < E_T e |F'| < E_F.
# As derivadas são a inclinação da reta (mínimos quadrados) dos últimos JANELA s, então os
# trancos de cada abanada (+30 em F) se compensam e só conta a tendência. Com histerese:
# para deixar de ser estável precisa passar de SAIR × o limite.
# Com o debug do caldeirão ligado, mostra T e F em número.
class_name ReguaCaldeirao
extends Control

const T_INI: float = 40.0
const T_FIM: float = 220.0
const E_T: float = 0.5      # °C/s
const E_F: float = 10.0     # °C/s
const JANELA: float = 3.0   # s de histórico para a derivada
const SAIR: float = 1.5     # histerese: sai do estável só acima de SAIR × limite
const COR_FERRO := Color(0.32, 0.31, 0.33)
const COR_RUBRO := Color(1.0, 0.22, 0.15)
const COR_TEXTO := Color(0.95, 0.92, 0.85)
const COR_SUAVE := Color(0.75, 0.72, 0.68)
## Categorias (T inicial, nome).
const CATEGORIAS := [[40.0, "ferro"], [100.0, "fundo rubro"], [160.0, "rubro"], [200.0, "rubro intenso"]]

var cena = null
var _fonte: Font
var estavel: bool = false
var dT: float = 0.0
var dF: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = get_theme_default_font()

func _process(_d: float) -> void:
	if is_visible_in_tree():
		estavel = _medir_estavel()
		queue_redraw()

func _medir_estavel() -> bool:
	var h: Array = cena.get("historico_T") if cena and cena.get("historico_T") != null else []
	if h.size() < 2:
		return false
	var t_fim: float = float(h[-1]["t"])
	var k := h.size() - 1
	while k > 0 and t_fim - float(h[k - 1]["t"]) <= JANELA:
		k -= 1
	if t_fim - float(h[k]["t"]) < JANELA * 0.8:
		return false
	dT = _inclinacao(h, k, "T")
	dF = _inclinacao(h, k, "F")
	var f: float = SAIR if estavel else 1.0
	return absf(dT) < E_T * f and absf(dF) < E_F * f

## Inclinação (°C/s) da reta que melhor passa pelos pontos h[k..fim].
func _inclinacao(h: Array, k: int, chave: String) -> float:
	var n := 0.0
	var st := 0.0
	var sy := 0.0
	var stt := 0.0
	var sty := 0.0
	for i in range(k, h.size()):
		var t: float = float(h[i]["t"])
		var y: float = float(h[i].get(chave, 0.0))
		n += 1.0
		st += t
		sy += y
		stt += t * t
		sty += t * y
	var den: float = n * stt - st * st
	return 0.0 if absf(den) < 1e-9 else (n * sty - st * sy) / den

## Cor do caldeirão para uma temperatura (igual ao vermelho do VisualCaldeirao).
static func cor_de(T: float) -> Color:
	return COR_FERRO.lerp(COR_RUBRO, VisualCaldeirao.progresso_vermelho(T) * VisualCaldeirao.VERMELHO_MAX)

static func categoria(T: float) -> String:
	var nome := "ferro"
	for c in CATEGORIAS:
		if T >= c[0]:
			nome = c[1]
	return nome

func _f(T: float) -> float:
	return clampf((T - T_INI) / (T_FIM - T_INI), 0.0, 1.0)

func _draw() -> void:
	var s = cena.get("sistema") if cena else null
	var T: float = float(s.T) if s else 20.0
	var xb := size.x - 22.0
	var y0 := 30.0
	var h := size.y - 72.0
	# barra em degradê (de baixo para cima)
	var passos := 40
	for k in passos:
		var f0 := float(k) / passos
		var f1 := float(k + 1) / passos
		var Tm: float = lerpf(T_INI, T_FIM, (f0 + f1) * 0.5)
		draw_rect(Rect2(xb, y0 + h * (1.0 - f1), 14, h * (f1 - f0) + 0.5), cor_de(Tm))
	# categorias
	for c in CATEGORIAS:
		var y: float = y0 + h * (1.0 - _f(c[0]))
		draw_line(Vector2(xb - 4, y), Vector2(xb + 14, y), Color(0, 0, 0, 0.5), 1.0)
		_texto_dir(Vector2(xb - 6, y - 3), c[1], 10, COR_TEXTO if categoria(T) == c[1] else COR_SUAVE)
	# marcador
	var ym := y0 + h * (1.0 - _f(T))
	draw_colored_polygon(PackedVector2Array([Vector2(xb + 15, ym), Vector2(xb + 22, ym - 6), Vector2(xb + 22, ym + 6)]), COR_TEXTO)
	draw_line(Vector2(xb - 1, ym), Vector2(xb + 15, ym), COR_TEXTO, 2.0)
	_texto_dir(Vector2(size.x - 4, 16), "Caldeirão", 12, cor_de(T).lightened(0.4))
	# selo estável
	var yb := y0 + h + 14
	var cor_selo := Color(0.35, 0.9, 0.45) if estavel else Color(0.5, 0.5, 0.55)
	draw_circle(Vector2(xb + 7, yb + 6), 6.0, cor_selo)
	_texto_dir(Vector2(xb - 4, yb + 10), "estável" if estavel else "mudando", 12, cor_selo)
	var d = cena.get("debug_ui") if cena else null
	if d != null and d.visible and s:
		_texto_dir(Vector2(size.x - 4, yb + 30), "T %.1f  F %d" % [T, roundi(float(s.F))], 11, COR_SUAVE)
		_texto_dir(Vector2(size.x - 4, yb + 46), "T' %.2f  F' %.1f" % [dT, dF], 11, COR_SUAVE)

func _texto_dir(p: Vector2, t: String, tam: int, cor: Color) -> void:
	var w := _fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_string(_fonte, Vector2(p.x - w, p.y) + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.7))
	draw_string(_fonte, Vector2(p.x - w, p.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
