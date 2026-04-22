extends Node

const LOADING_SCREEN_SCENE = preload("res://scenes/ui/LoadingScreen.tscn")

var _loading_screen: CanvasLayer = null

func _ready() -> void:
	_loading_screen = LOADING_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(_loading_screen)
	_loading_screen.visible = false

func go_to(scene_path: String, use_fake: bool = false, fake_duration: float = 2.0) -> void:
	_loading_screen.visible = true
	_loading_screen.modulate.a = 1.0
	_loading_screen.get_node("Control").modulate.a = 1.0
	if use_fake:
		_loading_screen.start_fake_loading(scene_path, fake_duration)
	else:
		_loading_screen.load_scene(scene_path)
