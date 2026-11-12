# ui_modal.gd
# Janelas que ficam por cima do jogo (menu de debug, caldeirão, popup do item, pausa...)
# entram no grupo "ui_modal". Quem lê toques direto em _input (cartas do HUD, lista
# rolável) pergunta aqui antes de reagir: se há uma janela modal aberta que não é ele
# mesmo nem um dos seus "pais", o toque é dela.
class_name UiModal
extends RefCounted

const GRUPO := "ui_modal"
## Botões que sempre ganham o toque (ex.: ☰ da pausa), mesmo de quem lê _input direto.
const GRUPO_BOTOES := "ui_botao_prioritario"

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

## true se o ponto (tela) cai num botão prioritário visível (ex.: ☰ da pausa).
static func em_botao_prioritario(no: Node, pos: Vector2) -> bool:
	if no == null or not no.is_inside_tree():
		return false
	for b in no.get_tree().get_nodes_in_group(GRUPO_BOTOES):
		if b is Control and b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return true
	return false
