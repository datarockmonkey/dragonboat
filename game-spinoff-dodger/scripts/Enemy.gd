extends Node2D

# ── State ──────────────────────────────────────────────────────────────
var direction  := Vector2(-1.0, 0.0)
var speed      := 260.0
var scared     := false
var lifetime   := 0.0
const MAX_LIFE := 14.0    # auto-despawn safety net

var sprite : Sprite2D

# ── Setup ──────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemies")

	sprite         = Sprite2D.new()
	sprite.texture = load("res://assets/red_team_boat.png")

	# Scale to game size and FLIP horizontally so red boat faces LEFT (head-on)
	var raw_w      := float(sprite.texture.get_width())
	var target_w   := 190.0
	var sc         := target_w / raw_w
	sprite.scale   = Vector2(-sc, sc)   # negative x = horizontal flip

	# Slight size variety
	var v := randf_range(0.88, 1.12)
	sprite.scale *= v

	add_child(sprite)

func set_dir(dir: Vector2) -> void:
	direction = dir.normalized()
	# Tilt the sprite to match diagonal movement
	rotation = direction.angle()

# ── Each frame ─────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	lifetime += delta

	if scared:
		# Retreat quickly to the right
		position.x += 380.0 * delta
		position.y += direction.y * -120.0 * delta
		if position.x > 1100.0:
			queue_free()
	else:
		position += direction * speed * delta

	# Off-screen cleanup
	if position.x < -120.0 or position.x > 1100.0 or lifetime > MAX_LIFE:
		queue_free()

# ── Called by Player skill ─────────────────────────────────────────────
func get_scared() -> void:
	scared = true
	sprite.modulate = Color(1.4, 0.5, 0.1)   # flash orange
