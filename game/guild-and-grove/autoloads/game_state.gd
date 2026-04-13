extends Node

# Player info (Firebase থেকে আসবে)
var player_uid: String = ""
var player_email: String = ""
var player_display_name: String = ""
var player_photo_url: String = ""

# Game state
var is_logged_in: bool = false
var current_x: float = 0.0
var current_y: float = 0.0

# Inventory (পরে expand করব)
var inventory: Dictionary = {}
var gold: int = 500  # Starting gold

# Server connection state
var socket_connected: bool = false
