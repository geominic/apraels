extends CharacterBody2D

@export_group("Prisoner Parameters")
@export var max_hp: int = 100
@export var weapon_scene: PackedScene # Assign in inspector (melee or ranged)
@export var is_ranged: bool = false # Determines AI behavior

var current_hp: int = 0
var is_freed: bool = false
var ally_timer: float = 0.0
var player_ref: Node2D = null
var melee_weapon: Node = null
var _shoot_cooldown: float = 0.0

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
			# Move toward or attack enemy
			if is_ranged:
				velocity = Vector2.ZERO
				look_at(closest_enemy.global_position)
				shoot_projectile_at_enemy(closest_enemy)
			else:
				if closest_distance > 50:
					velocity = global_position.direction_to(closest_enemy.global_position) * 100
				else:
					velocity = Vector2.ZERO
					start_melee_attack_at_enemy(closest_enemy)
		else:
			# Follow player
			var dist_to_player = global_position.distance_to(player_ref.global_position)
			if dist_to_player > 50:
				velocity = global_position.direction_to(player_ref.global_position) * 100
			else:
				velocity = Vector2.ZERO

		move_and_slide()

func free_prisoner(player: Node2D, duration: float, health: int) -> void:
	is_freed = true
	ally_timer = duration
	player_ref = player
	current_hp = health
	remove_from_group("prisoner")
	add_to_group("ally")
	modulate = Color(0.2, 0.8, 0.2, 1.0) # Green tint
	update_health_bar()
	_initialize_weapon()

func revert_to_prisoner() -> void:
	is_freed = false
	ally_timer = 0.0
	player_ref = null
	remove_from_group("ally")
	add_to_group("prisoner")
	modulate = Color(1, 1, 1, 1)
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
	projectile.damage = 10 # Or parameterize
	var direction = global_position.direction_to(enemy.global_position)
	projectile.set_direction(direction)
	get_parent().add_child(projectile)

func start_melee_attack_at_enemy(enemy: Node2D) -> void:
	if not melee_weapon or not enemy:
		return
	melee_weapon.face_position(enemy.global_position)
	melee_weapon.start_attack()

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	update_health_bar()
	if current_hp <= 0:
		die()

func die() -> void:
	queue_free()

func update_health_bar() -> void:
	if has_node("HealthLabel"):
		$HealthLabel.text = "HP: %d/%d" % [current_hp, max_hp]
	if has_node("HealthBar"):
		$HealthBar.size.x = 192 * float(current_hp) / float(max_hp)
