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
	"clientId" : "",        # firebase_secrets.gd থেকে load হবে
	"clientSecret" : "",    # firebase_secrets.gd থেকে load হবে
	"domainUriPrefix" : "",
	"functionsGeoZone" : "",
}

func _ready() -> void:
	_load_secrets()
	setup_modules(_config)


func _load_secrets() -> void:
	if Engine.has_singleton("FirebaseSecrets"):
		var secrets = Engine.get_singleton("FirebaseSecrets")
		_config["clientId"] = secrets.CLIENT_ID
		_config["clientSecret"] = secrets.CLIENT_SECRET


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
