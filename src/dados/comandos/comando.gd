# comando.gd
# Base de todos os comandos de evento. Cada subclasse sabe se executar:
#   executar(interp, ev) -> AVANCAR | MANTER
# AVANCAR: o Interpreter passa para o próximo comando.
# MANTER:  o comando cuidou do índice (pulo, pausa, espera) e o Interpreter não mexe.
# Comandos são Resources compartilhados entre execuções: nunca guarde estado
# no próprio comando, só em `ev` (EventInstance).
# to_dict() fica só para debug/log ({nome, args}).
class_name Comando
extends Resource

const AVANCAR := 0
const MANTER := 1


func to_dict() -> Dictionary:
	return {"nome": "", "args": []}


func nome_cmd() -> String:
	return str(to_dict().get("nome", get_script().get_global_name()))


func executar(_interp, _ev) -> int:
	return AVANCAR
