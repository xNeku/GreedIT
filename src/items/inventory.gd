class_name Inventory
extends RefCounted
## Inventario simple de materiales: objeto -> cantidad.

signal changed(item: ItemData, count: int)

var _counts: Dictionary[ItemData, int] = {}


func add(item: ItemData, amount: int = 1) -> void:
	if item == null or amount == 0:
		return
	_counts[item] = _counts.get(item, 0) + amount
	changed.emit(item, _counts[item])


func count(item: ItemData) -> int:
	return _counts.get(item, 0)


## Cantidad por id (útil en tests y crafteo).
func count_by_id(id: StringName) -> int:
	for item in _counts:
		if item.id == id:
			return _counts[item]
	return 0


func items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	result.assign(_counts.keys())
	return result
