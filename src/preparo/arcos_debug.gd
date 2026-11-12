# arcos_debug.gd
# Réguas em arco do preparo, só com o debug do caldeirão aberto:
#   arco de cima (acima do caldeirão): T do caldo, com as faixas de cor do caldeirão
#                                      (ferro, fundo rubro, rubro, rubro intenso).
#   arco de baixo (em volta do fogo):  F do fogo, com as faixas de cor da chama
#                                      (SistemaTermico.CORES_FOGO).
# Cada arco tem um marcador no valor atual e o número.
class_name ArcosDebug
extends Control

const T_INI: float = 40.0
const T_FIM: float = 220.0
const F_INI: float = 400.0
const F_FIM: float = 2000.0
const COR_TEXTO := Color(0.95, 0.92, 0.85)
const LARGURA: float = 9.0

var cena = null
## false: nunca aparece (o layout liga só no D).
var ativo: bool = true
## Arco de T (cima): centro, raio e ângulos (graus; 180 = esquerda, 270 = topo, 360 = direita).
var centro_T := Vector2(320, 290)
var raio_T: float = 150.0
var ang_T := Vector2(200.0, 340.0)
## Arco de F (baixo, em volta do fogo).
var centro_F := Vector2(320, 372)
var raio_F: float = 118.0
var ang_F := Vector2(160.0, 20.0)
var _fonte: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = get_theme_default_font()

func _process(_d: float) -> void:
	var d = cena.get("debug_ui") if cena else null
	visible = ativo and d != null and d.visible
	if visible:
		queue_redraw()

func _draw() -> void:
	var s = cena.get("sistema") if cena else null
	if s == null:
		return
	_arco_T(float(s.T))
	_arco_F(float(s.F), bool(s.fogo_ligado))

func _arco_T(T: float) -> void:
	var cats: Array = ReguaCaldeirao.CATEGORIAS
	for k in cats.size():
		var a: float = maxf(cats[k][0], T_INI)
		var b: float = cats[k + 1][0] if k + 1 < cats.size() else T_FIM
		var cor := ReguaCaldeirao.cor_de((a + b) * 0.5)
		var atual: bool = ReguaCaldeirao.categoria(T) == cats[k][1]
		_faixa(centro_T, raio_T, ang_T, _fT(a), _fT(b), cor if atual else Color(cor, 0.5))
	_marcador(centro_T, raio_T, ang_T, _fT(T), ReguaCaldeirao.cor_de(T))
	_texto_centro(centro_T + Vector2(0, -raio_T - 16), "Caldo T %.1f °C · %s" % [T, ReguaCaldeirao.categoria(T)], 13)

func _arco_F(F: float, ligado: bool) -> void:
	var cores: Array = SistemaTermico.CORES_FOGO
	for k in cores.size():
		var a: float = maxf(cores[k][0], F_INI)
		var b: float = cores[k + 1][0] if k + 1 < cores.size() else F_FIM
		if b <= a:
			continue
		var atual: bool = F >= a and F < b
		var cor: Color = cores[k][1]
		_faixa(centro_F, raio_F, ang_F, _fF(a), _fF(b), cor if atual else Color(cor, 0.5))
	_marcador(centro_F, raio_F, ang_F, _fF(F), Color.WHITE if ligado else Color(0.5, 0.5, 0.5))
	_texto_centro(centro_F + Vector2(0, raio_F + 28), "Fogo F %d °C%s" % [roundi(F), "" if ligado else " (apagado)"], 13)

func _fT(T: float) -> float:
	return clampf((T - T_INI) / (T_FIM - T_INI), 0.0, 1.0)

func _fF(F: float) -> float:
	return clampf((F - F_INI) / (F_FIM - F_INI), 0.0, 1.0)

func _ang(ang: Vector2, f: float) -> float:
	return deg_to_rad(lerpf(ang.x, ang.y, f))

func _faixa(c: Vector2, r: float, ang: Vector2, fa: float, fb: float, cor: Color) -> void:
	if fb <= fa:
		return
	draw_arc(c, r, _ang(ang, fa), _ang(ang, fb), 16, cor, LARGURA, true)

func _marcador(c: Vector2, r: float, ang: Vector2, f: float, cor: Color) -> void:
	var a := _ang(ang, f)
	var p := c + Vector2(cos(a), sin(a)) * r
	draw_circle(p, 8.0, COR_TEXTO)
	draw_circle(p, 5.0, cor)

func _texto_centro(p: Vector2, t: String, tam: int) -> void:
	var w := _fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_string(_fonte, Vector2(p.x - w * 0.5, p.y) + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.7))
	draw_string(_fonte, Vector2(p.x - w * 0.5, p.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, COR_TEXTO)
