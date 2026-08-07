extends Area3D
class_name MarkedLedge


@export var curve : Path3D


func get_curve_points() -> PackedVector3Array:
	var local_points = curve.curve.tessellate()
	var gloabl_points : PackedVector3Array
	for point in local_points:
		gloabl_points.append(global_transform * point)
	#print(gloabl_points)
	return gloabl_points
