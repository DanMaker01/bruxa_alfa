# menu_aplicar_pocao.gd
# Menu do "Aplicar poção" (CmdAplicarPocao): mostra a face e o nome do alvo e um pentagrama
# O-C-E-A-N com a personalidade dele (só a forma).
#   abrir(personagem, personalidade)  aparece com a personalidade atual
#   previa(p)                         tocar numa poção no inventário: como ficaria (tracejado)
#   aplicar(p_novo)                   destaque: a carta brilha, a face pulsa com faíscas e o
#                                     pentagrama muda devagar, com as pontas que mudaram
#                                     brilhando e setinhas ↑↓
#   fechar()
# Lugar: o pentagrama do alvo fica no lugar da carta Status da bruxa e a face com o nome numa
# carta logo acima dela (os outros jeitos e a tecla M saíram).
class_name MenuAplicarPocao
extends Control

## z (no CanvasLayer do main): na frente do HUD (z 20) e atrás do popup do item (z 50).
const Z_CARTA: int = 25
const T_ENTRAR: float = 0.3
const T_MUDAR: float = 1.4
## Depois do destaque: quanto o menu fica na tela antes de fechar (s).
const T_DEPOIS: float = 1.2
const COR_BRILHO := Color(1.0, 0.85, 0.45)

var _carta: Panel
var _carta_face: Panel   # carta da face e do nome, acima do Status
var _nome: Label
var _face: TextureRect
var _penta: PentagramaPersonalidade


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_carta = Panel.new()
	_carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carta.z_as_relative = false
	_carta.z_index = Z_CARTA
	_carta.add_theme_stylebox_override("panel", _estilo_carta())
	add_child(_carta)
	_carta_face = Panel.new()
	_carta_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carta_face.z_as_relative = false
	_carta_face.z_index = Z_CARTA
	_carta_face.add_theme_stylebox_override("panel", _estilo_carta())
	add_child(_carta_face)
	_nome = Label.new()
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.add_theme_font_size_override("font_size", Estilo.FONTE_NOME)
	_nome.add_theme_color_override("font_color", Estilo.DESTAQUE)
	_carta_face.add_child(_nome)
	_face = TextureRect.new()
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carta_face.add_child(_face)
	_penta = PentagramaPersonalidade.new()
	_carta.add_child(_penta)
	visible = false

## Mesmo sprite das cartas do HUD, em 9 fatias (cantos não deformam).
func _estilo_carta() -> StyleBox:
	var tex: Texture2D = load(Carta.SPRITE_CARTA) if ResourceLoader.exists(Carta.SPRITE_CARTA) else null
	if tex == null:
		return Estilo.caixa_menu()
	var st := StyleBoxTexture.new()
	st.texture = tex
	st.set_texture_margin_all(PainelMenu.MARGEM_CARTA)
	return st

func abrir(personagem: Personagem, nome_alvo: String, p: Array) -> void:
	if not is_node_ready():
		await ready
	_nome.text = personagem.nome if personagem and personagem.nome != "" else nome_alvo.capitalize()
	_face.texture = personagem.foto() if personagem else null
	_penta.definir(p)
	_penta.previa(null)
	_montar()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, T_ENTRAR)

## p = personalidade como ficaria (null = sem prévia).
func previa(p) -> void:
	_penta.previa(p)

func aplicar(p_novo: Array) -> void:
	_penta.previa(null)
	Vibrar.media()
	_clarao_carta()
	_pulsar_face()
	_faiscas(_face.get_global_rect().get_center(), 14)
	await get_tree().create_timer(0.35).timeout
	_faiscas(_penta.get_global_rect().get_center(), 10)
	await _penta.mudar_para(p_novo, T_MUDAR)
	await get_tree().create_timer(T_DEPOIS).timeout

## Clarão dourado na carta inteira.
func _clarao_carta() -> void:
	for cartinha in [_carta, _carta_face]:
		_clarao(cartinha)

func _clarao(cartinha: Control) -> void:
	var f := ColorRect.new()
	f.color = Color(COR_BRILHO, 0.0)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size = cartinha.size
	cartinha.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.45, 0.12)
	tw.tween_property(f, "color:a", 0.0, 0.6)
	tw.tween_callback(f.queue_free)

## A face brilha, cresce e treme um pouco (a poção fazendo efeito).
func _pulsar_face() -> void:
	_face.pivot_offset = _face.size * 0.5
	var x0 := _face.position.x
	var tw := _face.create_tween()
	tw.tween_property(_face, "modulate", Color(1.9, 1.7, 1.1), 0.15)
	tw.parallel().tween_property(_face, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in 6:
		tw.tween_property(_face, "position:x", x0 + (6.0 if k % 2 == 0 else -6.0), 0.05)
	tw.tween_property(_face, "position:x", x0, 0.05)
	tw.tween_property(_face, "modulate", Color.WHITE, 0.5)
	tw.parallel().tween_property(_face, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

## Faíscas douradas saindo de um ponto (tela).
func _faiscas(centro: Vector2, n: int) -> void:
	for k in n:
		var l := Label.new()
		l.text = "✦" if k % 2 == 0 else "✧"
		l.add_theme_font_size_override("font_size", randi_range(16, 28))
		l.add_theme_color_override("font_color", COR_BRILHO)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.z_as_relative = false
		l.z_index = Z_CARTA + 1
		add_child(l)
		l.position = centro - Vector2(10, 14)
		var ang := TAU * k / n + randf_range(-0.3, 0.3)
		var dist := randf_range(70.0, 140.0)
		var tw := l.create_tween().set_parallel(true)
		tw.tween_property(l, "position", l.position + Vector2.from_angle(ang) * dist, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
		tw.chain().tween_callback(l.queue_free)

func fechar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, T_ENTRAR)
	await tw.finished
	queue_free()


func _montar() -> void:
	var tela := get_viewport_rect().size
	# pentagrama no lugar da carta Status da bruxa; face e nome numa carta acima dela
	var r := _rect_status(tela)
	_carta.position = r.position
	_carta.size = r.size
	_penta.position = Vector2(8, 8)
	_penta.size = r.size - Vector2(16, 16)
	_carta_face.position = Vector2(r.position.x, r.position.y - ALTURA_CARTA_FACE - 8.0)
	_carta_face.size = Vector2(r.size.x, ALTURA_CARTA_FACE)
	_nome.position = Vector2(0, 14)
	_nome.size = Vector2(r.size.x, 30)
	_face.position = Vector2(14, 46)
	_face.size = Vector2(r.size.x - 28, ALTURA_CARTA_FACE - 60)

const ALTURA_CARTA_FACE: float = 260.0

## Retângulo da carta Status do HUD (ou o lugar dela no hud.tscn, se não achar).
func _rect_status(_tela: Vector2) -> Rect2:
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	var c = hud.get("carta_status") if hud else null
	if c is Control and c.size.x > 0.0:
		return c.get_global_rect()
	return Rect2(384, 640, 256, 320)

# -----------------------------------------------------------------------------
## Pentagrama O-C-E-A-N de uma personalidade (valores −10..10): só a forma.
## Prévia e mudança no valor real (mudanças pequenas aparecem pouco); o contorno cinza fica
## no lugar de antes e as setinhas mostram quem subiu e quem desceu.
class PentagramaPersonalidade extends Control:
	const TRACOS := ["O", "C", "E", "A", "N"]
	const COR_GRADE := Color(1, 1, 1, 0.14)
	const COR_FORMA := Color(1.0, 0.82, 0.3)
	const COR_ANTES := Color(0.8, 0.8, 0.8, 0.7)
	const COR_PREVIA := Color(1, 1, 1, 0.85)
	const COR_SOBE := Color(1.0, 0.82, 0.3)
	const COR_DESCE := Color(1.0, 0.35, 0.3)
	const R_MIN: float = 0.12   # traço em −10 ainda aparece um pouquinho
	const T_SETAS: float = 2.4
	var _p: Array = [0.0, 0.0, 0.0, 0.0, 0.0]      # personalidade real (antes de aplicar)
	var _rs: Array = [0.5, 0.5, 0.5, 0.5, 0.5]     # raio desenhado de cada ponta (0..1)
	var _rs_antes = null                           # contorno cinza (comparando)
	var _de: Array = []
	var _para: Array = []
	var _previa = null                             # raios da prévia (ou null)
	var _setas: Array = [0, 0, 0, 0, 0]            # −1 desce, 1 sobe
	var _t_setas: float = 0.0
	var _f: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_f = get_theme_default_font()

	func definir(p: Array) -> void:
		_p = _copia(p)
		_rs = _raios(_p)
		_rs_antes = null
		queue_redraw()

	## Prévia: como ficaria p (tracejado), já na escala da diferença.
	func previa(p) -> void:
		_previa = _raios(_copia(p)) if p is Array else null
		_rs_antes = null
		queue_redraw()

	func mudar_para(p: Array, tempo: float) -> void:
		var novo := _copia(p)
		_de = _rs.duplicate()
		_para = _raios(novo)
		_rs_antes = _de.duplicate()
		for i in 5:
			var d: float = float(novo[i]) - float(_p[i])
			_setas[i] = 0 if absf(d) < 0.005 else (1 if d > 0.0 else -1)
		_t_setas = T_SETAS + tempo
		var tw := create_tween()
		tw.tween_method(_animar, 0.0, 1.0, tempo).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished

	func _animar(v: float) -> void:
		for i in 5:
			_rs[i] = lerpf(float(_de[i]), float(_para[i]), v)
		queue_redraw()

	func _process(delta: float) -> void:
		if _t_setas > 0.0:
			_t_setas -= delta
			queue_redraw()

	static func _copia(p) -> Array:
		var out: Array = []
		for i in 5:
			out.append(float(p[i]) if p is Array and i < p.size() else 0.0)
		return out

	## Raio (0..1) de um valor −10..10.
	static func raio_de(v: float) -> float:
		# linear (sem raiz): as mudanças aparecem mais no raio
		return R_MIN + (1.0 - R_MIN) * clampf((v + 10.0) / 20.0, 0.0, 1.0)

	static func _raios(p: Array) -> Array:
		var out: Array = []
		for i in 5:
			out.append(raio_de(float(p[i])))
		return out

	func _centro() -> Vector2:
		return size * 0.5 + Vector2(0, 6)

	func _raio() -> float:
		return minf(size.x, size.y) * 0.5 - 26.0

	func _forma(rs: Array) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 5:
			pts.append(_centro() + Vector2.from_angle(-PI * 0.5 + TAU * i / 5.0) * _raio() * float(rs[i]))
		return pts

	func _draw() -> void:
		var c := _centro()
		var r := _raio()
		# grade: 3 pentágonos e os raios
		for k in [1.0, 0.66, 0.33]:
			var g := PackedVector2Array()
			for i in 6:
				g.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 5.0) * r * k)
			draw_polyline(g, COR_GRADE, 1.5, true)
		for i in 5:
			draw_line(c, c + Vector2.from_angle(-PI * 0.5 + TAU * i / 5.0) * r, COR_GRADE, 1.0, true)
		# forma atual
		var f := _forma(_rs)
		var brilho: float = clampf(_t_setas / T_SETAS, 0.0, 1.0)   # 1 logo depois de aplicar
		var pulso: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 10.0)
		draw_colored_polygon(f, Color(COR_FORMA, 0.35 + 0.25 * brilho))
		var borda := f.duplicate()
		borda.append(f[0])
		draw_polyline(borda, COR_FORMA.lerp(Color.WHITE, 0.6 * brilho * pulso), 3.0 + 3.0 * brilho, true)
		# como estava antes de aplicar (contorno cinza)
		if _rs_antes != null:
			var fa := _forma(_rs_antes)
			fa.append(fa[0])
			draw_polyline(fa, COR_ANTES, 2.0, true)
		# pontas que mudaram: brilho pulsando enquanto as setinhas aparecem
		if brilho > 0.0:
			for i in 5:
				if _setas[i] != 0:
					var cor_p: Color = COR_SOBE if _setas[i] > 0 else COR_DESCE
					draw_circle(f[i], 6.0 + 10.0 * pulso * brilho, Color(cor_p, 0.35 * brilho))
					draw_circle(f[i], 5.0, Color(cor_p, brilho))
		# prévia tracejada
		if _previa != null:
			var pv := _forma(_previa)
			for i in 5:
				draw_dashed_line(pv[i], pv[(i + 1) % 5], COR_PREVIA, 2.0, 7.0)
		# letras dos traços (as setinhas ↑↓ saíram; as pontas que mudaram ainda pulsam)
		for i in 5:
			var dir := Vector2.from_angle(-PI * 0.5 + TAU * i / 5.0)
			var q := c + dir * (r + 16.0)
			var txt: String = TRACOS[i]
			var w := _f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(_f, q + Vector2(-w * 0.5, 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Estilo.TEXTO_QUENTE)
