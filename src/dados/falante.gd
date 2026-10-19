# falante.gd
# Quem fala numa mensagem: nome (plaquinha) e foto, com as posições.
# Montado pela caixa de diálogo a partir do começo do texto:
#   [nome;foto;pos] texto      (pos vale para o nome e a foto: 0% = esquerda, 100% = direita)
# Ex.: [BRUXA;bruxa_grande;0] Entre logo.   [???;;100] Tem alguém aí?
# (o formato antigo [nome;pos_nome;foto;pos_foto] ainda é aceito)
class_name Falante
extends Resource

const PASTA_FOTOS := "res://assets/game_faces/"

@export var nome: String = ""
## 0% = esquerda da caixa, 100% = direita.
@export_range(0.0, 100.0, 1.0, "suffix:%") var posicao_nome: float = 0.0
@export var foto: Texture2D
## 0% = encostada à esquerda da tela, 100% = à direita.
@export_range(0.0, 100.0, 1.0, "suffix:%") var posicao_foto: float = 0.0
@export var altura_foto: float = 420.0
@export var espelhar_foto: bool = false

static var _cache_fotos: Dictionary = {}


## Lê "[nome;foto;pos] texto". Devolve {"falante": Falante ou null, "texto": String}.
## Campos vazios: sem nome / sem foto / posição 0.
## Com 4 campos, lê o formato antigo [nome;pos_nome;foto;pos_foto].
static func do_texto(msg: String) -> Dictionary:
	if not msg.begins_with("["):
		return {"falante": null, "texto": msg}
	var fim := msg.find("]")
	if fim < 1:
		return {"falante": null, "texto": msg}
	var campos := msg.substr(1, fim - 1).split(";")
	var f := Falante.new()
	if campos.size() >= 4:
		# formato antigo: [nome;pos_nome;foto;pos_foto]
		f.nome = campos[0].strip_edges()
		f.posicao_nome = _numero(campos[1])
		f.foto = _carregar_foto(campos[2].strip_edges())
		f.posicao_foto = _numero(campos[3])
	else:
		# [nome;foto;pos]
		while campos.size() < 3:
			campos.append("")
		f.nome = campos[0].strip_edges()
		f.foto = _carregar_foto(campos[1].strip_edges())
		f.posicao_nome = _numero(campos[2])
		f.posicao_foto = f.posicao_nome
	return {"falante": f, "texto": msg.substr(fim + 1).strip_edges()}

static func _numero(txt: String) -> float:
	txt = txt.strip_edges().trim_suffix("%")
	return clampf(float(txt), 0.0, 100.0) if txt.is_valid_float() else 0.0

static func _carregar_foto(nome_foto: String) -> Texture2D:
	if nome_foto == "":
		return null
	if not _cache_fotos.has(nome_foto):
		var caminho := nome_foto if nome_foto.begins_with("res://") else PASTA_FOTOS + nome_foto
		if caminho.get_extension() == "":
			caminho += ".png"
		if ResourceLoader.exists(caminho):
			_cache_fotos[nome_foto] = load(caminho)
		else:
			push_warning("[Falante] foto não encontrada: " + caminho)
			_cache_fotos[nome_foto] = null
	return _cache_fotos[nome_foto]
