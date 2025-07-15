# player.gd
# --- CÓDIGO CON MOVIMIENTO INSTANTÁNEO Y WALL JUMP CORREGIDO ---

extends CharacterBody2D

# --- CONSTANTES DE MOVIMIENTO ---
const SPEED: float = 150.0
const JUMP_VELOCITY: float = -250.0
const DASH_SPEED: float = 300.0
const WALL_JUMP_VELOCITY: Vector2 = Vector2(400.0, -220.0)

# ¡LA CONSTANTE CLAVE!
# Controla qué tan rápido tomas el control en el aire después de un wall jump.
# - 0.2 es muy rápido y responsivo (recomendado).
# - 0.1 es un poco más suave.
# - 1.0 es control 100% instantáneo (pero romperá el wall jump).
const AIR_CONTROL: float = 0.2

# --- CONSTANTES DE HABILIDADES ---
const MAX_JUMPS: int = 1

# --- VARIABLES DE FÍSICA ---
var gravity: float = 800

# --- VARIABLES DE ESTADO Y BUFFS ---
var has_dash: bool = true
var has_wall_jump: bool = true

# --- VARIABLES INTERNAS DE CONTROL ---
var jumps_left: int = 0
var can_dash: bool = true
var is_dashing: bool = false
var dashes_used: int = 0
var can_double_dash: bool = true

# --- REFERENCIAS A NODOS HIJOS ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_timer: Timer = $DashTimer
@onready var double_dash_cooldown_timer: Timer = $DoubleDashCooldownTimer

# --- FUNCIÓN DE INICIO ---
func _ready():
	PlayerInventory.add_item("double_dash_cooldown")

# --- BUCLE PRINCIPAL DE FÍSICAS ---
func _physics_process(delta: float) -> void:
	if not is_dashing:
		apply_gravity(delta)

	if is_on_floor():
		jumps_left = MAX_JUMPS
		can_dash = true
		dashes_used = 0
		if double_dash_cooldown_timer.is_stopped():
			can_double_dash = true

	handle_jump()
	handle_dash()
	handle_movement()
	
	update_collision()
	move_and_slide()
	update_animation()

# --- GESTIÓN DE COLISIONES (Sin cambios) ---
func update_collision() -> void:
	$CollisionStand.disabled = true
	$CollisionRun.disabled = true
	$CollisionDash.disabled = true
	$CollisionJump.disabled = true
	$CollisionFall.disabled = true
	$CollisionWallSlide.disabled = true
	$CollisionWallSlide.position.x = 0
	var is_pushing_wall = is_on_wall() and sign(Input.get_axis("move_left", "move_right")) == -sign(get_wall_normal().x)
	if is_dashing:
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

# ¡NUEVA FUNCIÓN DE MOVIMIENTO MEJORADA!
func handle_movement() -> void:
	if is_dashing:
		return

	var input_dir: float = Input.get_axis("move_left", "move_right")
	var target_velocity_x = input_dir * SPEED
	
	# Si estás en el suelo, el control es 100% instantáneo.
	if is_on_floor():
		velocity.x = target_velocity_x
	else:
		# Si estás en el aire, usas el "control aéreo" para mezclar tu input
		# con la velocidad actual. Esto preserva el wall jump.
		velocity.x = lerp(velocity.x, target_velocity_x, AIR_CONTROL)
	
	if input_dir != 0:
		animated_sprite.flip_h = (input_dir < 0)

# --- LÓGICA DE SALTO ---
func handle_jump() -> void:
	if not Input.is_action_just_pressed("ui_accept"):
		return
		
	if is_on_wall() and not is_on_floor() and has_wall_jump:
		var wall_normal = get_wall_normal()
		velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
		velocity.y = WALL_JUMP_VELOCITY.y
		jumps_left = MAX_JUMPS - 1
		return
		
	if jumps_left > 0 and velocity.y >= 0:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1
		return

func handle_wall_interaction() -> void:
	var is_pushing_wall = is_on_wall() and sign(Input.get_axis("move_left", "move_right")) == -sign(get_wall_normal().x)
	if is_pushing_wall and not is_on_floor() and has_wall_jump and velocity.y > 0:
		velocity.y = gravity * 0.1

# --- LÓGICA DE DASH ---
func handle_dash() -> void:
	if Input.is_action_just_pressed("dash"):
		if dashes_used == 0:
			perform_dash()
			dashes_used += 1
		elif dashes_used == 1 and PlayerInventory.has_item("double_dash_cooldown") and can_double_dash:
			perform_dash()
			can_double_dash = false
			double_dash_cooldown_timer.start()

func perform_dash():
	is_dashing = true
	var dash_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2(1 if not animated_sprite.flip_h else -1, 0)
	velocity = dash_direction.normalized() * DASH_SPEED
	dash_timer.start()

# --- MANEJO DE ANIMACIONES (Sin cambios) ---
func update_animation() -> void:
	animated_sprite.offset.x = 0
	var is_pushing_wall = is_on_wall() and sign(Input.get_axis("move_left", "move_right")) == -sign(get_wall_normal().x)
	if is_dashing:
		animated_sprite.play("dash")
	elif not is_on_floor():
		if is_pushing_wall and velocity.y > 0:
			animated_sprite.play("wallslide")
			animated_sprite.flip_h = get_wall_normal().x < 0
			var wall_slide_sprite_offset = 6.0
			if animated_sprite.flip_h:
				animated_sprite.offset.x = wall_slide_sprite_offset
			else:
				animated_sprite.offset.x = -wall_slide_sprite_offset
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

func _on_double_dash_cooldown_timer_timeout():
	can_double_dash = true
