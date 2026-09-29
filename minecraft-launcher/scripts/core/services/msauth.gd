class_name MsAuth
extends Node
## Вход через Microsoft: device-code flow + Xbox Live + Minecraft Services.
## Если вход не выполнен, лаунчер работает в оффлайн-режиме.

const CLIENT_ID := "00000000402b5328"
const DEVICE_CODE_URL := "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode"
const TOKEN_URL := "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
const XBL_URL := "https://user.auth.xboxlive.com/user/authenticate"
const XSTS_URL := "https://xsts.auth.xboxlive.com/xsts/authorize"
const MC_LOGIN_URL := "https://api.minecraftservices.com/authentication/login_with_xbox"
const MC_PROFILE_URL := "https://api.minecraftservices.com/minecraft/profile"

signal code_received(user_code: String, verification_uri: String)

## Полный цикл входа. Возвращает {"ok": bool, "name": String, "error": String}
func login_microsoft() -> Dictionary:
	var body := "client_id=%s&scope=XboxLive.signin%%20offline_access" % CLIENT_ID
	var r := await _post(DEVICE_CODE_URL, body)
	if not bool(r.get("ok", false)):
		return {"ok": false, "error": String(r.get("error", "не удалось запросить код"))}
	var device_code := String(r["json"].get("device_code", ""))
	var user_code := String(r["json"].get("user_code", ""))
	var verification_uri := String(r["json"].get("verification_uri", "https://microsoft.com/link"))
	var interval := maxi(1, int(r["json"].get("interval", 5)))
	var expires_in := maxi(60, int(r["json"].get("expires_in", 900)))
	code_received.emit(user_code, verification_uri)
	Notify.push("Код для входа: " + user_code, "Откройте " + verification_uri + " и введите код", "info")
	OS.shell_open(verification_uri)

	var deadline := Time.get_unix_time_from_system() + expires_in
	var access_token := ""
	while Time.get_unix_time_from_system() < deadline:
		await get_tree().create_timer(float(interval)).timeout
		var token_body := "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=%s&device_code=%s" % [CLIENT_ID, device_code]
		var tr := await _post(TOKEN_URL, token_body)
		if bool(tr.get("ok", false)):
			access_token = String(tr["json"].get("access_token", ""))
			break
		var error_code := ""
		if tr.get("json", null) != null:
			error_code = String(tr["json"].get("error", ""))
		if error_code == "authorization_declined" or error_code == "expired_token":
			return {"ok": false, "error": "Вход отменён или время вышло"}
	if access_token == "":
		return {"ok": false, "error": "Не удалось дождаться подтверждения входа"}

	var xbl := await _post_json(XBL_URL, {
		"Properties": {"AuthMethod": "RPS", "SiteName": "user.auth.xboxlive.com", "RpsTicket": "d=" + access_token},
		"RelyingParty": "http://auth.xboxlive.com",
		"TokenType": "JWT",
	})
	if not bool(xbl.get("ok", false)):
		return {"ok": false, "error": "Xbox Live: " + String(xbl.get("error", "ошибка"))}
	var xbl_token := String(xbl["json"].get("Token", ""))
	if xbl_token == "":
		return {"ok": false, "error": "Xbox Live не вернул токен"}

	var xsts := await _post_json(XSTS_URL, {
		"Properties": {"SandboxId": "RINOX", "UserTokens": [xbl_token]},
		"RelyingParty": "rp://api.minecraftservices.com/",
		"TokenType": "JWT",
	})
	if not bool(xsts.get("ok", false)):
		return {"ok": false, "error": "XSTS: " + String(xsts.get("error", "ошибка"))}
	var xsts_token := String(xsts["json"].get("Token", ""))
	var claims: Dictionary = xsts["json"].get("DisplayClaims", {})
	var xui: Array = claims.get("xui", [])
	var uhs := ""
	if xui.size() > 0:
		uhs = String((xui[0] as Dictionary).get("uhs", ""))
	if xsts_token == "" or uhs == "":
		return {"ok": false, "error": "XSTS не вернул данные пользователя"}

	var login := await _post_json(MC_LOGIN_URL, {"identityToken": "XBL3.0 x=%s;%s" % [uhs, xsts_token]})
	if not bool(login.get("ok", false)):
		return {"ok": false, "error": "Minecraft Services: " + String(login.get("error", "ошибка"))}
	var mc_token := String(login["json"].get("access_token", ""))
	if mc_token == "":
		return {"ok": false, "error": "Minecraft Services не вернул токен"}

	var profile := await Net.request(MC_PROFILE_URL, {"Authorization": "Bearer " + mc_token}, HTTPClient.MethodGet, "", 30.0)
	if not bool(profile.get("ok", false)) or profile.get("json", null) == null:
		return {"ok": false, "error": "Не удалось получить профиль. Если у аккаунта нет Java Edition, вход невозможен."}
	var name := String(profile["json"].get("name", ""))
	var uuid := String(profile["json"].get("id", ""))
	if name == "":
		return {"ok": false, "error": "Профиль Minecraft не найден"}
	Store.account = {"type": "msa", "name": name, "uuid": uuid, "token": mc_token, "expires_at": 0}
	Store.save_account()
	return {"ok": true, "name": name}

func logout() -> void:
	Store.account = {"type": "offline", "name": "Player", "uuid": "", "token": "", "expires_at": 0}
	Store.save_account()

# ------------------------------------------------------------- внутреннее ----
func _post(url: String, body: String) -> Dictionary:
	var r := await Net.request(url, {"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"}, HTTPClient.MethodPost, body, 30.0)
	if not bool(r.get("ok", false)) or r.get("json", null) == null:
		return {"ok": false, "error": String(r.get("error", "сетевая ошибка"))}
	return {"ok": true, "json": r["json"]}

func _post_json(url: String, payload: Dictionary) -> Dictionary:
	var r := await Net.request(url, {"Content-Type": "application/json", "Accept": "application/json"}, HTTPClient.MethodPost, JSON.stringify(payload), 30.0)
	if not bool(r.get("ok", false)) or r.get("json", null) == null:
		return {"ok": false, "error": String(r.get("error", "сетевая ошибка"))}
	return {"ok": true, "json": r["json"]}
