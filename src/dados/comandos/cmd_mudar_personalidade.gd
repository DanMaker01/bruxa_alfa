# Define um traço da personalidade de um personagem.
class_name CmdMudarPersonalidade
extends Comando

enum Traco { ABERTURA, CONSCIENCIA, EXTROVERSAO, AMABILIDADE, NEUROTICISMO }

@export var personalidade: PersonalidadeData
@export var traco: Traco = Traco.ABERTURA
@export var valor: float = 0.0

func to_dict() -> Dictionary:
	return {"nome": "mudar_personalidade", "args": [personalidade.id if personalidade else "", int(traco), valor]}

func executar(interp, ev) -> int:
	var gt = interp.game_temp
	if not gt or personalidade == null or not gt.has_personality(personalidade.id):
		interp.falhar(ev, self, "personalidade não encontrada")
		return AVANCAR
	var nome_p: String = personalidade.id
	var valores: Array = gt.get_personality(nome_p).duplicate()
	var i := int(traco)
	if i >= valores.size():
		interp.falhar(ev, self, "traço %d fora de %s" % [i, nome_p])
		return AVANCAR
	var antigo = valores[i]
	valores[i] = valor
	gt.set_personality(nome_p, valores)
	interp.personality_changed.emit(nome_p, i, antigo, valor)
	return AVANCAR
