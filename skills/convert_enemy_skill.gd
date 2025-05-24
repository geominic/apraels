extends Skill

@export var conversion_chance : float = 0.7  # Chance to convert enemy
@export var conversion_duration : float = 20.0  # How long the enemy becomes an ally
@export var max_health_percent : float = 0.3  # Enemy must be below this % of health to convert

func _ready() -> void:
	skill_name = "Mind Control"
	description = "%.0f%% chance to convert a weakened enemy to fight for you for %.0f seconds." % [conversion_chance * 100, conversion_duration]
	skill_color = Color(0.8, 0.2, 0.8, 1.0)  # Purple
	skill_range = 200.0  # Must target an enemy
	cooldown = 3.0  # Longer cooldown for powerful skill

	# Apply level bonuses on start
	_apply_level_bonuses()

func _execute_skill_effect(target_position: Vector2) -> void:
	# Find the closest enemy to the target position
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_enemy = null
	var closest_distance = skill_range

	for enemy in enemies:
		var distance = enemy.global_position.distance_to(target_position)

		# Check if enemy is within range and closer than current closest
		if distance <= skill_range and distance < closest_distance:
			# Check if enemy is weakened enough
			if enemy.has_method("get_health_percent"):
				var health_percent = enemy.get_health_percent()
				if health_percent <= max_health_percent:
					closest_enemy = enemy
					closest_distance = distance

	# If no valid enemy was found, the skill fails
	if not closest_enemy:
		emit_signal("skill_failed", self, "No valid target in range")
		# Refund stamina
		if caster.has_method("heal_stamina"):
			caster.heal_stamina(stamina_cost)
		return

	# Try to convert the enemy
	var success = randf() <= conversion_chance

	if success:
		# Convert the enemy to an ally
		if closest_enemy.has_method("convert_to_ally"):
			closest_enemy.convert_to_ally(caster, conversion_duration)
			spawn_effect(closest_enemy.global_position)
	else:
		# Conversion failed
		emit_signal("skill_failed", self, "Conversion failed")
		# Show a different effect for failure
		if skill_effect_scene:
			var effect = skill_effect_scene.instantiate()
			effect.global_position = closest_enemy.global_position
			effect.modulate = Color(1.0, 0.0, 0.0, 0.5)  # Red tint for failure
			get_tree().current_scene.add_child(effect)

	# Skill completed regardless of success
	emit_signal("skill_completed", self)

func can_activate(user: Node) -> bool:
	# Call parent method first
	var can_activate_base = super.can_activate(user)
	if not can_activate_base:
		return false

	# Check if there are any valid enemies in range
	var enemies = get_tree().get_nodes_in_group("enemy")
	# Get mouse position from viewport
	var target_position = Vector2.ZERO
	if user and user.has_method("get_global_mouse_position"):
		target_position = user.get_global_mouse_position()
	var valid_target = false

	for enemy in enemies:
		var distance = enemy.global_position.distance_to(target_position)
		if distance <= skill_range:
			# Check if enemy is weakened enough
			if enemy.has_method("get_health_percent"):
				var health_percent = enemy.get_health_percent()
				if health_percent <= max_health_percent:
					valid_target = true
					break

	if not valid_target:
		emit_signal("skill_failed", self, "No valid target in range")
		return false

	return true

func _apply_level_bonuses() -> void:
	# Increase conversion chance and duration with skill level
	conversion_chance = conversion_chance + (skill_level - 1) * 0.05
	conversion_duration = conversion_duration + (skill_level - 1) * 5.0

	# At level 3, allow converting stronger enemies
	if skill_level >= 3:
		max_health_percent += 0.4

	# At level 5, even higher chance and can convert stronger enemies
	if skill_level >= 5:
		conversion_chance = min(conversion_chance + 0.1, 0.95)  # Cap at 95%
		max_health_percent += 0.5

	description = "%.0f%% chance to convert an enemy below %.0f%% health to fight for you for %.0f seconds." % [conversion_chance * 100, max_health_percent * 100, conversion_duration]
