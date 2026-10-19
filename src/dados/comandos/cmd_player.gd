# Trava, destrava, mostra ou esconde a bruxa.
class_name CmdPlayer
extends Comando

enum Acao { TRAVAR, DESTRAVAR, MOSTRAR, SUMIR }
const NOMES := ["travar_player", "destravar_player", "mostrar_player", "sumir_player"]

@export var acao: Acao = Acao.TRAVAR

func to_dict() -> Dictionary:
	return {"nome": NOMES[acao], "args": []}

func executar(interp, ev) -> int:
	var gm = interp.game_manager
	if not gm:
		interp.falhar(ev, self, "sem GameManager")
		return AVANCAR
	match acao:
		Acao.TRAVAR: gm.lock_player()
		Acao.DESTRAVAR: gm.unlock_player()
		Acao.MOSTRAR, Acao.SUMIR:
			var player = gm.get_player()
			var metodo := "mostrar_player" if acao == Acao.MOSTRAR else "sumir_player"
			if player and player.has_method(metodo):
				player.call(metodo)
	return AVANCAR
