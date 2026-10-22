# A partir daqui, um toque na tela pula o evento para um label (ex.: pular a intro).
# O que estiver rodando é cancelado: legenda na tela, espera, movimento com espera.
# Quando o evento chega no label sozinho (ou termina), o toque deixa de pular.
class_name CmdPularComToque
extends Comando

## Nome do CmdLabel para onde pular.
@export var label: String = ""

func to_dict() -> Dictionary:
	return {"nome": "pular_com_toque", "args": [label]}

func executar(interp, ev) -> int:
	if not ev.labels.has(label):
		interp.falhar(ev, self, "label não encontrado: " + label)
		return AVANCAR
	var alvo: int = ev.labels[label]
	var no := _Ouvinte.new()
	no.process_mode = Node.PROCESS_MODE_ALWAYS
	no.ev = ev
	no.alvo = alvo
	interp.get_tree().root.add_child(no)
	return AVANCAR

class _Ouvinte extends Node:
	var ev
	var alvo: int

	func _process(_d: float) -> void:
		if ev.finished or ev.current_index >= alvo:
			queue_free()

	func _input(e: InputEvent) -> void:
		var toque: bool = (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed
		if not toque or ev.finished or ev.current_index >= alvo:
			return
		get_viewport().set_input_as_handled()
		# cancela o que está rodando e pula
		for n in get_tree().get_nodes_in_group(CmdLegenda.GRUPO):
			n.queue_free()
		ev.is_waiting = false
		ev.move_target_ref = null
		ev.pause_reason = ""
		ev.current_index = alvo
		queue_free()
