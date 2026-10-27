# Adiciona ou remove um item do inventário, ou esvazia o inventário (LIMPAR).
class_name CmdItem
extends Comando

enum Acao { ADICIONAR, REMOVER, LIMPAR }

@export var acao: Acao = Acao.ADICIONAR
@export var item: ItemData
@export var quantidade: int = 1

func to_dict() -> Dictionary:
	if acao == Acao.LIMPAR:
		return {"nome": "limpar_inventario", "args": []}
	var nome_cmd = "adicionar_item" if acao == Acao.ADICIONAR else "remover_item"
	return {"nome": nome_cmd, "args": [item.id if item else "", quantidade]}

func executar(interp, ev) -> int:
	var gt = interp.game_temp
	if gt and acao == Acao.LIMPAR:
		gt.clear_inventory()
		return AVANCAR
	if not gt or item == null:
		interp.falhar(ev, self, "sem item")
		return AVANCAR
	if acao == Acao.ADICIONAR:
		gt.add_item(item.id, quantidade)
		interp.item_added.emit(item.id, quantidade)
	else:
		gt.remove_item(item.id, quantidade)
		interp.item_removed.emit(item.id, quantidade)
	return AVANCAR
