extends CharacterBody2D

@export_group("Prisoner Parameters")
@export var max_hp: int = 100
@export var speed: int = 100
@export var weapon_scene: PackedScene # Assign in inspector (melee or ranged)
@export var is_ranged: bool = false # Determines AI behavior
@export var combat_move_timer_min: float = 0.7
@export var combat_move_timer_max: float = 1.5
@export var combat_preferred_distance: float = 200.0 # for ranged
@export var combat_distance_threshold: float = 20.0 # for ranged
@export var combat_melee_range: float = 50.0 # for melee

var current_hp: int = 0
var is_freed: bool = false
var ally_timer: float = 0.0
var player_ref: Node2D = null
var melee_weapon: Node = null
var _shoot_cooldown: float = 0.0

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

# Add invulnerability variables
var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0
var damage_flash_timer: float = 0.0
const INVULNERABILITY_DURATION: float = 0.5

# Combat movement variables
var combat_move_timer: float = 0.0
var combat_move_direction: int = 1 # 1 for right, -1 for left

func _ready() -> void:
	current_hp = max_hp
	add_to_group("prisoner")
	update_health_bar()

func _physics_process(delta: float) -> void:
	if !is_freed:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Ally logic: follow player, attack enemies
	if ally_timer > 0:
		ally_timer -= delta
		if ally_timer <= 0:
			revert_to_prisoner()
			return

		if player_ref == null:
			_find_player()
			return

		# Follow player if no enemies nearby
		var enemies = get_tree().get_nodes_in_group("enemy")
		var closest_enemy = null
		var closest_distance = 99999.0
		for enemy in enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_distance:
				closest_enemy = enemy
				closest_distance = dist

		if closest_enemy and closest_distance < 300:
			if is_ranged:
				if abs(closest_distance - combat_preferred_distance) <= combat_distance_threshold:
					combat_move_timer -= delta
					if combat_move_timer <= 0:
						combat_move_direction = (randi() % 2) * 2 - 1 # -1 or 1
						combat_move_timer = randf_range(combat_move_timer_min, combat_move_timer_max)
					var to_enemy = global_position.direction_to(closest_enemy.global_position)
					var strafe = Vector2(-to_enemy.y, to_enemy.x) * combat_move_direction
					velocity = strafe.normalized() * speed * speed_buff_multiplier
					shoot_projectile_at_enemy(closest_enemy)
				elif closest_distance < combat_preferred_distance:
					velocity = -global_position.direction_to(closest_enemy.global_position) * speed * speed_buff_multiplier
					shoot_projectile_at_enemy(closest_enemy)
				else:
					velocity = global_position.direction_to(closest_enemy.global_position) * speed * speed_buff_multiplier
			else:
				if closest_distance > combat_melee_range:
					velocity = global_position.direction_to(closest_enemy.global_position) * speed * speed_buff_multiplier
				else:
					combat_move_timer -= delta
					if combat_move_timer <= 0:
						combat_move_direction = (randi() % 2) * 2 - 1 # -1 or 1
						combat_move_timer = randf_range(combat_move_timer_min, combat_move_timer_max)
					var to_enemy = global_position.direction_to(closest_enemy.global_position)
					var strafe = Vector2(-to_enemy.y, to_enemy.x) * combat_move_direction
					velocity = strafe.normalized() * speed * speed_buff_multiplier
					start_melee_attack_at_enemy(closest_enemy)
		else:
			# Follow player
			var dist_to_player = global_position.distance_to(player_ref.global_position)
			if dist_to_player > 50:
				velocity = global_position.direction_to(player_ref.global_position) * speed * speed_buff_multiplier
			else:
				velocity = Vector2.ZERO

		move_and_slide()

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

	# Update invulnerability timer and flash
	if is_invulnerable:
		invulnerability_timer -= delta
		damage_flash_timer -= delta
		if damage_flash_timer <= 0:
			damage_flash_timer = 0.1
			modulate = Color(1, 1, 1, 1) if modulate.a < 1 else Color(1, 1, 1, 0.5)
		if invulnerability_timer <= 0:
			is_invulnerable = false
			modulate = Color(1, 1, 1, 1) if !is_freed else Color(0.2, 0.8, 0.2, 1.0)

func free_prisoner(player: Node2D, duration: float, health: int) -> void:
	is_freed = true
	ally_timer = duration
	player_ref = player
	current_hp = health
	remove_from_group("prisoner")
	add_to_group("ally")
	modulate = Color(0.2, 0.8, 0.2, 1.0) # Green tint
	is_invulnerable = false
	invulnerability_timer = 0.0
	update_health_bar()
	_initialize_weapon()

func revert_to_prisoner() -> void:
	is_freed = false
	ally_timer = 0.0
	player_ref = null
	remove_from_group("ally")
	add_to_group("prisoner")
	modulate = Color(1, 1, 1, 1)
	is_invulnerable = false
	invulnerability_timer = 0.0
	if melee_weapon:
		melee_weapon.queue_free()
		melee_weapon = null
	update_health_bar()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func _initialize_weapon() -> void:
	if weapon_scene:
		if is_ranged:
			# Ranged: handled in shoot_projectile_at_enemy
			pass
		else:
			if not has_node("MeleeWeaponHolder"):
				var holder = Node2D.new()
				holder.name = "MeleeWeaponHolder"
				add_child(holder)
			melee_weapon = weapon_scene.instantiate()
			melee_weapon.source = self
			$MeleeWeaponHolder.add_child(melee_weapon)

func shoot_projectile_at_enemy(enemy: Node2D) -> void:
	if not is_ranged or not weapon_scene:
		return
	if not enemy:
		return
	if not has_node("ProjectileSpawn"):
		return
	# Only shoot if not already a projectile in flight (simple cooldown)
	if _shoot_cooldown > 0:
		_shoot_cooldown -= get_process_delta_time()
		return
	_shoot_cooldown = 1.0 # Fire rate, can be parameterized
	var projectile = weapon_scene.instantiate()
	projectile.position = $ProjectileSpawn.global_position
	projectile.source = self
	projectile.damage *= damage_buff_multiplier #changed
	var direction = global_position.direction_to(enemy.global_position)
	projectile.set_direction(direction)
	get_parent().add_child(projectile)

func start_melee_attack_at_enemy(enemy: Node2D) -> void:
	if not melee_weapon or not enemy:
		return
	melee_weapon.face_position(enemy.global_position)
	melee_weapon.start_attack()

func take_damage(amount: int) -> void:
	if is_invulnerable:
		return
	var final_amount = int(amount * defense_buff_multiplier)
	if final_amount < 1 and amount > 0:
		final_amount = 1
	current_hp = max(0, current_hp - final_amount)
	update_health_bar()
	# Start invulnerability period
	is_invulnerable = true
	invulnerability_timer = INVULNERABILITY_DURATION
	damage_flash_timer = 0.1
	modulate = Color(1, 0.3, 0.3, 0.7)  # Red flash
	if current_hp <= 0:
		die()

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
	update_health_bar()

func die() -> void:
	print("[Prisoner] Died and queue_free called")
	# Optionally, add a visual effect here
	queue_free()

func update_health_bar() -> void:
	if has_node("HealthLabel"):
		$HealthLabel.text = "HP: %d/%d" % [current_hp, max_hp]
	if has_node("HealthBar"):
		$HealthBar.size.x = 64 * float(current_hp) / float(max_hp)
		# Color change based on health percent
		var health_percent = float(current_hp) / float(max_hp)
		if health_percent < 0.25:
			$HealthBar.color = Color(0.9, 0.1, 0.1, 0.8)  # Red when low
		elif health_percent < 0.5:
			$HealthBar.color = Color(0.9, 0.5, 0.1, 0.8)  # Orange when medium
		else:
			$HealthBar.color = Color(0.8, 0.2, 0.2, 0.8)  # Normal red

# Buff application methods
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
	print("Buff applied to: ", self.name, " DMG:", dmg_mult, " SPD:", spd_mult, " DEF:", def_mult, " DUR:", duration)
	apply_damage_buff(dmg_mult, duration)
	apply_speed_buff(spd_mult, duration)
	apply_defense_buff(def_mult, duration)

func get_damage_multiplier() -> float:
	return damage_buff_multiplier
