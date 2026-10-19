# Pergunta com opções. Cada opção pula para o label correspondente.
class_name CmdMostrarOpcoes
extends Comando

@export var pergunta: String = ""
## Aceita o mesmo [nome;foto;pos] do mostrar_msg no começo.
@export var opcoes: Array[String] = []
## Um label por opção, na mesma ordem.
@export var labels: Array[String] = []

func to_dict() -> Dictionary:
	return {"nome": "mostrar_opcoes", "args": [pergunta, Array(opcoes), Array(labels)]}

func executar(interp, ev) -> int:
	if opcoes.size() != labels.size() or opcoes.is_empty():
		interp.falhar(ev, self, "opções e labels precisam ter o mesmo tamanho")
		return AVANCAR
	ev.pending_option_labels = Array(labels)
	ev.pause("option")
	interp.enfileirar_dialogo({"event": ev, "kind": "option", "question": pergunta, "options": Array(opcoes)})
	return MANTER
