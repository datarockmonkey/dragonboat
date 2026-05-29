extends Node2D

# ── Constants ──────────────────────────────────────────────────────────
const GAME_W       := 960
const GAME_H       := 540
const SCROLL_SPEED := 180.0      # px/s – how fast the river moves
const FINISH_DIST  := 6000.0     # total river distance to paddle
const ENEMY_MIN    := 1.8        # seconds between enemy spawns (min)
const ENEMY_MAX    := 3.2
const ZONGZI_MIN   := 4.0
const ZONGZI_MAX   := 9.0

# ── State ──────────────────────────────────────────────────────────────
var bg_offset     := 0.0
var bg_width      := 0.0
var dist_traveled := 0.0
var enemy_timer   := 2.0
var zongzi_timer  := 4.0
var game_active   := false       # false until player presses Start

# ── Node refs (created in code) ────────────────────────────────────────
var bg1           : Sprite2D
var bg2           : Sprite2D
var finish_sprite : Sprite2D
var player_node   : CharacterBody2D
var enemies_root  : Node2D
var zongzis_root  : Node2D
var hud           : CanvasLayer

# HUD refs
var heart_labels  : Array = []
var oar_labels    : Array = []
var dist_label    : Label
var skill_label   : Label
var cooldown_bar  : ProgressBar
var msg_label     : Label
var start_label   : Label

func _ready() -> void:
	_build_background()
	_build_player()
	_build_hud()
	_show_start_screen()

# ═══════════════════════════════════════════════════════════════════════
# SCENE BUILDING
# ═══════════════════════════════════════════════════════════════════════

func _build_background() -> void:
	# Two tiling copies of the river panorama
	var container := Node2D.new()
	container.name = "Background"
	add_child(container)

	var tex : Texture2D = load("res://assets/scrolling_background.png")
	var raw_h : float   = tex.get_height()
	var raw_w : float   = tex.get_width()
	var scale_y : float = GAME_H / raw_h
	bg_width = raw_w * scale_y

	bg1 = Sprite2D.new()
	bg1.texture  = tex
	bg1.centered = false
	bg1.scale    = Vector2(scale_y, scale_y)
	container.add_child(bg1)

	bg2 = Sprite2D.new()
	bg2.texture  = tex
	bg2.centered = false
	bg2.scale    = Vector2(scale_y, scale_y)
	bg2.position = Vector2(bg_width, 0.0)
	container.add_child(bg2)

	# Finish line banner (hidden until player is close)
	finish_sprite = Sprite2D.new()
	finish_sprite.texture = load("res://assets/finish_line.png")
	var fl_h   : float = finish_sprite.texture.get_height()
	var fl_scl : float = GAME_H / fl_h
	finish_sprite.scale    = Vector2(fl_scl, fl_scl)
	finish_sprite.position = Vector2(GAME_W + 100.0, GAME_H / 2.0)
	finish_sprite.visible  = false
	add_child(finish_sprite)

	# Containers for spawned objects
	enemies_root = Node2D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)

	zongzis_root = Node2D.new()
	zongzis_root.name = "Zongzis"
	add_child(zongzis_root)

func _build_player() -> void:
	player_node = preload("res://scenes/Player.tscn").instantiate()
	player_node.position = Vector2(160.0, GAME_H / 2.0)
	add_child(player_node)
	player_node.health_changed.connect(_on_health_changed)
	player_node.skill_changed.connect(_on_skill_changed)
	player_node.set_active(false)   # frozen until game starts

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	# Dark top bar
	var bar := ColorRect.new()
	bar.color = Color(0.0, 0.08, 0.25, 0.82)
	bar.size  = Vector2(GAME_W, 52.0)
	hud.add_child(bar)

	# ── Hearts ──
	for i in 3:
		var lbl := Label.new()
		lbl.text = "♥"
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
		lbl.position = Vector2(12.0 + i * 38.0, 8.0)
		hud.add_child(lbl)
		heart_labels.append(lbl)

	# ── Oar / skill charges ──
	for i in 2:
		var lbl := Label.new()
		lbl.text = "🚣"
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.position = Vector2(138.0 + i * 34.0, 10.0)
		hud.add_child(lbl)
		oar_labels.append(lbl)

	# Skill text
	skill_label = Label.new()
	skill_label.text = "SKILL [SPACE]"
	skill_label.add_theme_font_size_override("font_size", 11)
	skill_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	skill_label.position = Vector2(135.0, 34.0)
	hud.add_child(skill_label)

	# Cooldown bar
	cooldown_bar = ProgressBar.new()
	cooldown_bar.max_value = 1.0
	cooldown_bar.value     = 0.0
	cooldown_bar.size      = Vector2(72.0, 8.0)
	cooldown_bar.position  = Vector2(135.0, 42.0)
	cooldown_bar.visible   = false
	hud.add_child(cooldown_bar)

	# Distance
	dist_label = Label.new()
	dist_label.text = "6000 m to FINISH"
	dist_label.add_theme_font_size_override("font_size", 15)
	dist_label.add_theme_color_override("font_color", Color.WHITE)
	dist_label.position = Vector2(GAME_W - 230.0, 14.0)
	hud.add_child(dist_label)

	# Big message (win / lose)
	msg_label = Label.new()
	msg_label.text    = ""
	msg_label.visible = false
	msg_label.add_theme_font_size_override("font_size", 52)
	msg_label.position = Vector2(GAME_W / 2.0 - 220.0, GAME_H / 2.0 - 50.0)
	hud.add_child(msg_label)

	# Start prompt
	start_label = Label.new()
	start_label.text = ""
	start_label.add_theme_font_size_override("font_size", 20)
	start_label.add_theme_color_override("font_color", Color.WHITE)
	start_label.position = Vector2(GAME_W / 2.0 - 160.0, GAME_H / 2.0 + 20.0)
	hud.add_child(start_label)

func _show_start_screen() -> void:
	msg_label.text    = "🐉  DRAGON BOAT DODGER"
	msg_label.add_theme_font_size_override("font_size", 36)
	msg_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	msg_label.visible = true
	start_label.text  = "ARROWS to move  •  SPACE to use skill\n\n         Press SPACE to start!"
	start_label.visible = true

# ═══════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not game_active:
		return

	_scroll_bg(delta)
	_tick_spawners(delta)
	_update_dist(delta)
	_check_finish()

func _scroll_bg(delta: float) -> void:
	bg_offset = fmod(bg_offset + SCROLL_SPEED * delta, bg_width)
	bg1.position.x = -bg_offset
	bg2.position.x = bg_width - bg_offset

func _tick_spawners(delta: float) -> void:
	enemy_timer -= delta
	if enemy_timer <= 0.0:
		_spawn_enemy()
		enemy_timer = randf_range(ENEMY_MIN, ENEMY_MAX)

	zongzi_timer -= delta
	if zongzi_timer <= 0.0:
		_spawn_zongzi()
		zongzi_timer = randf_range(ZONGZI_MIN, ZONGZI_MAX)

func _update_dist(delta: float) -> void:
	dist_traveled += SCROLL_SPEED * delta
	var remaining := max(0.0, FINISH_DIST - dist_traveled)
	dist_label.text = "%d m to FINISH" % int(remaining)

func _check_finish() -> void:
	if dist_traveled >= FINISH_DIST:
		_trigger_win()

# ═══════════════════════════════════════════════════════════════════════
# SPAWNING
# ═══════════════════════════════════════════════════════════════════════

func _spawn_enemy() -> void:
	var enemy = preload("res://scenes/Enemy.tscn").instantiate()
	enemy.position = Vector2(GAME_W + 70.0, randf_range(80.0, GAME_H - 80.0))
	# Three approach patterns
	match randi() % 3:
		0: enemy.set_dir(Vector2(-1.0,  0.0))                          # head-on
		1: enemy.set_dir(Vector2(-0.82,  0.38).normalized())           # diagonal down
		2: enemy.set_dir(Vector2(-0.82, -0.38).normalized())           # diagonal up
	enemy.speed = randf_range(210.0, 340.0)
	enemies_root.add_child(enemy)

func _spawn_zongzi() -> void:
	var z = preload("res://scenes/Zongzi.tscn").instantiate()
	z.position = Vector2(GAME_W + 50.0, randf_range(80.0, GAME_H - 80.0))
	zongzis_root.add_child(z)

# ═══════════════════════════════════════════════════════════════════════
# WIN / LOSE
# ═══════════════════════════════════════════════════════════════════════

func _trigger_win() -> void:
	game_active = false
	player_node.set_active(false)
	finish_sprite.visible  = true
	finish_sprite.position = Vector2(GAME_W / 2.0, GAME_H / 2.0)
	msg_label.text    = "🏆  YOU WIN!"
	msg_label.add_theme_font_size_override("font_size", 52)
	msg_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	msg_label.visible = true
	start_label.text    = "Press R to play again"
	start_label.visible = true

func _trigger_game_over() -> void:
	game_active = false
	player_node.set_active(false)
	msg_label.text    = "💀  CAPSIZED!"
	msg_label.add_theme_font_size_override("font_size", 52)
	msg_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	msg_label.visible = true
	start_label.text    = "Press R to try again"
	start_label.visible = true

# ═══════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if not game_active:
			# SPACE starts the game (or restarts after game over)
			if event.keycode == KEY_SPACE or event.keycode == KEY_R:
				if msg_label.visible:
					get_tree().reload_current_scene()
				else:
					_start_game()

func _start_game() -> void:
	game_active = true
	player_node.set_active(true)
	msg_label.visible   = false
	start_label.visible = false

# ═══════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════════

func _on_health_changed(new_hp: int) -> void:
	for i in 3:
		var lbl : Label = heart_labels[i]
		lbl.add_theme_color_override("font_color",
			Color(1.0, 0.18, 0.18) if i < new_hp else Color(0.28, 0.28, 0.28))
	if new_hp <= 0:
		_trigger_game_over()

func _on_skill_changed(charges: int, cooldown_frac: float) -> void:
	for i in 2:
		var lbl : Label = oar_labels[i]
		lbl.add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.0) if i < charges else Color(0.28, 0.28, 0.28))

	if cooldown_frac > 0.0:
		cooldown_bar.visible = true
		cooldown_bar.value   = cooldown_frac
		skill_label.text     = "charging..."
		skill_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	else:
		cooldown_bar.visible = false
		if charges > 0:
			skill_label.text = "SKILL [SPACE]"
			skill_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
		else:
			skill_label.text = "no charges"
			skill_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
