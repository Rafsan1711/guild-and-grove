@tool
extends Node


@onready var Auth : FirebaseAuth = $Auth
@onready var Firestore : FirebaseFirestore = $Firestore
@onready var Realtime : FirebaseRealtime = $Realtime
@onready var Storage : FirebaseStorage = $Storage
@onready var Functions : FirebaseFunctions = $Functions
@onready var DynamicLinks : FirebaseDynamicLinks = $DynamicLinks

var _config := {
	"apiKey" : "AIzaSyAFOGYbGjnhiRjnqVlNKxBnmiT5-K71qxs",
	"authDomain" : "medievalcraft-odyssey.firebaseapp.com",
	"databaseURL" : "https://medievalcraft-odyssey-default-rtdb.asia-southeast1.firebasedatabase.app",
	"projectId" : "medievalcraft-odyssey",
	"storageBucket" : "medievalcraft-odyssey.firebasestorage.app",
	"messagingSenderId" : "1037544242630",
	"appId" : "1:1037544242630:web:07cfcadf47cc8f0ee786c7",
	"measurementId" : "G-3459FRP6RH",
	"clientId" : "",
	"clientSecret" : "",
	"domainUriPrefix" : "",
	"functionsGeoZone" : "",
}

func _ready() -> void:
	_load_secrets()
	setup_modules(_config)


func _load_secrets() -> void:
	# secrets.cfg file থেকে load করো (gitignore এ আছে)
	var cfg = ConfigFile.new()
	var err = cfg.load("res://secrets.cfg")
	if err == OK:
		_config["clientId"] = cfg.get_value("firebase", "clientId", "")
		_config["clientSecret"] = cfg.get_value("firebase", "clientSecret", "")
	else:
		printerr("[Firebase] secrets.cfg not found! Google login will not work.")


func setup_modules(config : Dictionary) -> void:
	for key in config:
		_config[key] = config[key]
	for module in get_children():
		if module.has_method("_setup"):
			module._setup(_config)


static func _printerr(error : String) -> void:
	printerr("[Firebase Error] >> " + error)


static func _print(msg : String) -> void:
	print("[Firebase] >> " + msg)
