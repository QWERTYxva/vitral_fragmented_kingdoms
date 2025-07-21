# ItemDobleDash.gd
extends Area2D

# El nombre del ítem que otorga este objeto.
var item_name: String = "double_dash_cooldown"

func _on_body_entered(body):
	# Comprobamos si el cuerpo que entró pertenece al grupo "Player".
	if body.is_in_group("Player"):
		
		# Añadimos el ítem al inventario global.
		PlayerInventory.add_item(item_name)
		
		# Aquí podrías añadir un sonido de "poder adquirido".
		# Ejemplo: $PickupSound.play()
		
		# El ítem se autodestruye.
		queue_free()
