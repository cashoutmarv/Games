extends CharacterBody2D

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")

signal hp_changed(hp: int, max_hp: int)
signal defeated
signal wants_to_talk(line: String)

@export var max_hp: int = 500

var hp: int = max_hp
var behavior_id: String = "idle"
var _hesitate_timer: float = 0.0
var _talk_timer: float = 0.0

func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	_apply_phase(RunState.current_phase)
	RunState.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: int) -> void:
	_apply_phase(phase)

func _apply_phase(phase: int) -> void:
	match phase:
		PhaseMachine.NarrativePhase.NORMAL_FIGHT:
			behavior_id = "circle_strafe"
		PhaseMachine.NarrativePhase.BOSS_HESITATES:
			behavior_id = "hesitate"
			_hesitate_timer = 0.0
		PhaseMachine.NarrativePhase.BOSS_TALKS:
			behavior_id = "talk"
			_talk_timer = 0.0
		PhaseMachine.NarrativePhase.EASTER_EGG_HUNT:
			behavior_id = "hint"
		PhaseMachine.NarrativePhase.FILE_BROWSER_UNLOCKED:
			behavior_id = "plea"
		_:
			behavior_id = "idle"

func _physics_process(delta: float) -> void:
	match behavior_id:
		"circle_strafe", "dash":
			# Stubbed — log once if reached; full behavior is post-v1 scope.
			pass
		"hesitate":
			_hesitate_timer += delta
			if _hesitate_timer > 2.0:
				_hesitate_timer = 0.0
				_emit_random_line("BOSS_HESITATES")
		"talk":
			_talk_timer += delta
			if _talk_timer > 4.0:
				_talk_timer = 0.0
				_emit_random_line("BOSS_TALKS")
		"hint":
			_talk_timer += delta
			if _talk_timer > 6.0:
				_talk_timer = 0.0
				_emit_random_line("EASTER_EGG_HUNT")
		"plea":
			_talk_timer += delta
			if _talk_timer > 5.0:
				_talk_timer = 0.0
				_emit_random_line("FILE_BROWSER_UNLOCKED")
		"idle":
			pass

	if Input.is_action_just_pressed("debug_kill_boss"):
		take_damage(hp)

func _emit_random_line(phase_name: String) -> void:
	var line := DialogueDirector.get_random_line(phase_name)
	if line != "":
		wants_to_talk.emit(line)

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		defeated.emit()
