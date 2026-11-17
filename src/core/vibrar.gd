# vibrar.gd
# Vibração curta no celular (Opções > Vibração). No PC não faz nada.
#   Vibrar.leve()   toque em botão
#   Vibrar.media()  algo importante (item no ponto, pausa do tutorial)
#   Vibrar.forte()  poção com efeito
# Android: o export precisa da permissão VIBRATE.
class_name Vibrar
extends RefCounted

static var ligado: bool = true

static func leve() -> void:
	_vibrar(12)

static func media() -> void:
	_vibrar(35)

static func forte() -> void:
	_vibrar(70)

static func _vibrar(ms: int) -> void:
	if ligado and (OS.has_feature("android") or OS.has_feature("ios")):
		Input.vibrate_handheld(ms)
