extends Skill

@export var heal_amount : int = 75
@export var heal_radius : float = 50.0  # For area healing
@export var heal_allies : bool = false  # Whether to heal allies too

func _ready() -> void:
	skill_name = "Heal"
	description = "Restore %d health to yourself. Level up to increase healing amount." % heal_amount
	skill_color = Color(0.0, 1.0, 0.3, 1.0)  # Green

	# Apply level bonuses on start
	_apply_level_bonuses()

func _execute_skill_effect(_target_position: Vector2) -> void:
	# Heal the caster
	if caster.has_method("heal"):
		caster.heal(heal_amount)

	# Spawn healing effect
	spawn_effect(caster.global_position)

	# If heal_allies is true, heal nearby allies
	if heal_allies:
		var allies = get_tree().get_nodes_in_group("ally")
		for ally in allies:
			var distance = ally.global_position.distance_to(caster.global_position)
			if distance <= heal_radius:
				if ally.has_method("heal"):
					ally.heal(heal_amount)
				spawn_effect(ally.global_position)

	# Skill completed
	emit_signal("skill_completed", self)

func _apply_level_bonuses() -> void:
	# Increase healing amount with skill level
	heal_amount = heal_amount + (skill_level - 1) * 10

	# At level 3, enable healing allies
	if skill_level >= 3:
		heal_allies = true
		description = "Restore %d health to yourself and nearby allies." % heal_amount
	else:
		description = "Restore %d health to yourself. Level up to increase healing amount." % heal_amount
