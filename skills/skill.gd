extends Node2D
class_name Skill

# Basic skill properties
@export var skill_name : String = "Base Skill"
@export var description : String = "Base skill description"
@export var icon : Texture2D
@export var cooldown : float = 5.0
@export var mana_cost : int = 10
@export var stamina_cost : float = 20.0
@export var skill_range : float = 100.0  # How far the skill can reach
@export var skill_duration : float = 0.0  # For skills with duration effects
@export var skill_key : String = "skill_1"  # Default input mapping

# Skill state
var is_ready : bool = true
var cooldown_timer : float = 0.0
var caster : Node = null  # Who is using this skill
var skill_level : int = 1  # For skill upgrades

# Visual feedback
@export var skill_color : Color = Color(1.0, 1.0, 1.0, 1.0)
@export var skill_effect_scene : PackedScene  # Visual effect to spawn

# Signals
signal skill_activated(skill)
signal skill_completed(skill)
signal skill_failed(skill, reason)

func _ready() -> void:
	# Initialize skill
	set_process(false)  # Only process when active

func _process(delta: float) -> void:
	# Update cooldown
	if not is_ready:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			is_ready = true
			set_process(false)

# Activate the skill
func activate(user: Node, target_position: Vector2 = Vector2.ZERO) -> bool:
	if not can_activate(user):
		return false

	caster = user

	# Start cooldown
	is_ready = false
	cooldown_timer = cooldown
	set_process(true)

	# Consume resources
	if user.has_method("consume_stamina"):
		user.consume_stamina(stamina_cost)

	# Emit signal
	emit_signal("skill_activated", self)

	# Execute skill effect (to be overridden by child classes)
	_execute_skill_effect(target_position)

	return true

# Check if the skill can be activated
func can_activate(user: Node) -> bool:
	if not is_ready:
		emit_signal("skill_failed", self, "Skill is on cooldown")
		return false

	# Check stamina
	if stamina_cost > 0 and user.has_method("get_stamina"):
		if user.get_stamina() < stamina_cost:
			emit_signal("skill_failed", self, "Not enough stamina")
			return false

	# Check range if applicable
	# This would be implemented in child classes

	return true

# Execute the skill effect (to be overridden by child classes)
func _execute_skill_effect(_target_position: Vector2) -> void:
	# Base implementation does nothing
	# Child classes should override this

	# When done, emit completed signal
	emit_signal("skill_completed", self)

# Get skill info for UI
func get_skill_info() -> Dictionary:
	return {
		"name": skill_name,
		"description": description,
		"icon": icon,
		"cooldown": cooldown,
		"cooldown_remaining": cooldown_timer if not is_ready else 0.0,
		"stamina_cost": stamina_cost,
		"is_ready": is_ready,
		"level": skill_level
	}

# Spawn a visual effect at the target position
func spawn_effect(effect_position: Vector2) -> void:
	if skill_effect_scene:
		var effect = skill_effect_scene.instantiate()
		effect.global_position = effect_position
		get_tree().current_scene.add_child(effect)

# Level up the skill
func level_up() -> void:
	skill_level += 1
	_apply_level_bonuses()

# Apply bonuses based on skill level (to be overridden by child classes)
func _apply_level_bonuses() -> void:
	# Base implementation does nothing
	pass
