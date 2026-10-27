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
	var balao := _criar()
	no.add_child(balao)
	balao.position = Vector2(0, -altura)
	var tw := balao.create_tween()
	tw.tween_property(balao, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(duracao - 0.4, 0.1))
	tw.tween_property(balao, "modulate:a", 0.0, 0.22)
	tw.tween_callback(balao.queue_free)
	if not esperar:
		return AVANCAR
	ev.pause("balao")
	tw.finished.connect(func():
		if not ev.finished and ev.pause_reason == "balao":
			ev.resume_and_advance())
	return MANTER

func _criar() -> Node2D:
	var raiz := Node2D.new()
	raiz.z_index = 30
	raiz.scale = Vector2(0.2, 0.2)
	var painel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.95)
	st.border_color = Color(0.1, 0.1, 0.1)
	st.set_border_width_all(3)
	st.set_corner_radius_all(18)
	st.set_content_margin_all(8)
	st.content_margin_left = 14
	st.content_margin_right = 14
	painel.add_theme_stylebox_override("panel", st)
	var rot := Label.new()
	rot.text = SIMBOLOS[emocao]
	rot.add_theme_font_size_override("font_size", 34)
	rot.add_theme_color_override("font_color", CORES[emocao])
	rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	painel.add_child(rot)
	raiz.add_child(painel)
	# centraliza o balão acima do alvo depois que ele souber o próprio tamanho
	painel.resized.connect(func(): painel.position = Vector2(-painel.size.x * 0.5, -painel.size.y))
	# rabicho
	var rabo := Polygon2D.new()
	rabo.polygon = PackedVector2Array([Vector2(-8, -3), Vector2(8, -3), Vector2(0, 12)])
	rabo.color = Color(1, 1, 1, 0.95)
	raiz.add_child(rabo)
	return raiz

func _validate_property(property: Dictionary) -> void:
	if property.name == "evento" and alvo != Alvo.EVENTO:
		property.usage = PROPERTY_USAGE_STORAGE
