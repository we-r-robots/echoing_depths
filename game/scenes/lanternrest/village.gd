class_name Village
extends RefCounted
## Lanternrest's places and the rules for which of them stand (04-meta-progression.md; docs/BUILD.md
## "Lanternrest is a place, not a menu", "Lanternrest starts sparse", "Lanternrest view: top-down
## 3/4"). Pure data, no nodes: the screen (lanternrest.gd) builds a VillagePlace for every visible
## place, and tests ask the same functions.
##
## The town is a top-down 3/4 map on a 16 px grid, bigger than any screen both ways (1920 x 720 world
## px: three 16:9 screens wide, two high). Its art and geometry come from
## assets/lanternrest/src/make_town.py, which writes layout.json: each layer's world position, each
## place's tap zone and sign anchor, the lights, chimney smoke, swaying grass and banners.
##
##   Village.visible_places(meta)       # ids, back to front (draw order; hit tests go front to back)
##   Village.is_built("grounds", meta)
##   Village.clamp_cam(cam, view)       # the camera's top-left, kept inside the town

const LAYOUT_PATH := "res://assets/lanternrest/layout.json"
const ART := "res://assets/lanternrest/"

const FOG_TEXT := "Grey mist hides this side of Lanternrest. It will thin as the village remembers more."

## Every place in the town. kind: lantern | vault | building | plot | fog.
## `art`: its sprite (fog has none: the mist is the place), `<art>_hi` its highlight.
## `on_plot`: a building stands on that plot once built (the plot is then hidden).
## `unlock`: the placeholder rule that builds it (meta field >= value). See unlock_rule_text().
## `always_sign`: its signboard shows without hover (the places a player looks for first).
const PLACES := {
	"plot_w2": {"kind": "plot", "name": "Empty plot", "art": "plot_w2",
		"text": "A cleared square by the road. Room for something the village remembers."},
	"plot_e2": {"kind": "plot", "name": "Empty plot", "art": "plot_e2",
		"text": "Weeds through old flagstones. Room for something the village remembers."},
	"plot_w1": {"kind": "plot", "name": "Empty plot", "art": "plot_w1",
		"text": "Old foundation stones and a blank board. Room for something the village remembers."},
	"plot_e1": {"kind": "plot", "name": "Empty plot", "art": "plot_e1",
		"text": "Trodden ground and a broken fence. Room for something the village remembers."},
	"plot_s1": {"kind": "plot", "name": "Empty plot", "art": "plot_s1",
		"text": "The last plot before the mist. Room for something the village remembers."},
	"grounds": {"kind": "building", "name": "Training Grounds", "art": "grounds", "always_sign": true,
		"on_plot": "plot_e1", "unlock": {"runs": 1}},
	"vault": {"kind": "vault", "name": "Vault Entrance", "art": "vault", "always_sign": true},
	"lantern": {"kind": "lantern", "name": "The Lantern", "art": "lantern", "always_sign": true},
	"fog_north": {"kind": "fog", "name": "The mist", "sign": "Unexplored", "always_sign": true, "text": FOG_TEXT},
	"fog_west": {"kind": "fog", "name": "The mist", "sign": "Unexplored", "always_sign": true, "text": FOG_TEXT},
	"fog_east": {"kind": "fog", "name": "The mist", "sign": "Unexplored", "always_sign": true, "text": FOG_TEXT},
	"fog_south": {"kind": "fog", "name": "The mist", "sign": "Unexplored", "always_sign": true, "text": FOG_TEXT},
}
## Draw order, back to front (the mist's places last: they sit over the mist).
const ORDER := ["plot_w2", "plot_e2", "plot_w1", "plot_e1", "plot_s1", "grounds", "vault", "lantern",
	"fog_north", "fog_west", "fog_east", "fog_south"]

static var _layout: Dictionary = {}


static func layout() -> Dictionary:
	if _layout.is_empty():
		var j := load(LAYOUT_PATH) as JSON
		_layout = j.data if j != null and j.data is Dictionary else {}
	return _layout


static func world_size() -> Vector2:
	var w: Array = layout().get("world", [1920, 720])
	return Vector2(float(w[0]), float(w[1]))


static func _v(a: Variant) -> Vector2:
	var arr: Array = a
	return Vector2(float(arr[0]), float(arr[1]))


## World position of a generated layer (top-left; for glow_* the texture's centre offset).
static func layer_pos(layer: String) -> Vector2:
	return _v(layout()["layers"].get(layer, [0, 0]))


static func has_layer(layer: String) -> bool:
	return layout()["layers"].has(layer)


static func texture(layer: String) -> Texture2D:
	return load(ART + layer + ".png") as Texture2D


## A place's tap zone in world px.
static func zone(id: String) -> Rect2:
	var z: Array = layout()["places"][id]["zone"]
	return Rect2(float(z[0]), float(z[1]), float(z[2]), float(z[3]))


## Where a place's signboard hangs (the bottom of its stem), world px.
static func sign_at(id: String) -> Vector2:
	return _v(layout()["places"][id]["sign"])


## Where the team's banner hangs from the lantern's arm (world px, top-left).
static func banner_pos() -> Vector2:
	return _v(layout().get("banner", [0, 0]))


static func flame_pos() -> Vector2:
	return _v(layout().get("flame", [0, 0]))


## The lights: [{id, x, y, gx, gy, glow, place?, ...}] (gx, gy: where the glow is centred).
static func lights() -> Array:
	return layout().get("lights", [])


static func smoke() -> Array:
	return layout().get("smoke", [])


static func grass() -> Array:
	return layout().get("grass", [])


static func banners() -> Dictionary:
	return layout().get("banners", {})


## Where the camera centres when the town opens (the plaza, with the Vault and the lantern).
static func start_point() -> Vector2:
	return _v(layout().get("start", [960, 376]))


static func kind(id: String) -> String:
	return String(PLACES[id]["kind"])


static func place_name(id: String) -> String:
	return String(PLACES[id]["name"])


## What its signboard says ("Unexplored" for the mist; otherwise its name).
static func sign_label(id: String) -> String:
	return String(PLACES[id].get("sign", PLACES[id]["name"]))


## Places marked by a small pin (no text) until hovered or opened: the empty plots. Every other
## place has a signboard that always shows (touch has no hover).
static func has_pin(id: String) -> bool:
	return kind(id) == "plot"


## Where a place's pin stands (world px): the top of its sign board.
static func pin_at(id: String) -> Vector2:
	var p: Dictionary = layout()["places"][id]
	return _v(p.get("pin", p["sign"]))


## The town's stage, from the progress signals (docs/tasks/lanternrest-critic2.md "Round-3 build"):
## "fresh" on a new save (the Lantern and three street lamps lit, the cottages by the plaza dark and
## boarded, the mist close); "built" once the first run has come home (meta.runs >= 1) or the
## Training Grounds stand: the high street's lamps relit, the cottages reopened, the mist pushed back.
static func stage(meta: Dictionary) -> String:
	return "built" if int(meta.get("runs", 0)) >= 1 or is_built("grounds", meta) else "fresh"


## Whether a light / chimney entry burns for this meta: its stage is reached and, if it belongs to
## a place, that place stands.
static func entry_on(e: Dictionary, meta: Dictionary) -> bool:
	var st := String(e.get("stage", "fresh"))
	if st == "built" and stage(meta) != "built":
		return false
	var pid := String(e.get("place", ""))
	return pid == "" or visible_places(meta).has(pid)


## The plaza's rect (world px): the hint keeps off it.
static func plaza_rect() -> Rect2:
	var r: Array = layout().get("plaza", [834, 330, 252, 160])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## The night light at the Lantern's banner for a stage (the lift tints the banner by it).
static func banner_light(st: String) -> Color:
	var c: Array = layout().get("banner_light", {}).get(st, [1, 1, 1])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## The added ink that keeps lit black off (0, 0, 0) (layout "lift", 0..255).
static func lift_color() -> Color:
	var c: Array = layout().get("lift", [0, 0, 0])
	return Color(float(c[0]) / 255.0, float(c[1]) / 255.0, float(c[2]) / 255.0)


static func art(id: String) -> String:
	return String(PLACES[id].get("art", ""))


## Placeholder unlock rule (a question for the user): a building stands once the meta field in
## its `unlock` reaches the value. The Training Grounds: after the first run comes home.
static func is_built(id: String, meta: Dictionary) -> bool:
	var u: Dictionary = PLACES[id].get("unlock", {})
	for k: String in u:
		if int(meta.get(k, 0)) < int(u[k]):
			return false
	return true


static func unlock_rule_text(id: String) -> String:
	var u: Dictionary = PLACES[id].get("unlock", {})
	if u.get("runs", 0) == 1:
		return "Built when your first run comes home."
	return ""


## The places standing for this meta, back to front: the plots (a plot under a built building is
## gone), built buildings, the Vault entrance, the lantern and the mist's places.
static func visible_places(meta: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var covered := {}
	for id: String in PLACES:
		var p: Dictionary = PLACES[id]
		if p.has("on_plot") and is_built(id, meta):
			covered[String(p["on_plot"])] = true
	for id: String in ORDER:
		var p: Dictionary = PLACES[id]
		if covered.has(id):
			continue
		if p.has("unlock") and not is_built(id, meta):
			continue
		out.append(id)
	return out


## Built places the player has not looked at yet (a NEW tag on their signs).
static func unseen(meta: Dictionary) -> Array[String]:
	var seen: Array = meta.get("village_seen", [])
	var out: Array[String] = []
	for id in visible_places(meta):
		if PLACES[id].has("unlock") and not seen.has(id):
			out.append(id)
	return out


## The camera's top-left (world px), kept inside the town for a view of `view` design px.
static func clamp_cam(cam: Vector2, view: Vector2) -> Vector2:
	var ws := world_size()
	return Vector2(clampf(cam.x, 0.0, maxf(0.0, ws.x - view.x)), clampf(cam.y, 0.0, maxf(0.0, ws.y - view.y)))


## The camera that centres a world point in a view (clamped).
static func cam_for(world_point: Vector2, view: Vector2) -> Vector2:
	return clamp_cam(world_point - view / 2.0, view)
