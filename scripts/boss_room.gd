extends Node2D

const PhaseMachine := preload("res://scripts/systems/phase_machine.gd")
const SwapAnnouncementScene := preload("res://scenes/ui/swap_announcement.tscn")

signal boss_defeated
signal player_died

# Boss id used by BossSwap to look up which ability this fight bestows on
# boss-side victory. Floors override this when the fight is reused.
@export var boss_id: String = "boss_floor_1"

@onready var _boss: Node = $Boss
@onready var _dialogue_box: PanelContainer = $UI/DialogueBox
@onready var _ui: CanvasLayer = $UI

var _swap_overlay: CanvasLayer = null

func _ready() -> void:
	if _boss.has_signal("defeated"):
		_boss.connect("defeated", _on_boss_defeated)
	if _boss.has_signal("wants_to_talk"):
		_boss.connect("wants_to_talk", _on_boss_talk)
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: Node = players[0]
		# Tag the player so its death routes through BossSwap during this fight.
		if "swap_boss_id" in p:
			p.set("swap_boss_id", boss_id)
		if p.has_signal("died"):
			p.connect("died", _on_player_died)
		if p.has_signal("death_intercepted_by_swap"):
			p.connect("death_intercepted_by_swap", _on_death_intercepted)
	BossSwap.reset_for_new_run()
	BossSwap.swap_requested.connect(_on_swap_requested)
	BossSwap.boss_side_won.connect(_on_boss_side_won)
	# Greet the player based on phase.
	var phase_name := PhaseMachine.phase_name(RunState.current_phase)
	var greeting := DialogueDirector.get_random_line(phase_name)
	if greeting != "":
		_dialogue_box.show_line(greeting, 3.0)

func _on_boss_talk(line: String) -> void:
	_dialogue_box.show_line(line, 3.5)

func _on_boss_defeated() -> void:
	boss_defeated.emit()

func _on_player_died() -> void:
	# Reaches here only if the death was NOT intercepted by BossSwap, i.e.
	# the boss-fight context wasn't set or BossSwap was already mid-flow.
	player_died.emit()

func _on_death_intercepted(_boss_id: String) -> void:
	# Boss-fight death — the swap announcement will appear shortly.
	# Boss room stays alive; player.gd held off on queue_free.
	pass

func _on_swap_requested(_boss_id: String, is_first_ever: bool) -> void:
	_show_swap_announcement(is_first_ever)

func _show_swap_announcement(is_first_ever: bool) -> void:
	_swap_overlay = SwapAnnouncementScene.instantiate()
	add_child(_swap_overlay)
	_swap_overlay.show_for_swap(is_first_ever)
	_swap_overlay.acknowledged.connect(_on_swap_overlay_acknowledged, CONNECT_ONE_SHOT)

func _on_swap_overlay_acknowledged() -> void:
	_dismiss_overlay()
	BossSwap.acknowledge_swap_announcement()
	# v2a stub: boss-side combat is not yet implemented. To prove the loop
	# end-to-end, immediately resolve as if the player has won boss-side
	# and emit the return announcement. The full boss-side gameplay slots
	# in here in the next PR — at that point this immediate-win shortcut
	# is replaced with the actual hand-off.
	BossSwap.notify_boss_side_won()

func _on_boss_side_won(_boss_id: String, ability_id: String, bonus_damage: int) -> void:
	var label: String = _ability_label(ability_id)
	_swap_overlay = SwapAnnouncementScene.instantiate()
	add_child(_swap_overlay)
	_swap_overlay.show_for_return(label, bonus_damage)
	_swap_overlay.acknowledged.connect(_on_return_overlay_acknowledged, CONNECT_ONE_SHOT)

func _on_return_overlay_acknowledged() -> void:
	_dismiss_overlay()
	BossSwap.acknowledge_return()
	# v2a stub: control would normally return to the hero with their new
	# ability active. For now we end the run as a "win" so the rest of the
	# v1 flow (replay flush, run count bump) continues to work.
	player_died.emit()

func _dismiss_overlay() -> void:
	if _swap_overlay != null and is_instance_valid(_swap_overlay):
		_swap_overlay.queue_free()
		_swap_overlay = null

func _ability_label(ability_id: String) -> String:
	if ability_id == "":
		return "(nothing)"
	var cfg: Dictionary = BossSwap.get_ability_config(ability_id)
	return cfg.get("label", ability_id)
