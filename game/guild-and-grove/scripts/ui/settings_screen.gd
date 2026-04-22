extends Control

@onready var bg: ColorRect = $BackgroundRect
@onready var panel: PanelContainer = $PanelContainer
@onready var music_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $PanelContainer/MarginContainer/VBoxContainer/FullscreenCheck
@onready var back_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/BackBtn

func _ready() -> void:
	music_slider.value = AudioManager.get_music_volume_linear()
	sfx_slider.value = AudioManager.get_sfx_volume_linear()
	fullscreen_check.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	music_slider.value_changed.connect(func(v): AudioManager.set_music_volume(v))
	sfx_slider.value_changed.connect(func(v): AudioManager.set_sfx_volume(v))
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_btn.pressed.connect(_on_back_pressed)

	# Back button style
	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.1, 0.18, 0.1, 0.9)
	n.border_width_left = 2
	n.border_width_top = 2
	n.border_width_right = 2
	n.border_width_bottom = 2
	n.border_color = Color("#2D5A27")
	n.set_corner_radius_all(8)
	back_btn.add_theme_stylebox_override("normal", n)
	back_btn.add_theme_color_override("font_color", Color("#EAE8D5"))
	var h = StyleBoxFlat.new()
	h.bg_color = Color(0.2, 0.35, 0.15, 0.9)
	h.border_width_left = 2
	h.border_width_top = 2
	h.border_width_right = 2
	h.border_width_bottom = 2
	h.border_color = Color("#F4A53A")
	h.set_corner_radius_all(8)
	back_btn.add_theme_stylebox_override("hover", h)
	back_btn.add_theme_color_override("font_color_hover", Color("#F4A53A"))

	# Fade in
	bg.color.a = 0.0
	panel.modulate.a = 0.0
	var t = create_tween().set_parallel(true)
	t.tween_property(bg, "color:a", 0.72, 0.25)
	t.tween_property(panel, "modulate:a", 1.0, 0.25)

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(bg, "color:a", 0.0, 0.2)
	t.tween_property(panel, "modulate:a", 0.0, 0.2)
	await t.finished
	SceneManager.go_to("res://scenes/ui/HomeScreen.tscn", true, 0.5)
