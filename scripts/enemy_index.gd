extends RefCounted

const CELL = 4.0
var buckets: Dictionary = {}
var typed: Dictionary = {}
var entries: Dictionary = {}
var ids: Array[int] = []
var sample_cursor = 0

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

func nearby(position: Vector3, radius: float, limit: int = 0, kind: String = "") -> Array:
	var result: Array = []
	var source: Dictionary = buckets if kind == "" else typed.get(kind, {})
	var low = Vector2i(floori((position.x - radius) / CELL), floori((position.z - radius) / CELL))
	var high = Vector2i(floori((position.x + radius) / CELL), floori((position.z + radius) / CELL))
	var squared = radius * radius
	sample_cursor += 1
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var members: Array = source.get(Vector2i(x, y), [])
			var count = members.size()
			var probes = count if limit <= 0 else mini(count, maxi(64, limit * 4))
			for i in probes:
				var uid = int(members[(i + sample_cursor) % count] if limit > 0 else members[i])
				var delta: Vector3 = entries[uid].position - position
				if delta.x * delta.x + delta.z * delta.z > squared: continue
				result.append(uid)
				if limit > 0 and result.size() >= limit: return result
	return result

func of_type(kind: String) -> Array:
	var result: Array = []
	for members in typed.get(kind, {}).values(): result.append_array(members)
	return result
