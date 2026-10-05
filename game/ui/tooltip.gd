class_name Tip
extends RefCounted
## Shared tooltip for every screen (BUILD.md: effects are icons; the full text lives in a tooltip).
## Hover shows it on PC; tap toggles it and press-and-hold shows it on touch, so touch always
## reaches it. Tapping anywhere else closes it. One tooltip is open at a time.
##
##   Tip.attach(control, "Def +10%", "Front heroes get Def +10%.", Pal.LIFE4[, prefer_below])
##   Tip.detach(control)
##   Tip.show_for(control)   # open programmatically (demos, tutorials); Tip.close() closes
##   Tip.is_open_for(control)
## The control must receive mouse input (mouse_filter STOP or PASS). Text uses the shared bold
## font; the box keeps inside the 640x360 view, above the control when there is room, else below.

const HOLD_TIME := 0.35

static var _node: Node = null


static func attach(c: Control, title: String, body: String, accent := Pal.CRYSTAL4, prefer_below := false) -> void:
	c.set_meta("tip", {"title": title, "body": body, "accent": accent, "below": prefer_below})
	if c.has_meta("tip_wired"):
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
