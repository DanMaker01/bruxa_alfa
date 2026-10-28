# passo_rota.gd
# Um passo do movimento autônomo de uma página (PaginaData.movimento = ROTA).
# O evento executa os passos em ordem, sozinho, sem travar o jogo; o gatilho
# da página (clique, toque) continua funcionando normalmente.
@tool
class_name PassoRota
extends Resource

enum Tipo {
	MOVER,            ## anda "distancia" px (positivo = direita, negativo = esquerda)
	FRENTE,           ## anda "distancia" px para onde está olhando
	TRAS,             ## anda "distancia" px de costas (não vira)
	ALEATORIO,        ## anda até "distancia" px para um lado sorteado
	PULAR,            ## pulo em arco: "distancia" px para frente (0 = no lugar), "altura" px
	OLHAR,            ## vira para um lado (veja "olhar")
	FIXAR_DIRECAO,    ## liga/desliga: andando não vira para o lado do movimento
	ESPERAR,          ## espera "segundos" (ou um tempo sorteado até "segundos_max")
	BALAO,            ## balão de emoção acima do evento
	VELOCIDADE,       ## troca a velocidade dos próximos passos (px/s)
	ANIMACAO,         ## troca a animação ("" volta para a da página)
}
enum Olhar { ESQ, DIR, INVERTER, PARA_BRUXA, LONGE_DA_BRUXA, ALEATORIO }

@export var tipo: Tipo = Tipo.ESPERAR:
	set(v):
		tipo = v
		notify_property_list_changed()
## Chance de o passo acontecer (1 = sempre, 0.3 = 30% das vezes). Se não acontecer, pula.
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0

@export var distancia: float = 48.0
@export var altura: float = 24.0
@export var olhar: Olhar = Olhar.ALEATORIO
@export var fixar: bool = true
@export var segundos: float = 1.0
## Maior que "segundos" = sorteia um tempo entre os dois.
@export var segundos_max: float = 0.0
@export var emocao: CmdBalao.Emocao = CmdBalao.Emocao.NOTA
@export var velocidade: float = 80.0
@export var animacao: String = ""

func _validate_property(property: Dictionary) -> void:
	var campos := {
		"distancia": [Tipo.MOVER, Tipo.FRENTE, Tipo.TRAS, Tipo.ALEATORIO, Tipo.PULAR],
		"altura": [Tipo.PULAR],
		"olhar": [Tipo.OLHAR],
		"fixar": [Tipo.FIXAR_DIRECAO],
		"segundos": [Tipo.ESPERAR, Tipo.BALAO],
		"segundos_max": [Tipo.ESPERAR],
		"emocao": [Tipo.BALAO],
		"velocidade": [Tipo.VELOCIDADE],
		"animacao": [Tipo.ANIMACAO],
	}
	if campos.has(property.name) and not (tipo in campos[property.name]):
		property.usage = PROPERTY_USAGE_STORAGE
