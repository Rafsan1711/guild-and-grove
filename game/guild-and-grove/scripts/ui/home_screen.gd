extends Control

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var play_btn: Button = $CenterContainer/VBoxContainer/PlayBtn
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsBtn
@onready var credits_btn: Button = $CenterContainer/VBoxContainer/CreditsBtn
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var version_label: Label = $VersionLabel

var _pulse_time: float = 0.0

func _ready() -> void:
	video_player.play()
	_apply_button_styles()
	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	play_btn.mouse_entered.connect(func(): _btn_hover(play_btn))
	play_btn.mouse_exited.connect(func(): _btn_unhover(play_btn))
	settings_btn.mouse_entered.connect(func(): _btn_hover(settings_btn))
	settings_btn.mouse_exited.connect(func(): _btn_unhover(settings_btn))
	credits_btn.mouse_entered.connect(func(): _btn_hover(credits_btn))
	credits_btn.mouse_exited.connect(func(): _btn_unhover(credits_btn))
	var vp = get_viewport_rect().size
	version_label.position = Vector2(20.0, vp.y - 30.0)
	version_label.size = Vector2(400.0, 24.0)
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _apply_button_styles() -> void:
	var play_n = StyleBoxFlat.new()
	play_n.bg_color = Color("#F4A53A")
	play_n.set_corner_radius_all(10)
	play_btn.add_theme_stylebox_override("normal", play_n)
	play_btn.add_theme_color_override("font_color", Color("#0D1B12"))
	var play_h = StyleBoxFlat.new()
	play_h.bg_color = Color("#FFB84A")
	play_h.set_corner_radius_all(10)
	play_btn.add_theme_stylebox_override("hover", play_h)

	for btn: Button in [settings_btn, credits_btn]:
		var n = StyleBoxFlat.new()
		n.bg_color = Color(0.05, 0.1, 0.05, 0.75)
		n.border_width_left = 2
		n.border_width_top = 2
		n.border_width_right = 2
		n.border_width_bottom = 2
		n.border_color = Color("#2D5A27")
		n.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", n)
		btn.add_theme_color_override("font_color", Color("#EAE8D5"))
		var h = StyleBoxFlat.new()
		h.bg_color = Color(0.15, 0.25, 0.1, 0.9)
		h.border_width_left = 2
		h.border_width_top = 2
		h.border_width_right = 2
		h.border_width_bottom = 2
		h.border_color = Color("#F4A53A")
		h.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_color_override("font_color_hover", Color("#F4A53A"))

func _process(delta: float) -> void:
	_pulse_time += delta * 0.8
	title_label.modulate.a = lerp(0.85, 1.0, (sin(_pulse_time) + 1.0) / 2.0)
	if not video_player.is_playing():
		video_player.play()

func _btn_hover(btn: Button) -> void:
	create_tween().tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)

func _btn_unhover(btn: Button) -> void:
	create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)

func _on_play_pressed() -> void:
	var t = create_tween()
	t.tween_property(play_btn, "scale", Vector2(0.95, 0.95), 0.08)
	t.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.08)
	await t.finished
	# ROADMAP-3 এ Game World যাবে এখানে
	print("PLAY — Game World loads in Roadmap 3!")

func _on_settings_pressed() -> void:
	var t = create_tween()
	t.tween_property(settings_btn, "scale", Vector2(0.95, 0.95), 0.08)
	t.tween_property(settings_btn, "scale", Vector2(1.0, 1.0), 0.08)
	await t.finished
	SceneManager.go_to("res://scenes/ui/SettingsScreen.tscn", true, 0.5)

func _on_credits_pressed() -> void:
	print("Credits — coming soon!")
