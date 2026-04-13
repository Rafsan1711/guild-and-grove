extends Control

@onready var status_label = $StatusLabel
@onready var google_btn = $VBoxContainer/GoogleBtn

func _ready():
	Firebase.Auth.login_succeeded.connect(_on_login_success)
	Firebase.Auth.login_failed.connect(_on_login_failed)
	
	google_btn.pressed.connect(_on_google_login_pressed)
	status_label.text = "Sign in to play Guild & Grove"

func _on_google_login_pressed():
	google_btn.disabled = true
	status_label.text = "Opening Google login..."
	Firebase.Auth.get_google_auth_localhost(8060)

func _on_login_success(auth_info: Dictionary):
	status_label.text = "Logged in! Loading..."
	
	GameState.player_uid = auth_info.get("localid", "")
	GameState.player_email = auth_info.get("email", "")
	GameState.player_display_name = auth_info.get("displayname", "Player")
	GameState.player_photo_url = auth_info.get("photouri", "")
	GameState.is_logged_in = true
	
	print("✅ Login success: ", GameState.player_display_name)
	
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/world/MainWorld.tscn")

func _on_login_failed(code, message):
	google_btn.disabled = false
	status_label.text = "Login failed. Try again."
	print("❌ Login error [", code, "]: ", message)
