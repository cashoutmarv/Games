extends Node

# Records (steer_x, steer_y, fired) at the physics tick rate.
# Buffer is in-memory until flush_to_disk() promotes it to user://run1_inputs.dat.

const REPLAY_PATH := "user://run1_inputs.dat"
const RECORD_HEADER := "BBB_REPLAY_v1"

var _buffer: PackedByteArray = PackedByteArray()
var _tick: int = 0
var _recording: bool = false

func start() -> void:
	_buffer = PackedByteArray()
	_tick = 0
	_recording = true

func stop() -> void:
	_recording = false

func is_recording() -> bool:
	return _recording

func record(steer: Vector2, fired: bool) -> void:
	if not _recording:
		return
	# 13 bytes per tick: int32 tick, float32 x, float32 y, uint8 fired.
	var entry := PackedByteArray()
	entry.resize(13)
	entry.encode_s32(0, _tick)
	entry.encode_float(4, steer.x)
	entry.encode_float(8, steer.y)
	entry[12] = 1 if fired else 0
	_buffer.append_array(entry)
	_tick += 1

func discard() -> void:
	_buffer = PackedByteArray()
	_tick = 0
	_recording = false

func flush_to_disk() -> bool:
	if _buffer.is_empty():
		return false
	var f := FileAccess.open(REPLAY_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write replay file at %s" % REPLAY_PATH)
		return false
	f.store_string(RECORD_HEADER + "\n")
	f.store_32(_buffer.size() / 13)  # frame count
	f.store_buffer(_buffer)
	f.close()
	_recording = false
	return true

# ---- Playback ----

func load_playback() -> Array:
	# Returns Array of Dictionaries: [{tick, steer, fired}, ...].
	if not FileAccess.file_exists(REPLAY_PATH):
		return []
	var f := FileAccess.open(REPLAY_PATH, FileAccess.READ)
	if f == null:
		return []
	var header := f.get_line()
	if header != RECORD_HEADER:
		push_warning("Replay header mismatch: %s" % header)
		f.close()
		return []
	var frame_count := f.get_32()
	var raw := f.get_buffer(frame_count * 13)
	f.close()
	var frames: Array = []
	for i in frame_count:
		var offset := i * 13
		frames.append({
			"tick": raw.decode_s32(offset),
			"steer": Vector2(raw.decode_float(offset + 4), raw.decode_float(offset + 8)),
			"fired": raw[offset + 12] != 0,
		})
	return frames
