extends CharacterBody2D

const MOB_FOOT_OFFSET_Y := 78.35

@export var gravity := 1200.0
@export var jump_velocity := -450.0
@export var move_speed := 45.0
@export var acceleration := 500.0
@export var jump_interval_min := 1.5
@export var jump_interval_max := 3.0
@export var turn_interval := 2.5
@export var knockback_speed := 180.0
@export var knockback_jump_velocity := -240.0
@export var hit_stun_duration := 0.35
@export var chase_speed := 110.0
@export var chase_acceleration := 800.0
@export var attack_range := 80.0
@export var attack_cooldown := 1.0
@export var attack_duration := 0.8
@export var can_jump := true
@export var aggro_range := 0.0
@export var max_health := 10
@export var experience_reward := 10
@export var snapshot_render_delay := 0.12
@export var max_snapshot_extrapolation := 0.2

@onready var visual: AnimatedSprite2D = $Visual
@onready var animations: AnimationPlayer = $EnemySpriteAnimations
@onready var bite_hitbox: Area2D = $BiteHitbox
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var enemy_collision: CollisionShape2D = $EnemyArea/EnemyCollision
@onready var damage_label_template: Label = $DamageLabel

var player: Node2D = null
var move_direction := -1.0
var jump_timer := 0.0
var turn_timer := 0.0
var hit_stun_timer := 0.0
var attack_cooldown_timer := 0.0
var attack_timer := 0.0
var attacking := false
var chasing := false
var attack_hit_targets: Dictionary = {}
var health := 10
var dying := false
var authoritative_mode := false
var server_mob_id := ""
var server_position_initialized := false
var last_damage_health := -1
var snapshot_buffer: Array[Dictionary] = []
var server_velocity := Vector2.ZERO
var last_damage_attack_id := ""
var death_tween: Tween = null


func _ready() -> void:
	health = max_health
	damage_label_template.visible = false
	bite_hitbox.body_entered.connect(_on_bite_hitbox_body_entered)
	bite_hitbox.area_entered.connect(_on_bite_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	if authoritative_mode:
		return
	if dying:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if not chasing and player != null and aggro_range > 0.0 and global_position.distance_to(player.global_position) <= aggro_range:
		chasing = true
	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)

	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	elif attacking:
		attack_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		if attack_timer <= 0.0:
			_finish_attack()
	elif chasing and player != null:
		_update_chase(delta)
	else:
		_update_patrol(delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	move_and_slide()
	if is_on_wall():
		move_direction *= -1.0
		turn_timer = turn_interval

	_update_animation()

func _process(_delta: float) -> void:
	if not authoritative_mode or dying or not server_position_initialized:
		return
	var now_seconds := float(Time.get_ticks_msec()) / 1000.0
	var render_time := now_seconds - snapshot_render_delay
	if snapshot_buffer.size() >= 2:
		var older_snapshot: Dictionary = snapshot_buffer[0]
		var newer_snapshot: Dictionary = snapshot_buffer[1]
		var older_time := float(older_snapshot["time"])
		var newer_time := float(newer_snapshot["time"])
		if render_time <= older_time:
			global_position = older_snapshot["position"]
		elif render_time <= newer_time and newer_time > older_time:
			var interpolation_ratio := clampf((render_time - older_time) / (newer_time - older_time), 0.0, 1.0)
			global_position = (older_snapshot["position"] as Vector2).lerp(newer_snapshot["position"] as Vector2, interpolation_ratio)
		else:
			var extrapolation_seconds := minf(render_time - newer_time, max_snapshot_extrapolation)
			global_position = (newer_snapshot["position"] as Vector2) + (newer_snapshot["velocity"] as Vector2) * extrapolation_seconds
	else:
		var extrapolation_seconds := minf(maxf(render_time - float(snapshot_buffer[0]["time"]), 0.0), max_snapshot_extrapolation)
		global_position = (snapshot_buffer[0]["position"] as Vector2) + server_velocity * extrapolation_seconds


### ANIMATION CALLS ##

##jump/moving animation##
func jump():
	if is_on_floor():
		velocity.y = jump_velocity
	visual.play("jump")
	
func hit(attacker: Node2D = null):
	if dying:
		return

	if attacking:
		_finish_attack()

	var target: Node2D = attacker if attacker != null else player
	if target != null:
		player = target
		chasing = true
	if target != null:
		var direction_to_player: float = sign(target.global_position.x - global_position.x)
		if direction_to_player == 0.0:
			direction_to_player = -move_direction
		visual.flip_h = direction_to_player < 0.0
		velocity.x = -direction_to_player * knockback_speed
	else:
		velocity.x = move_direction * knockback_speed

	velocity.y = knockback_jump_velocity
	hit_stun_timer = hit_stun_duration
	visual.play("hit")
	animations.play("enemy_hit")


func take_damage(amount: int, attacker: Node2D = null, critical: bool = false) -> void:
	if authoritative_mode:
		return
	if dying:
		return

	if attacker != null:
		player = attacker

	health -= amount
	_show_damage_number(amount, critical)
	if health <= 0:
		_die()
	else:
		hit(attacker)

func set_server_authoritative(mob_id: String) -> void:
	authoritative_mode = true
	server_mob_id = mob_id
	dying = false
	attack_hit_targets.clear()
	snapshot_buffer.clear()
	server_position_initialized = false
	set_physics_process(false)

func get_server_mob_id() -> String:
	return server_mob_id

func apply_server_snapshot(data: Dictionary, snapshot_received_at: float = -1.0) -> void:
	if not authoritative_mode:
		return
	var position_data: Variant = data.get("position", {})
	if position_data is Dictionary:
		var position_dictionary: Dictionary = position_data
		var server_foot_position := Vector2(float(position_dictionary.get("x", global_position.x)), float(position_dictionary.get("y", global_position.y + MOB_FOOT_OFFSET_Y)))
		var snapshot_position := Vector2(server_foot_position.x, server_foot_position.y - MOB_FOOT_OFFSET_Y)
		var snapshot_time := snapshot_received_at
		if snapshot_time < 0.0:
			snapshot_time = float(Time.get_ticks_msec()) / 1000.0
		var snapshot_is_new := snapshot_buffer.is_empty() or snapshot_time > float(snapshot_buffer[-1]["time"])
		if snapshot_is_new:
			snapshot_buffer.append({"time": snapshot_time, "position": snapshot_position, "velocity": server_velocity})
			while snapshot_buffer.size() > 2:
				snapshot_buffer.pop_front()
		if not server_position_initialized:
			global_position = snapshot_position
			server_position_initialized = true
	var velocity_data: Variant = data.get("velocity", {})
	if velocity_data is Dictionary:
		var velocity_dictionary: Dictionary = velocity_data
		server_velocity = Vector2(float(velocity_dictionary.get("x", velocity.x)), float(velocity_dictionary.get("y", velocity.y)))
		velocity = server_velocity
		if not snapshot_buffer.is_empty():
			snapshot_buffer[-1]["velocity"] = server_velocity
	health = int(data.get("health", health))
	max_health = int(data.get("max_health", max_health))
	var facing := int(data.get("facing", 1))
	if facing != 0:
		visual.flip_h = facing < 0
	_update_server_animation(str(data.get("state", "idle")))

func apply_server_damage(data: Dictionary) -> void:
	if not authoritative_mode or dying:
		return
	var updated_health := int(data.get("remaining_health", health))
	var damage_amount := int(data.get("damage", 0))
	var attack_id := str(data.get("attack_id", ""))
	if not attack_id.is_empty() and attack_id == last_damage_attack_id:
		return
	if attack_id.is_empty() and updated_health == last_damage_health:
		return
	last_damage_attack_id = attack_id
	last_damage_health = updated_health
	health = updated_health
	var knockback_value: Variant = data.get("knockback", data.get("velocity", {}))
	if knockback_value is Dictionary:
		var knockback_data: Dictionary = knockback_value
		server_velocity = Vector2(float(knockback_data.get("x", server_velocity.x)), float(knockback_data.get("y", server_velocity.y)))
		velocity = server_velocity
		if not snapshot_buffer.is_empty():
			snapshot_buffer[-1]["velocity"] = server_velocity
	_show_damage_number(damage_amount, bool(data.get("critical", false)))
	visual.stop()
	visual.play("hit")
	animations.stop()
	animations.play("enemy_hit")

func apply_server_death(_data: Dictionary = {}) -> void:
	if not authoritative_mode or dying:
		return
	dying = true
	attack_hit_targets.clear()
	bite_hitbox.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)
	enemy_collision.set_deferred("disabled", true)
	var death_velocity := _knockback_from_data(_data)
	velocity = death_velocity
	server_velocity = death_velocity
	if death_tween != null:
		death_tween.kill()
	if death_velocity.length() > 1.0:
		death_tween = create_tween()
		death_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(self, "global_position", global_position + Vector2(death_velocity.x * 0.12, death_velocity.y * 0.08), 0.14)
		death_tween.tween_callback(_begin_death_animation)
	else:
		_begin_death_animation()


func _begin_death_animation() -> void:
	velocity = Vector2.ZERO
	visual.play("die")


func _knockback_from_data(data: Dictionary) -> Vector2:
	var value: Variant = data.get("knockback", data.get("velocity", {}))
	if value is Dictionary:
		var knockback: Dictionary = value
		return Vector2(float(knockback.get("x", 0.0)), float(knockback.get("y", 0.0)))
	return Vector2.ZERO

func _update_server_animation(state: String) -> void:
	if dying:
		return
	var animation_name := "idle"
	match state:
		"walk", "chase":
			animation_name = "walk"
		"jump":
			animation_name = "jump"
		"attack":
			animation_name = "attack"
	if visual.animation != animation_name:
		visual.play(animation_name)


func _die() -> void:
	dying = true
	attacking = false
	bite_hitbox.set_deferred("monitoring", false)
	body_collision.set_deferred("disabled", true)
	enemy_collision.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	if player != null and player.has_method("gain_experience"):
		player.call("gain_experience", experience_reward)
	visual.play("die")


func _show_damage_number(amount: int, critical: bool) -> void:
	var damage_label := damage_label_template.duplicate() as Label
	damage_label.visible = true
	damage_label.z_index = 100
	damage_label.text = str(amount)
	if critical:
		damage_label.modulate = Color(1.0, 1.0, 0.0, 1.0)
	damage_label.position = damage_label_template.position + Vector2(randf_range(-4.0, 4.0), 0.0)
	add_child(damage_label)

	var tween := create_tween()
	tween.tween_property(damage_label, "position", damage_label.position + Vector2(0.0, -16.0), 0.65)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(damage_label.queue_free)


func _on_animation_finished() -> void:
	if visual.animation == "die":
		queue_free()
	elif visual.animation == "attack":
		_finish_attack()
	elif visual.animation == "hit":
		visual.play("idle")


func _update_patrol(delta: float) -> void:
	turn_timer -= delta
	jump_timer -= delta

	if turn_timer <= 0.0:
		move_direction *= -1.0
		turn_timer = turn_interval

	velocity.x = move_toward(velocity.x, move_direction * move_speed, acceleration * delta)
	visual.flip_h = move_direction < 0.0

	if can_jump and is_on_floor() and jump_timer <= 0.0:
		jump()
		jump_timer = randf_range(jump_interval_min, jump_interval_max)


func _update_chase(delta: float) -> void:
	var horizontal_distance := player.global_position.x - global_position.x
	var vertical_distance := absf(player.global_position.y - global_position.y)
	var direction_to_player: float = sign(horizontal_distance)
	if direction_to_player == 0.0:
		direction_to_player = move_direction

	visual.flip_h = direction_to_player < 0.0
	if is_on_floor() and absf(horizontal_distance) <= attack_range and vertical_distance <= 45.0 and attack_cooldown_timer <= 0.0:
		_start_attack()
		return

	velocity.x = move_toward(velocity.x, direction_to_player * chase_speed, chase_acceleration * delta)
	if can_jump and is_on_floor() and jump_timer <= 0.0:
		jump()
		jump_timer = randf_range(jump_interval_min, jump_interval_max)


func _start_attack() -> void:
	attacking = true
	attack_timer = attack_duration
	attack_hit_targets.clear()
	bite_hitbox.position.x = absf(bite_hitbox.position.x) * (-1.0 if visual.flip_h else 1.0)
	bite_hitbox.set_deferred("monitoring", true)
	visual.play("attack")


func _finish_attack() -> void:
	if not attacking:
		return

	attacking = false
	bite_hitbox.set_deferred("monitoring", false)
	attack_cooldown_timer = attack_cooldown
	visual.play("idle")


func _on_bite_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerArea":
		_register_bite_hit(area.get_parent())


func _on_bite_hitbox_body_entered(body: Node2D) -> void:
	_register_bite_hit(body)


func _register_bite_hit(target: Node) -> void:
	if not attacking or not target.is_in_group("player") or attack_hit_targets.has(target):
		return

	attack_hit_targets[target] = true
	if target.has_method("hit"):
		target.call("hit", self)


func _update_animation() -> void:
	if dying or hit_stun_timer > 0.0 or attacking:
		return

	if not is_on_floor():
		if visual.animation != "jump":
			visual.play("jump")
	elif absf(velocity.x) > 0.1:
		if visual.animation != "walk":
			visual.play("walk")
	else:
		if visual.animation != "idle":
			visual.play("idle")
