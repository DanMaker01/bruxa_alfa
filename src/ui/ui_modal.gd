# ui_modal.gd
# Janelas que ficam por cima do jogo (menu de debug, caldeirão, popup do item, pausa...)
# entram no grupo "ui_modal". Quem lê toques direto em _input (cartas do HUD, lista
# rolável) pergunta aqui antes de reagir: se há uma janela modal aberta que não é ele
# mesmo nem um dos seus "pais", o toque é dela.
class_name UiModal
extends RefCounted

const GRUPO := "ui_modal"

## true se existe uma janela modal visível que não contém "no".
static func bloqueia(no: Node) -> bool:
	if no == null or not no.is_inside_tree():
		return false
	for m in no.get_tree().get_nodes_in_group(GRUPO):
		if m == no or not (m is CanvasItem) or not m.is_visible_in_tree():
			continue
		if m.is_ancestor_of(no):
			continue
		return true
	return false
