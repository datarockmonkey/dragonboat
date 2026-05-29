extends Node2D

const DRIFT_SPEED := 75.0     # drifts slowly left — player must steer to grab it
const BOB_SPEED   := 2.2      # bobbing frequency
const BOB_AMP     := 7.0      # bobbing amplitude (px)

var bob_t  := 0.0
var base_y := 0.0
var sprite : Sprite2D

func _ready() -> void:
	add_to_group("zongzis")
	base_y = position.y

	sprite         = Sprite2D.new()
	sprite.texture = load("res://assets/zongzi_sprite.png")

	var raw_w    := float(sprite.texture.get_width())
	var target_w := 52.0
	var sc       := target_w / raw_w
	sprite.scale = Vector2(sc, sc)

	add_child(sprite)

func _process(delta: float) -> void:
	# Drift leftward with the current
	position.x -= DRIFT_SPEED * delta

	# Gentle bob
	bob_t      += delta * BOB_SPEED
	position.y  = base_y + sin(bob_t) * BOB_AMP

	# Soft pulse to make it noticeable
	var pulse := 0.85 + 0.15 * sin(bob_t * 1.6)
	sprite.modulate = Color(pulse, 1.0, pulse)

	if position.x < -80.0:
		queue_free()
