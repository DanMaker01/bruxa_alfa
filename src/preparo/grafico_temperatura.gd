# =============================================================================
# grafico_temperatura.gd - Gráfico T(t) e F(t) ao vivo + feedback do preparo
# =============================================================================
# - T(t) no eixo da esquerda (escala própria, para o caldeirão não ficar "achatado")
# - F(t) no eixo da direita (linha fina)
# - Área sob T(t) fatiada: uma faixa horizontal por ingrediente no caldeirão,
#   pintada com a cor do estado dele naquele instante (cru → no ponto → passou/punido)
# - Faixas com o nome de cada ingrediente embaixo do gráfico (mesmas cores)
# - Linhas de limite (máx/mín) e marcadores (entrou ingrediente, punição, no ponto)
extends Control

# =============================================================================
# CONFIGURAÇÃO
# =============================================================================
var y_max_T: float = 250.0     # topo do eixo T (cresce sozinho se T passar)
var y_max_F: float = 1200.0    # topo do eixo F
var t_janela: float = 30.0     # Segundos visíveis

# =============================================================================
# DADOS
# =============================================================================
var pontos_T: Array = []       # Vector2(t, T)
var pontos_F: Array = []       # Vector2(t, F)
var pontos_punindo: Array = [] # bool: alguma punição acontecendo naquele instante
var pontos_fatias: Array = []  # Dictionary idx_ingrediente -> Color, por ponto
var t_atual: float = 0.0
## Nome de cada ingrediente (índice = ordem de entrada no caldeirão)
var nomes_ingredientes: Array = []
## Marcadores no tempo: [{"t", "cor", "texto"}]
var marcadores: Array = []
## Limites dos ingredientes: [{"T": float, "tipo": "max"|"min", "ativo": bool}]
var limites: Array = []

# =============================================================================
# CORES
# =============================================================================
const COR_FUNDO = Color(0.05, 0.05, 0.1, 0.95)
const COR_GRID = Color(0.2, 0.2, 0.3, 0.6)
const COR_EIXO = Color(0.7, 0.7, 0.8)
const COR_T = Color(1.0, 0.9, 0.85)
const COR_F = Color(0.4, 0.7, 1.0, 0.7)
const COR_T_EQ = Color(0.8, 0.4, 0.4, 0.5)
const COR_TEXTO = Color(0.85, 0.85, 0.9)
const COR_LIM_MAX = Color(1.0, 0.55, 0.15, 0.85)
const COR_LIM_MIN = Color(0.45, 0.75, 1.0, 0.85)
const COR_T_PUNINDO = Color(1.0, 0.15, 0.1)

# =============================================================================
# MARGENS
# =============================================================================
const MARGEM_ESQ: float = 34.0
const MARGEM_DIR: float = 34.0
const MARGEM_TOPO: float = 16.0
const MARGEM_BASE: float = 18.0
const ALTURA_FAIXA: float = 8.0
const MAX_FAIXAS: int = 6
const PX_POR_COLUNA: float = 2.0   # resolução das fatias (em px)

# =============================================================================
# API
# =============================================================================
## fatias: Dictionary idx_ingrediente -> Color (cor de cada ingrediente neste instante)
func adicionar_ponto(t: float, temp_T: float, temp_F: float, punindo: bool = false, fatias: Dictionary = {}) -> void:
	t_atual = t
	pontos_T.append(Vector2(t, temp_T))
	pontos_F.append(Vector2(t, temp_F))
	pontos_punindo.append(punindo)
	pontos_fatias.append(fatias)
	if temp_T * 1.1 > y_max_T:
		y_max_T = ceilf(temp_T * 1.2 / 50.0) * 50.0

	var t_min = t - t_janela
	while pontos_T.size() > 0 and pontos_T[0].x < t_min:
		pontos_T.pop_front()
		pontos_F.pop_front()
		pontos_punindo.pop_front()
		pontos_fatias.pop_front()
	while marcadores.size() > 0 and float(marcadores[0]["t"]) < t_min:
		marcadores.pop_front()
	queue_redraw()

func set_ingredientes(nomes: Array) -> void:
	nomes_ingredientes = nomes
	queue_redraw()

func set_limites(lista: Array) -> void:
	limites = lista
	queue_redraw()

func adicionar_marcador(t: float, cor: Color, texto: String = "") -> void:
	marcadores.append({"t": t, "cor": cor, "texto": texto})
	queue_redraw()

func reset() -> void:
	pontos_T.clear()
	pontos_F.clear()
	pontos_punindo.clear()
	pontos_fatias.clear()
	nomes_ingredientes = []
	marcadores.clear()
	limites = []
	t_atual = 0.0
	y_max_T = 250.0
	queue_redraw()

func configurar(cfg: Dictionary) -> void:
	y_max_T = cfg.get("y_max_T", y_max_T)
	y_max_F = cfg.get("y_max_F", cfg.get("y_max", y_max_F))
	t_janela = cfg.get("t_janela", 30.0)
	queue_redraw()

# =============================================================================
# DESENHO
# =============================================================================
func _draw() -> void:
	var w = size.x
	var h = size.y
	var fonte = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)

	var n_faixas: int = mini(nomes_ingredientes.size(), MAX_FAIXAS)
	var altura_faixas: float = n_faixas * ALTURA_FAIXA + (3.0 if n_faixas > 0 else 0.0)
	var px = MARGEM_ESQ
	var py = MARGEM_TOPO
	var pw = w - MARGEM_ESQ - MARGEM_DIR
	var ph = h - MARGEM_TOPO - MARGEM_BASE - altura_faixas
	if pw <= 0 or ph <= 0:
		return

	var t_max = max(t_atual, t_janela)
	var t_min = t_max - t_janela

	# ---------- GRID + EIXOS (T à esquerda, F à direita) ----------
	for i in range(6):
		var frac = float(i) / 5.0
		var y = py + ph * (1.0 - frac)
		draw_line(Vector2(px, y), Vector2(px + pw, y), COR_GRID, 1.0)
		draw_string(fonte, Vector2(2, y + 4), "%d" % int(y_max_T * frac), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COR_TEXTO)
		draw_string(fonte, Vector2(px + pw + 3, y + 4), "%d" % int(y_max_F * frac), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COR_F)
	for i in range(6):
		var frac = float(i) / 5.0
		var x = px + pw * frac
		draw_line(Vector2(x, py), Vector2(x, py + ph), COR_GRID, 1.0)
		draw_string(fonte, Vector2(x - 8, h - 4), "%.0f" % (t_min + t_janela * frac), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COR_TEXTO)
	draw_string(fonte, Vector2(2, py - 4), "T °C", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COR_TEXTO)
	draw_string(fonte, Vector2(px + pw + 3, py - 4), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COR_F)

	# ---------- ÁREA SOB T(t) FATIADA POR INGREDIENTE ----------
	_desenhar_fatias(px, py, pw, ph, t_min, t_max)

	# ---------- EQUILÍBRIO DO CALDEIRÃO ----------
	var y_Teq = _y_T(SistemaTermico.T_EQ, py, ph)
	draw_dashed_line(Vector2(px, y_Teq), Vector2(px + pw, y_Teq), COR_T_EQ, 1.0, 3.0)

	# ---------- LIMITES DOS INGREDIENTES ----------
	var piscar: bool = Time.get_ticks_msec() % 400 < 200
	for lim in limites:
		var y_lim = _y_T(float(lim["T"]), py, ph)
		var cor: Color = COR_LIM_MAX if lim["tipo"] == "max" else COR_LIM_MIN
		var largura: float = 1.5
		if lim.get("ativo", false):
			largura = 3.0
			if piscar:
				cor = COR_T_PUNINDO
		draw_dashed_line(Vector2(px, y_lim), Vector2(px + pw, y_lim), cor, largura, 6.0)
		draw_string(fonte, Vector2(px + 3, y_lim - 3),
			("máx " if lim["tipo"] == "max" else "mín ") + "%d" % int(lim["T"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, cor)

	# ---------- MARCADORES ----------
	for mk in marcadores:
		var xm = _x(float(mk["t"]), px, pw, t_min, t_max)
		if xm < px or xm > px + pw:
			continue
		var cor_mk: Color = mk["cor"]
		draw_line(Vector2(xm, py), Vector2(xm, py + ph), Color(cor_mk, 0.4), 1.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(xm - 4, py), Vector2(xm + 4, py), Vector2(xm, py + 6)]), cor_mk)
		if mk["texto"] != "":
			draw_string(fonte, Vector2(xm + 3, py + 9), mk["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, cor_mk)

	# ---------- EIXOS ----------
	draw_line(Vector2(px, py), Vector2(px, py + ph), COR_EIXO, 1.5)
	draw_line(Vector2(px + pw, py), Vector2(px + pw, py + ph), COR_F, 1.0)
	draw_line(Vector2(px, py + ph), Vector2(px + pw, py + ph), COR_EIXO, 1.5)

	# ---------- LINHAS F e T ----------
	_desenhar_linha(pontos_F, COR_F, 1.5, px, py, pw, ph, t_min, t_max, true)
	_desenhar_linha(pontos_T, COR_T, 2.0, px, py, pw, ph, t_min, t_max, false, pontos_punindo)
	if pontos_T.size() > 0:
		var p = pontos_T[-1]
		draw_circle(Vector2(_x(p.x, px, pw, t_min, t_max), _y_T(p.y, py, ph)), 3.5,
			COR_T_PUNINDO if (not pontos_punindo.is_empty() and pontos_punindo[-1]) else COR_T)

	# ---------- FAIXAS COM O NOME DE CADA INGREDIENTE ----------
	var y0 = py + ph + 3.0
	var primeiro: int = nomes_ingredientes.size() - n_faixas   # mostra os mais recentes
	for lane in n_faixas:
		var idx: int = primeiro + lane
		var yl: float = y0 + lane * ALTURA_FAIXA
		draw_string(fonte, Vector2(2, yl + ALTURA_FAIXA - 1), str(nomes_ingredientes[idx]).left(6),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COR_TEXTO)
		_desenhar_faixa(idx, yl, px, pw, t_min, t_max)

# Área sob T(t): em cada coluna, divide [0, T] em fatias iguais, uma por ingrediente
# presente naquele instante (o primeiro a entrar fica embaixo).
func _desenhar_fatias(px, py, pw, ph, t_min, t_max) -> void:
	var n = pontos_T.size()
	if n < 2:
		return
	var passo: int = maxi(1, int(ceil(n / (pw / PX_POR_COLUNA))))
	var y_base: float = py + ph
	var i := 0
	while i < n - 1:
		var j: int = mini(i + passo, n - 1)
		var fatias: Dictionary = pontos_fatias[j]
		if not fatias.is_empty():
			var xa = _x(pontos_T[i].x, px, pw, t_min, t_max)
			var xb = _x(pontos_T[j].x, px, pw, t_min, t_max)
			var ya = _y_T(pontos_T[i].y, py, ph)
			var yb = _y_T(pontos_T[j].y, py, ph)
			var chaves: Array = fatias.keys()
			chaves.sort()
			var k: int = chaves.size()
			for s in k:
				var f0: float = float(s) / k
				var f1: float = float(s + 1) / k
				var cor: Color = fatias[chaves[s]]
				draw_colored_polygon(PackedVector2Array([
					Vector2(xa, lerpf(y_base, ya, f0)), Vector2(xb, lerpf(y_base, yb, f0)),
					Vector2(xb, lerpf(y_base, yb, f1)), Vector2(xa, lerpf(y_base, ya, f1)),
				]), cor)
			# separadores finos entre fatias
			for s in range(1, k):
				var f: float = float(s) / k
				draw_line(Vector2(xa, lerpf(y_base, ya, f)), Vector2(xb, lerpf(y_base, yb, f)), Color(0, 0, 0, 0.35), 1.0)
		i = j

# Faixa de um ingrediente embaixo do gráfico: a mesma cor da fatia dele ao longo do tempo.
func _desenhar_faixa(idx: int, yl: float, px, pw, t_min, t_max) -> void:
	var n = pontos_T.size()
	if n < 2:
		return
	var passo: int = maxi(1, int(ceil(n / (pw / PX_POR_COLUNA))))
	var i := 0
	while i < n - 1:
		var j: int = mini(i + passo, n - 1)
		var fatias: Dictionary = pontos_fatias[j]
		if fatias.has(idx):
			var xa = _x(pontos_T[i].x, px, pw, t_min, t_max)
			var xb = _x(pontos_T[j].x, px, pw, t_min, t_max)
			var cor: Color = fatias[idx]
			draw_rect(Rect2(xa, yl, xb - xa + 0.5, ALTURA_FAIXA - 2.0), Color(cor, 1.0))
		i = j

# =============================================================================
# HELPERS
# =============================================================================
func _x(t: float, px: float, pw: float, t_min: float, t_max: float) -> float:
	if t_max - t_min == 0.0:
		return px
	return px + (t - t_min) / (t_max - t_min) * pw

func _y_T(temp: float, py: float, ph: float) -> float:
	return py + ph * (1.0 - clampf(temp / y_max_T, 0.0, 1.0))

func _y_F(temp: float, py: float, ph: float) -> float:
	return py + ph * (1.0 - clampf(temp / y_max_F, 0.0, 1.0))

func _desenhar_linha(pontos: Array, cor: Color, largura: float, px, py, pw, ph, t_min, t_max, eixo_F: bool, destaque: Array = []) -> void:
	if pontos.size() < 2:
		return
	var anterior := Vector2.ZERO
	for i in pontos.size():
		var p: Vector2 = pontos[i]
		var atual := Vector2(_x(p.x, px, pw, t_min, t_max), _y_F(p.y, py, ph) if eixo_F else _y_T(p.y, py, ph))
		if i > 0:
			var punindo: bool = i < destaque.size() and destaque[i]
			draw_line(anterior, atual, COR_T_PUNINDO if punindo else cor, largura + (1.5 if punindo else 0.0))
		anterior = atual
