# Classifica como cada traço de uma personalidade mudou em relação a uma referência
# (ex.: a personalidade inicial da princesa) e guarda em variáveis:
#   <prefixo>_O, _C, _E, _A, _N   −2 diminuiu muito · −1 diminuiu pouco · 0 neutro
#                                  +1 aumentou pouco · +2 aumentou muito
#   <prefixo>_extremo             quantos traços ficaram extremos (≈ 0 ou |v| ≥ limite_extremo):
#                                  a pessoa fica "estereotipada"
# Mudança relativa r = (novo − ref) / max(|ref|, 1): |r| < limite_neutro → 0; < limite_muito → ±1; senão ±2.
# As páginas/ifs do evento usam essas variáveis para escolher a reação.
class_name CmdClassificarPersonalidade
extends Comando

const TRACOS := ["O", "C", "E", "A", "N"]

## id da personalidade atual (no GameTemp).
@export var personalidade: String = ""
## Valores de referência (normalmente o .tres inicial do personagem).
@export var referencia: PersonalidadeData
## Prefixo das variáveis (ex.: "missao01" → missao01_N).
@export var prefixo: String = "missao01"
@export var limite_neutro: float = 0.1
@export var limite_muito: float = 0.4
## |valor| abaixo disto conta como traço zerado.
@export var limite_zerado: float = 0.5
## |valor| acima disto conta como traço extremo.
@export var limite_extremo: float = 9.5

func to_dict() -> Dictionary:
	return {"nome": "classificar_personalidade", "args": [personalidade, prefixo]}

func executar(interp, ev) -> int:
	var gt = interp.game_temp
	if gt == null or referencia == null or not gt.has_personality(personalidade):
		interp.falhar(ev, self, "personalidade/referência não encontrada")
		return AVANCAR
	var atual: Array = gt.get_personality(personalidade)
	var ref: Array = referencia.como_array()
	var extremos := 0
	for i in 5:
		var novo := float(atual[i])
		var r := (novo - float(ref[i])) / maxf(absf(float(ref[i])), 1.0)
		var classe := 0
		if absf(r) >= limite_muito:
			classe = 2
		elif absf(r) >= limite_neutro:
			classe = 1
		_definir(interp, gt, "%s_%s" % [prefixo, TRACOS[i]], float(classe * int(signf(r))))
		if absf(novo) < limite_zerado or absf(novo) >= limite_extremo:
			extremos += 1
	_definir(interp, gt, prefixo + "_extremo", float(extremos))
	return AVANCAR

func _definir(interp, gt, nome: String, valor: float) -> void:
	var antigo = gt.get_var(nome)
	gt.set_var(nome, valor)
	interp.variable_changed.emit(nome, antigo, valor)
