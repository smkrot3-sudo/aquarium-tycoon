extends Node
## Checks GitHub Releases for a newer build of this app and, if found, downloads the APK and
## hands off to Android's package installer — so "install the update" happens from inside the
## game instead of the player having to go find a new file somewhere else.
##
## IMPORTANT for whoever ships the next release: bump APP_VERSION_CODE here to the SAME number
## as export_presets.cfg's `version/code` on every release build. This is the one piece of
## version bookkeeping that lives in two places and has to be kept in sync by hand — there's no
## way for the running game to read its own installed versionCode back from the APK itself.
const APP_VERSION_CODE := 12
## Shown to the player (home screen, settings). Keep equal to export_presets.cfg `version/name`.
const APP_VERSION_NAME := "1.7.3"

const REPO := "smkrot3-sudo/aquarium-tycoon"
const API_URL := "https://api.github.com/repos/%s/releases/latest" % REPO
const UPDATE_APK_PATH := "user://update.apk"

signal check_completed(update_available: bool, latest_tag: String, error_code: String)
signal download_progress(fraction: float)
signal download_completed(local_path: String)
signal download_failed(error_code: String)

var _check_http: HTTPRequest
var _download_http: HTTPRequest
var _latest_download_url: String = ""
var _downloading: bool = false


func _ready() -> void:
	_check_http = HTTPRequest.new()
	add_child(_check_http)
	_check_http.request_completed.connect(_on_check_completed)

	_download_http = HTTPRequest.new()
	add_child(_download_http)
	_download_http.request_completed.connect(_on_download_completed)


func check_for_update() -> void:
	## GitHub's API requires a User-Agent header or it 403s the request.
	var err := _check_http.request(API_URL, ["User-Agent: AquariumTycoonApp"])
	if err != OK:
		check_completed.emit(false, "", "request_error_%d" % err)


func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		check_completed.emit(false, "", "http_%d" % response_code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		check_completed.emit(false, "", "bad_json")
		return

	var tag: String = parsed.get("tag_name", "")
	var remote_version_code := _parse_version_code(tag)
	var apk_url := ""
	for asset in parsed.get("assets", []):
		if String(asset.get("name", "")).to_lower().ends_with(".apk"):
			apk_url = asset.get("browser_download_url", "")
			break

	if apk_url == "":
		check_completed.emit(false, tag, "no_apk_asset")
		return
	if remote_version_code <= APP_VERSION_CODE:
		check_completed.emit(false, tag, "")
		return

	_latest_download_url = apk_url
	check_completed.emit(true, tag, "")


## Release tags are "v2", "v3", ... — pull the integer back out. Falls back to 0 (never newer
## than any real release) if the tag doesn't parse, so a malformed/missing tag fails safe.
func _parse_version_code(tag: String) -> int:
	var digits := ""
	for c in tag:
		if c.is_valid_int():
			digits += c
	return digits.to_int() if digits != "" else 0


## Where the new APK can be downloaded (set once a check found a newer release).
func download_url() -> String:
	return _latest_download_url


func start_download() -> void:
	if _latest_download_url == "":
		download_failed.emit("no_url")
		return
	if _downloading:
		return
	_downloading = true
	_download_http.download_file = UPDATE_APK_PATH
	var err := _download_http.request(_latest_download_url)
	if err != OK:
		_downloading = false
		download_failed.emit("request_error_%d" % err)


func _process(_delta: float) -> void:
	if not _downloading:
		return
	var total := _download_http.get_body_size()
	if total > 0:
		download_progress.emit(float(_download_http.get_downloaded_bytes()) / float(total))


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		download_failed.emit("http_%d" % response_code)
		return
	download_completed.emit(ProjectSettings.globalize_path(UPDATE_APK_PATH))


## Hands the downloaded APK to the OS's own installer. This is the one part of the flow that
## can't be verified from a desktop build — Android requires a content:// URI (not a raw file
## path) to open a file in another app on API 24+, which needs a FileProvider declared in the
## manifest. Godot's OS.shell_open is the standard way to ask for this; if it silently does
## nothing on a real device instead of opening the installer, that FileProvider step is the
## next thing to add (see the exported AndroidManifest / gradle_build export options).
func install_downloaded_update() -> void:
	OS.shell_open(ProjectSettings.globalize_path(UPDATE_APK_PATH))
