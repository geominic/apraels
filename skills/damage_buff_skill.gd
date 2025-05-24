extends Skill

@export var damage_multiplier : float = 1.5  # Damage multiplier bonus
@export var buff_duration : float = 15.0  # How long the buff lasts
@export var buff_radius : float = 100.0  # For area buffing
@export var buff_allies : bool = false  # Whether to buff allies too

func _ready() -> void:
	skill_name = "Battle Fury"
	description = "Increase your damage by %.0f%% for %.0f seconds." % [(damage_multiplier - 1.0) * 100, buff_duration]
	skill_color = Color(1.0, 0.5, 0.0, 1.0)  # Orange

	# Apply level bonuses on start
	_apply_level_bonuses()

func _execute_skill_effect(_target_position: Vector2) -> void:
	# Apply damage buff to caster
	if caster.has_method("apply_damage_buff"):
		caster.apply_damage_buff(damage_multiplier, buff_duration)

	# Spawn buff effect
	spawn_effect(caster.global_position)

	# If buff_allies is true, buff nearby allies
	if buff_allies:
		var allies = get_tree().get_nodes_in_group("ally")
		for ally in allies:
			var distance = ally.global_position.distance_to(caster.global_position)
			if distance <= buff_radius:
				if ally.has_method("apply_damage_buff"):
					ally.apply_damage_buff(damage_multiplier, buff_duration)
				spawn_effect(ally.global_position)

	# Skill completed
	emit_signal("skill_completed", self)

func _apply_level_bonuses() -> void:
	# Increase damage multiplier and duration with skill level
	damage_multiplier = damage_multiplier + (skill_level - 1) * 0.1
	buff_duration = buff_duration + (skill_level - 1) * 5.0

	# At level 3, enable buffing allies
	if skill_level >= 3:
		buff_allies = true
		description = "Increase your and nearby allies' damage by %.0f%% for %.0f seconds." % [(damage_multiplier - 1.0) * 100, buff_duration]
	else:
		description = "Increase your damage by %.0f%% for %.0f seconds." % [(damage_multiplier - 1.0) * 100, buff_duration]
