extends CanvasLayer

@onready var bar_fill: ColorRect = $Control/LoadingBarBG/LoadingBarFill
@onready var bar_bg: ColorRect = $Control/LoadingBarBG
@onready var percent_label: Label = $Control/PercentLabel
@onready var loading_label: Label = $Control/LoadingLabel
@onready var tip_label: Label = $Control/TipLabel
@onready var logo_texture: TextureRect = $Control/LogoTexture
@onready var game_title: Label = $Control/GameTitle
@onready var control: Control = $Control

const TIPS: Array[String] = [
	"Farming gives XP. Plant seeds every morning!",
	"Talk to the Village Elder for hidden quests.",
	"Join a Guild to unlock special buildings.",
	"You can hire NPCs to work in your shop.",
	"Mining at night gives rare gems.",
	"Horses move 3x faster than walking.",
	"Banks give interest on your deposited gold.",
	"Public chats can be joined by nearby players.",
	"Guild donations are tracked — top donors get rewards.",
	"Some trees only grow in certain seasons.",
]

const BAR_MAX_WIDTH: float = 696.0

var _progress: float = 0.0
var _target_scene: String = ""
var _is_loading: bool = false

func _ready() -> void:
	# FIX Bug 3: _ready() তে সরাসরি size set করলে layout system override করে।
	# একটা frame অপেক্ষা করে তারপর center করতে হবে।
	await get_tree().process_frame
	_center_elements()

	tip_label.text = "💡  " + TIPS[randi() % TIPS.size()]
	bar_fill.size.x = 0.0
	percent_label.text = "0%"
	logo_texture.modulate.a = 0.0
	game_title.modulate.a = 0.0

	var tween = create_tween().set_parallel(true)
	tween.tween_property(logo_texture, "modulate:a", 1.0, 0.8)
	tween.tween_property(game_title, "modulate:a", 1.0, 1.0)

	# আরেকটা frame দিয়ে loading শুরু করো
	await get_tree().process_frame
	start_fake_loading("res://scenes/auth/Login_Screen.tscn", 2.5)

func _center_elements() -> void:
	var vp = get_viewport().get_visible_rect().size

	# FIX Bug 3: size set করার সঠিক পদ্ধতি।
	# Control এর anchor Full Rect থাকলে size manually set না করলেও চলে।
	# কিন্তু position গুলো set করা যায়।
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	logo_texture.position = Vector2((vp.x - 200.0) / 2.0, vp.y * 0.22)
	game_title.position = Vector2(0.0, logo_texture.position.y + 215.0)
	game_title.size = Vector2(vp.x, 50.0)

	var bar_y = vp.y * 0.78
	bar_bg.position = Vector2((vp.x - 700.0) / 2.0, bar_y)
	bar_bg.size = Vector2(700.0, 22.0)

	percent_label.position = Vector2(0.0, bar_y + 28.0)
	percent_label.size = Vector2(vp.x, 30.0)

	loading_label.position = Vector2(0.0, bar_y + 60.0)
	loading_label.size = Vector2(vp.x, 28.0)

	tip_label.position = Vector2(vp.x * 0.1, bar_y + 92.0)
	tip_label.size = Vector2(vp.x * 0.8, 30.0)

func load_scene(scene_path: String) -> void:
	_target_scene = scene_path
	_is_loading = true
	loading_label.text = "Loading..."
	ResourceLoader.load_threaded_request(scene_path)

func start_fake_loading(scene_path: String, duration: float = 2.5) -> void:
	_target_scene = scene_path
	_is_loading = false
	loading_label.text = "Loading..."
	var tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	tween.tween_callback(_on_loading_complete)

func _process(_delta: float) -> void:
	if not _is_loading:
		return
	var progress_array: Array = []
	var status = ResourceLoader.load_threaded_get_status(_target_scene, progress_array)
	if progress_array.size() > 0:
		_set_progress(progress_array[0])
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_set_progress(1.0)
			_on_loading_complete()
			_is_loading = false
		ResourceLoader.THREAD_LOAD_FAILED:
			loading_label.text = "Load failed!"
			push_error("Failed to load: " + _target_scene)
			_is_loading = false

func _set_progress(value: float) -> void:
	_progress = clamp(value, 0.0, 1.0)
	var tween = create_tween()
	tween.tween_property(bar_fill, "size:x", BAR_MAX_WIDTH * _progress, 0.1)
	percent_label.text = str(int(_progress * 100.0)) + "%"
	if _progress < 0.3:
		loading_label.text = "Loading assets..."
	elif _progress < 0.6:
		loading_label.text = "Preparing world..."
	elif _progress < 0.9:
		loading_label.text = "Almost ready..."
	else:
		loading_label.text = "Ready!"

func _on_loading_complete() -> void:
	await get_tree().create_timer(0.3).timeout
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(_target_scene)
