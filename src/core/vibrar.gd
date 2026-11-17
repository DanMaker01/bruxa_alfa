# vibrar.gd
# Vibração curta no celular (Opções > Vibração). No PC não faz nada.
#   Vibrar.leve()   toque em botão, virar página, pegar item, bater num bloqueio
#   Vibrar.media()  algo importante (item no ponto, fogo aceso, tremor da câmera, memorizar, salvar)
#   Vibrar.forte()  poção com efeito, aplicar poção
#   Vibrar.dupla()  alerta: dois pulsos curtos (fogo apagou)
# Duas vibrações muito juntas (menos de INTERVALO_MIN_MS) viram uma só.
# Android: o export precisa da permissão VIBRATE.
class_name Vibrar
extends RefCounted

static var ligado: bool = true
const INTERVALO_MIN_MS: int = 90
static var _ultima_ms: int = -100000

static func leve() -> void:
	_vibrar(12)

static func media() -> void:
	_vibrar(35)

static func forte() -> void:
	_vibrar(70)

static func dupla() -> void:
	_vibrar(40)
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.create_timer(0.15, true, false, true).timeout.connect(func(): _vibrar(40, true))

static func _vibrar(ms: int, forcar: bool = false) -> void:
	if not ligado or not (OS.has_feature("android") or OS.has_feature("ios")):
		return
	var agora := Time.get_ticks_msec()
	if not forcar and agora - _ultima_ms < INTERVALO_MIN_MS:
		return
	_ultima_ms = agora
	Input.vibrate_handheld(ms)
