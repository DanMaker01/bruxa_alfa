# Mostra uma mensagem na caixa de diálogo.
# Nome e foto vão no começo do texto:  [nome;foto;pos] texto
#   nome  vazio = sem plaquinha de nome
#   foto  arquivo em res://assets/game_faces (com ou sem .png); vazio = sem foto
#   pos   0 a 100 (% da tela, 0 = esquerda) para o nome e a foto; vazio = 0
#         com foto, o nome fica centralizado embaixo dela
# Ex.: "[BRUXA;bruxa_grande;0] Entre logo."   "[???;;100] Tem alguém aí?"   "[GUARDA] Alto!"
# (o formato antigo [nome;pos_nome;foto;pos_foto] ainda funciona)
class_name CmdMostrarMsg
extends Comando

@export_multiline var texto: String = ""

func to_dict() -> Dictionary:
	return {"nome": "mostrar_msg", "args": [texto]}

func executar(interp, ev) -> int:
	# Se o texto for o nome de uma variável, mostra o valor dela.
	var t: String = texto
	if interp.game_temp and interp.game_temp.has_var(t):
		t = str(interp.game_temp.get_var(t))
	ev.pause("dialog")
	interp.enfileirar_dialogo({"event": ev, "kind": "msg", "messages": [t]})
	return MANTER
