# transcritor_receita.gd
# Transforma um preparo real (curva de T e entradas dos ingredientes) em passos do livro.
#   - cada entrada de ingrediente vira "<item> ×qtd, N s" (N = até a próxima entrada ou o fim)
#   - entradas do mesmo item a menos de JUNTAR_S uma da outra viram um passo só (qtd)
#   - antes de cada ingrediente, se a chama dominante naquele trecho mudou, entra "chama <estado>"
#   - tempos arredondados ao segundo; "Finalizar" fica implícito
# iguais(): mesma receita se os passos batem e cada tempo difere no máximo TOLERANCIA_S.
class_name TranscritorReceita
extends RefCounted

const JUNTAR_S: float = 1.5
const TOLERANCIA_S: float = 1.0


## historico: [{"t", "T", "fogo"}], ingredientes: [{"nome", "t0"}] (na ordem), t_final em s.
static func transcrever(historico: Array, ingredientes: Array, t_final: float) -> Array:
	# 1. grupos: mesmo item em sequência rápida
	var grupos: Array = []
	for ing in ingredientes:
		var t0: float = float(ing.get("t0", 0.0))
		var nome: String = str(ing.get("nome", "?"))
		if not grupos.is_empty() and grupos[-1]["item"] == nome and t0 - float(grupos[-1]["t_ult"]) <= JUNTAR_S:
			grupos[-1]["qtd"] += 1
			grupos[-1]["t_ult"] = t0
		else:
			grupos.append({"item": nome, "qtd": 1, "t": t0, "t_ult": t0})
	# 2. passos
	var passos: Array = []
	var estado_atual := ""
	for k in grupos.size():
		var g: Dictionary = grupos[k]
		var fim: float = float(grupos[k + 1]["t"]) if k + 1 < grupos.size() else t_final
		var dom := _estado_dominante(historico, float(g["t"]), fim)
		if dom != "" and dom != estado_atual:
			passos.append({"tipo": "chama", "estado": dom})
			estado_atual = dom
		passos.append({"tipo": "ingrediente", "item": g["item"], "qtd": int(g["qtd"]),
			"seg": float(roundi(fim - float(g["t"])))})
	return passos


## Estado da chama que mais tempo ficou no trecho [t_ini, t_fim].
static func _estado_dominante(historico: Array, t_ini: float, t_fim: float) -> String:
	var tempo := {}
	var t_ant := -1.0
	var e_ant := ""
	for p in historico:
		var t: float = float(p.get("t", 0.0))
		if t < t_ini:
			continue
		if t > t_fim:
			break
		var e := EstadosChama.de_T(float(p.get("T", 20.0)), bool(p.get("fogo", true)))
		if t_ant >= 0.0:
			tempo[e_ant] = float(tempo.get(e_ant, 0.0)) + (t - t_ant)
		t_ant = t
		e_ant = e
	var melhor := ""
	var maior := -1.0
	for e in tempo:
		if tempo[e] > maior:
			maior = tempo[e]
			melhor = e
	if melhor == "" and e_ant != "":
		melhor = e_ant
	return melhor


static func iguais(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Dictionary = a[i]
		var y: Dictionary = b[i]
		if x.get("tipo") != y.get("tipo"):
			return false
		if x.get("tipo") == "chama":
			if x.get("estado") != y.get("estado"):
				return false
		elif x.get("tipo") == "ingrediente":
			if x.get("item") != y.get("item") or int(x.get("qtd", 1)) != int(y.get("qtd", 1)):
				return false
			if absf(float(x.get("seg", 0.0)) - float(y.get("seg", 0.0))) > TOLERANCIA_S:
				return false
	return true
