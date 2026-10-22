# Mede o quanto uma personalidade mudou em relação a uma referência (ex.: a
# personalidade inicial da princesa): guarda numa variável a MAIOR diferença
# (em módulo) entre os traços marcados. Ex.: marcar O, C, E, A para saber se a
# poção mexeu demais nos outros traços além do N.
class_name CmdMedirMudanca
extends Comando

## id da personalidade atual (no GameTemp).
@export var personalidade: String = ""
## Valores de referência (normalmente o .tres inicial do personagem).
@export var referencia: PersonalidadeData
@export_flags("O", "C", "E", "A", "N") var tracos: int = 15
@export var variavel: String = "mudanca"

func to_dict() -> Dictionary:
	return {"nome": "medir_mudanca", "args": [personalidade, tracos, variavel]}

func executar(interp, ev) -> int:
	var gt = interp.game_temp
	if gt == null or referencia == null or not gt.has_personality(personalidade):
		interp.falhar(ev, self, "personalidade/referência não encontrada")
		return AVANCAR
	var atual: Array = gt.get_personality(personalidade)
	var ref: Array = referencia.como_array()
	var maior := 0.0
	for i in 5:
		if tracos & (1 << i):
			maior = maxf(maior, absf(float(atual[i]) - float(ref[i])))
	var antigo = gt.get_var(variavel)
	gt.set_var(variavel, maior)
	interp.variable_changed.emit(variavel, antigo, maior)
	return AVANCAR
