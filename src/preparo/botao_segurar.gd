# botao_segurar.gd
# Componente para botões com toque curto E segurar (ex.: fogo, poção).
#   var b := BotaoSegurar.anexar(meu_botao)
#   b.toque_curto.connect(...)   # soltou antes do tempo longo
#   b.segurou.connect(...)       # segurou até o tempo longo (dispara uma vez)
#   b.carregando.connect(...)    # 0..1 enquanto segura, antes de disparar
#   b.repetiu.connect(...)       # continua segurando: a cada intervalo_repeticao (0 = não repete)
# Também aplica o efeito de clique (afunda ao apertar, volta com mola ao soltar).
class_name BotaoSegurar
extends Node

signal toque_curto
signal segurou
signal carregando(progresso: float)
signal soltou
signal repetiu

var tempo_longo: float = 0.3
## Depois de disparar, segurando ainda: emite repetiu a cada intervalo (0 = desligado).
var intervalo_repeticao: float = 0.0
var botao: BaseButton
var _segurando: bool = false
var _tempo: float = 0.0
var _disparou: bool = false


static func anexar(btn: BaseButton, tempo: float = 0.3) -> BotaoSegurar:
	var b := BotaoSegurar.new()
	b.name = "BotaoSegurar"
	b.botao = btn
	b.tempo_longo = tempo
	btn.add_child(b)
	btn.button_down.connect(b._on_down)
	btn.button_up.connect(b._on_up)
	efeito_clique(btn)
	return b


func _process(delta: float) -> void:
	if not _segurando:
		return
	_tempo += delta
	if _disparou:
		if intervalo_repeticao > 0.0 and _tempo >= tempo_longo + intervalo_repeticao:
			_tempo -= intervalo_repeticao
			repetiu.emit()
		return
	carregando.emit(clampf(_tempo / tempo_longo, 0.0, 1.0))
	if _tempo >= tempo_longo:
		_disparou = true
		segurou.emit()

func _on_down() -> void:
	_segurando = true
	_tempo = 0.0
	_disparou = false

func _on_up() -> void:
	if _segurando and not _disparou:
		toque_curto.emit()
	cancelar()
	soltou.emit()

## Esquece o toque em andamento (ex.: o app perdeu o foco).
func cancelar() -> void:
	_segurando = false
	_tempo = 0.0
	_disparou = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancelar()


# =============================================================================
# EFEITO DE CLIQUE (serve para qualquer botão, ex.: itens do inventário)
# =============================================================================
static func efeito_clique(btn: BaseButton) -> void:
	if btn == null:
		return
	btn.button_down.connect(_apertado.bind(btn))
	btn.button_up.connect(_solto.bind(btn))
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	btn.pivot_offset = btn.size * 0.5

static func _apertado(btn: BaseButton) -> void:
	var tw := btn.create_tween().set_parallel(true)
	tw.tween_property(btn, "scale", Vector2(0.88, 0.88), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "modulate", Color(1.35, 1.3, 1.15), 0.06)

static func _solto(btn: BaseButton) -> void:
	if not is_instance_valid(btn):
		return
	var tw := btn.create_tween().set_parallel(true)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.25)
