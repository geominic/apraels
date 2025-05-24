extends Skill

@export var damage_buff : float = 1.3  # Damage multiplier for allies
@export var speed_buff : float = 1.2  # Speed multiplier for allies
@export var defense_buff : float = 0.8  # Damage reduction for allies (lower is better)
@export var buff_duration : float = 25.0  # How long the buffs last
@export var buff_radius : float = 200.0  # Area of effect

func _ready() -> void:
	skill_name = "Rally"
	description = "Buff all allies within range, increasing damage by %.0f%%, speed by %.0f%%, and reducing damage taken by %.0f%% for %.0f seconds." % [
		(damage_buff - 1.0) * 100,
		(speed_buff - 1.0) * 100,
		(1.0 - defense_buff) * 100,
		buff_duration
	]
	skill_color = Color(1.0, 0.8, 0.0, 1.0)  # Gold

	# Apply level bonuses on start
	_apply_level_bonuses()

func _execute_skill_effect(_target_position: Vector2) -> void:
	# Find allies in range
	var allies = get_tree().get_nodes_in_group("ally")
	var buffed_count = 0

	for ally in allies:
		var distance = ally.global_position.distance_to(caster.global_position)

		# Check if ally is within range
		if distance <= buff_radius:
			# Apply buffs to the ally
			if ally.has_method("apply_buffs"):
				ally.apply_buffs(damage_buff, speed_buff, defense_buff, buff_duration)
				spawn_effect(ally.global_position)
				buffed_count += 1

	# If no allies were buffed, the skill still works but we inform the player
	if buffed_count == 0:
		print("No allies in range to buff")

	# Skill completed
	emit_signal("skill_completed", self)

func can_activate(user: Node) -> bool:
	# Call parent method first
	var can_activate_base = super.can_activate(user)
	if not can_activate_base:
		return false

	# This skill can always be activated, even if no allies are in range
	# It might be useful to activate it just before allies arrive

	return true

func _apply_level_bonuses() -> void:
	# Increase buff strength and duration with skill level
	damage_buff = damage_buff + (skill_level - 1) * 0.1
	speed_buff = speed_buff + (skill_level - 1) * 0.05
	defense_buff = defense_buff - (skill_level - 1) * 0.05
	buff_duration = buff_duration + (skill_level - 1) * 5.0

	# At level 3, increase buff radius
	if skill_level >= 3:
		buff_radius += 150.0

	# At level 5, further improve buffs
	if skill_level >= 5:
		damage_buff += 0.1
		speed_buff += 0.1
		defense_buff = max(defense_buff - 0.1, 0.5)  # Cap at 50% damage reduction

	description = "Buff all allies within range, increasing damage by %.0f%%, speed by %.0f%%, and reducing damage taken by %.0f%% for %.0f seconds." % [
		(damage_buff - 1.0) * 100,
		(speed_buff - 1.0) * 100,
		(1.0 - defense_buff) * 100,
		buff_duration
	]
