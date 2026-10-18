extends Node2D
## Retained draw commands for the static grid; only the node transform rotates.

var _polygons: Array[PackedVector2Array] = []
var _outlines: Array[PackedVector2Array] = []


func configure(polygons: Array[PackedVector2Array]) -> void:
	_polygons = polygons
	_outlines.clear()
	for points: PackedVector2Array in polygons:
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		_outlines.append(outline)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 271.0, Color(0.04, 0.085, 0.12, 0.6))
	draw_arc(Vector2.ZERO, 269.0, 0.0, TAU, 128, Color(0.2, 0.45, 0.49, 0.2), 1.0, true)
	for index: int in range(_polygons.size()):
		draw_colored_polygon(_polygons[index], Color(0.07, 0.13, 0.18, 0.5))
		draw_polyline(_outlines[index], Color(0.22, 0.38, 0.44, 0.23), 0.7, true)
