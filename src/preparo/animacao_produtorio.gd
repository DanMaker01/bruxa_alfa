# animacao_produtorio.gd
# Animação do produtório no fim do preparo (antes da poção aparecer na JanelaResultado):
#   1. os ingredientes saem do caldeirão e se alinham na ordem da fórmula A = B_n · … · B_1
#      numa coluna (o 1º ingrediente fica embaixo);
#   2. cada um mostra a matriz A_i (grade colorida) e o anel de aproveitamento enche até a_i,
#      enquanto a grade desbota em direção à identidade: vira B_i = a_i·A_i + (1 − a_i)·I;
#   3. os B_i se multiplicam em ordem (o próximo vem até o produto acumulado, que fica parado) até sobrar a
#      matriz final, que vai para o lugar da grade na janela e fica lá.
# Cada unidade é um cartão (sem agrupar). A matriz final fica na janela até confirmar;
# aí a JanelaResultado transforma ela na poção.
# Teste: K troca o que o toque faz (acelera/pula), no preparo.
# Depois da 1ª combinação o cartão do acumulado vira um ícone de poção; o anel mostra a
# média do aproveitamento dos ingredientes que já entraram.
class_name AnimacaoProdutorio
extends Control

enum Toque { ACELERA, PULA }
const NOMES_TOQUE := ["toque acelera", "toque pula"]
static var toque: int = Toque.ACELERA

const ACELERAR: float = 4.0
const ICONE_POCAO := "res://assets/game_caldeirao/pocao.png"
const COR_OP := Color(1.0, 0.9, 0.6)
const T_CHEGAR: float = 0.55
const T_APROVEITAR: float = 0.8
const T_MULTIPLICAR: float = 0.7
const T_FINAL: float = 0.7
## Duração da troca de valores do acumulado quando o próximo chega (curta de propósito).
const T_TROCA: float = 0.12

var _vel: float = 1.0
var _pular: bool = false
var _rodando: bool = false
var _tweens: Array = []
var _cartas: Array = []     # [CartaProd]
var _ops: Array = []        # [Label] entre as cartas
var _tam0 := Vector2.ONE    # tamanho dos cartões quando todos estão na tela


# -----------------------------------------------------------------------------
# Cartão de um ingrediente (ou grupo): ícone, anel de aproveitamento, % e a grade
# -----------------------------------------------------------------------------
class CartaProd extends Control:
	var icone: TextureRect
	var rotulo: Label
	var grade: GradeMatriz
	var a: float = 0.0          # anel mostrado (0..1)
	var a_alvo: float = 1.0
	var qtd: int = 1
	var horizontal: bool = false
	var M: Array = []           # matriz mostrada agora

	func montar(tex: Texture2D, tam: Vector2, horiz: bool) -> void:
		horizontal = horiz
		size = tam
		pivot_offset = tam * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		icone = TextureRect.new()
		icone.texture = tex
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icone)
		rotulo = Label.new()
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.add_theme_font_size_override("font_size", 14)
		rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
		rotulo.add_theme_constant_override("outline_size", 4)
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rotulo)
		grade = GradeMatriz.new()
		grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(grade)
		var lado_ic: float
		if horiz:
			lado_ic = minf(tam.y * 0.62, 70.0)
			icone.position = Vector2(8, (tam.y - lado_ic) * 0.5 - 8)
			icone.size = Vector2(lado_ic, lado_ic)
			rotulo.position = Vector2(0, icone.position.y + lado_ic + 2)
			rotulo.size = Vector2(lado_ic + 16, 20)
			var lado_g: float = tam.y
			grade.position = Vector2(lado_ic + 30, 0)
			grade.size = Vector2(lado_g, lado_g)
		else:
			lado_ic = minf(tam.x * 0.62, 70.0)
			icone.position = Vector2((tam.x - lado_ic) * 0.5, 10)
			icone.size = Vector2(lado_ic, lado_ic)
			rotulo.position = Vector2(0, icone.position.y + lado_ic + 6)
			rotulo.size = Vector2(tam.x, 20)
			grade.position = Vector2(0, rotulo.position.y + 24)
			grade.size = Vector2(tam.x, tam.x)

	func set_a(v: float) -> void:
		a = v
		var pct: String = "%d%%" % int(round(a * 100.0))
		rotulo.text = (("x%d · " % qtd) if qtd > 1 else "") + pct
		rotulo.add_theme_color_override("font_color", IconesCaldeirao.cor_aproveitamento(a))
		queue_redraw()

	func set_m(m: Array) -> void:
		M = m
		grade.mostrar(m)

	var anel_alfa: float = 1.0:
		set(v):
			anel_alfa = v
			queue_redraw()

	## Primeira combinação: o ícone do ingrediente vira o da poção (com um "pop").
	func virar_pocao(tex: Texture2D) -> void:
		if tex:
			icone.texture = tex
		qtd = 1
		icone.pivot_offset = icone.size * 0.5
		icone.scale = Vector2(0.4, 0.4)
		icone.create_tween().tween_property(icone, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		if not icone.visible or anel_alfa <= 0.0:
			return
		var c := icone.position + icone.size * 0.5
		var r: float = icone.size.x * 0.5 + 6.0
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.15 * anel_alfa), 5.0, true)
		if a > 0.001:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * a, 48, Color(IconesCaldeirao.cor_aproveitamento(a), anel_alfa), 5.0, true)


# -----------------------------------------------------------------------------
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 960)


func rodando() -> bool:
	return _rodando


## Toque na tela durante a animação.
func tocou() -> void:
	if not _rodando:
		return
	if toque == Toque.PULA:
		_pular = true
		for tw in _tweens:
			if is_instance_valid(tw) and tw.is_running():
				tw.custom_step(1000.0)
	else:
		_vel = ACELERAR
		for tw in _tweens:
			if is_instance_valid(tw) and tw.is_running():
				tw.set_speed_scale(_vel)


## Roda a animação. diagnosticos: os do CalculadoraPocao (com "item" e "a").
## origem: de onde os ingredientes saem (caldeirão); destino: onde a poção vai surgir.
## saidas: (opcional) [{"item", "pos"}] com a posição na TELA de cada ingrediente no caldeirão;
## cada cartão sai do seu ícone. Sem par para o cartão, ele sai da origem.
func tocar(diagnosticos: Array, origem: Vector2, destino: Vector2, lado_final: float, saidas: Array = []) -> void:
	limpar()
	var grupos := _agrupar(diagnosticos)
	if grupos.is_empty():
		return
	_rodando = true
	_pular = false
	_vel = 1.0
	visible = true
	var n: int = grupos.size()
	var slots := _slots(n)
	_tam0 = slots["tam"]
	var horiz: bool = true   # cartão deitado: ícone à esquerda, grade à direita
	var de_onde := _origens(grupos, origem, saidas)
	# 1. saem do caldeirão e se alinham
	var tw := _tw().set_parallel(true)
	for i in n:
		var g: Dictionary = grupos[i]
		var c := CartaProd.new()
		c.montar(g["item"].icone if g["item"] else null, slots["tam"], horiz)
		c.qtd = g["qtd"]
		add_child(c)
		c.position = de_onde[i] - slots["tam"] * 0.5
		c.scale = Vector2(0.3, 0.3)
		c.modulate.a = 0.0
		c.set_m(g["A"])
		c.set_a(0.0)
		_cartas.append(c)
		var alvo: Vector2 = slots["pos"][i]
		tw.tween_property(c, "position", alvo, T_CHEGAR).set_delay(i * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, T_CHEGAR).set_delay(i * 0.1)
		tw.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(i * 0.1)
	await _rodar(tw)
	await _pausa(0.25)

	# 2. aproveitamento: anel enche até a_i e A_i desbota até B_i (na ordem de ação)
	for i in n:
		var g: Dictionary = grupos[i]
		var c: CartaProd = _cartas[i]
		var A: Array = g["A"]
		var B: Array = g["B"]
		tw = _tw()
		tw.tween_method(_passo_aproveitar.bind(c, float(g["a"]), A, B), 0.0, 1.0, T_APROVEITAR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _rodar(tw)

	# 3. multiplica: o produto acumulado entra no próximo
	for i in n - 1:
		_ops.append(_op("×", slots, i))
	if not _ops.is_empty():   # 1 ingrediente só: sem "×" (tween vazio nunca termina e travava aqui)
		tw = _tw().set_parallel(true)
		for o in _ops:
			tw.tween_property(o, "modulate:a", 1.0, 0.3)
		await _rodar(tw)
		await _pausa(0.2)
	# o produto acumulado fica parado (à direita / embaixo) e o próximo vem até ele;
	# a grade do acumulado só muda de P para o novo valor, suave (sem voltar a zero)
	var acc: CartaProd = _cartas[0]
	var P: Array = grupos[0]["B"]
	# o anel do acumulado = média do aproveitamento dos que já entraram
	var soma_a: float = float(grupos[0]["a"])
	var tex_pocao: Texture2D = load(ICONE_POCAO) if ResourceLoader.exists(ICONE_POCAO) else null
	for i in range(1, n):
		var atual: CartaProd = _cartas[i]
		var novo: Array = CalculadoraPocao.multiplicar(grupos[i]["B"], P)
		tw = _tw().set_parallel(true)
		tw.tween_property(atual, "position", acc.position, T_MULTIPLICAR * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(atual, "modulate:a", 0.0, T_MULTIPLICAR * 0.6).set_delay(T_MULTIPLICAR * 0.2)
		tw.tween_property(_ops[i - 1], "modulate:a", 0.0, T_MULTIPLICAR * 0.4)
		# o da esquerda chega e já altera o acumulado (troca rápida, sem animar do zero)
		tw.tween_method(_passo_matriz.bind(acc, P, novo), 0.0, 1.0, T_TROCA).set_delay(T_MULTIPLICAR * 0.55)
		var media_antes: float = soma_a / i
		soma_a += float(grupos[i]["a"])
		var media: float = soma_a / (i + 1)
		tw.tween_method(acc.set_a, media_antes, media, T_TROCA * 2.0).set_delay(T_MULTIPLICAR * 0.55)
		if i == 1:
			tw.tween_callback(acc.virar_pocao.bind(tex_pocao)).set_delay(T_MULTIPLICAR * 0.5)
		# (sem pulso: a matriz acumulada fica parada, só os valores mudam)
		await _rodar(tw)
		P = novo
		await _reorganizar(i)
	# 4. a matriz final vai para o lugar dela na janela (do tamanho lado_final) e fica;
	#    o ícone e o anel somem no caminho (a poção só aparece quando confirmar)
	var fim: CartaProd = acc
	var centro_grade: Vector2 = fim.grade.position + fim.grade.size * 0.5
	var s_atual: float = fim.scale.x
	fim.position += (fim.pivot_offset - centro_grade) * (1.0 - s_atual)   # troca o pivô sem pular
	fim.pivot_offset = centro_grade
	var esc: float = lado_final / maxf(fim.grade.size.x, 1.0)
	tw = _tw().set_parallel(true)
	tw.tween_property(fim, "position", destino - centro_grade, T_FINAL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(fim, "scale", Vector2(esc, esc), T_FINAL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(fim.icone, "modulate:a", 0.0, T_FINAL * 0.5)
	tw.tween_property(fim.rotulo, "modulate:a", 0.0, T_FINAL * 0.5)
	tw.tween_property(fim, "anel_alfa", 0.0, T_FINAL * 0.5)
	await _rodar(tw)
	_rodando = false


# -----------------------------------------------------------------------------
## Grupos de ingredientes iguais em sequência: {item, qtd, a (média), A (do item), B (produto do grupo)}.
## Posição (local) de onde cada cartão sai: o ícone do mesmo item no caldeirão, na ordem;
## sem par, a origem.
func _origens(grupos: Array, origem: Vector2, saidas: Array) -> Array:
	var para_local := get_global_transform_with_canvas().affine_inverse()
	var livres := saidas.duplicate()
	var r := []
	for g in grupos:
		var pos := origem
		for k in livres.size():
			if livres[k]["item"] == g["item"]:
				pos = para_local * (livres[k]["pos"] as Vector2)
				livres.remove_at(k)
				break
		r.append(pos)
	return r

func _agrupar(diags: Array) -> Array:
	var out: Array = []
	for d in diags:
		var item: ItemData = d.get("item")
		var a: float = float(d.get("a", 1.0))
		var A: Array = CalculadoraPocao.matriz_do_item(item)
		var B: Array = CalculadoraPocao.interpolar(A, a)
		out.append({"item": item, "qtd": 1, "a": a, "A": A, "B": B})
	return out


## Posição e tamanho dos cartões. Índice 0 = 1º ingrediente (embaixo).
func _slots(n: int) -> Dictionary:
	var pos: Array = []
	var tam: Vector2
	var gap: float = 14.0
	# cabe entre y = 60 e y = 900, centralizado na tela
	var h: float = clampf((840.0 - gap * (n - 1)) / n, 36.0, 120.0)
	tam = Vector2(minf(h * 0.62, 70.0) + 30.0 + h, h)
	var total: float = h * n + gap * (n - 1)
	var y0: float = 480.0 - total * 0.5
	var x: float = (640.0 - tam.x) * 0.5
	for i in n:
		var slot: int = n - 1 - i
		pos.append(Vector2(x, y0 + slot * (h + gap)))
	return {"pos": pos, "tam": tam}


## Depois de cada combinação: os cartões que sobraram se juntam (sem buraco),
## centralizados, e crescem para ocupar o espaço livre.
func _reorganizar(feito: int) -> void:
	var rest: Array = [_cartas[0]]
	for k in range(feito + 1, _cartas.size()):
		rest.append(_cartas[k])
	var m: int = rest.size()
	if m <= 1:
		return
	var sl := _slots(m)
	var s: float = sl["tam"].y / _tam0.y
	var vis: Vector2 = _tam0 * s       # tamanho visível de cada cartão
	var tops: Array = []
	for k in m:
		var p: Vector2 = sl["pos"][k]
		p.x = (640.0 - vis.x) * 0.5
		tops.append(p)
	var tw := _tw().set_parallel(true)
	for k in m:
		var c: CartaProd = rest[k]
		tw.tween_property(c, "position", tops[k] - c.pivot_offset * (1.0 - s), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2(s, s), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var cg: Vector2 = _centro_grade(_tam0) * s
	for k in m - 1:
		var o: Label = _ops[feito + k]
		var meio: Vector2 = (tops[k] + tops[k + 1]) * 0.5 + cg
		tw.tween_property(o, "position", meio - o.size * 0.5, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _rodar(tw)


func _op(txt: String, slots: Dictionary, i: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", COR_OP)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	l.size = Vector2(30, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var a: Vector2 = slots["pos"][i]
	var b: Vector2 = slots["pos"][i + 1]
	var t: Vector2 = slots["tam"]
	var c_g := _centro_grade(t)
	l.position = (a + b) * 0.5 + c_g - l.size * 0.5
	add_child(l)
	return l


func _centro_grade(t: Vector2) -> Vector2:
	return Vector2(t.x * 0.5, t.y * 0.5)


func _passo_aproveitar(t: float, c: CartaProd, a: float, A: Array, B: Array) -> void:
	c.set_a(a * t)
	c.set_m(_lerp_m(A, B, t))


func _passo_matriz(t: float, c: CartaProd, de: Array, para: Array) -> void:
	c.set_m(_lerp_m(de, para, t))


static func _lerp_m(A: Array, B: Array, t: float) -> Array:
	var out: Array = []
	for i in A.size():
		var linha: Array = []
		for j in A[i].size():
			linha.append(lerpf(float(A[i][j]), float(B[i][j]), t))
		out.append(linha)
	return out


func _tw() -> Tween:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_speed_scale(_vel)
	_tweens.append(tw)
	return tw


## Espera o tween (ou termina na hora, se o toque mandou pular).
func _rodar(tw: Tween) -> void:
	if _pular:
		tw.custom_step(1000.0)
		return
	await tw.finished


func _pausa(s: float) -> void:
	var tw := _tw()
	tw.tween_interval(s)
	await _rodar(tw)


func limpar() -> void:
	for tw in _tweens:
		if is_instance_valid(tw):
			tw.kill()
	_tweens.clear()
	for c in _cartas + _ops:
		if is_instance_valid(c):
			c.queue_free()
	_cartas.clear()
	_ops.clear()
