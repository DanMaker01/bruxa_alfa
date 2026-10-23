# catalogo_pocoes.gd
# Poções com nome. Dois catálogos:
#   do jogo     → res://dados/pocoes/catalogo_pocoes.tres (você preenche no Inspector)
#   do jogador  → GameTemp.pocoes_nomeadas (nomes que o jogador deu; só valem nesta sessão/save)
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
	# catálogo do jogador mora no GameTemp (não é salvo em user://)
	var gt = _game_temp()
	if gt:
		_jogador = gt.pocoes_nomeadas
	elif _jogador == null:
		_jogador = CatalogoPocoes.new()

static func _game_temp():
	var arvore = Engine.get_main_loop()
	return arvore.root.get_node_or_null("Main/GameManager/GameTemp") if arvore is SceneTree else null

## Erro relativo de A em relação à poção "nome" do catálogo do jogo:
## distância(A, ideal) / distância(identidade, ideal). 0 = perfeita; 1 = tão longe quanto água pura.
## −1 se a poção não existir.
static func erro_relativo(nome: String, A: Array) -> float:
	_garantir()
	for ref in _jogo.pocoes:
		if ref and ref.nome == nome:
			var base := distancia(CalculadoraPocao.identidade(), ref.A)
			return distancia(A, ref.A) / maxf(base, 0.0001)
	return -1.0

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
