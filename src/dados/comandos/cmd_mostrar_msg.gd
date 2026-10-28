# Mostra uma mensagem na caixa de diálogo.
# Quem fala: um Personagem (dados/falantes/*.tres: nome e faces), a face e a posição na tela.
# Ainda funciona escrever no começo do texto (tem prioridade):  [nome;foto;pos] texto
#   nome  vazio = sem plaquinha de nome
#   foto  arquivo em res://assets/faces (com ou sem .png); vazio = sem foto
#   pos   0 a 100 (% da tela, 0 = esquerda) para o nome e a foto; vazio = 0
#         com foto, o nome fica centralizado embaixo dela
# Ex.: "[BRUXA;bruxa_grande;0] Entre logo."   "[???;;100] Tem alguém aí?"   "[GUARDA] Alto!"
# (o formato antigo [nome;pos_nome;foto;pos_foto] ainda funciona)
@tool
class_name CmdMostrarMsg
extends Comando

## Quem fala (dados/falantes). Vazio = sem nome e sem foto (ou o [nome;foto;pos] do texto).
@export var personagem: Personagem
## Nome da face do personagem ("" = a primeira, normalmente "normal").
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
@export_multiline var texto: String = ""

# posicao_modo só existe no inspetor (o arquivo guarda só posicao; -1 = padrão).
func _validate_property(property: Dictionary) -> void:
	if property.name == "posicao_modo":
		property.usage = PROPERTY_USAGE_EDITOR
	elif property.name == "posicao" and posicao < 0.0:
		property.usage = PROPERTY_USAGE_STORAGE

func to_dict() -> Dictionary:
	return {"nome": "mostrar_msg", "args": [(personagem.nome + ": " if personagem else "") + texto]}

func executar(interp, ev) -> int:
	# Se o texto for o nome de uma variável, mostra o valor dela.
	var t: String = texto
	if interp.game_temp and interp.game_temp.has_var(t):
		t = str(interp.game_temp.get_var(t))
	ev.pause("dialog")
	interp.enfileirar_dialogo({"event": ev, "kind": "msg", "messages": [t], "falante": Personagem.falante_de(personagem, face, posicao)})
	return MANTER
