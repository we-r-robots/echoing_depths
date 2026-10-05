class_name SpritePortrait
extends RefCounted
## Portraits cut from the hero's own battle sprite (idle frame 0), so the party list, the draft
## header and the grid all show the same character. The crop follows the sprite's opaque pixels,
## so it keeps working when the placeholder art is replaced (sizes come from sprite_meta.json).

static var _cache := {}


## A size x size head-and-shoulders crop for a base class (null if the class has no sprite).
static func for_class(base: String, size := 24) -> Texture2D:
	var key := "%s:%d" % [base, size]
	if _cache.has(key):
		return _cache[key]
	var frames := HeroCard._frames_for(base)
	if frames == null or not frames.has_animation(&"idle"):
		return null
	var tex := frames.get_frame_texture(&"idle", 0)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x <= 0:
		return null
	# horizontal centre of the head: mean x of opaque pixels in the top rows of the figure
	var sx := 0
	var n := 0
	for y in range(used.position.y, mini(used.position.y + 14, used.end.y)):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > 0.5:
				sx += x
				n += 1
	var cx := sx / maxi(n, 1)
	var x0 := clampi(cx - size / 2, 0, img.get_width() - size)
	var y0 := clampi(used.position.y - 2, 0, img.get_height() - size)
	var out := img.get_region(Rect2i(x0, y0, size, size))
	var it := ImageTexture.create_from_image(out)
	_cache[key] = it
	return it
