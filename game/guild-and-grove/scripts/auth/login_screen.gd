extends Control

@onready var status_label = $CenterPanel/VBox/StatusLabel
@onready var google_btn = $CenterPanel/VBox/GoogleBtn
@onready var title_label = $CenterPanel/VBox/Title
@onready var video_player = $VideoPlayer

# Video original resolution
const VIDEO_WIDTH = 1584.0
const VIDEO_HEIGHT = 672.0
const VIDEO_RATIO = VIDEO_WIDTH / VIDEO_HEIGHT

# ✅ এই value বাড়ালে zoom out হবে — 1.0 = normal, 0.85 = zoom out
const ZOOM_SCALE = 1.00

# Title pulse
var pulse_time := 0.0

func _ready():
	Firebase.Auth.login_succeeded.connect(_on_login_success)
	Firebase.Auth.login_failed.connect(_on_login_failed)
	google_btn.pressed.connect(_on_google_login_pressed)
	status_label.text = "Sign in to play Guild & Grove"
	
	video_player.play()
	
	get_tree().root.size_changed.connect(_fit_video)
	_fit_video()
	
	# Fade in
	google_btn.modulate.a = 0.0
	title_label.modulate.a = 0.0
	$CenterPanel.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 1.0, 1.5)
	tween.tween_property(google_btn, "modulate:a", 1.0, 2.0)
	tween.tween_property($CenterPanel, "modulate:a", 1.0, 1.2)


func _fit_video():
	var screen_size = get_viewport_rect().size
	var screen_ratio = screen_size.x / screen_size.y
	
	var new_size: Vector2
	
	if screen_ratio > VIDEO_RATIO:
		new_size.x = screen_size.x
		new_size.y = screen_size.x / VIDEO_RATIO
	else:
		new_size.x = screen_size.y * VIDEO_RATIO
		new_size.y = screen_size.y
	
	# ZOOM_SCALE apply করো
	new_size *= ZOOM_SCALE
	
	# Center এ রাখো
	var new_pos: Vector2
	new_pos.x = (screen_size.x - new_size.x) / 2.0
	new_pos.y = (screen_size.y - new_size.y) / 2.0
	
	video_player.position = new_pos
	video_player.size = new_size


func _process(delta):
	if not video_player.is_playing():
		video_player.play()
	
	pulse_time += delta * 1.2
	var pulse = (sin(pulse_time) + 1.0) / 2.0
	title_label.modulate.a = lerp(0.88, 1.0, pulse)


func _on_google_login_pressed():
	google_btn.disabled = true
	
	var tween = create_tween()
	tween.tween_property(google_btn, "scale", Vector2(0.96, 0.96), 0.08)
	tween.tween_property(google_btn, "scale", Vector2(1.0, 1.0), 0.08)
	
	status_label.text = "Opening Google login..."
	Firebase.Auth.get_google_auth_localhost(49152)


func _on_login_success(auth_info: Dictionary):
	status_label.text = "✅ Logged in successfully!"
	
	GameState.player_uid = auth_info.get("localid", "")
	GameState.player_email = auth_info.get("email", "")
	GameState.player_display_name = auth_info.get("displayname", "Player")
	GameState.player_photo_url = auth_info.get("photouri", "")
	GameState.is_logged_in = true
	
	print("✅ Login success! UID: ", GameState.player_uid)
	print("   Name: ", GameState.player_display_name)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property($DarkOverlay, "color:a", 1.0, 1.0)
	tween.tween_property($CenterPanel, "modulate:a", 0.0, 0.8)
	await get_tree().create_timer(1.2).timeout
	# get_tree().change_scene_to_file("res://scenes/world/MainWorld.tscn")


func _on_login_failed(code, message):
	google_btn.disabled = false
	status_label.text = "❌ Login failed. Try again."
	print("Login error [", code, "]: ", message)
	
	var original_x = $CenterPanel.position.x
	var tween = create_tween()
	for i in 3:
		tween.tween_property($CenterPanel, "position:x", original_x + 10, 0.05)
		tween.tween_property($CenterPanel, "position:x", original_x - 10, 0.05)
	tween.tween_property($CenterPanel, "position:x", original_x, 0.05)
