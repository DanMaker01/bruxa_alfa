# page_selector.gd
# Regra ÚNICA de seleção de página e avaliação de condições.
# Usada pelo evento_base (página visível) e pelo Interpeter (página executada),
# para que os dois nunca discordem sobre qual página está ativa.
#
# Uso: const PageSelector = preload("res://src/core/page_selector.gd")
extends RefCounted


# Regra estilo RPG Maker: vence a ÚLTIMA página cujas condições são TODAS verdadeiras.
# Página sem condições vale sempre. Se nenhuma servir, usa a página 0.
## chave_self: chave do nó do evento (para condições de self-variable).
static func select(pages: Array, game_temp, chave_self: String = "") -> int:
	if pages.is_empty():
		return -1
	for i in range(pages.size() - 1, -1, -1):
		var p = pages[i]
		if p is PaginaData:
			if p.condicoes_ok(game_temp, chave_self):
				return i
		elif evaluate(p.get("cond"), game_temp, chave_self):
			return i
	return 0


# cond pode ser: null (verdadeiro), bool, Condicao, ou {"var": nome, "op": "==", "val": valor}
static func evaluate(cond, game_temp, chave_self: String = "") -> bool:
	if cond == null:
		return true
	if cond is Condicao:
		return cond.avaliar(game_temp, chave_self)
	if typeof(cond) == TYPE_BOOL:
		return cond
	if typeof(cond) != TYPE_DICTIONARY or game_temp == null:
		return false
	var current = game_temp.get_var(str(cond.get("var", "")))
	return compare(current, str(cond.get("op", "==")), cond.get("val", null))


# Comparação segura: nunca gera erro de runtime com null ou tipos diferentes.
static func compare(a, op: String, b) -> bool:
	var numeric = is_number(a) and is_number(b)
	match op:
		"==":
			return is_equal_approx(float(a), float(b)) if numeric else (typeof(a) == typeof(b) and a == b)
		"!=":
			return not is_equal_approx(float(a), float(b)) if numeric else not (typeof(a) == typeof(b) and a == b)
		">":
			return numeric and float(a) > float(b)
		"<":
			return numeric and float(a) < float(b)
		">=":
			return numeric and float(a) >= float(b)
		"<=":
			return numeric and float(a) <= float(b)
	push_warning("[PageSelector] Operador desconhecido: " + op)
	return false


static func is_number(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
