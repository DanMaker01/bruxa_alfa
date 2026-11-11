# regua_chama.gd
# Régua dos estados da chama (os mesmos do livro): faixas coloridas pela temperatura
# do caldo, um marcador na T atual e o nome do estado atual.
# Três formatos (um por layout): HORIZONTAL (faixa embaixo do caldeirão), VERTICAL
# (termômetro ao lado) e ARCO (em volta da boca do caldeirão).
class_name ReguaChama
extends Control

enum Formato { HORIZONTAL, VERTICAL, ARCO }

const T_INI: float = 40.0     # começo da escala (°C)
const T_FIM: float = 220.0    # fim da escala (°C)
const COR_TEXTO := Color(0.95, 0.92, 0.85)
const COR_SUAVE := Color(0.75, 0.72, 0.68)
const CURTO := {"apagado": "apag.", "transparente": "transp.", "transparente_grande": "transp.+",
	"normal": "normal", "laranja": "laranja", "amarelo": "amarelo", "branco": "branco",
	"purpura": "púrpura", "negro": "negro"}

var formato: Formato = Formato.HORIZONTAL
var cena = null
## ARCO: centro (local) e raio.
var centro_arco := Vector2(320, 430)
var raio_arco: float = 190.0
var _fonte: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = get_theme_default_font()

func _process(_d: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _T() -> float:
	var s = cena.get("sistema") if cena else null
	return float(s.T) if s else 20.0

func _fogo() -> bool:
	var s = cena.get("sistema") if cena else null
	return bool(s.fogo_ligado) if s else false

## 0..1 na escala
func _f(T: float) -> float:
	return clampf((T - T_INI) / (T_FIM - T_INI), 0.0, 1.0)


func _draw() -> void:
	var T := _T()
	var atual := EstadosChama.de_T(T, _fogo())
	match formato:
		Formato.HORIZONTAL: _horizontal(T, atual)
		Formato.VERTICAL: _vertical(T, atual)
		Formato.ARCO: _arco(T, atual)


func _horizontal(T: float, atual: String) -> void:
	var x0 := 16.0
	var w := size.x - 32.0
	var y := 26.0
	_texto_centro(Vector2(size.x * 0.5, 16), "Chama " + EstadosChama.nome(atual).to_lower(), 15, EstadosChama.cor(atual).lightened(0.3))
	for e in EstadosChama.LISTA:
		var a := x0 + w * _f(maxf(e["T_min"], T_INI))
		var b := x0 + w * _f(minf(e["T_max"], T_FIM))
		if b <= a:
			continue
		draw_rect(Rect2(a, y, b - a, 10), e["cor"] if e["id"] == atual else Color(e["cor"], 0.45))
		_texto_centro(Vector2((a + b) * 0.5, y + 24), CURTO.get(e["id"], ""), 10, COR_TEXTO if e["id"] == atual else COR_SUAVE)
	var xm := x0 + w * _f(T)
	draw_colored_polygon(PackedVector2Array([Vector2(xm, y - 1), Vector2(xm - 6, y - 9), Vector2(xm + 6, y - 9)]), COR_TEXTO)
	draw_line(Vector2(xm, y - 1), Vector2(xm, y + 11), COR_TEXTO, 2.0)


func _vertical(T: float, atual: String) -> void:
	var xb := size.x - 22.0
	var y0 := 30.0
	var h := size.y - 40.0
	_texto_dir(Vector2(size.x - 4, 16), EstadosChama.nome(atual), 13, EstadosChama.cor(atual).lightened(0.3))
	for e in EstadosChama.LISTA:
		var a := y0 + h * (1.0 - _f(minf(e["T_max"], T_FIM)))
		var b := y0 + h * (1.0 - _f(maxf(e["T_min"], T_INI)))
		if b <= a:
			continue
		draw_rect(Rect2(xb, a, 14, b - a), e["cor"] if e["id"] == atual else Color(e["cor"], 0.45))
		_texto_dir(Vector2(xb - 6, (a + b) * 0.5 + 4), CURTO.get(e["id"], ""), 10, COR_TEXTO if e["id"] == atual else COR_SUAVE)
	var ym := y0 + h * (1.0 - _f(T))
	draw_colored_polygon(PackedVector2Array([Vector2(xb + 15, ym), Vector2(xb + 22, ym - 6), Vector2(xb + 22, ym + 6)]), COR_TEXTO)
	draw_line(Vector2(xb - 1, ym), Vector2(xb + 15, ym), COR_TEXTO, 2.0)


func _arco(T: float, atual: String) -> void:
	# de 200° (esquerda) a 340° (direita), por cima do centro
	for e in EstadosChama.LISTA:
		var fa := _f(maxf(e["T_min"], T_INI))
		var fb := _f(minf(e["T_max"], T_FIM))
		if fb <= fa:
			continue
		draw_arc(centro_arco, raio_arco, _ang(fa), _ang(fb), 16, e["cor"] if e["id"] == atual else Color(e["cor"], 0.45), 10.0, true)
	var am: float = _ang(_f(T))
	var pm := centro_arco + Vector2(cos(am), sin(am)) * raio_arco
	draw_circle(pm, 8.0, COR_TEXTO)
	draw_circle(pm, 5.0, EstadosChama.cor(atual))
	_texto_centro(centro_arco + Vector2(0, -raio_arco - 18), "Chama " + EstadosChama.nome(atual).to_lower(), 15, EstadosChama.cor(atual).lightened(0.3))


func _ang(f: float) -> float:
	return deg_to_rad(200.0 + 140.0 * f)

func _texto_centro(p: Vector2, s: String, tam: int, cor: Color) -> void:
	var w := _fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_sombra(Vector2(p.x - w * 0.5, p.y), s, tam, cor)

func _texto_dir(p: Vector2, s: String, tam: int, cor: Color) -> void:
	var w := _fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_sombra(Vector2(p.x - w, p.y), s, tam, cor)

func _sombra(p: Vector2, s: String, tam: int, cor: Color) -> void:
	draw_string(_fonte, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.7))
	draw_string(_fonte, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
