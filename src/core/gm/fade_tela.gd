# fade_tela.gd
# Escurecer/clarear a tela (nó CanvasLayer/Fade). O GameManager repassa a API e os
# sinais, então quem já usava gm.fade_out()/gm.fade_out_completed continua igual.
class_name FadeTela
extends Node

signal fade_out_completed
signal fade_in_completed

var fade_rect: ColorRect = null
var _tween: Tween = null
var _tipo: String = ""   # "out" / "in" enquanto um fade está rodando


func fade_out(tempo: float = 1.0) -> void:
	_rodar("out", 0.0, 1.0, tempo)

func fade_in(tempo: float = 1.0) -> void:
	_rodar("in", 1.0, 0.0, tempo)

func is_fading() -> bool:
	return _tween != null and _tween.is_running()

## true enquanto um fade_in (clarear) está rodando.
func clareando() -> bool:
	return _tipo == "in" and is_fading()

func _rodar(tipo: String, de: float, ate: float, tempo: float) -> void:
	if not fade_rect:
		push_warning("[Fade] nó Fade não encontrado")
		_emitir(tipo)
		return
	# começa de onde a tela está (um fade interrompido no meio não pisca)
	if fade_rect.visible:
		de = fade_rect.color.a
	_interromper()
	_tipo = tipo
	fade_rect.color = Color(0, 0, 0, de)
	fade_rect.visible = true
	_tween = create_tween()
	_tween.tween_property(fade_rect, "color:a", ate, tempo)
	_tween.tween_callback(func():
		if tipo == "in":
			fade_rect.visible = false
		_tipo = ""
		_emitir(tipo))

## Mata o fade atual e emite o sinal dele, para nenhum await ficar preso.
func _interromper() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		var tipo := _tipo
		_tipo = ""
		if tipo != "":
			_emitir(tipo)

func _emitir(tipo: String) -> void:
	if tipo == "out":
		fade_out_completed.emit()
	else:
		fade_in_completed.emit()
