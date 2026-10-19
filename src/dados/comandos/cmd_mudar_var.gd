# Altera uma variável do jogo.
class_name CmdMudarVar
extends Comando

enum Operacao { DEFINIR, SOMAR, SUBTRAIR, MULTIPLICAR, DIVIDIR }
const OPERACOES := ["=", "+=", "-=", "*=", "/="]

@export var variavel: String = ""
@export var operacao: Operacao = Operacao.DEFINIR
@export var valor: float = 0.0

func to_dict() -> Dictionary:
	return {"nome": "mudar_var", "args": [variavel, OPERACOES[operacao], valor]}

func executar(interp, ev) -> int:
	var gt = interp.game_temp
	if not gt or variavel == "":
		interp.falhar(ev, self, "sem variável")
		return AVANCAR
	var antigo = gt.get_var(variavel)
	var op: String = OPERACOES[operacao]
	if op == "=":
		gt.set_var(variavel, valor)
	else:
		# variável inexistente conta como 0; tipos não numéricos não quebram o jogo
		var base = 0.0 if antigo == null else antigo
		if not (typeof(base) == TYPE_INT or typeof(base) == TYPE_FLOAT):
			interp.falhar(ev, self, "'%s' precisa de número (%s = %s)" % [op, variavel, str(antigo)])
			return AVANCAR
		match op:
			"+=": gt.set_var(variavel, base + valor)
			"-=": gt.set_var(variavel, base - valor)
			"*=": gt.set_var(variavel, base * valor)
			"/=": gt.set_var(variavel, base / valor if valor != 0 else base)
	interp.variable_changed.emit(variavel, antigo, gt.get_var(variavel))
	return AVANCAR
