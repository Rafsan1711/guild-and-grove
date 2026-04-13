@tool
class_name FirebaseAuth
extends HTTPRequest


const _API_VERSION := "v1"

signal auth_request(result_code, result_content)
signal signup_succeeded(auth_result)
signal login_succeeded(auth_result)
signal login_failed(code, message)
signal signup_failed(code, message)
signal userdata_received(userdata)
signal token_exchanged(successful)
signal token_refresh_succeeded(auth_result)
signal logged_out()

const RESPONSE_SIGNUP := "identitytoolkit#SignupNewUserResponse"
const RESPONSE_SIGNIN := "identitytoolkit#VerifyPasswordResponse"
const RESPONSE_ASSERTION := "identitytoolkit#VerifyAssertionResponse"
const RESPONSE_USERDATA := "identitytoolkit#GetAccountInfoResponse"
const RESPONSE_CUSTOM_TOKEN := "identitytoolkit#VerifyCustomTokenResponse"

var _base_url : String
var _refresh_request_base_url
var _signup_request_url : String
var _signin_with_oauth_request_url : String
var _signin_request_url : String
var _signin_custom_token_url : String
var _userdata_request_url : String
var _oobcode_request_url : String
var _delete_account_request_url : String
var _update_account_request_url : String
var _refresh_request_url : String

var _google_auth_request_url := "https://accounts.google.com/o/oauth2/v2/auth?"
var _google_token_request_url := "https://oauth2.googleapis.com/token"

var auth := {}
var _needs_refresh := false
var is_busy := false

# TCP server — Google OAuth redirect catch করার জন্য
var tcp_server : TCPServer = TCPServer.new()
var tcp_timer : Timer = Timer.new()
var tcp_timeout : float = 0.3
var _oauth_port : int = 49152

# দ্বিতীয় HTTPRequest node — token exchange এর জন্য আলাদা
var _token_http : HTTPRequest

var _headers := [
	"Accept: application/json",
	"Content-Type: application/json"
]

# Google OAuth এর জন্য আলাদা headers (JSON না, form encoded)
var _token_exchange_headers := [
	"Content-Type: application/x-www-form-urlencoded"
]

var requesting := -1

enum Requests {
	NONE = -1,
	EXCHANGE_TOKEN,
	LOGIN_WITH_OAUTH
}

var auth_request_type := -1

enum Auth_Type {
	NONE = -1,
	LOGIN_EP,
	LOGIN_ANON,
	LOGIN_CT,
	LOGIN_OAUTH,
	SIGNUP_EP
}

var _login_request_body := {
	"email":"",
	"password":"",
	"returnSecureToken": true,
}

var _oauth_login_request_body := {
	"postBody":"",
	"requestUri":"",
	"returnIdpCredential":true,
	"returnSecureToken":true
}

var _anonymous_login_request_body := {
	"returnSecureToken":true
}

var _refresh_request_body := {
	"grant_type":"refresh_token",
	"refresh_token":"",
}

var _custom_token_body := {
	"token":"",
	"returnSecureToken":true
}

var _password_reset_body := {
	"requestType":"password_reset",
	"email":"",
}

var _change_email_body := {
	"idToken":"",
	"email":"",
	"returnSecureToken": true,
}

var _change_password_body := {
	"idToken":"",
	"password":"",
	"returnSecureToken": true,
}

var _account_verification_body := {
	"requestType":"verify_email",
	"idToken":"",
}

var _update_profile_body := {
	"idToken":"",
	"displayName":"",
	"photoUrl":"",
	"deleteAttribute":"",
	"returnSecureToken":true
}


func _ready() -> void:
	# Main HTTP request — Firebase API calls এর জন্য
	connect("request_completed", _on_FirebaseAuth_request_completed)

	# TCP timer setup
	tcp_timer.wait_time = tcp_timeout
	tcp_timer.timeout.connect(_tcp_stream_timer)

	# আলাদা HTTPRequest node — Google token exchange এর জন্য
	_token_http = HTTPRequest.new()
	add_child(_token_http)
	_token_http.request_completed.connect(_on_token_exchange_completed)


func _setup(config_json : Dictionary) -> void:
	_signup_request_url = "accounts:signUp?key=" + config_json.apiKey
	_signin_request_url = "accounts:signInWithPassword?key=" + config_json.apiKey
	_signin_custom_token_url = "accounts:signInWithCustomToken?key=" + config_json.apiKey
	_signin_with_oauth_request_url = "accounts:signInWithIdp?key=" + config_json.apiKey
	_userdata_request_url = "accounts:lookup?key=" + config_json.apiKey
	_refresh_request_url = "/v1/token?key=" + config_json.apiKey
	_oobcode_request_url = "accounts:sendOobCode?key=" + config_json.apiKey
	_delete_account_request_url = "accounts:delete?key=" + config_json.apiKey
	_update_account_request_url = "accounts:update?key=" + config_json.apiKey
	_base_url = "https://identitytoolkit.googleapis.com/" + _API_VERSION + "/"
	_refresh_request_base_url = "https://securetoken.googleapis.com"


func _is_ready() -> bool:
	if is_busy:
		Firebase._printerr("Firebase Auth is currently busy")
		return false
	if _base_url == "":
		Firebase._printerr("Firebase hasn't been configured")
		return false
	return true


func is_logged_in() -> bool:
	return auth != null and auth.has("idtoken")


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GOOGLE OAUTH — সম্পূর্ণ নতুন, সঠিক flow
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_google_auth_localhost(port : int = 49152) -> void:
	_oauth_port = port
	var redirect_uri = "http://localhost:%d/" % port

	# Google OAuth URL তৈরি করো
	var url = _google_auth_request_url
	url += "client_id=" + Firebase._config.clientId
	url += "&redirect_uri=" + redirect_uri.uri_encode()
	url += "&response_type=code"
	url += "&scope=email%20openid%20profile"
	url += "&access_type=offline"
	url += "&prompt=select_account"

	print("[Firebase Auth] Opening Google OAuth URL...")

	# Browser খোলো
	OS.shell_open(url)

	# TCP server চালু করো — redirect catch করতে
	await get_tree().create_timer(1.0).timeout
	var err = tcp_server.listen(port, "127.0.0.1")
	if err != OK:
		Firebase._printerr("TCP server listen failed on port %d: %s" % [port, err])
		return

	add_child(tcp_timer)
	tcp_timer.start()
	print("[Firebase Auth] Waiting for Google redirect on port %d..." % port)


func _tcp_stream_timer() -> void:
	if not tcp_server.is_connection_available():
		return

	var peer : StreamPeerTCP = tcp_server.take_connection()
	if peer == null:
		return

	# Browser এর HTTP request পড়ো
	await get_tree().create_timer(0.1).timeout
	var raw = ""
	var tries = 0
	while raw == "" and tries < 10:
		raw = peer.get_utf8_string(peer.get_available_bytes())
		if raw == "":
			await get_tree().create_timer(0.05).timeout
		tries += 1

	# Browser কে success page দেখাও
	var html = "<html><body style='font-family:sans-serif;text-align:center;padding:50px'>"
	html += "<h2>✅ Login successful!</h2><p>You can close this tab and return to the game.</p></body></html>"
	var response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [html.length(), html]
	peer.put_data(response.to_utf8_buffer())
	await get_tree().create_timer(0.1).timeout
	peer.disconnect_from_host()

	# TCP server বন্ধ করো
	tcp_timer.stop()
	remove_child(tcp_timer)
	tcp_server.stop()

	print("[Firebase Auth] Raw TCP data received, length: %d" % raw.length())

	# auth code parse করো
	var code = _parse_auth_code(raw)
	if code == "":
		Firebase._printerr("Could not parse auth code from OAuth redirect")
		login_failed.emit("parse_error", "Could not parse auth code")
		return

	print("[Firebase Auth] Auth code parsed successfully, length: %d" % code.length())

	# Google এ token exchange করো
	_exchange_code_for_token(code)


func _parse_auth_code(raw : String) -> String:
	# Raw HTTP format: "GET /?code=4%2F0AX...&scope=... HTTP/1.1\r\n..."
	# অথবা error: "GET /?error=access_denied&..."

	if "error=" in raw:
		var err_part = raw.split("error=")[1].split("&")[0].split(" ")[0]
		Firebase._printerr("OAuth error from Google: " + err_part)
		return ""

	if "code=" not in raw:
		Firebase._printerr("No code found in OAuth redirect")
		return ""

	# প্রথম line নাও
	var first_line = raw.split("\r\n")[0]
	if "code=" not in first_line:
		# fallback — পুরো raw এ খোঁজো
		first_line = raw

	var after_code = first_line.split("code=")[1]

	# & অথবা space অথবা HTTP/ যেটা আগে আসে সেখানে cut করো
	var code = after_code
	for delimiter in ["&", " ", "\r", "\n"]:
		if delimiter in code:
			code = code.split(delimiter)[0]

	# URL decode করো (%2F → /)
	code = code.uri_decode()

	return code.strip_edges()


func _exchange_code_for_token(code : String) -> void:
	print("[Firebase Auth] Exchanging code for token...")

	var redirect_uri = "http://localhost:%d/" % _oauth_port

	# Form-encoded body — JSON না!
	# Google token endpoint এ JSON accept করে না
	var body = "code=" + code.uri_encode()
	body += "&client_id=" + Firebase._config.clientId.uri_encode()
	body += "&client_secret=" + Firebase._config.clientSecret.uri_encode()
	body += "&redirect_uri=" + redirect_uri.uri_encode()
	body += "&grant_type=authorization_code"

	var err = _token_http.request(
		_google_token_request_url,
		_token_exchange_headers,
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		Firebase._printerr("Token exchange request failed: %s" % err)
		login_failed.emit("request_error", "Token exchange failed")


func _on_token_exchange_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_str = body.get_string_from_utf8()
	print("[Firebase Auth] Token exchange response code: %d" % response_code)

	var res = JSON.parse_string(body_str)
	if res == null:
		Firebase._printerr("Token exchange: failed to parse JSON response")
		login_failed.emit("parse_error", "Failed to parse token response")
		return

	if response_code != 200:
		var err_msg = res.get("error_description", res.get("error", "Unknown error"))
		Firebase._printerr("Token exchange failed: " + err_msg)
		login_failed.emit(res.get("error", "token_error"), err_msg)
		return

	# Google থেকে id_token এবং access_token পেলাম
	var id_token = res.get("id_token", "")
	var access_token = res.get("access_token", "")

	if id_token == "":
		Firebase._printerr("No id_token in token exchange response")
		login_failed.emit("no_id_token", "No id_token received")
		return

	print("[Firebase Auth] Token exchange successful! Now signing into Firebase...")

	# Firebase signInWithIdp call করো
	_sign_in_with_firebase(id_token, access_token)


func _sign_in_with_firebase(id_token: String, access_token: String) -> void:
	if not _is_ready():
		return

	is_busy = true
	requesting = Requests.LOGIN_WITH_OAUTH
	auth_request_type = Auth_Type.LOGIN_OAUTH

	# postBody এ id_token দিতে হবে
	var post_body = "id_token=" + id_token + "&providerId=google.com"
	if access_token != "":
		post_body += "&access_token=" + access_token

	var firebase_body = {
		"postBody": post_body,
		"requestUri": "http://localhost",
		"returnIdpCredential": true,
		"returnSecureToken": true
	}

	request(
		_base_url + _signin_with_oauth_request_url,
		_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(firebase_body)
	)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STANDARD AUTH METHODS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func signup_with_email_and_password(email : String, password : String) -> void:
	if _is_ready():
		is_busy = true
		_login_request_body.email = email
		_login_request_body.password = password
		auth_request_type = Auth_Type.SIGNUP_EP
		request(_base_url + _signup_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_login_request_body))


func login_anonymous() -> void:
	if _is_ready():
		is_busy = true
		auth_request_type = Auth_Type.LOGIN_ANON
		request(_base_url + _signup_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_anonymous_login_request_body))


func login_with_email_and_password(email : String, password : String) -> void:
	if _is_ready():
		is_busy = true
		_login_request_body.email = email
		_login_request_body.password = password
		auth_request_type = Auth_Type.LOGIN_EP
		request(_base_url + _signin_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_login_request_body))


func login_with_custom_token(token : String) -> void:
	if _is_ready():
		is_busy = true
		_custom_token_body.token = token
		auth_request_type = Auth_Type.LOGIN_CT
		request(_base_url + _signin_custom_token_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_custom_token_body))


func get_user_data() -> void:
	if _is_ready():
		is_busy = true
		if not is_logged_in():
			print_debug("Not logged in")
			is_busy = false
			return
		request(_base_url + _userdata_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify({"idToken": auth.idtoken}))


func change_user_email(email : String) -> void:
	if _is_ready():
		is_busy = true
		_change_email_body.email = email
		_change_email_body.idToken = auth.idtoken
		request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_change_email_body))


func change_user_password(password : String) -> void:
	if _is_ready():
		is_busy = true
		_change_password_body.password = password
		_change_password_body.idToken = auth.idtoken
		request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_change_password_body))


func update_account(idToken : String, displayName : String, photoUrl : String, deleteAttribute : PackedStringArray, returnSecureToken : bool) -> void:
	if _is_ready():
		is_busy = true
		_update_profile_body.idToken = idToken
		_update_profile_body.displayName = displayName
		_update_profile_body.photoUrl = photoUrl
		_update_profile_body.deleteAttribute = deleteAttribute
		_update_profile_body.returnSecureToken = returnSecureToken
		request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_update_profile_body))


func send_account_verification_email() -> void:
	if _is_ready():
		is_busy = true
		_account_verification_body.idToken = auth.idtoken
		request(_base_url + _oobcode_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_account_verification_body))


func send_password_reset_email(email : String) -> void:
	if _is_ready():
		is_busy = true
		_password_reset_body.email = email
		request(_base_url + _oobcode_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_password_reset_body))


func delete_user_account() -> void:
	if _is_ready():
		is_busy = true
		request(_base_url + _delete_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify({"idToken": auth.idtoken}))


func manual_token_refresh(auth_data) -> void:
	auth = get_clean_keys(auth_data)
	var refresh_token = auth.get("refreshtoken", auth.get("refresh_token", ""))
	if refresh_token == "":
		return
	_needs_refresh = true
	_refresh_request_body.refresh_token = refresh_token
	request(_refresh_request_base_url + _refresh_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_refresh_request_body))


func begin_refresh_countdown() -> void:
	auth = get_clean_keys(auth)
	var refresh_token = auth.get("refreshtoken", auth.get("refresh_token", ""))
	var expires_in = int(auth.get("expiresin", auth.get("expires_in", 3600)))
	if auth.has("userid"):
		auth.localid = auth.userid
	_needs_refresh = true
	token_refresh_succeeded.emit(auth)
	await get_tree().create_timer(float(expires_in)).timeout
	if refresh_token != "":
		_refresh_request_body.refresh_token = refresh_token
		request(_refresh_request_base_url + _refresh_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_refresh_request_body))


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FIREBASE RESPONSE HANDLER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_FirebaseAuth_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	is_busy = false
	var res

	if response_code == 0:
		res = {"error": {"code": "connection_error", "message": "Error connecting to auth service"}}
	else:
		var bod = body.get_string_from_utf8()
		var json_result = JSON.parse_string(bod)
		if json_result == null:
			Firebase._printerr("Error while parsing auth body json")
			auth_request.emit(ERR_PARSE_ERROR, "Error while parsing auth body json")
			return
		res = json_result

	if response_code == HTTPClient.RESPONSE_OK:
		if not res.has("kind"):
			# Refresh token response
			auth = get_clean_keys(res)
			begin_refresh_countdown()
			auth_request.emit(1, auth)
		else:
			match res.kind:
				RESPONSE_SIGNUP:
					auth = get_clean_keys(res)
					signup_succeeded.emit(auth)
					begin_refresh_countdown()
				RESPONSE_SIGNIN, RESPONSE_ASSERTION, RESPONSE_CUSTOM_TOKEN:
					auth = get_clean_keys(res)
					login_succeeded.emit(auth)
					begin_refresh_countdown()
				RESPONSE_USERDATA:
					var userdata = FirebaseUserData.new(res.users[0])
					userdata_received.emit(userdata)
			auth_request.emit(1, auth)
	else:
		var err_code = ""
		var err_msg = ""

		if res.has("error"):
			if res.error is Dictionary:
				err_code = str(res.error.get("code", "error"))
				err_msg = res.error.get("message", "Unknown error")
			else:
				err_code = str(res.get("error", "error"))
				err_msg = res.get("error_description", "Unknown error")

		Firebase._printerr("Auth error [%s]: %s" % [err_code, err_msg])

		if auth_request_type == Auth_Type.SIGNUP_EP:
			signup_failed.emit(err_code, err_msg)
		else:
			login_failed.emit(err_code, err_msg)

		auth_request.emit(err_code, err_msg)

	requesting = Requests.NONE
	auth_request_type = Auth_Type.NONE


func get_clean_keys(auth_result : Dictionary) -> Dictionary:
	var cleaned : Dictionary = {}
	for key in auth_result.keys():
		cleaned[key.replace("_", "").to_lower()] = auth_result[key]
	return cleaned


# Legacy methods — পুরনো code এর compatibility এর জন্য রাখা
func get_google_auth_manual() -> void:
	get_google_auth_localhost(49152)

func login_with_oauth(_token: String, _uri: String = "", _provider: String = "google.com") -> void:
	Firebase._printerr("login_with_oauth() is deprecated. Use get_google_auth_localhost() instead.")

func exchange_google_token(_token: String, _uri: String = "") -> void:
	Firebase._printerr("exchange_google_token() is deprecated.")

func get_google_auth(_uri: String = "", _id: String = "") -> void:
	get_google_auth_localhost(49152)

func get_google_auth_redirect(_uri: String, _port: int) -> void:
	get_google_auth_localhost(_port)
