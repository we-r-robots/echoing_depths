class_name UIFrame
extends RefCounted
## Wide-screen layout helpers for menu screens (docs/BUILD.md "Rendering: world and UI layers").
## Each screen keeps its 640x360 content frame centred in the view (the 16:9 safe area on a wide
## phone); bars and backdrops span the whole view, and edge-anchored groups follow the safe edges.


## x of the centred 640x360 frame (0 at 16:9).
static func fx(ci: CanvasItem) -> float:
	return UIText.frame_rect(ci).position.x


## Safe left / right edges of the view, in design px.
static func left(ci: CanvasItem) -> float:
	return UIText.safe_rect(ci).position.x


static func right(ci: CanvasItem) -> float:
	return UIText.safe_rect(ci).end.x


## A 640-wide painted backdrop centred in the view, mirrored into the wings on wide screens (the
## copy meets the original edge to edge, so the seam is continuous), then dimmed by `dim`.
static func backdrop(ci: CanvasItem, tex: Texture2D, dim := Color(0, 0, 0, 0), extra: Array = []) -> void:
	var vr := ci.get_viewport_rect()
	var x := fx(ci)
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	for layer: Texture2D in [tex] + extra:
		ci.draw_texture(layer, Vector2(x, 0))
		var k := 1
		while x - (k - 1) * tw > vr.position.x:
			var flip := k % 2 == 1
			var lx := x - k * tw
			ci.draw_texture_rect(layer, Rect2(lx + (tw if flip else 0.0), 0, -tw if flip else tw, th), false)
			var rx := x + k * tw
			ci.draw_texture_rect(layer, Rect2(rx + (tw if flip else 0.0), 0, -tw if flip else tw, th), false)
			k += 1
	if dim.a > 0.0:
		ci.draw_rect(vr, dim)


## The top bar chrome across the whole view (height h).
static func top_bar(ci: CanvasItem, h := 28.0) -> void:
	var vw := ci.get_viewport_rect().size.x
	ci.draw_rect(Rect2(0, 0, vw, h), Pal.INK2)
	ci.draw_rect(Rect2(0, 0, vw, 1), Pal.INK3)
	ci.draw_rect(Rect2(0, h, vw, 1), Pal.INK4)
	ci.draw_rect(Rect2(0, h + 1, vw, 1), Pal.INK1)
