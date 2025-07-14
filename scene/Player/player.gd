# player.gd
# --- SCRIPT CON CORRECCIÓN DE RE-ENGANCHE DE WALLSLIDE ---

extends CharacterBody2D

# --- CONSTANTES DE MOVIMIENTO ---
const SPEED: float = 150.0
const JUMP_VELOCITY: float = -300.0
const DASH_SPEED: float = 300.0
const WALL_JUMP_VELOCITY: Vector2 = Vector2(350.0, -250.0)

# --- VARIABLES DE FÍSICA ---
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- VARIABLES DE ESTADO Y BUFFS ---
var has_dash: bool = true
var has_wall_jump: bool = true
var has_double_jump: bool = true

# --- VARIABLES INTERNAS DE CONTROL ---
var can_dash: bool = true
var can_double_jump: bool = true
var is_dashing: bool = false
var is_grabbing_ledge: bool = false

# --- REFERENCIAS A NODOS HIJOS ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_timer: Timer = $DashTimer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var ledge_detector: RayCast2D = $LedgeDetector

# --- BUCLE PRINCIPAL DE FÍSICAS ---
func _physics_process(delta: float) -> void:
	if is_grabbing_ledge:
		velocity = Vector2.ZERO
		handle_ledge_climb()
	else:
		if not is_dashing:
			apply_gravity(delta)

		handle_ledge_detection()
		handle_wall_interaction()
		handle_jump()

		if not is_dashing:
			handle_movement()
			handle_dash()

	update_collision()
	move_and_slide()
	update_animation()


# --- GESTIÓN DE COLISIONES ---
func update_collision() -> void:
	$CollisionStand.disabled = true
	$CollisionRun.disabled = true
	$CollisionDash.disabled = true
	$CollisionJump.disabled = true
	$CollisionFall.disabled = true
	$CollisionWallSlide.disabled = true
	$CollisionLedge.disabled = true
	$CollisionWallSlide.position.x = 0

	var is_pushing_wall = is_on_wall() and sign(Input.get_axis("move_left", "move_right")) == -sign(get_wall_normal().x)

	if is_grabbing_ledge:
		$CollisionLedge.disabled = false
	elif is_dashing:
		$CollisionDash.disabled = false
	elif not is_on_floor():
		if is_pushing_wall and velocity.y > 0:
			$CollisionWallSlide.disabled = false
			var collision_offset_x: float = 4.0
			if animated_sprite.flip_h:
				$CollisionWallSlide.position.x = -collision_offset_x
			else:
				$CollisionWallSlide.position.x = collision_offset_x
		elif velocity.y < 0:
			$CollisionJump.disabled = false
		else:
			$CollisionFall.disabled = false
	else:
		if abs(velocity.x) > 5:
			$CollisionRun.disabled = false
		else:
			$CollisionStand.disabled = false

# --- MANEJO DE LÓGICA DE MOVIMIENTO ---
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_movement() -> void:
	var input_dir: float = Input.get_axis("move_left", "move_right")
	velocity.x = input_dir * SPEED
	if input_dir != 0:
		animated_sprite.flip_h = (input_dir < 0)
		ledge_detector.target_position.x = 20 if not animated_sprite.flip_h else -20

func handle_jump() -> void:
	if is_on_floor():
		can_double_jump = true

	if not is_on_floor() and not is_on_wall() and velocity.y >= 0 and coyote_timer.is_stopped():
		coyote_timer.start(0.1)

	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor() or not coyote_timer.is_stopped():
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
		elif is_on_wall() and has_wall_jump:
			var wall_normal = get_wall_normal()
			velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
			velocity.y = WALL_JUMP_VELOCITY.y
		elif can_double_jump and has_double_jump:
			can_double_jump = false
			velocity.y = JUMP_VELOCITY * 0.8

func handle_wall_interaction() -> void:
	var is_pushing_wall = is_on_wall() and sign(Input.get_axis("move_left", "move_right")) == -sign(get_wall_normal().x)

	if is_pushing_wall and not is_on_floor() and has_wall_jump and velocity.y > 0:
		velocity.y = gravity * 0.1

func handle_dash() -> void:
	if Input.is_action_just_pressed("dash") and can_dash and has_dash:
		is_dashing = true
		can_dash = false
		var dash_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dash_direction == Vector2.ZERO:
			dash_direction = Vector2(1 if not animated_sprite.flip_h else -1, 0)
		velocity = dash_direction.normalized() * DASH_SPEED
		dash_timer.start(0.2)

# --- MANEJO DE LÓGICA DE BORDES ---
func handle_ledge_detection() -> void:
	var is_pushing_wall = is_on_wall() and sign(Input.get_axis("move_left", "move_right")) == -sign(get_wall_normal().x)
	if not is_on_floor() and is_pushing_wall and not ledge_detector.is_colliding():
		is_grabbing_ledge = true

func handle_ledge_climb() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		animated_sprite.play("ledgeup")
		await animated_sprite.animation_finished
		is_grabbing_ledge = false
		self.global_position += Vector2(35 if not animated_sprite.flip_h else -35, -50)
	elif Input.is_action_just_pressed("move_right" if animated_sprite.flip_h else "move_left"):
		is_grabbing_ledge = false

# --- MANEJO DE ANIMACIONES ---
func update_animation() -> void:
	var is_pushing_wall = is_on_wall() and sign(Input.get_axis("move_left", "move_right")) == -sign(get_wall_normal().x)

	if is_grabbing_ledge:
		animated_sprite.play("ledgegrab")
	elif is_dashing:
		animated_sprite.play("dash")
	elif not is_on_floor():
		if is_pushing_wall and velocity.y > 0:
			animated_sprite.play("wallslide")
			animated_sprite.flip_h = get_wall_normal().x > 0
		elif velocity.y < 0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	else:
		if abs(velocity.x) > 5:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

# --- CONEXIÓN DE SEÑALES ---
func _on_dash_timer_timeout() -> void:
	is_dashing = false
	can_dash = true
