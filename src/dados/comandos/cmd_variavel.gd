# Muda uma variável: global (do jogo) ou deste evento (self-variable A/B/C/D, cada nó no
# mapa tem as suas). "Aleatório" sorteia um inteiro entre valor e valor_max (inclusive).
# Junta os antigos mudar_var e self_var.
class_name CmdVariavel
extends Comando

enum Escopo { GLOBAL, DO_EVENTO }
enum Operacao { DEFINIR, SOMAR, SUBTRAIR, MULTIPLICAR, DIVIDIR, ALEATORIO }
const OPERACOES := ["=", "+=", "-=", "*=", "/=", "aleatorio"]

@export var escopo: Escopo = Escopo.GLOBAL:
	set(v):
		escopo = v
		notify_property_list_changed()
## Nome da variável global (escopo = GLOBAL).
@export var variavel: String = ""
## Self-variable (escopo = DO_EVENTO).
@export var letra: Condicao.Letra = Condicao.Letra.A
## Evento dono da self-variable (escopo = DO_EVENTO). Vazio = este evento.
@export var evento: String = ""
@export var operacao: Operacao = Operacao.DEFINIR:
	set(v):
		operacao = v
		notify_property_list_changed()
@export var valor: float = 0.0
## Maior valor do sorteio (operacao = ALEATORIO).
@export var valor_max: float = 1.0

func to_dict() -> Dictionary:
	var nome := variavel if escopo == Escopo.GLOBAL else "%s.%s" % [evento if evento != "" else "(este)", Condicao.Letra.keys()[letra]]
	var args: Array = [nome, OPERACOES[operacao], valor]
	if operacao == Operacao.ALEATORIO:
		args.append(valor_max)
	return {"nome": "variavel", "args": args}

func executar(interp, ev) -> int:
	var gt = interp.game_temp
	if gt == null:
		interp.falhar(ev, self, "sem GameTemp")
		return AVANCAR
	if escopo == Escopo.GLOBAL:
		if variavel == "":
			interp.falhar(ev, self, "sem variável")
			return AVANCAR
		var antigo = gt.get_var(variavel)
		var novo = _calcular(interp, ev, antigo)
		if novo == null:
			return AVANCAR
		gt.set_var(variavel, novo)
		interp.variable_changed.emit(variavel, antigo, novo)
		return AVANCAR
	# self-variable
	var chave: String = ev.chave_self
	if evento != "":
		var no = interp.encontrar_evento(evento)
		chave = no.chave_self() if no and no.has_method("chave_self") else ""
	if chave == "":
		interp.falhar(ev, self, "evento sem chave (não está no mapa?)")
		return AVANCAR
	var l: String = Condicao.Letra.keys()[letra]
	var novo_self = _calcular(interp, ev, gt.get_self_var(chave, l))
	if novo_self != null:
		gt.set_self_var(chave, l, float(novo_self))
	return AVANCAR

## Novo valor (ou null se não deu).
func _calcular(interp, ev, antigo):
	match operacao:
		Operacao.DEFINIR:
			return valor
		Operacao.ALEATORIO:
			var a := int(round(minf(valor, valor_max)))
			var b := int(round(maxf(valor, valor_max)))
			return float(randi_range(a, b))
	# variável inexistente conta como 0; tipo não numérico não quebra o jogo
	var base = 0.0 if antigo == null else antigo
	if not (typeof(base) == TYPE_INT or typeof(base) == TYPE_FLOAT):
		interp.falhar(ev, self, "'%s' precisa de número (%s)" % [OPERACOES[operacao], str(antigo)])
		return null
	match operacao:
		Operacao.SOMAR: return base + valor
		Operacao.SUBTRAIR: return base - valor
		Operacao.MULTIPLICAR: return base * valor
		Operacao.DIVIDIR: return base / valor if valor != 0 else base
	return base

func _validate_property(property: Dictionary) -> void:
	var mostrar := true
	match property.name:
		"variavel": mostrar = escopo == Escopo.GLOBAL
		"letra", "evento": mostrar = escopo == Escopo.DO_EVENTO
		"valor_max": mostrar = operacao == Operacao.ALEATORIO
		_: return
	if not mostrar:
		property.usage = PROPERTY_USAGE_STORAGE
