class_name Kinds
## Finds the kinds. Every .tres in data/kinds/ is one kind, and its file name is its id, so adding a kind never
## means editing a list.

const DIR := "res://data/kinds"

static var _all: Dictionary[StringName, Kind] = {}
static var _loaded := false


## The kind with this id, or null for &"" and for an id that has no file.
static func of(id: StringName) -> Kind:
	_load()
	return _all.get(id)


## Every kind, by `order` and then by id.
static func all() -> Array[Kind]:
	_load()
	var out: Array[Kind] = []
	out.assign(_all.values())
	out.sort_custom(func(a: Kind, b: Kind) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return out


## The special bricks, in the order they are rolled.
static func bricks() -> Array[BrickKind]:
	var out: Array[BrickKind] = []
	out.assign(all().filter(func(k: Kind) -> bool: return k is BrickKind))
	return out


## The placeables, in tray order.
static func placeables() -> Array[PlaceableKind]:
	var out: Array[PlaceableKind] = []
	out.assign(all().filter(func(k: Kind) -> bool: return k is PlaceableKind))
	return out


## Adds a kind that has no file, or replaces one. For tests.
static func add(kind: Kind) -> void:
	_load()
	_all[kind.id] = kind


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for file in ResourceLoader.list_directory(DIR):
		if file.get_extension() == "tres":
			var kind := load(DIR.path_join(file)) as Kind
			if kind:
				_all[kind.id] = kind
