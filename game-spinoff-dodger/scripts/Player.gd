extends CharacterBody2D

# ── Constants ──────────────────────────────────────────────────────────
const SPEED          := 230.0
const GAME_W         := 960
const GAME_H         := 540
const HIT_RADIUS     := 48.0     # collision distance vs enemies
const PICK_RADIUS    := 58.0     # pickup distance vs zongzi
const SCARE_RANGE    := 380.0    # skill reach
const MAX_HP         := 3
const MAX_CHARGES    := 2
const COOLDOWN_TIME  := 10.0     # seconds per charge refill
const TAUNT_FRAME_T  := 0.20     # seconds per taunt animation frame
const BOAT_SCALE     := 0.32     # visual scale for the boat sprite

# ── State ──────────────────────────────────────────────────────────────
var health         := MAX_HP
var invincible     := false
var inv_timer      := 0.0
var charges        := MAX_CHARGES
var cooldown       := 0.0
var is_taunting    := false
var taunt_frame    := 0
var taunt_timer    := 0.0
var active         := false      # set by Main when game starts

# ── Node refs ──────────────────────────────────────────────────────────
var boat_sprite   : Sprite2D
var taunt_sprite  : Sprite2D
var taunt_textures: Array        # loaded in _ready

signal health_changed(new_hp: int)
signal skill_changed(charges: int, cooldown_frac: float)

# ═══════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# Collision shape (required for CharacterBody2D)
	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90.0, 38.0)
	col.shape = rect
	add_child(col)

	# Green boat sprite
	boat_sprite         = Sprite2D.new()
	boat_sprite.texture = load("res://assets/green_team_boat.png")
	boat_sprite.scale   = Vector2(BOAT_SCALE, BOAT_SCALE)
	add_child(boat_sprite)

	# Taunt sprite — floats above-right of boat, hidden until skill fires
	taunt_sprite          = Sprite2D.new()
	taunt_sprite.visible  = false
	taunt_sprite.position = Vector2(70.0, -75.0)
	taunt_sprite.scale    = Vector2(0.30, 0.30)
	add_child(taunt_sprite)

	# Load the 3-frame taunt animation (viral HK paddler)
	taunt_textures = [
		load("res://assets/taunt_f1_cutout.png"),   # rising up
		load("res://assets/taunt_f2_precise.png"),  # arms wide standoff
		load("res://assets/taunt_f3_cutout.png"),   # paddle POINTED (Saizeriya Easter egg 🍝)
	]

# ═══════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if not active:
		return

	_move(delta)
	_handle_skill_input()
	_tick_cooldown(delta)
	_tick_invincibility(delta)
	_tick_taunt(delta)
	_check_hits()

	# Keep inside game area
	position.x = clamp(position.x, 55.0, GAME_W - 80.0)
	position.y = clamp(position.y, 65.0, GAME_H - 65.0)

# ── Movement ───────────────────────────────────────────────────────────
func _move(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1.0
	if Input.is_action_pressed("ui_left"):  dir.x -= 1.0
	if Input.is_action_pressed("ui_up"):    dir.y -= 1.0
	if Input.is_action_pressed("ui_down"):  dir.y += 1.0
	velocity = dir.normalized() * SPEED
	move_and_slide()

# ── Skill ──────────────────────────────────────────────────────────────
func _handle_skill_input() -> void:
	if Input.is_action_just_pressed("ui_accept") and charges > 0 and not is_taunting:
		_activate_skill()

func _activate_skill() -> void:
	charges    -= 1
	is_taunting = true
	taunt_frame = 0
	taunt_timer = 0.0
	if taunt_textures.size() > 0:
		taunt_sprite.texture = taunt_textures[0]
	taunt_sprite.visible = true

	_scare_nearest_enemy()

	# Start cooldown if a charge was spent
	if charges < MAX_CHARGES and cooldown <= 0.0:
		cooldown = COOLDOWN_TIME

	emit_signal("skill_changed", charges, cooldown / COOLDOWN_TIME)

func _scare_nearest_enemy() -> void:
	var nearest : Node2D = null
	var best    := SCARE_RANGE

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d := position.distance_to(enemy.position)
		if d < best:
			best    = d
			nearest = enemy

	if nearest and nearest.has_method("get_scared"):
		nearest.get_scared()

func _tick_cooldown(delta: float) -> void:
	if cooldown <= 0.0 or charges >= MAX_CHARGES:
		return
	cooldown -= delta
	if cooldown <= 0.0:
		cooldown  = 0.0
		charges   = min(charges + 1, MAX_CHARGES)
		# If still missing a charge, keep counting
		if charges < MAX_CHARGES:
			cooldown = COOLDOWN_TIME
	emit_signal("skill_changed", charges, max(0.0, cooldown / COOLDOWN_TIME))

# ── Taunt animation ────────────────────────────────────────────────────
func _tick_taunt(delta: float) -> void:
	if not is_taunting:
		return
	taunt_timer += delta
	if taunt_timer >= TAUNT_FRAME_T:
		taunt_timer -= TAUNT_FRAME_T
		taunt_frame += 1
		if taunt_frame >= taunt_textures.size():
			is_taunting          = false
			taunt_sprite.visible = false
		else:
			taunt_sprite.texture = taunt_textures[taunt_frame]

# ── Invincibility flicker ──────────────────────────────────────────────
func _tick_invincibility(delta: float) -> void:
	if not invincible:
		return
	inv_timer -= delta
	boat_sprite.visible = int(inv_timer * 9.0) % 2 == 0
	if inv_timer <= 0.0:
		invincible          = false
		boat_sprite.visible = true

# ── Collision checks (simple distance-based) ──────────────────────────
func _check_hits() -> void:
	# Enemies
	if not invincible:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if position.distance_to(enemy.position) < HIT_RADIUS:
				_take_damage()
				enemy.queue_free()
				break

	# Zongzi pickups
	for z in get_tree().get_nodes_in_group("zongzis"):
		if position.distance_to(z.position) < PICK_RADIUS:
			_heal()
			z.queue_free()

# ── Health ─────────────────────────────────────────────────────────────
func _take_damage() -> void:
	health    = max(0, health - 1)
	invincible = true
	inv_timer  = 2.2
	emit_signal("health_changed", health)

func _heal() -> void:
	if health < MAX_HP:
		health = min(MAX_HP, health + 1)
		emit_signal("health_changed", health)

# ── Called by Main ─────────────────────────────────────────────────────
func set_active(val: bool) -> void:
	active = val
