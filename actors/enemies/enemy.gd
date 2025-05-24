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
@export var combat_move_timer_min: float = 0.7
@export var combat_move_timer_max: float = 1.5
@export var combat_preferred_distance: float = 150.0 # for ranged (default to preferred_distance)
@export var combat_distance_threshold: float = 20.0 # for ranged (default to distance_threshold)
@export var combat_melee_range: float = 30.0 # for melee (default to attack_range)

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

# Buff variables
var damage_buff_active: bool = false
var damage_buff_multiplier: float = 1.0
var damage_buff_timer: float = 0.0
var speed_buff_active: bool = false
var speed_buff_multiplier: float = 1.0
var speed_buff_timer: float = 0.0
var defense_buff_active: bool = false
var defense_buff_multiplier: float = 1.0
var defense_buff_timer: float = 0.0

# Combat movement variables
var combat_move_timer: float = 0.0
var combat_move_direction: int = 1 # 1 for right, -1 for left

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

	# Update buff timers
	if damage_buff_active:
		damage_buff_timer -= delta
		if damage_buff_timer <= 0:
			damage_buff_active = false
			damage_buff_multiplier = 1.0
	if speed_buff_active:
		speed_buff_timer -= delta
		if speed_buff_timer <= 0:
			speed_buff_active = false
			speed_buff_multiplier = 1.0
	if defense_buff_active:
		defense_buff_timer -= delta
		if defense_buff_timer <= 0:
			defense_buff_active = false
			defense_buff_multiplier = 1.0

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
	if is_converted:
		# Converted enemies follow their own logic
		return
	# Find closest target (player or ally)
	var target = find_closest_target()
	if target:
		distance_to_player = global_position.distance_to(target.global_position)
		can_see_player = distance_to_player <= detection_radius
		target_position = target.global_position
		player_ref = target
		# Always update is_at_preferred_distance for current target
		if is_ranged:
			var was_at_preferred_distance = is_at_preferred_distance
			is_at_preferred_distance = abs(distance_to_player - preferred_distance) <= distance_threshold
			if is_at_preferred_distance != was_at_preferred_distance:
				update_ranged_status_visual()
	else:
		can_see_player = false

# Calculate movement direction
func calculate_direction() -> void:
	if can_see_player and player_ref != null:
		if is_ranged:
			if is_at_preferred_distance:
				combat_move_timer -= get_physics_process_delta_time()
				if combat_move_timer <= 0:
					combat_move_direction = (randi() % 2) * 2 - 1 # -1 or 1
					combat_move_timer = randf_range(combat_move_timer_min, combat_move_timer_max)
				var to_target = global_position.direction_to(target_position)
				var strafe = Vector2(-to_target.y, to_target.x) * combat_move_direction
				direction = strafe.normalized()
			else:
				calculate_ranged_direction()
		else:
			if distance_to_player <= combat_melee_range:
				combat_move_timer -= get_physics_process_delta_time()
				if combat_move_timer <= 0:
					combat_move_direction = (randi() % 2) * 2 - 1 # -1 or 1
					combat_move_timer = randf_range(combat_move_timer_min, combat_move_timer_max)
				var to_target = global_position.direction_to(target_position)
				var strafe = Vector2(-to_target.y, to_target.x) * combat_move_direction
				direction = strafe.normalized()
			else:
				direction = global_position.direction_to(target_position)
	else:
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
			if is_at_preferred_distance:
				combat_move_timer -= get_physics_process_delta_time()
				if combat_move_timer <= 0:
					combat_move_direction = (randi() % 2) * 2 - 1 # -1 or 1
					combat_move_timer = randf_range(combat_move_timer_min, combat_move_timer_max)
				var to_enemy = global_position.direction_to(closest_enemy.global_position)
				var strafe = Vector2(-to_enemy.y, to_enemy.x) * combat_move_direction
				direction = strafe.normalized()
			else:
				if closest_distance < combat_preferred_distance - combat_distance_threshold:
					direction = global_position.direction_to(closest_enemy.global_position) * -1
				elif closest_distance > combat_preferred_distance + combat_distance_threshold:
					direction = global_position.direction_to(closest_enemy.global_position)
				else:
					direction = Vector2.ZERO
		else:
			if closest_distance <= combat_melee_range:
				combat_move_timer -= get_physics_process_delta_time()
				if combat_move_timer <= 0:
					combat_move_direction = (randi() % 2) * 2 - 1 # -1 or 1
					combat_move_timer = randf_range(combat_move_timer_min, combat_move_timer_max)
				var to_enemy = global_position.direction_to(closest_enemy.global_position)
				var strafe = Vector2(-to_enemy.y, to_enemy.x) * combat_move_direction
				direction = strafe.normalized()
			else:
				direction = global_position.direction_to(closest_enemy.global_position)
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
		var target_velocity = direction * max_speed * speed_buff_multiplier
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

	# Apply defense buff (damage reduction)
	var final_amount = int(amount * defense_buff_multiplier)
	current_hp = max(0, current_hp - final_amount)

	# Flash red to indicate damage
	modulate = Color(1.0, 0.0, 0.0, 1.0)

	# Create a timer to reset the color
	var timer = get_tree().create_timer(0.2)
	timer.connect("timeout", _on_damage_flash_timeout)

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
		# Enemy behavior - attack player or ally
		if player_ref == null:
			print("[Enemy] No valid target to attack!")
			return
		if is_ranged:
			# Always update is_at_preferred_distance for current target
			var dist = global_position.distance_to(player_ref.global_position)
			is_at_preferred_distance = abs(dist - preferred_distance) <= distance_threshold
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

		if is_ranged:
			# Ranged attack - always shoot if within reasonable range
			# Relaxed distance check for ranged allies
			if closest_distance <= detection_radius:
				shoot_projectile_at_enemy(target_enemy)
			else:
				pass
		else:
			# Melee attack - if close enough
			if closest_distance <= attack_range and melee_weapon:
				start_melee_attack_at_enemy(target_enemy)
			else:
				pass
	else:
		pass

# Shoot a projectile at the player
func shoot_projectile() -> void:
	# Skip if no projectile scene
	if not projectile_scene:
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


# Called when melee attack is finished
func _on_melee_attack_finished() -> void:
	is_attacking = false

# Shoot a projectile at a specific enemy
func shoot_projectile_at_enemy(target_enemy: Node2D) -> void:
	# Skip if no projectile scene
	if not projectile_scene:
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

func apply_damage_buff(multiplier: float, duration: float) -> void:
	damage_buff_active = true
	damage_buff_multiplier = multiplier
	damage_buff_timer = duration

func apply_speed_buff(multiplier: float, duration: float) -> void:
	speed_buff_active = true
	speed_buff_multiplier = multiplier
	speed_buff_timer = duration

func apply_defense_buff(multiplier: float, duration: float) -> void:
	defense_buff_active = true
	defense_buff_multiplier = multiplier
	defense_buff_timer = duration

func apply_buffs(dmg_mult: float, spd_mult: float, def_mult: float, duration: float) -> void:
	apply_damage_buff(dmg_mult, duration)
	apply_speed_buff(spd_mult, duration)
	apply_defense_buff(def_mult, duration)

func get_damage_multiplier() -> float:
	return damage_buff_multiplier

# Add a helper to find the closest target (player or ally)
func find_closest_target() -> Node2D:
	var candidates = []
	candidates += get_tree().get_nodes_in_group("player")
	candidates += get_tree().get_nodes_in_group("ally")
	var closest = null
	var closest_distance = INF
	for node in candidates:
		if node == self:
			continue
		var dist = global_position.distance_to(node.global_position)
		if dist < closest_distance:
			closest = node
			closest_distance = dist
	return closest
