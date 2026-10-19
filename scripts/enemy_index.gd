extends RefCounted

const CELL = 4.0
var buckets: Dictionary = {}
var typed: Dictionary = {}
var entries: Dictionary = {}
var ids: Array[int] = []
var sample_cursor = 0
var search_offsets: Dictionary = {}

func clear() -> void:
	buckets.clear()
	typed.clear()
	entries.clear()
	ids.clear()

func add(uid: int, position: Vector3, kind: String) -> void:
	var cell = Vector2i(floori(position.x / CELL), floori(position.z / CELL))
	if not buckets.has(cell): buckets[cell] = []
	if not typed.has(kind): typed[kind] = {}
	if not typed[kind].has(cell): typed[kind][cell] = []
	entries[uid] = {"position": position, "cell": cell, "slot": buckets[cell].size(), "kind": kind, "kind_slot": typed[kind][cell].size(), "dense_slot": ids.size()}
	ids.append(uid)
	buckets[cell].append(uid)
	typed[kind][cell].append(uid)

func remove(uid: int) -> void:
	if not entries.has(uid): return
	var entry: Dictionary = entries[uid]
	var members: Array = buckets[entry.cell]
	var last = int(members.back())
	members[entry.slot] = last
	entries[last].slot = entry.slot
	members.pop_back()
	if members.is_empty(): buckets.erase(entry.cell)
	var kind_members: Array = typed[entry.kind][entry.cell]
	last = int(kind_members.back())
	kind_members[entry.kind_slot] = last
	entries[last].kind_slot = entry.kind_slot
	kind_members.pop_back()
	if kind_members.is_empty(): typed[entry.kind].erase(entry.cell)
	last = ids.back()
	ids[entry.dense_slot] = last
	entries[last].dense_slot = entry.dense_slot
	ids.pop_back()
	entries.erase(uid)

func move(uid: int, position: Vector3) -> void:
	if not entries.has(uid): return
	var entry: Dictionary = entries[uid]
	var cell = Vector2i(floori(position.x / CELL), floori(position.z / CELL))
	if cell == entry.cell:
		entry.position = position
		return
	var members: Array = buckets[entry.cell]
	var last = int(members.back())
	members[entry.slot] = last
	entries[last].slot = entry.slot
	members.pop_back()
	if members.is_empty(): buckets.erase(entry.cell)
	var kind_members: Array = typed[entry.kind][entry.cell]
	last = int(kind_members.back())
	kind_members[entry.kind_slot] = last
	entries[last].kind_slot = entry.kind_slot
	kind_members.pop_back()
	if kind_members.is_empty(): typed[entry.kind].erase(entry.cell)
	if not buckets.has(cell): buckets[cell] = []
	if not typed[entry.kind].has(cell): typed[entry.kind][cell] = []
	entry.cell = cell
	entry.position = position
	entry.slot = buckets[cell].size()
	entry.kind_slot = typed[entry.kind][cell].size()
	buckets[cell].append(uid)
	typed[entry.kind][cell].append(uid)

func nearby_offsets(extent: int) -> Array:
	if not search_offsets.has(extent):
		var offsets: Array[Vector2i] = []
		for y in range(-extent, extent + 1):
			for x in range(-extent, extent + 1): offsets.append(Vector2i(x, y))
		offsets.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
		search_offsets[extent] = offsets
	return search_offsets[extent]

func nearby(position: Vector3, radius: float, limit: int = 0, kind: String = "") -> Array:
	var result: Array = []
	var source: Dictionary = buckets if kind == "" else typed.get(kind, {})
	var squared = radius * radius
	sample_cursor += 1
	if limit > 0:
		var center = Vector2i(floori(position.x / CELL), floori(position.z / CELL))
		for offset in nearby_offsets(ceili(radius / CELL)):
			var members: Array = source.get(center + offset, [])
			var count = members.size()
			for i in mini(count, maxi(64, limit * 4)):
				var uid = int(members[(i + sample_cursor) % count])
				var delta: Vector3 = entries[uid].position - position
				if delta.x * delta.x + delta.z * delta.z > squared: continue
				result.append(uid)
				if result.size() >= limit: return result
		return result
	var low = Vector2i(floori((position.x - radius) / CELL), floori((position.z - radius) / CELL))
	var high = Vector2i(floori((position.x + radius) / CELL), floori((position.z + radius) / CELL))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			for uid in source.get(Vector2i(x, y), []):
				var delta: Vector3 = entries[uid].position - position
				if delta.x * delta.x + delta.z * delta.z > squared: continue
				result.append(uid)
	return result

func of_type(kind: String) -> Array:
	var result: Array = []
	for members in typed.get(kind, {}).values(): result.append_array(members)
	return result
