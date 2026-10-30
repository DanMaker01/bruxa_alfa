# reacao_bruxa.gd
# Retratinho da Bruxa no canto da cena de preparo, reagindo ao caldeirão:
#   concentrada (normal)  → respira devagar
#   satisfeita (no ponto) → pulinho
#   preocupada (perto de um limite) → inclina e olha de lado
#   assustada (perdendo aproveitamento agora) → treme
# E um balãozinho com uma fala curta quando o humor muda ("Tá queimando!", "Isso!"...).
# Não decide nada do jogo: a cena chama atualizar() com os estados dos ingredientes.
class_name ReacaoBruxa
extends Node2D

# ---- ajuste aqui ----
const FOTO_PATH := "res://assets/game_caldeirao'/bruxa_chibi.png"
## Posição do retrato (mesmas coordenadas do caldeirão, em $Animações).
const POSICAO := Vector2(80, 470)
const ALTURA_FOTO: float = 240.0
const BALAO_OFFSET := Vector2(0, -260)   # canto inferior esquerdo do balão, relativo ao retrato
const BALAO_DURACAO: float = 2.2          # s na tela
const INTERVALO_MIN_FALA: float = 2.5     # s entre falas
const SUAVIZACAO: float = 6.0

enum Humor { CONCENTRADA, SATISFEITA, PREOCUPADA, ASSUSTADA }

const FALAS := {
	"quente": ["Tá queimando!", "Fogo demais!", "Quente, quente!"],
	"frio": ["Esfriou...", "Mais fogo!", "Brrr, tá frio."],
	"tempo": ["Tempo demais!", "Já devia ter tirado..."],
	"ponto": ["Passou do ponto!", "Cozinhou demais..."],
	"perto": ["Cuidado...", "Hmm, quase...", "Atenção!"],
	"perfeito": ["Isso!", "Perfeito!", "No ponto!"],
	"novo": ["Vamos ver...", "Mais um.", "Hmm."],
	"apagando": ["O fogo tá morrendo!", "Vai apagar...", "Cuidado com o fogo!"],
}

var _foto: Sprite2D
var _balao: PanelContainer
var _balao_label: Label
var _humor: int = Humor.CONCENTRADA
var _motivo: String = ""
var _t: float = 0.0
var _ultima_fala: float = -100.0
var _balao_ate: float = 0.0
# pose suavizada
var _rot: float = 0.0
var _sobe: float = 0.0
var _treme: float = 0.0


func _ready() -> void:
	position = POSICAO
	_foto = Sprite2D.new()
	if ResourceLoader.exists(FOTO_PATH):
		_foto.texture = load(FOTO_PATH)
		_foto.scale = Vector2.ONE * (ALTURA_FOTO / maxf(_foto.texture.get_height(), 1.0))
	_foto.offset = Vector2(0, -(_foto.texture.get_height() * 0.5) if _foto.texture else 0.0)   # pivô no pé
	add_child(_foto)
	_criar_balao()

func _criar_balao() -> void:
	_balao = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.95, 0.95, 0.92, 0.95)
	st.set_corner_radius_all(12)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	_balao.add_theme_stylebox_override("panel", st)
	_balao_label = Label.new()
	_balao_label.add_theme_font_size_override("font_size", 28)
	_balao_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_balao.add_child(_balao_label)
	_balao.position = BALAO_OFFSET
	_balao.modulate.a = 0.0
	_balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_balao)

func resetar() -> void:
	_humor = Humor.CONCENTRADA
	_motivo = ""
	_balao_ate = 0.0
	_balao.modulate.a = 0.0

## Um ingrediente entrou no caldeirão.
## Fala avulsa (ex.: "apagando").
func avisar(motivo: String) -> void:
	_ultima_fala = -100.0   # aviso importante: fala mesmo que tenha falado agora há pouco
	_falar(motivo)

func novo_ingrediente() -> void:
	_falar("novo")

## estados: CalculadoraPocao.estado_ao_vivo() de cada ingrediente.
func atualizar(estados: Array) -> void:
	var motivo := ""
	var humor := Humor.CONCENTRADA
	var todos_no_ponto := not estados.is_empty()
	var perto := false
	for est in estados:
		if est.is_empty():
			todos_no_ponto = false
			continue
		var niveis: Dictionary = est.get("niveis", {})
		for k in ["quente", "frio", "tempo", "ponto"]:
			if niveis.get(k, 0) == 2 and motivo == "":
				motivo = k
			elif niveis.get(k, 0) == 1:
				perto = true
		if not est.get("no_ponto", false):
			todos_no_ponto = false
	if motivo != "":
		humor = Humor.ASSUSTADA
	elif perto:
		humor = Humor.PREOCUPADA
		motivo = "perto"
	elif todos_no_ponto:
		humor = Humor.SATISFEITA
		motivo = "perfeito"
	if humor != _humor or motivo != _motivo:
		_humor = humor
		_motivo = motivo
		if motivo != "":
			_falar(motivo)

func _falar(motivo: String) -> void:
	if _t - _ultima_fala < INTERVALO_MIN_FALA or not FALAS.has(motivo):
		return
	var opcoes: Array = FALAS[motivo]
	_balao_label.text = opcoes[randi() % opcoes.size()]
	_balao.size = _balao.get_combined_minimum_size()
	_ultima_fala = _t
	_balao_ate = _t + BALAO_DURACAO
	_balao.scale = Vector2(0.6, 0.6)
	var tw := _balao.create_tween().set_parallel(true)
	tw.tween_property(_balao, "modulate:a", 1.0, 0.15)
	tw.tween_property(_balao, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_t += delta
	# pose alvo por humor
	var rot_alvo := 0.0
	var sobe_alvo := sin(_t * 1.6) * 2.0          # respirando
	var treme_alvo := 0.0
	match _humor:
		Humor.SATISFEITA:
			sobe_alvo = -absf(sin(_t * 6.0)) * 8.0     # pulinhos
		Humor.PREOCUPADA:
			rot_alvo = -0.08 + 0.03 * sin(_t * 2.0)    # inclina e olha de lado
		Humor.ASSUSTADA:
			treme_alvo = 1.0
			rot_alvo = 0.05 * sin(_t * 9.0)
	var k := clampf(delta * SUAVIZACAO, 0.0, 1.0)
	_rot = lerpf(_rot, rot_alvo, k)
	_sobe = lerpf(_sobe, sobe_alvo, k)
	_treme = lerpf(_treme, treme_alvo, k)
	var tremor := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.5 * _treme
	_foto.position = Vector2(0, _sobe) + tremor
	_foto.rotation = _rot
	# balão some sozinho
	if _balao_ate > 0.0 and _t > _balao_ate:
		_balao_ate = 0.0
		_balao.create_tween().tween_property(_balao, "modulate:a", 0.0, 0.3)
