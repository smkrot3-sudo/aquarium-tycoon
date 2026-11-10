extends Node
## Dev-only: exercises UpdateChecker's real network calls (check + download) against the actual
## GitHub repo headlessly. Can't verify the final OS.shell_open install handoff this way (that
## needs a real Android device), but this proves the check/parse/download pipeline genuinely
## works end to end, not just compiles.

func _ready() -> void:
	UpdateChecker.check_completed.connect(_on_check)
	UpdateChecker.download_completed.connect(_on_download_done)
	UpdateChecker.download_failed.connect(_on_download_failed)
	print("Checking for updates against ", UpdateChecker.API_URL)
	print("Local APP_VERSION_CODE = ", UpdateChecker.APP_VERSION_CODE)
	UpdateChecker.check_for_update()


func _on_check(update_available: bool, tag: String, error: String) -> void:
	print("check_completed -> available=%s tag=%s error=%s" % [update_available, tag, error])
	if error != "":
		get_tree().quit(1)
		return
	if not update_available:
		print("No update available relative to current code — this is expected if this build already matches the latest release.")
		get_tree().quit()
		return
	print("Starting download from: ", UpdateChecker._latest_download_url)
	UpdateChecker.start_download()


func _on_download_done(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	var size := f.get_length() if f != null else -1
	print("download_completed -> path=%s size=%d bytes" % [path, size])
	get_tree().quit()


func _on_download_failed(error: String) -> void:
	print("download_failed -> ", error)
	get_tree().quit(1)
