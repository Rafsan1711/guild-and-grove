extends Node

const LOADING_SCREEN_SCENE = preload("res://scenes/ui/LoadingScreen.tscn")

var _loading_screen: CanvasLayer = null

func _ready() -> void:
	_loading_screen = LOADING_SCREEN_SCENE.instantiate()
	# FIX Bug 2: _ready() এর সময় root tree busy থাকে।
	# call_deferred দিয়ে পরের frame এ add করলে crash হয় না।
	get_tree().root.add_child.call_deferred(_loading_screen)
	_hide_deferred.call_deferred()

func _hide_deferred() -> void:
	if _loading_screen:
		_loading_screen.visible = false

func go_to(scene_path: String, use_fake: bool = false, fake_duration: float = 2.0) -> void:
	_loading_screen.visible = true

	# FIX Bug 5: CanvasLayer এ .modulate property নেই।
	# Control child এর modulate reset করতে হবে।
	var ctrl: Control = _loading_screen.get_node_or_null("Control")
	if ctrl:
		ctrl.modulate.a = 1.0

	if use_fake:
		_loading_screen.start_fake_loading(scene_path, fake_duration)
	else:
		_loading_screen.load_scene(scene_path)
