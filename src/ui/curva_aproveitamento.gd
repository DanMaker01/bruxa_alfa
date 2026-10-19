# curva_aproveitamento.gd
# Mini-gráfico da curva de aproveitamento (0..1) de uma poção/ingrediente:
#   COZIMENTO   a_Q(Q)  — gaussiana de dois lados (m, s−, s+), só o valor de m embaixo do pico
#   TEMPERATURA a_T(T)  — logística do Tmin (k_min) × logística do Tmax (k_max)
#   TEMPO       a_t(t)  — logística do tmin (h_min) × logística do tmax (h_max)
# Usa as mesmas funções da CalculadoraPocao, então o desenho é exatamente a regra do jogo.
class_name CurvaAproveitamento
extends Control

enum Tipo { COZIMENTO, TEMPERATURA, TEMPO }

const AMOSTRAS: int = 90
const COR_CURVA := Color(1.0, 0.82, 0.3)
const COR_AREA := Color(1.0, 0.82, 0.3, 0.18)
const COR_EIXO := Color(1, 1, 1, 0.25)
const COR_TEXTO := Color(1, 1, 1, 0.75)
const FONTE_TITULO: int = 14
const FONTE_VALOR: int = 12
const ALTURA_TITULO: float = 16.0
const ALTURA_VALORES: float = 13.0

var tipo: int = Tipo.COZIMENTO
var _item: ItemData = null
var _x0: float = 0.0
var _x1: float = 1.0
var _marcas: Array = []   # [{x, texto}] valores mostrados embaixo (m, limites de T e t)
var _sem_limite: bool = true   # até mostrar() ser chamado


func mostrar(p_tipo: int, item: ItemData) -> void:
	tipo = p_tipo
	_item = item
	_marcas = []
	_sem_limite = false
	if item == null:
		_sem_limite = true
	else:
		match tipo:
			Tipo.COZIMENTO:
				if item.m <= 0.0:
					_sem_limite = true
				else:
					_x0 = maxf(0.0, item.m - 3.0 * maxf(item.s_menos, 1.0))
					_x1 = item.m + 3.0 * maxf(item.s_mais, 1.0)
					_marcas.append({"x": item.m, "texto": str(roundi(item.m))})
			Tipo.TEMPERATURA:
				_faixa(item.T_min, item.k_min, item.T_max, item.k_max, "°")
			Tipo.TEMPO:
				_faixa(item.t_min, item.h_min, item.t_max, item.h_max, "s")
	queue_redraw()

## Escolhe o trecho do eixo x que mostra as duas quedas (com folga dos dois lados).
func _faixa(vmin: float, fmin: float, vmax: float, fmax: float, unidade: String) -> void:
	var tem_min := vmin > 0.0
	var tem_max := vmax > 0.0 and vmax < 999.0
	if not tem_min and not tem_max:
		_sem_limite = true
		return
	var ini: float = vmin * (1.0 - maxf(fmin, 0.0)) if tem_min else 0.0
	var fim: float = vmax * (1.0 + maxf(fmax, 0.0)) if tem_max else vmin * 2.0
	var margem: float = maxf((fim - ini) * 0.15, 1.0)
	_x0 = maxf(0.0, ini - margem)
	_x1 = fim + margem
	if tem_min:
		_marcas.append({"x": vmin, "texto": "%d%s" % [roundi(vmin), unidade]})
	if tem_max:
		_marcas.append({"x": vmax, "texto": "%d%s" % [roundi(vmax), unidade]})

func _valor(x: float) -> float:
	var it := _item
	match tipo:
		Tipo.COZIMENTO:
			return CalculadoraPocao.a_cozimento(x, it.m, it.s_menos, it.s_mais)
		Tipo.TEMPERATURA:
			return CalculadoraPocao.curva_min(x, it.T_min, it.k_min) * CalculadoraPocao.curva_max(x, it.T_max, it.k_max)
		Tipo.TEMPO:
			return CalculadoraPocao.curva_min(x, it.t_min, it.h_min) * CalculadoraPocao.curva_max(x, it.t_max, it.h_max)
	return 1.0

func _titulo() -> String:
	match tipo:
		Tipo.COZIMENTO: return "Cozimento"
		Tipo.TEMPERATURA: return "Temperatura"
		Tipo.TEMPO: return "Tempo"
	return ""

func _draw() -> void:
	var fonte := get_theme_default_font()
	var titulo := _titulo() + ("  (sem exigência)" if _sem_limite else "")
	draw_string(fonte, Vector2(0, FONTE_TITULO), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_TITULO, COR_TEXTO)
	var area := Rect2(0, ALTURA_TITULO + 2.0, size.x, size.y - ALTURA_TITULO - 2.0 - (ALTURA_VALORES if not _marcas.is_empty() else 0.0))
	if area.size.y <= 4.0:
		return
	draw_line(Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), COR_EIXO, 1.0)
	if _sem_limite or _item == null:
		draw_line(Vector2(area.position.x, area.position.y), Vector2(area.end.x, area.position.y), COR_CURVA, 2.0)
		return
	var pts := PackedVector2Array()
	for k in AMOSTRAS + 1:
		var f: float = float(k) / AMOSTRAS
		var x: float = lerpf(_x0, _x1, f)
		var v: float = clampf(_valor(x), 0.0, 1.0)
		pts.append(Vector2(area.position.x + f * area.size.x, area.end.y - v * area.size.y))
	var poligono := pts.duplicate()
	poligono.append(Vector2(area.end.x, area.end.y))
	poligono.append(Vector2(area.position.x, area.end.y))
	draw_colored_polygon(poligono, COR_AREA)
	draw_polyline(pts, COR_CURVA, 2.0, true)
	# valores marcados embaixo: m (cozimento) ou os limites (temperatura e tempo)
	for mk in _marcas:
		var fx: float = (mk["x"] - _x0) / maxf(_x1 - _x0, 0.0001)
		var px: float = area.position.x + fx * area.size.x
		draw_line(Vector2(px, area.end.y), Vector2(px, area.end.y + 3.0), COR_TEXTO, 1.0)
		var largura := fonte.get_string_size(mk["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_VALOR).x
		draw_string(fonte, Vector2(clampf(px - largura * 0.5, 0.0, size.x - largura), size.y - 1.0), mk["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_VALOR, COR_TEXTO)
