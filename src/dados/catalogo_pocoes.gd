# catalogo_pocoes.gd
# Poções com nome. Dois catálogos:
#   do jogo     → res://dados/pocoes/catalogo_pocoes.tres (você preenche no Inspector)
#   do jogador  → user://pocoes_nomeadas.tres (nomes que o jogador deu durante o jogo)
# Uma poção nova recebe o nome da poção conhecida mais perto, se a distância entre as
# matrizes for <= distancia_max (do catálogo do jogo). Senão, o jogador pode dar um nome,
# que fica registrado e vale para as próximas poções parecidas.
class_name CatalogoPocoes
extends Resource

const CAMINHO_JOGO := "res://dados/pocoes/catalogo_pocoes.tres"
const CAMINHO_JOGADOR := "user://pocoes_nomeadas.tres"

## Distância máxima (Frobenius entre as matrizes A) para considerar "a mesma poção".
@export var distancia_max: float = 0.05
@export var pocoes: Array[PocaoReferencia] = []

static var _jogo: CatalogoPocoes = null
static var _jogador: CatalogoPocoes = null


## Distância de Frobenius entre duas matrizes 5x5: raiz da soma dos quadrados das diferenças.
static func distancia(a: Array, b: Array) -> float:
	var soma := 0.0
	for i in 5:
		for j in 5:
			var va: float = float(a[i][j]) if i < a.size() and j < a[i].size() else (1.0 if i == j else 0.0)
			var vb: float = float(b[i][j]) if i < b.size() and j < b[i].size() else (1.0 if i == j else 0.0)
			soma += (va - vb) * (va - vb)
	return sqrt(soma)

static func _garantir() -> void:
	if _jogo == null:
		_jogo = load(CAMINHO_JOGO) if ResourceLoader.exists(CAMINHO_JOGO) else CatalogoPocoes.new()
	if _jogador == null:
		_jogador = load(CAMINHO_JOGADOR) if ResourceLoader.exists(CAMINHO_JOGADOR) else CatalogoPocoes.new()

## Procura a poção conhecida mais perto de A nos dois catálogos.
## Devolve {"nome": String ("" se não houver nenhuma), "dist": float, "perto": bool}.
static func procurar(A: Array) -> Dictionary:
	_garantir()
	var melhor := {"nome": "", "dist": INF, "perto": false}
	for cat in [_jogo, _jogador]:
		for ref in cat.pocoes:
			if ref == null or ref.nome == "":
				continue
			var d := distancia(A, ref.A)
			if d < melhor["dist"]:
				melhor = {"nome": ref.nome, "dist": d, "perto": false}
	melhor["perto"] = melhor["nome"] != "" and melhor["dist"] <= _jogo.distancia_max
	return melhor

## O jogador deu nome a uma poção nova: guarda no catálogo do jogador (user://).
static func registrar(nome: String, A: Array, descricao: String = "") -> void:
	_garantir()
	var ref := PocaoReferencia.new()
	ref.nome = nome
	ref.descricao = descricao
	var A_tipada: Array[PackedFloat32Array] = []
	for linha in A:
		A_tipada.append(PackedFloat32Array(linha))
	ref.A = A_tipada
	_jogador.pocoes.append(ref)
	var erro := ResourceSaver.save(_jogador, CAMINHO_JOGADOR)
	if erro != OK:
		push_warning("[CatalogoPocoes] não consegui salvar " + CAMINHO_JOGADOR + " (erro %d)" % erro)
