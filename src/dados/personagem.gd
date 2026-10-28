# personagem.gd
# Quem fala: o nome e as faces (fotos) dele, cada uma com um nome.
# Ex.: dados/falantes/bruxa.tres  nome "BRUXA", faces {"normal": bruxa_grande.png, "pensando": bruxa_pensando.png}
# O lado da tela NÃO fica aqui: é de cada mensagem (varia conforme a cena).
# Escrever [nome;foto;pos] no começo do texto continua valendo e tem prioridade.
class_name Personagem
extends Resource

@export var nome: String = ""
## Faces por nome (texto -> imagem). A primeira é a padrão.
@export var faces: Dictionary = {}

## Imagem da face pedida ("" ou inexistente = a primeira).
func foto(face: String = "") -> Texture2D:
	if face != "" and faces.has(face):
		return faces[face]
	if face != "":
		push_warning("[Personagem] " + nome + " não tem a face '" + face + "'")
	return faces.values()[0] if not faces.is_empty() else null

## Última posição usada por cada personagem (posição "padrão" = -1 repete a última).
static var _ultima_posicao: Dictionary = {}

## Monta o Falante (o que a caixa de diálogo usa) com a face e a posição da mensagem.
## posicao -1 (padrão) = a última posição em que este personagem falou (0 se nunca falou).
## Qualquer outro valor passa a ser a nova posição lembrada.
static func falante_de(p: Personagem, face: String, posicao: float) -> Falante:
	if p == null:
		return null
	var chave: String = p.resource_path if p.resource_path != "" else p.nome
	if posicao < 0.0:
		posicao = _ultima_posicao.get(chave, 0.0)
	else:
		_ultima_posicao[chave] = posicao
	var f := Falante.new()
	f.nome = p.nome
	f.foto = p.foto(face)
	f.posicao_nome = posicao
	f.posicao_foto = posicao
	return f
