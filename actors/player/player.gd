extends CharacterBody2D

@export_group("Movement Parameters")
@export var max_speed : float = 250
@export var acceleration : float = 2000
@export var deceleration : float = 2500

@export_group("Dash Parameters")
@export var dash_strength : float = 2.5
@export var dash_duration : float = 0.2
@export var dash_cooldown : float = 1.0

@export_group("Ranged Weapon Parameters")
@export var projectile_scene : PackedScene

@export_group("Melee Weapon Parameters")
@export var melee_scene : PackedScene
# Melee weapon parameters are now in the melee_weapon.gd script

@export_group("Health Parameters")
@export var max_hp : int = 100
@export var hp_regen_rate : float = 0.5  # HP regenerated per second
@export var invulnerability_duration : float = 0.5  # Time in seconds player is invulnerable after taking damage

@export_group("Damage Parameters")
@export var base_damage : int = 10
@export var damage_multiplier : float = 1.0

@export_group("Stamina Parameters")
@export var max_stamina : float = 100.0
@export var stamina_regen_rate : float = 10.0  # Stamina regenerated per second
@export var dash_stamina_cost : float = 25.0

# Dash state variables
var can_dash : bool = true
var is_dashing : bool = false
var dash_timer : float = 0.0
var dash_cooldown_timer : float = 0.0
var dash_direction : Vector2 = Vector2.ZERO

# Ranged weapon variables
var can_shoot : bool = true
var shoot_cooldown_timer : float = 0.0

# Melee weapon variables
var can_melee_attack : bool = true
var melee_cooldown_timer : float = 0.0
var is_melee_attacking : bool = false
var melee_attack_timer : float = 0.0
var melee_weapon : Node = null

# Health and stamina variables
var current_hp : int = 0
var current_stamina : float = 0.0
var is_invulnerable : bool = false
var invulnerability_timer : float = 0.0
var damage_flash_timer : float = 0.0

# Buff variables
var damage_buff_active : bool = false
var damage_buff_multiplier : float = 1.0
var damage_buff_timer : float = 0.0
var speed_buff_active : bool = false
var speed_buff_multiplier : float = 1.0
var speed_buff_timer : float = 0.0
var defense_buff_active : bool = false
var defense_buff_multiplier : float = 1.0
var defense_buff_timer : float = 0.0

var character_direction : Vector2

func _ready() -> void:
	# Add to player group for enemy detection
	add_to_group("player")

	# Initialize dash effect
	$CPUParticles2D.emitting = false

	# Initialize health and stamina
	current_hp = max_hp - 50
	current_stamina = max_stamina

	# Initialize UI elements
	update_health_bar()
	update_stamina_bar()

	# Initialize melee weapon
	if melee_scene:
		melee_weapon = melee_scene.instantiate()
		melee_weapon.source = self
		$MeleeWeaponHolder.add_child(melee_weapon)

func _physics_process(delta: float) -> void:
	# Get input direction
	character_direction.x = Input.get_axis("move_left", "move_right")
	character_direction.y = Input.get_axis("move_up", "move_down")
	character_direction = character_direction.normalized()

	# Flip sprite based on movement direction
	if character_direction.x > 0: $Sprite2D.flip_h = false
	elif character_direction.x < 0: $Sprite2D.flip_h = true

	# Handle dash timers
	update_dash_state(delta)

	# Handle shooting cooldown
	update_shoot_state(delta)

	# Handle melee attack state
	update_melee_attack_state(delta)

	# Handle health and stamina regeneration
	update_health_and_stamina(delta)

	# Handle invulnerability timer
	update_invulnerability(delta)

	# Handle buff timers
	update_buffs(delta)

	# Process dash input
	if Input.is_action_just_pressed("dash") and can_dash and character_direction != Vector2.ZERO and current_stamina >= dash_stamina_cost:
		start_dash()

	# Process shooting input
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()

	# Process melee attack input
	if Input.is_action_pressed("melee_attack") and can_melee_attack and not is_melee_attacking:
		start_melee_attack()

	# Movement logic
	if is_dashing:
		# During dash, maintain dash velocity
		velocity = dash_direction * max_speed * dash_strength
	else:
		# Normal movement with acceleration/deceleration
		if character_direction:
			# Accelerate towards the target velocity
			var target_velocity = character_direction * max_speed
			velocity = velocity.move_toward(target_velocity, acceleration * delta)
		else:
			# Decelerate to zero when no input
			velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

	move_and_slide()

# Handle dash state and timers
func update_dash_state(delta: float) -> void:
	# Update dash cooldown timer
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

	# Update dash duration timer
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			end_dash()

# Start dash
func start_dash() -> void:
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	dash_direction = character_direction
	dash_cooldown_timer = dash_cooldown

	# Consume stamina
	current_stamina -= dash_stamina_cost
	update_stamina_bar()

	# Visual feedback
	$CPUParticles2D.emitting = true

	# Optional: play dash sound
	# $DashSound.play()

# End dash
func end_dash() -> void:
	is_dashing = false
	$CPUParticles2D.emitting = false

# Handle shoot state and cooldown
func update_shoot_state(delta: float) -> void:
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= delta
		if shoot_cooldown_timer <= 0:
			can_shoot = true

# Shoot projectile toward mouse position
func shoot() -> void:
	# Create projectile instance first to get its fire rate
	var projectile = projectile_scene.instantiate()

	# Set cooldown based on the projectile's fire rate
	can_shoot = false
	shoot_cooldown_timer = projectile.fire_rate

	# Set projectile position and source
	projectile.position = global_position
	projectile.source = self

	# Set projectile damage based on player's base damage and multiplier
	projectile.damage = int(base_damage * damage_multiplier)

	# Calculate direction to mouse position
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	projectile.set_direction(direction)

	# Add projectile to scene
	get_parent().add_child(projectile)

# Handle health and stamina regeneration
func update_health_and_stamina(delta: float) -> void:
	# Regenerate health if not at max
	if current_hp < max_hp:
		# Use integer division to avoid fractional HP
		var hp_to_add = int(hp_regen_rate * delta)
		if hp_to_add > 0:
			current_hp = min(current_hp + hp_to_add, max_hp)
			update_health_bar()

	# Regenerate stamina if not at max
	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + stamina_regen_rate * delta, max_stamina)
		update_stamina_bar()

# Update the health bar UI
func update_health_bar() -> void:
	if not has_node("CanvasLayer/UI/HealthBar"):
		return

	# Update health bar width based on current health percentage
	var health_percent = float(current_hp) / float(max_hp)
	var bar_width = 400 * health_percent
	$CanvasLayer/UI/HealthBar.size.x = bar_width

	# Update health text
	$CanvasLayer/UI/HealthLabel.text = "HP: %d/%d" % [current_hp, max_hp]

	# Change color based on health percentage
	if health_percent < 0.25:
		$CanvasLayer/UI/HealthBar.color = Color(0.9, 0.1, 0.1, 0.8)  # Red when low
	elif health_percent < 0.5:
		$CanvasLayer/UI/HealthBar.color = Color(0.9, 0.5, 0.1, 0.8)  # Orange when medium
	else:
		$CanvasLayer/UI/HealthBar.color = Color(0.8, 0.2, 0.2, 0.8)  # Normal red

# Update the stamina bar UI
func update_stamina_bar() -> void:
	if not has_node("CanvasLayer/UI/StaminaBar"):
		return

	# Update stamina bar width based on current stamina percentage
	var stamina_percent = current_stamina / max_stamina
	var bar_width = 400 * stamina_percent
	$CanvasLayer/UI/StaminaBar.size.x = bar_width

	# Update stamina text
	$CanvasLayer/UI/StaminaLabel.text = "Stamina: %d/%d" % [int(current_stamina), int(max_stamina)]

	# Change color based on stamina percentage
	if stamina_percent < 0.25:
		$CanvasLayer/UI/StaminaBar.color = Color(0.1, 0.3, 0.7, 0.8)  # Darker blue when low
	else:
		$CanvasLayer/UI/StaminaBar.color = Color(0.2, 0.6, 0.8, 0.8)  # Normal blue

# Handle invulnerability timer
func update_invulnerability(delta: float) -> void:
	if is_invulnerable:
		invulnerability_timer -= delta

		# Flash effect while invulnerable
		damage_flash_timer -= delta
		if damage_flash_timer <= 0:
			damage_flash_timer = 0.1  # Flash frequency
			modulate = Color(1, 1, 1, 1) if modulate.a < 1 else Color(1, 1, 1, 0.5)

		if invulnerability_timer <= 0:
			is_invulnerable = false
			modulate = Color(1, 1, 1, 1)  # Reset to normal

# Take damage from an attack
func take_damage(amount: int) -> void:
	# Skip if invulnerable
	if is_invulnerable:
		return

	# Apply damage
	current_hp = max(0, current_hp - amount)
	update_health_bar()

	# Start invulnerability period
	is_invulnerable = true
	invulnerability_timer = invulnerability_duration
	damage_flash_timer = 0.1

	# Visual feedback
	modulate = Color(1, 0.3, 0.3, 0.7)  # Red flash

	# Check for death
	if current_hp <= 0:
		die()

# Heal the player
func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
	update_health_bar()

# This function is replaced by the one below that includes buffs
# func get_damage_multiplier() -> float:
# 	return damage_multiplier

# Handle melee attack state and cooldown
func update_melee_attack_state(delta: float) -> void:
	# Update melee cooldown timer
	if melee_cooldown_timer > 0:
		melee_cooldown_timer -= delta
		if melee_cooldown_timer <= 0:
			can_melee_attack = true

# Start melee attack
func start_melee_attack() -> void:
	if not melee_weapon:
		return

	# Set cooldown
	can_melee_attack = false
	melee_cooldown_timer = melee_weapon.cooldown

	# Rotate melee weapon to face mouse position
	var mouse_pos = get_global_mouse_position()
	melee_weapon.face_position(mouse_pos)

	# Start the attack
	melee_weapon.start_attack()

# Update active buffs
func update_buffs(delta: float) -> void:
	# Update damage buff
	if damage_buff_active:
		damage_buff_timer -= delta
		if damage_buff_timer <= 0:
			damage_buff_active = false
			damage_buff_multiplier = 1.0

	# Update speed buff
	if speed_buff_active:
		speed_buff_timer -= delta
		if speed_buff_timer <= 0:
			speed_buff_active = false
			speed_buff_multiplier = 1.0

	# Update defense buff
	if defense_buff_active:
		defense_buff_timer -= delta
		if defense_buff_timer <= 0:
			defense_buff_active = false
			defense_buff_multiplier = 1.0

# Apply a damage buff
func apply_damage_buff(multiplier: float, duration: float) -> void:
	damage_buff_active = true
	damage_buff_multiplier = multiplier
	damage_buff_timer = duration

# Apply a speed buff
func apply_speed_buff(multiplier: float, duration: float) -> void:
	speed_buff_active = true
	speed_buff_multiplier = multiplier
	speed_buff_timer = duration

	# Update max_speed with the buff
	# Note: This assumes max_speed is reset when the buff expires

# Apply a defense buff (damage reduction)
func apply_defense_buff(multiplier: float, duration: float) -> void:
	defense_buff_active = true
	defense_buff_multiplier = multiplier
	defense_buff_timer = duration

# Apply multiple buffs at once
func apply_buffs(dmg_mult: float, spd_mult: float, def_mult: float, duration: float) -> void:
	apply_damage_buff(dmg_mult, duration)
	apply_speed_buff(spd_mult, duration)
	apply_defense_buff(def_mult, duration)

# Get current stamina (for skills)
func get_stamina() -> float:
	return current_stamina

# Consume stamina (for skills)
func consume_stamina(amount: float) -> void:
	current_stamina = max(0, current_stamina - amount)
	update_stamina_bar()

# Restore stamina (for skills)
func heal_stamina(amount: float) -> void:
	current_stamina = min(current_stamina + amount, max_stamina)
	update_stamina_bar()

# Get health percentage (for skills)
func get_health_percent() -> float:
	return float(current_hp) / float(max_hp)

# Override get_damage_multiplier to include buffs
func get_damage_multiplier() -> float:
	return damage_multiplier * damage_buff_multiplier

# Handle player death
func die() -> void:
	# Disable player input
	set_physics_process(false)

	# Visual feedback
	modulate = Color(0.5, 0.0, 0.0, 0.7)  # Dark red fade

	# Optional: Play death animation
	# $AnimationPlayer.play("death")

	print("Player died!")

	# Show game over message
	if has_node("CanvasLayer/UI"):
		var game_over_label = Label.new()
		game_over_label.text = "GAME OVER"
		game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		game_over_label.add_theme_font_size_override("font_size", 48)
		game_over_label.add_theme_color_override("font_color", Color(1, 0, 0))
		game_over_label.size = Vector2(400, 100)
		game_over_label.position = Vector2(get_viewport_rect().size.x / 2 - 200, get_viewport_rect().size.y / 2 - 50)
		$CanvasLayer/UI.add_child(game_over_label)

	# Create a timer to delay scene reload
	var timer = get_tree().create_timer(2.0)
	timer.connect("timeout", _on_death_timer_timeout)

# Called when death timer expires
func _on_death_timer_timeout() -> void:
	# Reset health and stamina
	current_hp = max_hp
	current_stamina = max_stamina
	update_health_bar()
	update_stamina_bar()

	# Reload the current scene
	get_tree().reload_current_scene()
