# PlayerInventory.gd
extends Node

# Un diccionario para guardar los ítems que tenemos.
var items: Dictionary = {
	"double_jump": false,
	"double_dash_cooldown": false, #<-- NUEVO ÍTEM
	"ground_pound": false # Lo dejamos por si lo quieres reusar
}

func add_item(item_name: String):
	if items.has(item_name):
		items[item_name] = true
		print("Item recogido: ", item_name)

func has_item(item_name: String) -> bool:
	if items.has(item_name):
		return items[item_name]
	return false
