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
## Cada poção conhecida é um .tres (PocaoReferencia) nesta pasta (e subpastas, ex.: proibidas/).
## As que não estiverem na lista do catálogo entram sozinhas ao carregar.
const PASTA_POCOES := "res://dados/pocoes/"

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
		_incluir_pasta(_jogo, PASTA_POCOES)
	# catálogo do jogador mora no GameTemp (não é salvo em user://)
	var gt = _game_temp()
	if gt:
		_jogador = gt.pocoes_nomeadas
	elif _jogador == null:
		_jogador = CatalogoPocoes.new()

## Acrescenta ao catálogo as poções (.tres) da pasta que ainda não estão na lista.
static func _incluir_pasta(cat: CatalogoPocoes, pasta: String) -> void:
	var dir := DirAccess.open(pasta)
	if dir == null:
		return
	var ja := {}
	for ref in cat.pocoes:
		if ref:
			ja[ref.resource_path] = true
	for sub in dir.get_directories():
		_incluir_pasta(cat, pasta.path_join(sub))
	for arq in dir.get_files():
		var nome := arq.trim_suffix(".remap")   # no jogo exportado os .tres viram .tres.remap
		if not nome.ends_with(".tres"):
			continue
		var caminho := pasta.path_join(nome)
		if ja.has(caminho) or caminho == CAMINHO_JOGO:
			continue
		var r = load(caminho)
		if r is PocaoReferencia:
			cat.pocoes.append(r)

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

## Efeito da poção do catálogo do jogo com este nome (vazio se não houver).
static func efeito_de(nome: String) -> Array[Comando]:
	_garantir()
	for ref in _jogo.pocoes:
		if ref and ref.nome == nome:
			return ref.efeito.duplicate()
	var vazio: Array[Comando] = []
	return vazio

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
