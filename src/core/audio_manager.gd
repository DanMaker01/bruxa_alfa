# game_audio_manager.gd
extends Node

@onready var bgm_player: AudioStreamPlayer = $BGM
@onready var bgs_player: AudioStreamPlayer = $BGS
@onready var se_container: Node = $SE

var bgm_volume: float = 1.0
var bgs_volume: float = 1.0
var se_volume: float = 1.0
var master_volume: float = 1.0

var current_bgm: String = ""
var current_bgs: String = ""

var current_bgm_base_volume: float = 1.0
var current_bgs_base_volume: float = 1.0

const BGM_PATH = "res://audio/bgm/"
const BGS_PATH = "res://audio/bgs/"
const SE_PATH = "res://audio/se/"

func _ready():
	if not bgm_player:
		push_error("[AudioManager] BGM não encontrado!")
	if not bgs_player:
		push_error("[AudioManager] BGS não encontrado!")
	if not se_container:
		push_error("[AudioManager] SE não encontrado!")
	if bgm_player:
		bgm_player.process_mode = PROCESS_MODE_ALWAYS
	if bgs_player:
		bgs_player.process_mode = PROCESS_MODE_ALWAYS
	print("[AudioManager] Inicializado!")
	print("  BGM: ", bgm_player != null)
	print("  BGS: ", bgs_player != null)
	print("  SE: ", se_container != null)
	
	# 🔥 DEBUG: LISTA O CONTEÚDO DA PASTA AUDIO
	_debug_list_audio_folder()

func _debug_list_audio_folder():
	"""Lista o conteúdo da pasta audio para debug"""
	print("\n=== 🔍 AUDIO FOLDER DEBUG ===")
	print("Caminho: ", BGM_PATH)
	
	# 🔥 LISTA O CONTEÚDO DA PASTA BGM
	var bgm_dir = DirAccess.open(BGM_PATH)
	if bgm_dir:
		print("\n📁 BGM (", BGM_PATH, "):")
		bgm_dir.list_dir_begin()
		var file_name = bgm_dir.get_next()
		while file_name != "":
			if bgm_dir.current_is_dir():
				print("  📁 ", file_name)
			else:
				print("  📄 ", file_name)
			file_name = bgm_dir.get_next()
		bgm_dir.list_dir_end()
	else:
		print("❌ BGM_DIR não encontrado: ", BGM_PATH)
	
	# 🔥 LISTA O CONTEÚDO DA PASTA BGS
	var bgs_dir = DirAccess.open(BGS_PATH)
	if bgs_dir:
		print("\n📁 BGS (", BGS_PATH, "):")
		bgs_dir.list_dir_begin()
		var file_name = bgs_dir.get_next()
		while file_name != "":
			if bgs_dir.current_is_dir():
				print("  📁 ", file_name)
			else:
				print("  📄 ", file_name)
			file_name = bgs_dir.get_next()
		bgs_dir.list_dir_end()
	else:
		print("❌ BGS_DIR não encontrado: ", BGS_PATH)
	
	# 🔥 LISTA O CONTEÚDO DA PASTA SE
	var se_dir = DirAccess.open(SE_PATH)
	if se_dir:
		print("\n📁 SE (", SE_PATH, "):")
		se_dir.list_dir_begin()
		var file_name = se_dir.get_next()
		while file_name != "":
			if se_dir.current_is_dir():
				print("  📁 ", file_name)
			else:
				print("  📄 ", file_name)
			file_name = se_dir.get_next()
		se_dir.list_dir_end()
	else:
		print("❌ SE_DIR não encontrado: ", SE_PATH)
	
	print("===========================\n")

func play_bgm(filename: String, volume: float = 1.0):
	if filename == "None" or filename == "":
		_stop_bgm()
		return
	
	var path = BGM_PATH + filename + ".mp3"
	
	# 🔥 TENTA CARREGAR DIRETO SEM VERIFICAR
	var stream = ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
	if not stream:
		print("[AudioManager] ❌ BGM não encontrado: ", path)
		return
	
	if current_bgm == filename and bgm_player.playing:
		return
	
	if "loop" in stream:
		stream.loop = true   # BGM sempre em loop (mesmo se o .import veio com loop desligado)
	bgm_player.stop()
	bgm_player.stream = stream
	current_bgm_base_volume = volume
	bgm_player.volume_db = _linear_to_db(volume * bgm_volume * master_volume)
	bgm_player.play()
	current_bgm = filename
	print("[AudioManager] ✅ BGM: ", filename)

func _stop_bgm():
	bgm_player.stop()
	current_bgm = ""

func pause_bgm():
	bgm_player.stream_paused = true

func resume_bgm():
	bgm_player.stream_paused = false

func play_bgs(filename: String, volume: float = 0.5):
	if filename == "None" or filename == "":
		_stop_bgs()
		return
	
	var path = BGS_PATH + filename + ".mp3"
	
	var stream = ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
	if not stream:
		print("[AudioManager] ❌ BGS não encontrado: ", path)
		return
	
	if current_bgs == filename and bgs_player.playing:
		return
	
	if "loop" in stream:
		stream.loop = true   # BGS sempre em loop (vento, pássaros...)
	bgs_player.stop()
	bgs_player.stream = stream
	current_bgs_base_volume = volume
	bgs_player.volume_db = _linear_to_db(volume * bgs_volume * master_volume)
	bgs_player.play()
	current_bgs = filename
	print("[AudioManager] ✅ BGS: ", filename)

func _stop_bgs():
	bgs_player.stop()
	current_bgs = ""

func play_se(filename: String, volume: float = 1.0):
	if filename == "None" or filename == "":
		return
	
	var path = SE_PATH + filename + ".mp3"
	
	var stream = ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
	if not stream:
		print("[AudioManager] ❌ SE não encontrado: ", path)
		return
	
	var player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.name = "SE_" + filename
	player.bus = "SFX"
	player.stream = stream
	player.set_meta("base_volume",volume)
	player.volume_db = _linear_to_db(volume * se_volume * master_volume)
	
	se_container.add_child(player)
	
	player.play()
	player.finished.connect(_on_se_finished.bind(player))
	print("[AudioManager] ✅ SE: ", filename)

func _on_se_finished(player: AudioStreamPlayer):
	if player.get_parent():
		player.queue_free()

func stop_all_se():
	for child in se_container.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	_update_all_volumes()

func set_bgm_volume(volume: float):
	bgm_volume = clamp(volume, 0.0, 1.0)
	_update_bgm_volume()

func set_bgs_volume(volume: float):
	bgs_volume = clamp(volume, 0.0, 1.0)
	_update_bgs_volume()

func set_se_volume(volume: float):
	se_volume = clamp(volume, 0.0, 1.0)
	_update_se_volumes()

func _update_all_volumes():
	_update_bgm_volume()
	_update_bgs_volume()
	_update_se_volumes()


func _update_bgm_volume():
	# 🔥 Recalcula sempre a partir do volume BASE guardado, nunca do volume_db atual
	if bgm_player and bgm_player.playing:
		bgm_player.volume_db = _linear_to_db(current_bgm_base_volume * bgm_volume * master_volume)

func _update_bgs_volume():
	if bgs_player and bgs_player.playing:
		bgs_player.volume_db = _linear_to_db(current_bgs_base_volume * bgs_volume * master_volume)

func _update_se_volumes():
	for child in se_container.get_children():
		if child is AudioStreamPlayer and child.has_meta("base_volume"):
			var base: float = child.get_meta("base_volume")
			child.volume_db = _linear_to_db(base * se_volume * master_volume)


func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

func _db_to_linear(db: float) -> float:
	return pow(10.0, db / 20.0)

func debug():
	print("\n=== AUDIO MANAGER DEBUG ===")
	print("BGM: ", current_bgm, " (", bgm_player.playing if bgm_player else false, ")")
	print("BGS: ", current_bgs, " (", bgs_player.playing if bgs_player else false, ")")
	print("SE ativos: ", se_container.get_child_count())
	print("Master: ", master_volume)
	print("BGM Vol: ", bgm_volume)
	print("BGS Vol: ", bgs_volume)
	print("SE Vol: ", se_volume)
	print("Bus BGM: ", str(bgm_player.bus) if bgm_player else "N/A")
	print("Bus BGS: ", str(bgs_player.bus) if bgs_player else "N/A")
	print("===========================\n")
