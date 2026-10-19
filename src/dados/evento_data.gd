# evento_data.gd
# Um evento do jogo. O nó EventoBase no mapa aponta para um EventoData.
# O mesmo EventoData pode ser usado por vários nós (ex.: a maçã nas três casas).
class_name EventoData
extends Resource

## Identificador do evento. Usado por move_event / parar_movimento para achar o nó no mapa.
@export var id: String = ""
@export var paginas: Array[PaginaData] = []
