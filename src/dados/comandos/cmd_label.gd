# Marca um ponto da lista para goto / opções.
class_name CmdLabel
extends Comando

@export var nome: String = ""

func to_dict() -> Dictionary:
	return {"nome": "label", "args": [nome]}

func executar(_interp, _ev) -> int:
	return AVANCAR
