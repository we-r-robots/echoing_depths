class_name Tip
extends RefCounted
## Shared tooltip for every screen (BUILD.md: effects are icons; the full text lives in a tooltip).
## Hover shows it on PC; tap toggles it and press-and-hold shows it on touch, so touch always
## reaches it. Tapping anywhere else closes it. One tooltip is open at a time.
##
##   Tip.attach(control, "Def +10%", "Front heroes get Def +10%.", Pal.LIFE4[, place])
##     place: "auto" (above, else below), "below", "left" / "right" (beside the control), or
##     "zone": inside the screen's free zone set with Tip.set_zone(rect) (e.g. empty floor on a
##     board, so the tip covers neither the list nor the heroes); falls back to "left";
##     "row": anchored to its own row of a list: the zone's width, directly under the row (or over
##     it when the zone's foot leaves no room), with a caret on the row's icon.
##   opts (optional): {"entries": [{"effect": EffectIcons effect or {}, "text": String}, ...]} draws a
##     list of icon + sentence rows under the body (the setup card's Details: the long read the
##     player asks for, in the same box as every other tooltip); "width": the box's max width;
##     "wire": false sets the content without hover / tap wiring (the owner opens it with show_for).
##   Tip.set_zone(Rect2)     # global rect for "zone" tips (Rect2() clears it)
##   Tip.detach(control)
##   Tip.show_for(control)   # open programmatically (demos, tutorials); Tip.close() closes
##   Tip.is_open_for(control)
## The control must receive mouse input (mouse_filter STOP or PASS). Text uses the shared bold
## font; the box keeps inside the visible view (wider than 640 on wide screens), above the control when
## there is room, else below.

const HOLD_TIME := 0.35

static var _node: Node = null


static func attach(c: Control, title: String, body: String, accent := Pal.CRYSTAL4, place := "auto", opts := {}) -> void:
	var d := {"title": title, "body": body, "accent": accent, "place": place}
	d.merge(opts)
	c.set_meta("tip", d)
	if not bool(opts.get("wire", true)) or c.has_meta("tip_wired"):
		return
	c.set_meta("tip_wired", true)
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_entered.connect(func() -> void: _layer(c).hover(c, true))
	c.mouse_exited.connect(func() -> void: _layer(c).hover(c, false))
	c.gui_input.connect(func(e: InputEvent) -> void: _layer(c).owner_input(c, e))
	c.tree_exiting.connect(func() -> void:
		if _node != null and is_instance_valid(_node):
			_node.forget(c))


static var zone := Rect2()


static func set_zone(r: Rect2) -> void:
	zone = r


static func detach(c: Control) -> void:
	if c.has_meta("tip"):
		c.remove_meta("tip")
	if _node != null and is_instance_valid(_node):
		_node.forget(c)


static func show_for(c: Control) -> void:
	_layer(c).open(c, true)


static func close() -> void:
	if _node != null and is_instance_valid(_node):
		_node.shut()


## Is any tooltip open right now (e.g. to keep a toast out from under it)?
static func any_open() -> bool:
	return _node != null and is_instance_valid(_node) and _node.visible_now()


## The open tooltip's box (global rect), or an empty rect (tests, layout checks).
static func box_rect() -> Rect2:
	return _node.box_rect() if _node != null and is_instance_valid(_node) else Rect2()


static func is_open_for(c: Control) -> bool:
	return _node != null and is_instance_valid(_node) and _node.owner_control == c and _node.visible_now()


static func _layer(c: Control) -> Node:
	if _node == null or not is_instance_valid(_node):
		var layer := CanvasLayer.new()
		layer.layer = 100
		layer.name = "TipLayer"
		var n: Control = (load("res://ui/tooltip_box.gd") as GDScript).new()
		layer.add_child(n)
		c.get_tree().root.add_child.call_deferred(layer)
		_node = n
	return _node
