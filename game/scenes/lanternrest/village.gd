class_name Village
extends RefCounted
## Lanternrest's places and the rules for which of them stand (04-meta-progression.md; docs/BUILD.md
## "Lanternrest is a place, not a menu", "Lanternrest starts sparse"). Pure data, no nodes:
## the screen (lanternrest.gd) builds a VillagePlace for every visible place, and tests ask the
## same functions.
##
## The art and its geometry come from assets/lanternrest/src/make_village.py, which writes
## layout.json: each layer's world position and each place's tap zone and name-plate line. The
## world is WORLD_W x 360 world px, wider than any screen, and scrolls sideways.
##
##   Village.visible_places(meta)     # ids, back to front (draw order; hit tests go front to back)
##   Village.is_built("grounds", meta)
##   Village.clamp_cam(x, view_w)     # the camera's left edge, kept inside the world

const LAYOUT_PATH := "res://assets/lanternrest/layout.json"
const ART := "res://assets/lanternrest/"

## Every place in the village. kind: lantern | vault | building | plot | fog.
## `on_plot`: a building stands on that plot once built (the plot is then hidden).
## `unlock`: the placeholder rule that builds it (meta field >= value). See unlock_rule_text().
## `always_plate`: its name plate shows without hover (the places a player looks for first).
const PLACES := {
	"fog_west": {"kind": "fog", "name": "The mist", "art": "fog_west",
		"text": "Grey mist hides this side of Lanternrest. It will thin as the village remembers more."},
	"plot_w1": {"kind": "plot", "name": "Empty plot", "art": "plot_w1",
		"text": "Old foundation stones, a blank board on a stake. Something the village remembers could stand here."},
	"vault": {"kind": "vault", "name": "Vault Entrance", "art": "vault", "always_plate": true,
		"glow": "vault_glow"},
	"plot_w2": {"kind": "plot", "name": "Empty plot", "art": "plot_w2",
		"text": "A cleared square by the road, waiting. Something the village remembers could stand here."},
	"lantern": {"kind": "lantern", "name": "The Lantern", "art": "lantern", "always_plate": true,
		"glow": "lantern_glow"},
	"plot_e1": {"kind": "plot", "name": "Empty plot", "art": "plot_e1",
		"text": "Trodden ground and a broken fence. Something the village remembers could stand here."},
	"grounds": {"kind": "building", "name": "Training Grounds", "art": "grounds", "always_plate": true,
		"glow": "grounds_glow", "on_plot": "plot_e1", "unlock": {"runs": 1}},
	"plot_e2": {"kind": "plot", "name": "Empty plot", "art": "plot_e2",
		"text": "Weeds through old flagstones. Something the village remembers could stand here."},
	"plot_e3": {"kind": "plot", "name": "Empty plot", "art": "plot_e3",
		"text": "The last plot before the mist. Something the village remembers could stand here."},
	"fog_east": {"kind": "fog", "name": "The mist", "art": "fog_east",
		"text": "Grey mist hides this side of Lanternrest. It will thin as the village remembers more."},
}
## Draw order, back to front (fog last: it lies over everything at the edges).
const ORDER := ["plot_w1", "plot_w2", "plot_e1", "plot_e2", "plot_e3", "vault", "grounds", "lantern",
	"fog_west", "fog_east"]

static var _layout: Dictionary = {}


static func layout() -> Dictionary:
	if _layout.is_empty():
		var j := load(LAYOUT_PATH) as JSON
		_layout = j.data if j != null and j.data is Dictionary else {}
	return _layout


static func world_size() -> Vector2:
	var w: Array = layout().get("world", [1280, 360])
	return Vector2(float(w[0]), float(w[1]))


static func far_width() -> float:
	return float(layout().get("far_w", 1040))


## World position of a generated layer (top-left).
static func layer_pos(layer: String) -> Vector2:
	var p: Array = layout()["layers"].get(layer, [0, 0])
	return Vector2(float(p[0]), float(p[1]))


static func texture(layer: String) -> Texture2D:
	return load(ART + layer + ".png") as Texture2D


## A place's tap zone in world px.
static func zone(id: String) -> Rect2:
	var z: Array = layout()["places"][id]["zone"]
	return Rect2(float(z[0]), float(z[1]), float(z[2]), float(z[3]))


## The world y its name plate's bottom edge sits on.
static func plate_y(id: String) -> float:
	return float(layout()["places"][id]["plate_y"])


## Where the team's crest is drawn on the lantern's banner (world px, top-left).
static func banner_pos() -> Vector2:
	var b: Array = layout().get("banner", [0, 0])
	return Vector2(float(b[0]), float(b[1]))


static func kind(id: String) -> String:
	return String(PLACES[id]["kind"])


static func place_name(id: String) -> String:
	return String(PLACES[id]["name"])


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


## The places standing for this meta, back to front: the lantern, the Vault entrance, the plots
## (a plot under a built building is gone) and the fogged side areas.
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


## Built places the player has not looked at yet (a NEW tag on their plates).
static func unseen(meta: Dictionary) -> Array[String]:
	var seen: Array = meta.get("village_seen", [])
	var out: Array[String] = []
	for id in visible_places(meta):
		if PLACES[id].has("unlock") and not seen.has(id):
			out.append(id)
	return out


## The camera's left edge (world px), kept inside the world for a view `view_w` wide.
static func clamp_cam(x: float, view_w: float) -> float:
	return clampf(x, 0.0, maxf(0.0, world_size().x - view_w))


## The camera position that centres a world x in a view `view_w` wide.
static func cam_for(world_x: float, view_w: float) -> float:
	return clamp_cam(world_x - view_w / 2.0, view_w)
