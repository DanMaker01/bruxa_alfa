# Balão de emoção acima da bruxa ou de um evento: "!", "?", "...", coração, raiva, nota, "!?".
# Some sozinho depois de "duracao" segundos.
class_name CmdBalao
extends Comando

enum Alvo { BRUXA, EVENTO }
enum Emocao { EXCLAMACAO, INTERROGACAO, RETICENCIAS, CORACAO, RAIVA, NOTA, SURPRESA }
const SIMBOLOS := ["!", "?", "...", "♥", "#", "♪", "!?"]
const NOMES := ["!", "?", "...", "coracao", "raiva", "nota", "surpresa"]
const CORES := [Color(0.85, 0.1, 0.1), Color(0.15, 0.3, 0.8), Color(0.2, 0.2, 0.2),
	Color(0.9, 0.2, 0.45), Color(0.85, 0.25, 0.1), Color(0.3, 0.5, 0.2), Color(0.25, 0.55, 0.9)]

@export var alvo: Alvo = Alvo.BRUXA:
	set(v):
		alvo = v
		notify_property_list_changed()
## id do evento (alvo = EVENTO).
@export var evento: String = ""
@export var emocao: Emocao = Emocao.EXCLAMACAO
@export var duracao: float = 1.2
## Altura do balão acima dos pés do alvo (px).
@export var altura: float = 150.0
## Ligado: o evento espera o balão sumir.
@export var esperar: bool = true

func to_dict() -> Dictionary:
	return {"nome": "balao", "args": ["bruxa" if alvo == Alvo.BRUXA else evento, NOMES[emocao], duracao]}

func executar(interp, ev) -> int:
	var no = interp.game_manager.get_player() if alvo == Alvo.BRUXA and interp.game_manager else interp.encontrar_evento(evento)
	if not (no is Node2D):
		interp.falhar(ev, self, "alvo não encontrado")
		return AVANCAR
	var tw := mostrar(no, emocao, duracao, altura)
	if not esperar:
		return AVANCAR
	ev.pause("balao")
	tw.finished.connect(func():
		if not ev.finished and ev.pause_reason == "balao":
			ev.resume_and_advance())
	return MANTER

## Mostra um balão em "no" (também usado pela rota dos eventos). Devolve o tween.
static func mostrar(no: Node2D, emocao_: int, duracao_: float = 1.2, altura_: float = 150.0) -> Tween:
	var balao := _criar_balao(emocao_)
	no.add_child(balao)
	balao.position = Vector2(0, -altura_)
	# entra com um "pop", flutua um pouquinho para cima e some
	var tw := balao.create_tween()
	tw.tween_property(balao, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(balao, "position:y", -altura_ - 6.0, maxf(duracao_ - 0.45, 0.1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(balao, "modulate:a", 0.0, 0.22)
	tw.tween_callback(balao.queue_free)
	# o símbolo dá um pulinho logo depois de aparecer
	var simb: Node2D = balao.get_node_or_null("Simbolo")
	if simb:
		var tw2 := simb.create_tween()
		tw2.tween_interval(0.15)
		tw2.tween_property(simb, "scale", Vector2(1.25, 1.25), 0.1)
		tw2.tween_property(simb, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

static func _criar_balao(emocao_: int) -> Node2D:
	var raiz := Node2D.new()
	raiz.z_index = 30
	raiz.scale = Vector2(0.2, 0.2)
	var texto: String = SIMBOLOS[emocao_]
	var fundo := Desenho.new()
	fundo.largura = maxf(58.0, 20.0 * texto.length() + 30.0)
	raiz.add_child(fundo)
	# símbolo num Node2D próprio, centrado no corpo do balão (para poder pular sozinho)
	var simb := Node2D.new()
	simb.name = "Simbolo"
	simb.position = Vector2(0, -Desenho.ALTURA * 0.5 - Desenho.RABO)
	raiz.add_child(simb)
	var rot := Label.new()
	rot.text = texto
	rot.add_theme_font_size_override("font_size", 32)
	rot.add_theme_color_override("font_color", CORES[emocao_])
	rot.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	rot.add_theme_constant_override("outline_size", 4)
	rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rot.size = Vector2(fundo.largura, Desenho.ALTURA)
	rot.position = -rot.size * 0.5
	simb.add_child(rot)
	return raiz

## Corpo do balão: sombra, contorno escuro, miolo creme e rabicho, com a ponta em (0, 0).
class Desenho extends Node2D:
	const ALTURA := 50.0
	const RABO := 12.0
	const RAIO := 20.0
	const BORDA := 3.0
	const COR_BORDA := Color(0.17, 0.12, 0.25)
	const COR_MIOLO := Color(1.0, 0.98, 0.94)
	const COR_SOMBRA := Color(0, 0, 0, 0.22)
	var largura := 58.0

	func _draw() -> void:
		var ret := Rect2(-largura * 0.5, -ALTURA - RABO, largura, ALTURA)
		_corpo(ret.grow(BORDA), Vector2(3, 4), COR_SOMBRA, BORDA)
		_corpo(ret.grow(BORDA), Vector2.ZERO, COR_BORDA, BORDA)
		_corpo(ret, Vector2.ZERO, COR_MIOLO, 0.0)
		# brilho no canto de cima
		draw_line(ret.position + Vector2(RAIO * 0.6, 7), ret.position + Vector2(RAIO * 1.4, 5), Color(1, 1, 1, 0.9), 3.0, true)

	func _corpo(r: Rect2, desloc: Vector2, c: Color, extra: float) -> void:
		draw_colored_polygon(_retangulo_redondo(r, RAIO + extra, desloc), c)
		var base := r.end.y + desloc.y - 1.0
		var meio := desloc.x
		var rabo := PackedVector2Array([Vector2(meio - 9 - extra, base), Vector2(meio + 9 + extra, base),
			Vector2(meio + 2, base + RABO + extra * 1.5)])
		draw_colored_polygon(rabo, c)

	static func _retangulo_redondo(r: Rect2, raio: float, desloc: Vector2) -> PackedVector2Array:
		raio = minf(raio, minf(r.size.x, r.size.y) * 0.5)
		var pts := PackedVector2Array()
		var cantos := [Vector2(r.end.x - raio, r.position.y + raio), Vector2(r.end.x - raio, r.end.y - raio),
			Vector2(r.position.x + raio, r.end.y - raio), Vector2(r.position.x + raio, r.position.y + raio)]
		var ang0 := [-PI * 0.5, 0.0, PI * 0.5, PI]
		for k in 4:
			for i in 7:
				var a: float = ang0[k] + PI * 0.5 * i / 6.0
				pts.append(cantos[k] + Vector2(cos(a), sin(a)) * raio + desloc)
		return pts

func _validate_property(property: Dictionary) -> void:
	if property.name == "evento" and alvo != Alvo.EVENTO:
		property.usage = PROPERTY_USAGE_STORAGE
