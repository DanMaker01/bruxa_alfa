# Liga/desliga uma self-variable (A, B, C ou D) de um evento.
# Cada nó de evento no mapa tem as suas (cópias de uma área de spawn também),
# então "pegar este cogumelo" não afeta os outros cogumelos.
# Use com uma página cuja condição seja do tipo "self" (ex.: A == 1 → página vazia).
class_name CmdSelfVar
extends Comando

## id do EventoData do evento. Vazio = o próprio evento que está rodando.
@export var evento: String = ""
@export var letra: Condicao.Letra = Condicao.Letra.A
## true = 1, false = 0.
@export var ativar: bool = true

func to_dict() -> Dictionary:
	return {"nome": "self_var", "args": [evento if evento != "" else "(este)", Condicao.Letra.keys()[letra], 1 if ativar else 0]}

func executar(interp, ev) -> int:
	var gt = interp.game_temp
	var chave: String = ev.chave_self
	if evento != "":
		var no = interp.encontrar_evento(evento)
		chave = no.chave_self() if no and no.has_method("chave_self") else ""
	if not gt or chave == "":
		interp.falhar(ev, self, "evento sem chave (não está no mapa?)")
		return AVANCAR
	gt.set_self_var(chave, Condicao.Letra.keys()[letra], 1.0 if ativar else 0.0)
	return AVANCAR
