class_name Cursor
extends RefCounted
## The mouse on the ground: a ray from the camera through the cursor (the 480x270 stretch maps the
## mouse already), the same ray the winch is aimed with (docs/plan.md §5, §8). The ground is found
## by marching the ray over the height map, so it needs no physics frame and works headless.


## The camera's ray through the screen point at (the viewport's mouse when null): [origin, dir].
static func ray(camera: Camera3D, at: Variant = null) -> Array[Vector3]:
	var p: Vector2 = at if at != null else camera.get_viewport().get_mouse_position()
	return [camera.project_ray_origin(p), camera.project_ray_normal(p)]


## Where the ray from origin along dir first meets the ground of height(x, z), within reach
## metres; null if it does not.
static func ground(origin: Vector3, dir: Vector3, height: Callable, reach := 300.0) -> Variant:
	const STEP := 0.5
	var prev := origin
	var d := 0.0
	while d < reach:
		d += STEP
		var p := origin + dir * d
		if p.y <= float(height.call(p.x, p.z)):
			var lo := prev
			var hi := p
			for i in 12:
				var mid := (lo + hi) * 0.5
				if mid.y <= float(height.call(mid.x, mid.z)):
					hi = mid
				else:
					lo = mid
			return hi
		prev = p
	return null
