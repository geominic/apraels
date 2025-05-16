extends Node
class_name SkillManager

# Skill slots
@export var skill_1 : PackedScene
@export var skill_2 : PackedScene
@export var skill_3 : PackedScene
@export var skill_4 : PackedScene
@export var skill_5 : PackedScene

# References
var player : Node = null
var active_skills : Dictionary = {}  # Maps input action to skill instance
var skill_nodes : Array = []  # List of all skill nodes

# Signals
signal skill_activated(skill)
signal skill_completed(skill)
signal skill_failed(skill, reason)

func _ready() -> void:
	# Get player reference
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	if not player:
		push_error("SkillManager: Player not found!")
		return

	# Load skills
	_load_skills()

	# Connect signals
	for skill in skill_nodes:
		skill.skill_activated.connect(_on_skill_activated)
		skill.skill_completed.connect(_on_skill_completed)
		skill.skill_failed.connect(_on_skill_failed)

func _process(_delta: float) -> void:
	# Check for skill inputs
	for action in active_skills:
		if Input.is_action_just_pressed(action):
			activate_skill(action)

# Load all skills into the scene
func _load_skills() -> void:
	# Clear existing skills
	for skill in skill_nodes:
		skill.queue_free()

	skill_nodes.clear()
	active_skills.clear()

	# Load skill 1
	if skill_1:
		var skill = skill_1.instantiate()
		add_child(skill)
		skill_nodes.append(skill)
		active_skills["skill_1"] = skill

	# Load skill 2
	if skill_2:
		var skill = skill_2.instantiate()
		add_child(skill)
		skill_nodes.append(skill)
		active_skills["skill_2"] = skill

	# Load skill 3
	if skill_3:
		var skill = skill_3.instantiate()
		add_child(skill)
		skill_nodes.append(skill)
		active_skills["skill_3"] = skill

	# Load skill 4
	if skill_4:
		var skill = skill_4.instantiate()
		add_child(skill)
		skill_nodes.append(skill)
		active_skills["skill_4"] = skill

	# Load skill 5
	if skill_5:
		var skill = skill_5.instantiate()
		add_child(skill)
		skill_nodes.append(skill)
		active_skills["skill_5"] = skill

# Activate a skill by its input action
func activate_skill(action: String) -> bool:
	if not action in active_skills:
		return false

	var skill = active_skills[action]
	# Get mouse position from viewport
	var target_position = Vector2.ZERO
	if player:
		target_position = player.get_global_mouse_position()

	return skill.activate(player, target_position)

# Get skill info for UI
func get_skill_info(action: String) -> Dictionary:
	if not action in active_skills:
		return {}

	return active_skills[action].get_skill_info()

# Signal handlers
func _on_skill_activated(skill) -> void:
	emit_signal("skill_activated", skill)

func _on_skill_completed(skill) -> void:
	emit_signal("skill_completed", skill)

func _on_skill_failed(skill, reason) -> void:
	emit_signal("skill_failed", skill, reason)

	# Show feedback to player
	if player and player.has_node("CanvasLayer/UI"):
		# You could implement a notification system here
		print("Skill failed: " + reason)
