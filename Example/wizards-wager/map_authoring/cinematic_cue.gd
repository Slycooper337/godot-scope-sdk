@tool
class_name CinematicCue
extends Resource

@export var cue_id := "cue_1"
@export_enum(
	"lock_input",
	"unlock_input",
	"save_camera",
	"restore_camera",
	"pan_to_marker",
	"follow_npc",
	"follow_player",
	"zoom_camera",
	"hold",
	"fade_in",
	"fade_out",
	"show_text",
	"title_card",
	"face_npc",
	"play_npc_animation",
	"move_npc_to_marker",
	"play_sound",
	"complete"
) var cue_type := "hold"
@export_range(0.0, 120.0, 0.05) var duration_seconds := 1.0
@export var marker_id := ""
@export var npc_id := ""
@export var zoom := Vector2.ONE
@export_multiline var text := ""
@export var animation_id := ""
@export_file("*.wav", "*.ogg", "*.mp3") var sound_path := ""
@export var skippable := true


func get_definition() -> Dictionary:
	return {
		"cue_id": cue_id,
		"cue_type": cue_type,
		"duration_seconds": duration_seconds,
		"marker_id": marker_id,
		"npc_id": npc_id,
		"zoom": {"x": zoom.x, "y": zoom.y},
		"text": text,
		"animation_id": animation_id,
		"sound_path": sound_path,
		"skippable": skippable
	}


func summary() -> String:
	var target := marker_id if not marker_id.is_empty() else npc_id
	if target.is_empty():
		target = text.left(32)
	return "%s — %s (%.2fs)" % [cue_type, target, duration_seconds]
