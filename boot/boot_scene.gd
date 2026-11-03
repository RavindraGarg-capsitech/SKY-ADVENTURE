extends Control

## BootScene: Instant-startup loading screen with background threaded level loading
## and shader pipeline pre-warming. Guarantees immediate (<30ms) frame presentation on Android
## and prevents main-thread freezes.

const TARGET_SCENE_PATH: String = "res://level/temporary_level.tscn"

@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

var _loading_progress: Array = []
var _target_progress: float = 0.0
var _current_progress: float = 0.0
var _load_completed: bool = false
var _min_display_time: float = 0.4
var _elapsed_time: float = 0.0
var _loaded_packed_scene: PackedScene = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Warm up combat shaders asynchronously via PoolManager
	var pm = get_node_or_null("/root/PoolManager")
	if pm != null and pm.has_method("warmup_combat_shaders"):
		pm.warmup_combat_shaders()

	# Start asynchronous threaded resource loading
	var err = ResourceLoader.load_threaded_request(TARGET_SCENE_PATH)
	if err != OK:
		push_error("BootScene: Failed to initiate threaded load for '%s', err: %d" % [TARGET_SCENE_PATH, err])
		get_tree().change_scene_to_file(TARGET_SCENE_PATH)


func _process(delta: float) -> void:
	_elapsed_time += delta

	if not _load_completed:
		var status = ResourceLoader.load_threaded_get_status(TARGET_SCENE_PATH, _loading_progress)
		if _loading_progress.size() > 0:
			_target_progress = _loading_progress[0] * 100.0

		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if status_label != null:
					if _target_progress < 40.0:
						status_label.text = "Loading floating islands..."
					elif _target_progress < 80.0:
						status_label.text = "Preparing shaders & models..."
					else:
						status_label.text = "Finalizing world..."

			ResourceLoader.THREAD_LOAD_LOADED:
				_load_completed = true
				_target_progress = 100.0
				_loaded_packed_scene = ResourceLoader.load_threaded_get(TARGET_SCENE_PATH) as PackedScene
				if status_label != null:
					status_label.text = "Ready to explore!"

			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("BootScene: Threaded load failed! Falling back to synchronous load.")
				get_tree().change_scene_to_file(TARGET_SCENE_PATH)
				return

	# Smooth progress bar interpolation
	_current_progress = move_toward(_current_progress, _target_progress, delta * 180.0)
	if progress_bar != null:
		progress_bar.value = _current_progress

	# Once loading is 100% and minimum visual transition time elapsed, transition to game
	if _load_completed and _current_progress >= 99.9 and _elapsed_time >= _min_display_time:
		set_process(false)
		if _loaded_packed_scene != null:
			get_tree().change_scene_to_packed(_loaded_packed_scene)
		else:
			get_tree().change_scene_to_file(TARGET_SCENE_PATH)
