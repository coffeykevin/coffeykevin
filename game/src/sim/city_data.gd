class_name CityData
extends RefCounted
## Occupancy grid for the throw plane. Buildings are 1x1 world-unit cells;
## gameplay collision reads this grid, never engine physics (PRD section 12).

const CELL := 1.0
const SKY_CELLS := 50

var width_cells: int = 0
var grid := PackedByteArray()
var buildings: Array[Dictionary] = []
## Two rooftop stand positions in world units (x = building center, y = roof).
var gorilla_spots: Array[Vector2] = []
var profile_name := ""


func setup(w: int) -> void:
	width_cells = w
	grid.resize(w * SKY_CELLS)
	grid.fill(0)


func set_cell(cx: int, cy: int, v: int) -> void:
	if cx < 0 or cx >= width_cells or cy < 0 or cy >= SKY_CELLS:
		return
	grid[cy * width_cells + cx] = v


func cell(cx: int, cy: int) -> int:
	if cx < 0 or cx >= width_cells or cy < 0 or cy >= SKY_CELLS:
		return 0
	return grid[cy * width_cells + cx]


func solid_at_world(p: Vector2) -> bool:
	if p.y < 0.0:
		return false
	return cell(int(floor(p.x / CELL)), int(floor(p.y / CELL))) != 0


func world_width() -> float:
	return width_cells * CELL


## Remove all cells within radius r of world point p. Returns removed count.
func carve_world(p: Vector2, r: float) -> int:
	var removed := 0
	var cx0 := int(floor((p.x - r) / CELL))
	var cx1 := int(floor((p.x + r) / CELL))
	var cy0 := int(floor(max(p.y - r, 0.0) / CELL))
	var cy1 := int(floor((p.y + r) / CELL))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if cell(cx, cy) == 0:
				continue
			var center := Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL)
			if center.distance_to(p) <= r:
				set_cell(cx, cy, 0)
				removed += 1
	return removed


## Column height profile distance vs another city, for the distinctness check.
func profile_distance(other: CityData) -> float:
	var n := mini(width_cells, other.width_cells)
	if n == 0:
		return 1e9
	var acc := 0.0
	for cx in range(n):
		acc += absf(_col_height(cx) - other._col_height(cx))
	return acc / float(n)


func _col_height(cx: int) -> float:
	for cy in range(SKY_CELLS - 1, -1, -1):
		if cell(cx, cy) != 0:
			return float(cy + 1)
	return 0.0
