# =============================================================================
# calculadora_pocao.gd
# Fase 1 — Diagnóstico por ingrediente (Q, T_max, T_min, duração)
# Fase 2 — Aproveitamento a_i ∈ [0,1] de cada ingrediente
# Matriz  — A = B_n · … · B_1,  com B_i = a_i·A_i + (1 − a_i)·I
# =============================================================================
class_name CalculadoraPocao
extends RefCounted

## 2·ln(99): distância (em unidades de R·x) entre a = 0.99 e a = 0.01 na logística.
const K_LOGISTICA: float = 9.189587
const N: int = 5

# =============================================================================
# ENTRADA — cálculo principal
# =============================================================================
# `bruto` no formato do `_calcular_resultado()` do cena_preparo:
# {
#   "ingredientes": [{"nome": ..., "t0": ...}, ...],
#   "t_final": float,
#   "historico_T": [{"t": ..., "T": ..., "F": ...}, ...],
# }
# `database`: DatabaseManager (usa get_item(id) -> ItemData). Sem database,
# nenhum ingrediente é reconhecido e a poção sai neutra (identidade).
static func calcular(bruto: Dictionary, database = null) -> Dictionary:
	var historico: Array = bruto.get("historico_T", [])
	var t_final: float = bruto.get("t_final", 0.0)
	var ingredientes: Array = bruto.get("ingredientes", [])

	var diagnosticos: Array = []
	var A: Array = identidade()
	for ing in ingredientes:
		var nome: String = str(ing.get("nome", "?"))
		var item: ItemData = database.get_item(nome) if database else null
		var d = _diagnostico_ingrediente(ing, historico, t_final, item)
		_aproveitamento(d, item)
		d["nome_exibicao"] = item.get_nome() if item else nome
		d["item"] = item
		d["problemas"] = problemas(d, item, true)
		diagnosticos.append(d)
		# Ordem de entrada = ordem do efeito: o primeiro ingrediente age primeiro.
		var B = interpolar(matriz_do_item(item), d["a"])
		A = multiplicar(B, A)

	return {
		"ingredientes_brutos": ingredientes,
		"t_final": t_final,
		"historico_T": historico,
		"diagnosticos": diagnosticos,
		"A": A,
	}

# =============================================================================
# FASE 1 — DIAGNÓSTICO POR INGREDIENTE
# =============================================================================
# Se `ing` já for um acumulador (ver novo_acumulador, usado ao vivo pelo cena_preparo),
# usa os valores dele; senão recalcula a partir do histórico.
static func _diagnostico_ingrediente(ing: Dictionary, historico: Array, t_final: float, item: ItemData = null) -> Dictionary:
	var acc: Dictionary
	if ing.has("n_pontos"):
		acc = ing
	else:
		acc = novo_acumulador(str(ing.get("nome", "?")), float(ing.get("t0", 0.0)))
		for p in historico:
			if float(p.get("t", 0.0)) <= t_final:
				acumular(acc, p, item)
	return diagnostico_do_acumulador(acc, t_final)

## Acumulador de um ingrediente no caldeirão (Q, T_max, T_min...).
## É alimentado ponto a ponto com acumular(); assim o cálculo ao vivo e o final são o mesmo.
static func novo_acumulador(nome: String, t0: float) -> Dictionary:
	return {
		"nome": nome,
		"t0": t0,
		"Q": 0.0,
		"T_max": -INF,
		"T_min": INF,
		"soma_T": 0.0,
		"n_pontos": 0,
		"ultimo": {},
	}

## Soma um ponto {"t", "T"} do histórico (trapézio com o ponto anterior).
static func acumular(acc: Dictionary, p: Dictionary, _item: ItemData = null) -> void:
	var t: float = float(p.get("t", 0.0))
	if t < float(acc["t0"]):
		return
	var T: float = float(p.get("T", 0.0))
	acc["T_max"] = maxf(acc["T_max"], T)
	acc["T_min"] = minf(acc["T_min"], T)
	acc["soma_T"] += T
	acc["n_pontos"] += 1
	var ant: Dictionary = acc["ultimo"]
	if not ant.is_empty():
		var t_a: float = float(ant["t"])
		var T_a: float = float(ant["T"])
		var dt: float = t - t_a
		acc["Q"] += (T_a + T) * 0.5 * dt
	acc["ultimo"] = {"t": t, "T": T}

static func diagnostico_do_acumulador(acc: Dictionary, t_final: float) -> Dictionary:
	var n: int = int(acc["n_pontos"])
	var t0: float = float(acc["t0"])
	return {
		"nome": acc["nome"],
		"t0": t0,
		"tf": t_final,
		"duracao": t_final - t0,
		"Q": acc["Q"],
		"T_max": acc["T_max"] if n > 0 else 0.0,
		"T_min": acc["T_min"] if n > 0 else 0.0,
		"T_media": acc["soma_T"] / float(n) if n > 0 else 0.0,
		"n_pontos": n,
	}

# =============================================================================
# FASE 2 — APROVEITAMENTO
# =============================================================================
# a = a_Q · a_Tmax · a_Tmin · a_tmin · a_tmax   (escreve tudo dentro de `d`)
# Item desconhecido → a = 0 (entra como identidade, não faz nada).
static func _aproveitamento(d: Dictionary, item: ItemData) -> void:
	if item == null:
		d["reconhecido"] = false
		d["a_Q"] = 0.0
		d["a_T_max"] = 0.0
		d["a_T_min"] = 0.0
		d["a_t_min"] = 0.0
		d["a_t_max"] = 0.0
		d["a"] = 0.0
		return

	d["reconhecido"] = true
	d["a_Q"] = a_cozimento(d["Q"], item.m, item.s_menos, item.s_mais)
	# Temperatura: pela maior e pela menor temperatura alcançadas desde que entrou.
	if int(d["n_pontos"]) > 0:
		d["a_T_max"] = curva_max(d["T_max"], item.T_max, item.k_max)
		d["a_T_min"] = curva_min(d["T_min"], item.T_min, item.k_min)
	else:
		d["a_T_max"] = 1.0
		d["a_T_min"] = 1.0
	d["a_t_min"] = curva_min(d["duracao"], item.t_min, item.h_min)
	d["a_t_max"] = curva_max(d["duracao"], item.t_max, item.h_max)
	d["a"] = d["a_Q"] * d["a_T_max"] * d["a_T_min"] * d["a_t_min"] * d["a_t_max"]

## Cozimento: gaussiana de dois lados, pico 1 em Q = m.
##   a_Q = exp(−½·((Q − m)/s)²),  s = s_menos se Q < m, s_mais se Q ≥ m.
## m <= 0 → sem exigência (1). s <= 0 → só vale 1 exatamente em m.
static func a_cozimento(Q: float, m: float, s_menos: float, s_mais: float) -> float:
	if m <= 0.0:
		return 1.0
	var s: float = s_menos if Q < m else s_mais
	if s <= 0.0:
		return 1.0 if is_equal_approx(Q, m) else 0.0
	var z: float = (Q - m) / s
	return exp(-0.5 * z * z)

## Limite máximo x0 com folga h: 1 até x0, cai de 0.99 (x0) a 0.01 ((1+h)·x0).
## x0 <= 0 → sem limite (1). h <= 0 → corte duro.
static func curva_max(x: float, x0: float, h: float) -> float:
	if x0 <= 0.0 or x <= x0:
		return 1.0
	if h <= 0.0:
		return 0.0
	var x_m: float = (1.0 + h * 0.5) * x0
	var R: float = K_LOGISTICA / (h * x0)
	return 1.0 / (1.0 + exp(R * (x - x_m)))

## Limite mínimo x0 com folga h: 1 a partir de x0, cai de 0.99 (x0) a 0.01 ((1−h)·x0).
## x0 <= 0 → sem limite (1). h <= 0 → corte duro.
static func curva_min(x: float, x0: float, h: float) -> float:
	if x0 <= 0.0 or x >= x0:
		return 1.0
	if h <= 0.0:
		return 0.0
	var x_m: float = (1.0 - h * 0.5) * x0
	var R: float = K_LOGISTICA / (h * x0)
	return 1.0 / (1.0 + exp(-R * (x - x_m)))

# =============================================================================
# PROBLEMAS — uma tag para cada critério que tirou aproveitamento do ingrediente
# =============================================================================
# Cada tag: {"chave", "texto", "perda" (0..1 = 1 − a do critério), "fixo"}
# fixo = true  → já aconteceu e não volta (passou do limite, passou do ponto...).
# fixo = false → ainda pode ser resolvido cozinhando mais (cru, pouco tempo).
#                No resultado final (final = true) tudo vira fixo.
const LIMIAR_PROBLEMA: float = 0.99

static func problemas(d: Dictionary, item: ItemData, final: bool = false) -> Array:
	var tags: Array = []
	if item == null:
		tags.append({"chave": "desconhecido", "texto": "não faz efeito", "perda": 1.0, "fixo": true})
		return tags
	var passou: bool = item.m > 0.0 and d["Q"] > item.m
	if d["a_T_max"] < LIMIAR_PROBLEMA:
		tags.append(_tag("quente", "quente demais", d["a_T_max"], true))
	if d["a_T_min"] < LIMIAR_PROBLEMA:
		tags.append(_tag("frio", "frio demais", d["a_T_min"], true))
	if d["a_t_max"] < LIMIAR_PROBLEMA:
		tags.append(_tag("demorou", "tempo demais", d["a_t_max"], true))
	if d["a_Q"] < LIMIAR_PROBLEMA:
		if passou:
			tags.append(_tag("passou", "passou do ponto", d["a_Q"], true))
		else:
			tags.append(_tag("cru", "cru", d["a_Q"], final))
	if d["a_t_min"] < LIMIAR_PROBLEMA:
		tags.append(_tag("pouco_tempo", "pouco tempo", d["a_t_min"], final))
	return tags

static func _tag(chave: String, texto: String, a: float, fixo: bool) -> Dictionary:
	return {"chave": chave, "texto": texto, "perda": 1.0 - a, "fixo": fixo}

# =============================================================================
# AO VIVO — estado de um ingrediente enquanto cozinha (feedback na cena)
# =============================================================================
# Níveis: 0 = ok, 1 = alerta (ainda não perdeu nada), 2 = punição (perdendo agora).
# "perda" = parte IRREVERSÍVEL do aproveitamento (o que já foi perdido e não volta):
#   excesso de calor, falta de calor, tempo demais e cozimento além do ponto.
## Avisos de passar do ponto (aproveitamento do cozimento a_Q).
const PONTO_ALERTA: float = 0.95
const PONTO_MUITO: float = 0.75

static func estado_ao_vivo(acc: Dictionary, item: ItemData, t_agora: float, T_agora: float) -> Dictionary:
	var d = diagnostico_do_acumulador(acc, t_agora)
	_aproveitamento(d, item)
	var niveis := {"quente": 0, "frio": 0, "tempo": 0, "ponto": 0}
	if item == null:
		d["perda"] = 0.0
		d["progresso"] = 0.0
		d["no_ponto"] = false
		d["fase"] = "inutil"
		d["niveis"] = niveis
		d["texto"] = "não serve pra nada?"
		d["problemas"] = problemas(d, null)
		return d

	# ---- calor ----
	# 2 = está além do limite agora (o pico/vale está piorando); 1 = chegando perto (5%).
	if item.T_max > 0.0:
		if T_agora > item.T_max:
			niveis["quente"] = 2
		elif T_agora > 0.95 * item.T_max:
			niveis["quente"] = 1
	if item.T_min > 0.0:
		if T_agora < item.T_min:
			niveis["frio"] = 2
		elif T_agora < 1.05 * item.T_min:
			niveis["frio"] = 1
	# ---- tempo ----
	if item.t_max > 0.0:
		if d["a_t_max"] < 0.99:
			niveis["tempo"] = 2
		elif d["duracao"] >= 0.8 * item.t_max:
			niveis["tempo"] = 1
	# ---- ponto do cozimento ----
	# Passar um pouco do ponto é normal (perde quase nada); só avisa quando a perda
	# começa a pesar (a_Q < PONTO_ALERTA) e alarma quando é grande (a_Q < PONTO_MUITO).
	var passou: bool = item.m > 0.0 and d["Q"] > item.m
	if passou and d["a_Q"] < PONTO_MUITO:
		niveis["ponto"] = 2
	elif passou and d["a_Q"] < PONTO_ALERTA:
		niveis["ponto"] = 1

	var perda: float = d["a_T_max"] * d["a_T_min"] * d["a_t_max"] * (d["a_Q"] if passou else 1.0)
	var progresso: float = clampf(d["Q"] / item.m, 0.0, 1.0) if item.m > 0.0 else 1.0
	if item.t_min > 0.0:
		progresso = minf(progresso, clampf(d["duracao"] / item.t_min, 0.0, 1.0))
	var no_ponto: bool = d["a_Q"] >= 0.9 and d["a_t_min"] >= 0.99

	var texto: String
	if niveis["quente"] == 2: texto = "queimando!"
	elif niveis["frio"] == 2: texto = "esfriando demais!"
	elif niveis["tempo"] == 2: texto = "tempo demais!"
	elif niveis["ponto"] == 2: texto = "passou muito do ponto!"
	elif niveis["quente"] == 1: texto = "quase quente demais"
	elif niveis["frio"] == 1: texto = "quase frio demais"
	elif niveis["tempo"] == 1: texto = "quase passando do tempo"
	elif no_ponto: texto = "no ponto ✓"
	else: texto = "cozinhando %d%%" % int(progresso * 100.0)

	d["perda"] = perda
	d["problemas"] = problemas(d, item, false)
	d["progresso"] = progresso
	d["no_ponto"] = no_ponto
	d["niveis"] = niveis
	d["T_agora"] = T_agora   # temperatura do caldeirão agora (o ícone usa para o aviso de quente/frio)
	# Fase para o gráfico: cru → cozido; "estragou" = já perdeu algo; "punindo" = perdendo agora.
	var punindo_agora := false
	for k in niveis:
		if niveis[k] == 2:
			punindo_agora = true
	if punindo_agora:
		d["fase"] = "punindo"
	elif perda < LIMIAR_PROBLEMA:
		d["fase"] = "estragou"
	elif no_ponto:
		d["fase"] = "cozido"
	else:
		d["fase"] = "cru"
	d["texto"] = texto
	return d

# =============================================================================
# RESULTADO — a poção vira um item comum
# =============================================================================
## Cria o ItemData da poção a partir do resultado de calcular().
static func criar_pocao(resultado: Dictionary, id: String, nome: String) -> ItemData:
	var pocao := ItemData.new()
	pocao.id = id
	pocao.nome = nome
	var A_tipada: Array[PackedFloat32Array] = []
	for linha in resultado.get("A", identidade()):
		A_tipada.append(PackedFloat32Array(linha))
	pocao.A = A_tipada

	# Descrição: ingredientes agrupados com o aproveitamento médio de cada um.
	var grupos := {}
	var ordem: Array = []
	for d in resultado.get("diagnosticos", []):
		var k: String = d.get("nome_exibicao", d["nome"])
		if not grupos.has(k):
			grupos[k] = {"n": 0, "soma_a": 0.0, "problemas": []}
			ordem.append(k)
		grupos[k]["n"] += 1
		grupos[k]["soma_a"] += float(d.get("a", 0.0))
		for t in d.get("problemas", []):
			if not grupos[k]["problemas"].has(t["texto"]):
				grupos[k]["problemas"].append(t["texto"])
	var partes: Array = []
	for k in ordem:
		var g = grupos[k]
		var parte: String = "%s x%d (%d%%)" % [k, g["n"], int(round(100.0 * g["soma_a"] / g["n"]))]
		if not g["problemas"].is_empty():
			parte += " [" + ", ".join(g["problemas"]) + "]"
		partes.append(parte)
	pocao.descricao = "Feita no caldeirão com: " + (", ".join(partes) if not partes.is_empty() else "nada")
	# Atributos de cozimento: média dos ingredientes pesada pelo aproveitamento (a poção
	# pode virar ingrediente de outra receita).
	var at := atributos_da_pocao(resultado.get("diagnosticos", []))
	for k in at:
		pocao.set(k, at[k])
	return pocao

## Adjetivo da qualidade (aproveitamento médio) para poções de um item só, do melhor ao pior:
## [aproveitamento mínimo, adjetivo]. Concordam com "Poção" (feminino).
const ADJETIVOS_QUALIDADE := [
	[0.95, "Concentrada"],
	[0.80, "Refinada"],
	[0.60, ""],          # qualidade normal: sem adjetivo
	[0.40, "Rala"],
	[0.20, "Aguada"],
	[0.0, "Estragada"],
]

static func adjetivo_qualidade(a: float) -> String:
	for par in ADJETIVOS_QUALIDADE:
		if a >= float(par[0]):
			return par[1]
	return ADJETIVOS_QUALIDADE[-1][1]

## Poção feita com um item só (uma ou mais unidades do mesmo item): "Poção de [item] [adjetivo]",
## com o adjetivo pela média do aproveitamento. Vários itens diferentes (ou nenhum) → "".
static func nome_item_unico(diagnosticos: Array) -> String:
	var nome := ""
	var soma_a := 0.0
	for d in diagnosticos:
		var k: String = str(d.get("nome_exibicao", d.get("nome", "")))
		if nome != "" and k != nome:
			return ""
		nome = k
		soma_a += float(d.get("a", 0.0))
	if nome == "":
		return ""
	var adj := adjetivo_qualidade(soma_a / diagnosticos.size())
	return ("Poção de %s %s" % [nome, adj]) if adj != "" else ("Poção de %s" % nome)

## Poção cuja matriz é parecida com a de um ingrediente puro → "Poção de [ingrediente]".
## Parecida = distância (Frobenius) até a matriz do ingrediente <= SEMELHANCA_MAX × o quanto
## esse ingrediente se afasta da identidade. Só ingredientes do banco (não poções feitas).
## Nenhum parecido → "".
const SEMELHANCA_MAX: float = 0.3

static func nome_por_ingrediente(A: Array, database) -> String:
	if database == null:
		return ""
	var dinamicos: Dictionary = database.get("itens_dinamicos") if database.get("itens_dinamicos") != null else {}
	var melhor_nome := ""
	var melhor_rel := INF
	for id in database.get_items():
		if dinamicos.has(id):
			continue
		var item: ItemData = database.get_item(id)
		var Ai := matriz_do_item(item)
		var efeito := CatalogoPocoes.distancia(Ai, identidade())
		if efeito < 0.001:
			continue   # não faz nada (identidade)
		var rel := CatalogoPocoes.distancia(A, Ai) / efeito
		if rel < melhor_rel:
			melhor_rel = rel
			melhor_nome = item.get_nome()
	return ("Poção de " + melhor_nome) if melhor_rel <= SEMELHANCA_MAX else ""

## Média dos atributos dos ingredientes, pesada pelo aproveitamento (a) de cada um.
## Limites (Tmin, Tmax, tmin, tmax) só entram na média de quem TEM aquele limite
## (0 ou >= 999 = sem limite); a folga vai junto com o limite (kmin com Tmin etc.).
## Cozimento (m, s−, s+) só conta quem cozinha (m > 0). Ninguém tem? Fica 0 (sem limite).
static func atributos_da_pocao(diagnosticos: Array) -> Dictionary:
	var grupos := {
		"m": ["s_menos", "s_mais"],
		"T_min": ["k_min"], "T_max": ["k_max"],
		"t_min": ["h_min"], "t_max": ["h_max"],
	}
	var out := {}
	for principal in grupos:
		var soma_w := 0.0
		var somas := {}
		var n := 0
		for campo in [principal] + grupos[principal]:
			somas[campo] = 0.0
		for d in diagnosticos:
			var item: ItemData = d.get("item")
			if item == null:
				continue
			var v: float = float(item.get(principal))
			if v <= 0.0 or (principal.ends_with("max") and v >= 999.0):
				continue   # este ingrediente não tem esse limite
			var w: float = maxf(float(d.get("a", 0.0)), 0.0001)
			soma_w += w
			n += 1
			for campo in somas:
				somas[campo] += float(item.get(campo)) * w
		for campo in somas:
			out[campo] = somas[campo] / soma_w if n > 0 else 0.0
		if n == 0:
			out[principal] = 0.0
	return out

# =============================================================================
# MATRIZES 5x5 (Array de 5 linhas PackedFloat32Array)
# =============================================================================
static func identidade() -> Array:
	var M: Array = []
	for i in N:
		var linha := PackedFloat32Array()
		linha.resize(N)
		linha[i] = 1.0
		M.append(linha)
	return M

## Matriz A do item, ou identidade se o item não existir / estiver malformado.
static func matriz_do_item(item: ItemData) -> Array:
	if item == null:
		return identidade()
	if item.A.size() != N:
		push_warning("[CalculadoraPocao] Matriz de '%s' não é 5x5, usando identidade" % item.id)
		return identidade()
	for linha in item.A:
		if linha.size() != N:
			push_warning("[CalculadoraPocao] Matriz de '%s' não é 5x5, usando identidade" % item.id)
			return identidade()
	return item.A

## B = a·A + (1 − a)·I
static func interpolar(A: Array, a: float) -> Array:
	var B: Array = []
	for i in N:
		var linha := PackedFloat32Array()
		linha.resize(N)
		for j in N:
			linha[j] = a * A[i][j] + (1.0 - a) * (1.0 if i == j else 0.0)
		B.append(linha)
	return B

## X · Y
static func multiplicar(X: Array, Y: Array) -> Array:
	var M: Array = []
	for i in N:
		var linha := PackedFloat32Array()
		linha.resize(N)
		for j in N:
			var soma: float = 0.0
			for k in N:
				soma += X[i][k] * Y[k][j]
			linha[j] = soma
		M.append(linha)
	return M

# =============================================================================
# PRINT — relatório formatado (debug)
# =============================================================================
static func imprimir_relatorio(resultado: Dictionary) -> void:
	print("\n" + "=".repeat(64))
	print("📊 RELATÓRIO DA POÇÃO")
	print("=".repeat(64))
	print("  t_final : %.2f s" % resultado.get("t_final", 0.0))
	print("  nº pontos no histórico: ", resultado.get("historico_T", []).size())
	print("-".repeat(64))

	var diags: Array = resultado.get("diagnosticos", [])
	if diags.is_empty():
		print("  (sem ingredientes)")
	else:
		for d in diags:
			print("  🧪 %s%s" % [d["nome"], "" if d.get("reconhecido", true) else "  (item desconhecido!)"])
			print("     t0      = %.2f s" % d["t0"])
			print("     tf      = %.2f s" % d["tf"])
			print("     duração = %.2f s" % d["duracao"])
			print("     T_max   = %.2f °C" % d["T_max"])
			print("     T_min   = %.2f °C" % d["T_min"])
			print("     T_média = %.2f °C" % d["T_media"])
			print("     Q (∫Tdt)= %.2f" % d["Q"])
			print("     pontos  = %d" % d["n_pontos"])
			if d.has("a"):
				print("     a_Q=%.3f  a_Tmax=%.3f  a_Tmin=%.3f  a_tmin=%.3f  a_tmax=%.3f" % [
					d["a_Q"], d["a_T_max"], d["a_T_min"], d["a_t_min"], d["a_t_max"]])
				print("     ➜ aproveitamento a = %.3f" % d["a"])
				var tags: Array = []
				for t in d.get("problemas", []):
					tags.append("[%s -%d%%]" % [t["texto"], int(round(t["perda"] * 100.0))])
				if not tags.is_empty():
					print("     problemas: ", " ".join(tags))
			print("  " + "-".repeat(60))

	if resultado.has("A"):
		print("  Matriz da poção A (linhas O, C, E, A, N):")
		for linha in resultado["A"]:
			var cels: Array = []
			for v in linha:
				cels.append("%7.3f" % v)
			print("     [", " ".join(cels), " ]")

	print("=".repeat(64) + "\n")
