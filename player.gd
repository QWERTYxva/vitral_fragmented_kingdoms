# player.gd

extends CharacterBody2D

# --- Constantes de Movimiento ---
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 600.0
const WALL_JUMP_VELOCITY = Vector2(450.0, -350.0)

# --- Variables de Física ---
# Obtiene el valor de la gravedad desde los ajustes del proyecto.
# Ve a Proyecto -> Ajustes del Proyecto -> Physics -> 2d -> Default Gravity
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- Variables de Estado y Buffs ---
var has_dash: bool = true # Empezamos con el dash por defecto. Podrías cambiarlo a 'false'.
var has_wall_jump: bool = true # Igual para el salto de pared.
var has_double_jump: bool = false # Este lo encontraremos como un Eco de Luz.

# --- Variables Internas de Control ---
var can_dash: bool = true
var can_double_jump: bool = true
var is_dashing: bool = false

# --- Nodos "OnReady" ---
# Usamos "@onready" para asegurarnos de que los nodos existen antes de usarlos.
@onready var sprite = $Sprite2D
@onready var dash_timer = $DashTimer
@onready var coyote_timer = $CoyoteTimer


# _physics_process se ejecuta en cada fotograma de física. Ideal para movimiento.
func _physics_process(delta: float):
	
	# Solo aplicamos la gravedad si no estamos en modo dash.
	if not is_dashing:
		apply_gravity(delta)
	
	handle_wall_interaction()
	handle_jump()
	
	if not is_dashing:
		handle_movement()
		handle_dash()
	
	# move_and_slide() es la función mágica de Godot que mueve el cuerpo y gestiona colisiones.
	move_and_slide()

# --- Funciones de Manejo de Lógica ---

func apply_gravity(delta: float):
	# Si no estamos en el suelo, caemos.
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_movement():
	# Obtiene la dirección del input (teclas A/D o flechas izquierda/derecha).
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	# Mueve al personaje.
	velocity.x = input_dir * SPEED
	
	# Voltea el sprite según la dirección.
	if input_dir != 0:
		sprite.flip_h = (input_dir < 0)

func handle_jump():
	# Resetea el doble salto cuando estamos en el suelo.
	if is_on_floor():
		can_double_jump = true
	
	# Inicia el "tiempo de coyote" justo cuando dejamos una plataforma.
	# Esto permite al jugador saltar un instante después de caer de un borde. ¡Se siente genial!
	if not is_on_floor() and not is_on_wall() and velocity.y > 0 and coyote_timer.is_stopped():
		coyote_timer.start(0.1)

	# Manejo del salto normal, de pared y doble salto.
	if Input.is_action_just_pressed("ui_accept"): # "ui_accept" es la barra espaciadora por defecto.
		if is_on_floor() or not coyote_timer.is_stopped():
			# Salto normal desde el suelo o usando el coyote time.
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop() # Usamos el salto de coyote, así que lo detenemos.
		elif is_on_wall() and has_wall_jump:
			# Salto de pared. Empuja al jugador lejos de la pared y hacia arriba.
			var wall_normal = get_wall_normal()
			velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
			velocity.y = WALL_JUMP_VELOCITY.y
		elif can_double_jump and has_double_jump:
			# Doble salto.
			can_double_jump = false
			velocity.y = JUMP_VELOCITY * 0.8 # Un poco menos potente que el primero.

func handle_wall_interaction():
	if is_on_wall() and not is_on_floor() and has_wall_jump:
		# Deslizamiento en la pared. Reducimos la velocidad de caída.
		if velocity.y > 0:
			velocity.y = gravity * 0.1
	else:
		# Si no estamos en una pared, reseteamos cualquier lógica de pared.
		pass

func handle_dash():
	# La acción "dash" necesita ser creada en Proyecto -> Ajustes -> Mapa de Entrada.
	if Input.is_action_just_pressed("dash") and can_dash and has_dash:
		is_dashing = true
		can_dash = false
		
		# La dirección del dash se basa en las teclas de movimiento. Si no se presiona ninguna, dashea hacia adelante.
		var dash_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if dash_direction == Vector2.ZERO:
			dash_direction = Vector2(1 if not sprite.flip_h else -1, 0) # Hacia donde mira el personaje

		velocity = dash_direction.normalized() * DASH_SPEED
		dash_timer.start(0.2) # Duración del dash.

# --- Conexiones de Señales ---

# Esta función se llama automáticamente cuando el DashTimer termina.
func _on_dash_timer_timeout():
	is_dashing = false
	can_dash = true # Permitimos que el jugador pueda volver a dashear.
	# Le damos al jugador un pequeño impulso hacia arriba al final del dash para que se sienta mejor.
	velocity = Vector2.ZERO
	velocity.y = JUMP_VELOCITY * 0.3
