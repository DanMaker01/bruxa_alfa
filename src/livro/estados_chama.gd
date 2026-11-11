# estados_chama.gd
# Estados da chama usados nas receitas (o livro fala em cor, nunca em número).
# Cada estado é uma faixa da temperatura do caldo T, com a chama estável.
# O fogo continua em pulsos (abanar / abaixar); o estado só dá nome à faixa.
class_name EstadosChama
extends RefCounted

## id, nome no livro, faixa de T (°C) com a chama estável, cor da bolinha no livro.
const LISTA := [
	{"id": "apagado", "nome": "Apagado", "T_min": -999.0, "T_max": 59.0, "cor": Color(0.35, 0.33, 0.3)},
	{"id": "transparente", "nome": "Transparente", "T_min": 59.0, "T_max": 80.0, "cor": Color(0.75, 0.85, 0.95)},
	{"id": "transparente_grande", "nome": "Transparente grande", "T_min": 80.0, "T_max": 95.0, "cor": Color(0.55, 0.7, 0.9)},
	{"id": "normal", "nome": "Normal", "T_min": 95.0, "T_max": 105.0, "cor": Color(0.9, 0.25, 0.1)},
	{"id": "laranja", "nome": "Laranja", "T_min": 105.0, "T_max": 122.0, "cor": Color(1.0, 0.55, 0.12)},
	{"id": "amarelo", "nome": "Amarelo", "T_min": 122.0, "T_max": 145.0, "cor": Color(0.95, 0.8, 0.15)},
	{"id": "branco", "nome": "Branco", "T_min": 145.0, "T_max": 163.0, "cor": Color(0.85, 0.85, 0.8)},
	{"id": "purpura", "nome": "Púrpura", "T_min": 163.0, "T_max": 195.0, "cor": Color(0.6, 0.35, 0.85)},
	{"id": "negro", "nome": "Negro", "T_min": 195.0, "T_max": 999.0, "cor": Color(0.12, 0.1, 0.3)},
]


static func indice(id: String) -> int:
	for i in LISTA.size():
		if LISTA[i]["id"] == id:
			return i
	return -1

static func nome(id: String) -> String:
	var i := indice(id)
	return LISTA[i]["nome"] if i >= 0 else id

static func cor(id: String) -> Color:
	var i := indice(id)
	return LISTA[i]["cor"] if i >= 0 else Color.GRAY

## Estado pela temperatura do caldo (para transcrever um preparo). Fogo apagado = "apagado".
static func de_T(T: float, fogo_ligado: bool = true) -> String:
	if not fogo_ligado:
		return "apagado"
	for e in LISTA:
		if T >= e["T_min"] and T < e["T_max"]:
			return e["id"]
	return "negro"
