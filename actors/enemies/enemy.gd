extends CharacterBody2D
class_name Enemy

# Enemy type parameters
@export_group("Enemy Type")
@export var is_ranged: bool = false

# Movement parameters
@export_group("Movement Parameters")
@export var max_speed: float = 150.0
@export var acceleration: float = 800.0
@export var deceleration: float = 1000.0
@export var detection_radius: float = 300.0

# Health parameters
@export_group("Health Parameters")
@export var max_hp: int = 50
@export var drop_chance: float = 0.3  # Chance to drop an item on death

# Ranged enemy parameters
@export_group("Ranged Parameters")
@export var preferred_distance: float = 150.0
@export var distance_threshold: float = 20.0  # How close to preferred distance is acceptable

# Attack parameters
@export_group("Attack Parameters")
@export var base_damage: int = 10
@export var attack_cooldown: float = 1.0  # Time between attacks
@export var attack_range: float = 30.0  # For melee attacks
@export var projectile_scene: PackedScene  # For ranged attacks
@export var melee_scene: PackedScene  # For melee attacks

# State variables
var player_ref: Node2D = null
var target_position: Vector2 = Vector2.ZERO
var can_see_player: bool = false
var direction: Vector2 = Vector2.ZERO
var distance_to_player: float = 0.0
var is_at_preferred_distance: bool = false

# Health variables
var current_hp: int = 0
var is_dying: bool = false
var is_converted: bool = false  # For the convert enemy skill
var ally_timer: float = 0.0     # Timer for temporary ally status

# Attack variables
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0
var melee_weapon: Node = null
var is_attacking: bool = false

func _ready() -> void:
	# Add to enemy group for easier management
	add_to_group("enemy")

	# Initialize health
	current_hp = max_hp

	# Configure enemy based on type
	configure_enemy_type()

	# Initialize weapons based on enemy type
	initialize_weapons()

	# Find the player on ready
	find_player()

# Configure the enemy based on its type
func configure_enemy_type() -> void:
	# Show/hide the preferred distance indicator for ranged enemies
	if has_node("RangedPreferredDistance"):
		$RangedPreferredDistance.visible = is_ranged

		# Update the preferred distance circle size
		if is_ranged and $RangedPreferredDistance/CollisionShape2D:
			var shape = $RangedPreferredDistance/CollisionShape2D.shape as CircleShape2D
			if shape:
				shape.radius = preferred_distance

func _physics_process(delta: float) -> void:
	# Skip processing if dying
	if is_dying:
		return

	# Update ally timer if converted
	if is_converted:
		ally_timer -= delta
		if ally_timer <= 0:
			revert_to_enemy()

	# Update attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true

	# Update player detection
	update_player_detection()

	# Calculate movement direction based on status
	if is_converted:
		calculate_ally_direction()
	else:
		calculate_direction()

	# Apply movement with acceleration/deceleration
	apply_movement(delta)

	# Move the enemy
	move_and_slide()

	# Update sprite facing direction
	update_sprite_direction()

	# Try to attack based on status
	if can_attack:
		if is_converted:
			# Allies always try to attack enemies
			try_attack()

			# Debug output for ranged allies
			if is_ranged:
				print("Ranged ally can attack: " + str(can_attack) +
					  ", Is attacking: " + str(is_attacking) +
					  ", Has projectile: " + str(projectile_scene != null))
		elif can_see_player:
			# Enemies attack player if they can see them
			try_attack()

# Find the player node
func find_player() -> void:
	# Try to find player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

# Update player detection based on distance
func update_player_detection() -> void:
	if player_ref == null:
		find_player()
		return

	# Check if player is within detection radius
	distance_to_player = global_position.distance_to(player_ref.global_position)
	can_see_player = distance_to_player <= detection_radius

	# For ranged enemies, check if at preferred distance
	if is_ranged:
		var was_at_preferred_distance = is_at_preferred_distance
		is_at_preferred_distance = abs(distance_to_player - preferred_distance) <= distance_threshold

		# Visual feedback when at preferred distance
		if is_at_preferred_distance != was_at_preferred_distance:
			update_ranged_status_visual()

	if can_see_player:
		target_position = player_ref.global_position

# Calculate movement direction
func calculate_direction() -> void:
	if can_see_player and player_ref != null:
		if is_ranged:
			# Handle ranged enemy movement
			calculate_ranged_direction()
		else:
			# Melee enemy - move directly towards player
			direction = global_position.direction_to(target_position)
	else:
		# No player detected, stop moving
		direction = Vector2.ZERO

# Calculate direction for ranged enemies
func calculate_ranged_direction() -> void:
	if distance_to_player < preferred_distance - distance_threshold:
		# Too close to player, move away
		direction = global_position.direction_to(target_position) * -1
	elif distance_to_player > preferred_distance + distance_threshold:
		# Too far from player, move closer
		direction = global_position.direction_to(target_position)
	else:
		# At preferred distance, stop moving
		direction = Vector2.ZERO

		# Still face the player even when not moving
		update_sprite_direction_to_face_player()

# Calculate movement direction for allies
func calculate_ally_direction() -> void:
	# Find the closest enemy
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_enemy = null
	var closest_distance = detection_radius

	for enemy in enemies:
		# Skip self
		if enemy == self:
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance

	# If found a nearby enemy
	if closest_enemy != null:
		if is_ranged:
			# Update preferred distance status for ranged allies
			var was_at_preferred_distance = is_at_preferred_distance
			is_at_preferred_distance = abs(closest_distance - preferred_distance) <= distance_threshold

			# Debug output
			print("Ranged ally distance to enemy: " + str(closest_distance) +
				  ", At preferred distance: " + str(is_at_preferred_distance))

			# Ranged ally behavior
			if closest_distance < preferred_distance - distance_threshold:
				# Too close to enemy, move away
				direction = global_position.direction_to(closest_enemy.global_position) * -1
			elif closest_distance > preferred_distance + distance_threshold:
				# Too far from enemy, move closer
				direction = global_position.direction_to(closest_enemy.global_position)
			else:
				# At preferred distance, stop moving
				direction = Vector2.ZERO

				# Face the enemy
				update_sprite_direction_to_face_enemy(closest_enemy)
		else:
			# Melee ally behavior - move directly toward enemy
			if closest_distance > attack_range:
				direction = global_position.direction_to(closest_enemy.global_position)
			else:
				# Close enough to attack, stop moving
				direction = Vector2.ZERO
	else:
		# No enemies found, follow the player
		if player_ref != null:
			var distance_to_master = global_position.distance_to(player_ref.global_position)

			# Stay close to player if no enemies around
			if distance_to_master > 50.0:
				direction = global_position.direction_to(player_ref.global_position)
			else:
				direction = Vector2.ZERO

# Apply movement with acceleration and deceleration
func apply_movement(delta: float) -> void:
	if direction != Vector2.ZERO:
		# Accelerate towards target velocity
		var target_velocity = direction * max_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		# Decelerate to stop
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

# Update sprite direction based on movement
func update_sprite_direction() -> void:
	if is_converted:
		# Allies should face enemies or movement direction
		var enemies = get_tree().get_nodes_in_group("enemy")
		if enemies.size() > 0:
			var closest_enemy = null
			var closest_distance = detection_radius

			for enemy in enemies:
				if enemy == self:
					continue

				var distance = global_position.distance_to(enemy.global_position)
				if distance < closest_distance:
					closest_enemy = enemy
					closest_distance = distance

			if closest_enemy != null:
				update_sprite_direction_to_face_enemy(closest_enemy)
				return

	if is_ranged and is_at_preferred_distance and player_ref != null and not is_converted:
		# Ranged enemies at preferred distance should face the player
		update_sprite_direction_to_face_player()
	else:
		# Otherwise face movement direction
		if velocity.x > 0:
			$Sprite2D.flip_h = false
		elif velocity.x < 0:
			$Sprite2D.flip_h = true

# Make the enemy face the player
func update_sprite_direction_to_face_player() -> void:
	if player_ref == null:
		return

	var direction_to_player = global_position.direction_to(player_ref.global_position)
	if direction_to_player.x > 0:
		$Sprite2D.flip_h = false
	elif direction_to_player.x < 0:
		$Sprite2D.flip_h = true

# Make the ally face an enemy
func update_sprite_direction_to_face_enemy(enemy: Node2D) -> void:
	if enemy == null:
		return

	var direction_to_enemy = global_position.direction_to(enemy.global_position)
	if direction_to_enemy.x > 0:
		$Sprite2D.flip_h = false
	elif direction_to_enemy.x < 0:
		$Sprite2D.flip_h = true

# Update visual indicators for ranged enemy status
func update_ranged_status_visual() -> void:
	if not is_ranged:
		return

	if is_at_preferred_distance:
		# Visual indicator when at preferred distance
		modulate = Color(0.2, 0.8, 1.0, 1.0)  # Blue tint
	else:
		# Normal color when not at preferred distance
		modulate = Color(1.0, 0.4, 0.4, 1.0)  # Red tint

# Take damage from player attacks
func take_damage(amount: int) -> void:
	# Skip if already dying
	if is_dying:
		return

	# Apply damage
	current_hp = max(0, current_hp - amount)

	# Flash red to indicate damage
	modulate = Color(1.0, 0.0, 0.0, 1.0)

	# Create a timer to reset the color
	var timer = get_tree().create_timer(0.2)
	timer.connect("timeout", _on_damage_flash_timeout)

	# Print damage for testing
	print("Enemy took " + str(amount) + " damage! HP: " + str(current_hp) + "/" + str(max_hp))

	# Check for death
	if current_hp <= 0:
		die()

# Reset color after damage flash
func _on_damage_flash_timeout() -> void:
	# Skip if dying
	if is_dying:
		return

	if is_converted:
		modulate = Color(0.2, 0.8, 0.2, 1.0)  # Green tint for allies
	elif is_ranged and is_at_preferred_distance:
		modulate = Color(0.2, 0.8, 1.0, 1.0)  # Blue tint for ranged at preferred distance
	else:
		modulate = Color(1.0, 0.4, 0.4, 1.0)  # Normal color

# Get health percentage (for skills)
func get_health_percent() -> float:
	return float(current_hp) / float(max_hp)

# Convert enemy to temporary ally
func convert_to_ally(new_master: Node2D, duration: float) -> void:
	is_converted = true
	ally_timer = duration

	# Store reference to master (player) for potential AI behavior
	player_ref = new_master

	# Change appearance to indicate ally status
	modulate = Color(0.2, 0.8, 0.2, 1.0)  # Green tint

	# Remove from enemy group and add to ally group
	remove_from_group("enemy")
	add_to_group("ally")

	print("Enemy converted to ally for " + str(duration) + " seconds!")

# Revert back to enemy when ally timer expires
func revert_to_enemy() -> void:
	is_converted = false

	# Change appearance back to normal
	if is_ranged and is_at_preferred_distance:
		modulate = Color(0.2, 0.8, 1.0, 1.0)  # Blue tint for ranged
	else:
		modulate = Color(1.0, 0.4, 0.4, 1.0)  # Normal red tint

	# Remove from ally group and add back to enemy group
	remove_from_group("ally")
	add_to_group("enemy")

	print("Ally reverted to enemy!")

# Handle enemy death
func die() -> void:
	# Set dying state
	is_dying = true

	# Visual feedback
	modulate = Color(0.3, 0.3, 0.3, 0.7)  # Fade out

	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)

	# Optional: Play death animation
	# $AnimationPlayer.play("death")

	print("Enemy died!")

	# Check for item drop
	if randf() <= drop_chance:
		# Implement item drop logic here
		print("Enemy dropped an item!")

	# Remove from groups
	remove_from_group("enemy")
	if is_converted:
		remove_from_group("ally")

	# Create a timer to remove the enemy
	var timer = get_tree().create_timer(1.0)
	timer.connect("timeout", _on_death_timer_timeout)

# Remove enemy after death animation
func _on_death_timer_timeout() -> void:
	queue_free()

# Initialize weapons based on enemy type
func initialize_weapons() -> void:
	# Create a weapon holder node if it doesn't exist
	if not has_node("MeleeWeaponHolder"):
		var holder = Node2D.new()
		holder.name = "MeleeWeaponHolder"
		add_child(holder)

	# Initialize melee weapon for melee enemies
	if not is_ranged and melee_scene:
		melee_weapon = melee_scene.instantiate()
		melee_weapon.source = self

		# Connect to the end_attack signal to reset is_attacking flag
		if not melee_weapon.has_signal("attack_finished"):
			melee_weapon.add_user_signal("attack_finished")
		melee_weapon.connect("attack_finished", _on_melee_attack_finished)

		$MeleeWeaponHolder.add_child(melee_weapon)

# Try to attack targets (player or enemies)
func try_attack() -> void:
	# Skip if already attacking
	if is_attacking:
		return

	if is_converted:
		# Ally behavior - attack nearby enemies
		try_attack_enemies()
	else:
		# Enemy behavior - attack player
		if is_ranged:
			# Ranged attack - shoot projectile
			if is_at_preferred_distance and projectile_scene:
				shoot_projectile()
		else:
			# Melee attack - use melee weapon
			if distance_to_player <= attack_range and melee_weapon:
				start_melee_attack()

# Try to attack nearby enemies (for allies)
func try_attack_enemies() -> void:
	# Find the closest enemy
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_enemy = null
	var closest_distance = attack_range * 3  # Larger search range for ranged allies

	# Debug output
	print("Ally trying to attack enemies. Is ranged: " + str(is_ranged) + ", Enemies count: " + str(enemies.size()))

	for enemy in enemies:
		# Skip self
		if enemy == self:
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance

	# If found a nearby enemy
	if closest_enemy != null:
		# Store as target
		var target_enemy = closest_enemy

		# Debug output
		print("Found target enemy at distance: " + str(closest_distance) +
			  ", Preferred distance: " + str(preferred_distance) +
			  ", Threshold: " + str(distance_threshold))

		if is_ranged:
			# Ranged attack - always shoot if within reasonable range
			# Relaxed distance check for ranged allies
			if closest_distance <= detection_radius:
				print("Ranged ally attempting to shoot at enemy")
				shoot_projectile_at_enemy(target_enemy)
			else:
				print("Enemy too far for ranged ally to shoot")
		else:
			# Melee attack - if close enough
			if closest_distance <= attack_range and melee_weapon:
				start_melee_attack_at_enemy(target_enemy)
			else:
				print("Enemy too far for melee ally to attack: " + str(closest_distance) + " > " + str(attack_range))
	else:
		print("No enemy targets found for ally")

# Shoot a projectile at the player
func shoot_projectile() -> void:
	# Skip if no projectile scene
	if not projectile_scene:
		print("ERROR: No projectile scene assigned to ranged enemy!")
		return

	# Set cooldown
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	is_attacking = true  # Set attacking flag for consistency

	# Create projectile
	var projectile = projectile_scene.instantiate()
	projectile.position = global_position
	projectile.source = self
	projectile.damage = base_damage

	# Calculate direction to player
	var direction = global_position.direction_to(player_ref.global_position)
	projectile.set_direction(direction)

	# Add projectile to scene
	get_parent().add_child(projectile)

	print("Enemy fired projectile!")

	# Reset attacking flag immediately for ranged attacks
	is_attacking = false

# Start a melee attack
func start_melee_attack() -> void:
	# Skip if no melee weapon
	if not melee_weapon:
		return

	# Set cooldown
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	is_attacking = true

	# Face the weapon toward the player
	melee_weapon.face_position(player_ref.global_position)

	# Start the attack
	melee_weapon.start_attack()

	print("Enemy performed melee attack!")

# Called when melee attack is finished
func _on_melee_attack_finished() -> void:
	is_attacking = false
	print("Enemy melee attack finished")

# Shoot a projectile at a specific enemy
func shoot_projectile_at_enemy(target_enemy: Node2D) -> void:
	# Skip if no projectile scene
	if not projectile_scene:
		print("ERROR: No projectile scene assigned to ranged ally!")
		return

	# Set cooldown
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	is_attacking = true  # Set attacking flag for consistency with melee

	# Create projectile
	var projectile = projectile_scene.instantiate()
	projectile.position = global_position
	projectile.source = self
	projectile.damage = base_damage

	# Calculate direction to enemy
	var direction = global_position.direction_to(target_enemy.global_position)
	projectile.set_direction(direction)

	# Add projectile to scene
	get_parent().add_child(projectile)

	print("Ally fired projectile at enemy!")

	# Reset attacking flag immediately for ranged attacks
	is_attacking = false

# Start a melee attack against a specific enemy
func start_melee_attack_at_enemy(target_enemy: Node2D) -> void:
	# Skip if no melee weapon
	if not melee_weapon:
		return

	# Set cooldown
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	is_attacking = true

	# Face the weapon toward the enemy
	melee_weapon.face_position(target_enemy.global_position)

	# Start the attack
	melee_weapon.start_attack()

	print("Ally performed melee attack against enemy!")
