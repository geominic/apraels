extends Area2D

signal attack_finished

@export_group("Basic Attack Parameters")
@export var damage : int = 20
@export var attack_duration : float = 0.2
@export var cooldown : float = 0.4
@export var swing_angle : float = 90.0  # Swing angle in degrees
@export var swing_direction : int = 1  # 1 for clockwise, -1 for counter-clockwise

@export_group("Combo System")
@export var combo_window : float = 1.2  # Time window to perform the next attack in combo
@export var combo_damage_multiplier_2 : float = 1.25  # Damage multiplier for second attack in combo
@export var combo_damage_multiplier_3 : float = 1.5  # Damage multiplier for third attack in combo
@export var combo_swing_angle_2 : float = 120.0  # Swing angle for second attack
@export var combo_swing_angle_3 : float = 180.0  # Swing angle for third attack
@export var combo_attack_duration_2 : float = 0.25  # Duration for second attack
@export var combo_attack_duration_3 : float = 0.3  # Duration for third attack

var is_attacking : bool = false
var attack_timer : float = 0.0
var cooldown_timer : float = 0.0  # Separate timer for cooldown
var can_attack : bool = true  # Whether the weapon can be used
var source : Node = null  # Who is using this weapon

# Swing animation variables
var start_rotation : float = 0.0
var end_rotation : float = 0.0
var swing_progress : float = 0.0

# Combo system variables
var current_combo : int = 1  # Current combo stage (1, 2, or 3)
var combo_timer : float = 0.0  # Timer for combo window
var combo_active : bool = false  # Whether a combo is currently active
var last_attack_ended : float = 0.0  # Time when the last attack ended

func _ready() -> void:
	# Initialize in hidden state
	visible = false
	monitoring = false
	monitorable = false

	# Disable collision shape
	if has_node("MeleeShape"):
		$MeleeShape.disabled = true

	# Connect body entered signal
	connect("body_entered", _on_body_entered)

	# Create a debug arc indicator if in editor
	if Engine.is_editor_hint():
		update_arc_indicator()

func _physics_process(delta: float) -> void:
	# Update attack timer
	if is_attacking:
		attack_timer -= delta

		# Update swing animation
		if attack_duration > 0:
			swing_progress = 1.0 - (attack_timer / attack_duration)
			swing_progress = clamp(swing_progress, 0.0, 1.0)

			# Calculate current rotation based on swing progress
			var current_rotation = lerp_angle(start_rotation, end_rotation, swing_progress)
			rotation = current_rotation

			# Check for hits at different points in the swing
			if swing_progress > 0.2 and swing_progress < 0.8:
				check_hits()

		if attack_timer <= 0:
			end_attack()

	# Update cooldown timer (separate from attack animation)
	if cooldown_timer > 0:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_attack = true

	# Update combo timer
	if combo_active:
		combo_timer -= delta
		if combo_timer <= 0:
			# Combo window expired, reset combo
			reset_combo()

	# Check if it's been too long since the last attack
	elif Time.get_ticks_msec() / 1000.0 - last_attack_ended > combo_window * 1.5:
		# Reset combo if we haven't attacked in a while
		reset_combo()

# Reset combo to initial state
func reset_combo() -> void:
	current_combo = 1
	combo_active = false
	combo_timer = 0.0

# Start a melee attack
func start_attack() -> void:
	# Check if we can attack
	if not can_attack:
		return

	is_attacking = true
	can_attack = false  # Prevent attacking until cooldown is complete

	# Apply combo-specific parameters
	var current_swing_angle = swing_angle
	var current_attack_duration = attack_duration

	# Set parameters based on current combo stage
	match current_combo:
		1:
			current_swing_angle = swing_angle
			current_attack_duration = attack_duration
		2:
			current_swing_angle = combo_swing_angle_2
			current_attack_duration = combo_attack_duration_2
		3:
			current_swing_angle = combo_swing_angle_3
			current_attack_duration = combo_attack_duration_3

	# Set attack timer based on current combo stage
	attack_timer = current_attack_duration
	swing_progress = 0.0

	# Show weapon and enable collision
	visible = true
	monitoring = true
	monitorable = true

	# Make sure collision shape is enabled
	if has_node("MeleeShape"):
		$MeleeShape.disabled = false

	# Set up swing animation
	# Start from the current rotation
	start_rotation = rotation

	# Calculate end rotation based on swing angle and direction
	var half_swing = deg_to_rad(current_swing_angle / 2.0)
	end_rotation = start_rotation + (half_swing * swing_direction * 2.0)

	# Visual feedback for combo
	match current_combo:
		1:
			modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal color
		2:
			modulate = Color(1.0, 0.7, 0.2, 1.0)  # Orange for second attack
		3:
			modulate = Color(1.0, 0.2, 0.2, 1.0)  # Red for third attack

# End the attack
func end_attack() -> void:
	is_attacking = false
	visible = false
	monitoring = false
	monitorable = false

	# Disable collision shape
	if has_node("MeleeShape"):
		$MeleeShape.disabled = true

	# Start cooldown timer AFTER the attack animation is complete
	# This way, the cooldown doesn't overlap with the attack animation
	cooldown_timer = cooldown

	# Update combo state
	last_attack_ended = Time.get_ticks_msec() / 1000.0

	# Advance combo if not at max
	if current_combo < 3:
		current_combo += 1
		combo_active = true
		combo_timer = combo_window
	else:
		# Reset immediately after the 3rd combo attack
		reset_combo()

	# Emit signal to notify that the attack is finished
	emit_signal("attack_finished")

# Face the weapon toward a target position
func face_position(target_pos: Vector2) -> void:
	var direction = (target_pos - global_position).normalized()
	var target_angle = direction.angle()

	# Offset the initial rotation to prepare for the swing
	var half_swing = deg_to_rad(swing_angle / 2.0)
	rotation = target_angle - (half_swing * swing_direction)

# Check for targets hit by the attack
func check_hits() -> void:
	# Determine which targets to check based on who's using the weapon
	var targets = []

	if source and source.is_in_group("player"):
		# Player attacking enemies
		targets = get_tree().get_nodes_in_group("enemy")
	elif source and source.is_in_group("enemy"):
		# Enemy attacking players and allies
		targets = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("ally")
	elif source and source.is_in_group("ally"):
		# Ally attacking enemies
		targets = get_tree().get_nodes_in_group("enemy")
	else:
		return

	# Get the collision shape
	var collision_shape = $MeleeShape
	if not collision_shape or not collision_shape.shape:
		return

	# Get shape dimensions
	var shape_extents = Vector2.ZERO
	if collision_shape.shape is RectangleShape2D:
		shape_extents = collision_shape.shape.size / 2
	elif collision_shape.shape is CircleShape2D:
		shape_extents = Vector2(collision_shape.shape.radius, collision_shape.shape.radius)
	else:
		# Fallback for other shape types
		shape_extents = Vector2(20, 10)

	# Get the weapon's global transform
	var weapon_transform = global_transform

	# Check if any targets are within the melee weapon's area
	for target in targets:
		# Skip allies if source is player
		if source.is_in_group("player") and target.is_in_group("ally"):
			continue

		# Skip player if source is ally
		if source.is_in_group("ally") and target.is_in_group("player"):
			continue

		var target_pos = target.global_position

		# Convert target position to local space
		var local_target_pos = weapon_transform.affine_inverse() * target_pos

		# Adjust for collision shape offset
		local_target_pos -= collision_shape.position

		# Check if the target is within the shape bounds
		var is_hit = false

		if collision_shape.shape is RectangleShape2D:
			is_hit = abs(local_target_pos.x) < shape_extents.x and abs(local_target_pos.y) < shape_extents.y
		elif collision_shape.shape is CircleShape2D:
			is_hit = local_target_pos.length() < shape_extents.x

		if is_hit:
			# Apply damage to target
			apply_damage_to_target(target)

# Handle collision with bodies
func _on_body_entered(body: Node) -> void:
	# Skip collision with source
	if body == source:
		return

	# Skip collision with allies (converted enemies)
	if source and source.is_in_group("ally") and body.is_in_group("player"):
		return
	if source and source.is_in_group("player") and body.is_in_group("ally"):
		return
	if source and source.is_in_group("ally") and body.is_in_group("ally"):
		return

	# Handle collision with enemies (when player attacks)
	if source and source.is_in_group("player") and body.is_in_group("enemy"):
		apply_damage_to_target(body)

	# Handle collision with player (when enemy attacks)
	elif source and source.is_in_group("enemy") and body.is_in_group("player"):
		apply_damage_to_target(body)

	# Handle collision with enemies (when ally attacks)
	elif source and source.is_in_group("ally") and body.is_in_group("enemy"):
		apply_damage_to_target(body)
		
	# Handle collision with ally (when enemy attacks)
	elif source and source.is_in_group("enemy") and body.is_in_group("ally"):
		apply_damage_to_target(body)

# Apply damage to the target
func apply_damage_to_target(target: Node) -> void:
	if not target.has_method("take_damage"):
		return

	# Get base damage
	var damage_amount = damage

	# Apply combo multiplier based on current combo stage
	var combo_multiplier = 1.0
	match current_combo:
		1:
			combo_multiplier = 1.0
		2:
			combo_multiplier = combo_damage_multiplier_2
		3:
			combo_multiplier = combo_damage_multiplier_3

	# Apply source's damage multiplier if available
	if source and source.has_method("get_damage_multiplier"):
		damage_amount = int(damage * source.get_damage_multiplier() * combo_multiplier)
	else:
		damage_amount = int(damage * combo_multiplier)

	target.take_damage(damage_amount)

# Get current combo information for UI display
func get_combo_info() -> Dictionary:
	return {
		"current_combo": current_combo,
		"combo_active": combo_active,
		"combo_timer": combo_timer,
		"combo_window": combo_window
	}

# Create a visual indicator for the swing arc (for debugging)
func update_arc_indicator() -> void:
	# Remove any existing arc indicator
	for child in get_children():
		if child.name == "ArcIndicator":
			child.queue_free()

	# Create a new arc indicator
	var arc = Node2D.new()
	arc.name = "ArcIndicator"
	add_child(arc)

	# Draw the arc in _draw
	arc.set_script(preload("res://weapons/arc_indicator.gd"))

	# Get the collision shape to determine arc radius
	var collision_shape = $MeleeShape
	var arc_radius = 50.0  # Default fallback value

	if collision_shape and collision_shape.shape:
		if collision_shape.shape is RectangleShape2D:
			# Use the length of the rectangle (assuming it's oriented horizontally)
			arc_radius = collision_shape.shape.size.x
		elif collision_shape.shape is CircleShape2D:
			arc_radius = collision_shape.shape.radius * 2

	# Set arc properties
	arc.swing_angle = swing_angle
	arc.swing_direction = swing_direction
	arc.arc_radius = arc_radius
	arc.arc_color = Color(1.0, 0.5, 0.0, 0.5)  # Orange, semi-transparent
