# controle_preparo.gd
# Abre/fecha a cena de preparo de poções e aplica o resultado (poção no inventário).
# Ao fechar, o GameManager emite preparo_fechado, que retoma o evento que abriu o preparo.
class_name ControlePreparo
extends Node

var gm   # GameManager

func _cena():
	var cena = gm.get_node_or_null("/root/Main/CanvasLayer/CenaPreparo")
	if not cena:
		push_warning("[ControlePreparo] CenaPreparo não encontrada")
	return cena

func abrir() -> void:
	var cena = _cena()
	if not cena:
		return
	gm._pause_game_with_reset()
	cena.visible = true
	if cena.has_method("iniciar"):
		cena.iniciar()
	print("[ControlePreparo] 🧪 preparo aberto")

func fechar(resultado: Dictionary = {}) -> void:
	var cena = _cena()
	if not cena:
		return
	if cena.has_method("encerrar"):
		cena.encerrar()
	cena.visible = false
	gm._unpause_game_with_reset()
	# só aplica o resultado se NÃO for cancelamento
	if not resultado.is_empty() and not resultado.get("cancelado", false):
		_aplicar_resultado(resultado)
	# avisa o Interpreter que pode continuar (mesmo se cancelado)
	gm.preparo_fechado.emit(resultado)
	print("[ControlePreparo] 🧪 preparo fechado", " (cancelado)" if resultado.get("cancelado", false) else "")

## Espaço para as regras do resultado (variáveis, som...). Hoje: a poção vai pro inventário.
func _aplicar_resultado(resultado: Dictionary) -> void:
	if resultado.has("item") and gm.game_temp:
		gm.game_temp.add_item(resultado.item, resultado.get("quantidade", 1))
