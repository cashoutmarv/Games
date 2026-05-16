extends Node

# Stub audio bus — v1 has no real audio. Calls are no-ops that log in debug.

func play_sfx(_id: String) -> void:
	if OS.is_debug_build():
		print("[AudioBus] sfx: ", _id)

func play_music(_id: String) -> void:
	if OS.is_debug_build():
		print("[AudioBus] music: ", _id)

func stop_music() -> void:
	pass
