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

## s: a legenda que estava na tela some neste tempo ao pular.
const SAIDA_LEGENDA: float = 0.3

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
		if UiModal.bloqueia(self) or UiModal.em_botao_prioritario(self, e.position):
			return   # menu de pausa (ou o botão ☰) por cima: o toque é dele
		get_viewport().set_input_as_handled()
		# cancela o que está rodando e pula
		# legenda na tela: some com fade curto (sem corte seco), junto com o fade do comando
		for n in get_tree().get_nodes_in_group(CmdLegenda.GRUPO):
			n.remove_from_group(CmdLegenda.GRUPO)
			var tw: Tween = n.create_tween().set_parallel(true)
			for c in n.get_children():
				if c is Control:
					c.mouse_filter = Control.MOUSE_FILTER_IGNORE   # o toque não fica preso na legenda
				if c is CanvasItem:
					tw.tween_property(c, "modulate:a", 0.0, CmdPularComToque.SAIDA_LEGENDA)
			tw.chain().tween_callback(n.queue_free)
		ev.is_waiting = false
		ev.move_target_ref = null
		ev.pause_reason = ""
		ev.current_index = alvo
		queue_free()
