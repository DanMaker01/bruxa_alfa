# Pergunta com opções. Cada opção pula para o label correspondente.
@tool
class_name CmdMostrarOpcoes
extends Comando

## Quem pergunta (dados/falantes). Vazio = sem nome e sem foto (ou o [nome;foto;pos] da pergunta).
@export var personagem: Personagem
## Nome da face do personagem ("" = a primeira).
@export var face: String = ""
## (padrão) = a última posição em que este personagem falou (0 na primeira vez).
## escolher posição = mostra o campo Posicao logo abaixo.
@export_enum("(padrão)", "escolher posição") var posicao_modo: int:
	get: return 0 if posicao < 0.0 else 1
	set(v):
		if v == 0: posicao = -1.0
		elif posicao < 0.0: posicao = 0.0
		notify_property_list_changed()
## Posição do nome e da foto (% da tela: 0 = esquerda, 100 = direita).
@export_range(0.0, 100.0, 1.0, "suffix:%") var posicao: float = -1.0
## Aceita o mesmo [nome;foto;pos] do mostrar_msg no começo (tem prioridade sobre o Falante).
@export var pergunta: String = ""
@export var opcoes: Array[String] = []
## Um label por opção, na mesma ordem.
@export var labels: Array[String] = []

# posicao_modo só existe no inspetor (o arquivo guarda só posicao; -1 = padrão).
func _validate_property(property: Dictionary) -> void:
	if property.name == "posicao_modo":
		property.usage = PROPERTY_USAGE_EDITOR
	elif property.name == "posicao" and posicao < 0.0:
		property.usage = PROPERTY_USAGE_STORAGE

func to_dict() -> Dictionary:
	return {"nome": "mostrar_opcoes", "args": [pergunta, Array(opcoes), Array(labels)]}

func executar(interp, ev) -> int:
	if opcoes.size() != labels.size() or opcoes.is_empty():
		interp.falhar(ev, self, "opções e labels precisam ter o mesmo tamanho")
		return AVANCAR
	ev.pending_option_labels = Array(labels)
	ev.pause("option")
	interp.enfileirar_dialogo({"event": ev, "kind": "option", "question": pergunta, "options": Array(opcoes),
		"falante": Personagem.falante_de(personagem, face, posicao)})
	return MANTER
