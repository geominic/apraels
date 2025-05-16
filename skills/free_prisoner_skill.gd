extends Skill

@export var ally_duration : float = 30.0  # How long the prisoner becomes an ally
@export var max_prisoners : int = 1  # Maximum number of prisoners that can be freed at once
@export var prisoner_health : int = 50  # Health given to freed prisoners

func _ready() -> void:
	skill_name = "Free Prisoner"
	description = "Free a prisoner to temporarily fight as your ally for %.0f seconds." % ally_duration
	skill_color = Color(0.0, 0.7, 1.0, 1.0)  # Blue
	skill_range = 150.0  # Must be close to prisoner

	# Apply level bonuses on start
	_apply_level_bonuses()

func _execute_skill_effect(target_position: Vector2) -> void:
	# Find prisoners near the target position
	var prisoners = get_tree().get_nodes_in_group("prisoner")
	var freed_count = 0

	for prisoner in prisoners:
		var distance = prisoner.global_position.distance_to(target_position)

		# Check if prisoner is within range
		if distance <= skill_range:
			# Free the prisoner and make them an ally
			if prisoner.has_method("free_prisoner"):
				prisoner.free_prisoner(caster, ally_duration, prisoner_health)
				spawn_effect(prisoner.global_position)
				freed_count += 1

				# Stop if we've reached the maximum
				if freed_count >= max_prisoners:
					break

	# If no prisoners were freed, the skill fails
	if freed_count == 0:
		emit_signal("skill_failed", self, "No prisoners in range")
		# Refund stamina
		if caster.has_method("heal_stamina"):
			caster.heal_stamina(stamina_cost)
		return

	# Skill completed
	emit_signal("skill_completed", self)

func can_activate(user: Node) -> bool:
	# Call parent method first
	var can_activate_base = super.can_activate(user)
	if not can_activate_base:
		return false

	# Check if there are any prisoners in range
	var prisoners = get_tree().get_nodes_in_group("prisoner")
	# Get mouse position from viewport
	var target_position = Vector2.ZERO
	if user and user.has_method("get_global_mouse_position"):
		target_position = user.get_global_mouse_position()
	var prisoners_in_range = false

	for prisoner in prisoners:
		var distance = prisoner.global_position.distance_to(target_position)
		if distance <= skill_range:
			prisoners_in_range = true
			break

	if not prisoners_in_range:
		emit_signal("skill_failed", self, "No prisoners in range")
		return false

	return true

func _apply_level_bonuses() -> void:
	# Increase duration with skill level
	ally_duration = 30.0 + (skill_level - 1) * 15.0

	# At level 3, allow freeing more prisoners at once
	if skill_level >= 3:
		max_prisoners = 2
		description = "Free up to %d prisoners to temporarily fight as your allies for %.0f seconds." % [max_prisoners, ally_duration]
	else:
		description = "Free a prisoner to temporarily fight as your ally for %.0f seconds." % ally_duration

	# At level 5, give freed prisoners more health
	if skill_level >= 5:
		prisoner_health = 80
