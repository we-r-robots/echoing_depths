class_name VaultPanel
extends VillagePanel
## The Vault entrance: every dungeon run starts here. Descend (a new run), or continue the run in
## progress; starting a new run over a saved one asks a second tap, since the saved run is lost.

signal descend
signal resume

const W := 260

var has_saved := false
var _confirming := false
var _new_btn: Button
var _warn: Label


func _init() -> void:
	place_id = "vault"
	title = "Vault Entrance"
	width = W


func _build() -> void:
	body.add_child(FlowUI.para("Stairs down into the Memory Vaults. The lantern's light follows every party that goes below.", W, Pal.INK9))
	var who := FlowUI.hbox(6)
	who.add_child(FlowUI.crest(GameState.crest(), 1))
	who.add_child(FlowUI.label(GameState.team_name(), &"GoldLabel", null, W - 20))
	body.add_child(who)
	if has_saved:
		var go := FlowUI.primary("Continue the descent", W)
		go.name = "Continue"
		go.pressed.connect(func() -> void: resume.emit())
		body.add_child(go)
		_warn = FlowUI.para("", W, Pal.BLOOD4)
		_warn.visible = false
		body.add_child(_warn)
		_new_btn = FlowUI.button("Begin a new descent", W, 22)
		_new_btn.name = "New"
		_new_btn.pressed.connect(new_descent)
		body.add_child(_new_btn)
	else:
		var go := FlowUI.primary("Descend", W)
		go.name = "New"
		go.pressed.connect(new_descent)
		body.add_child(go)


## A new run. Over a saved run the first tap only warns; the second starts it.
func new_descent() -> void:
	if has_saved and not _confirming:
		_confirming = true
		_warn.text = "Your run in progress will be lost. Tap again to begin anew."
		_warn.visible = true
		_new_btn.text = "Abandon it and descend"
		return
	descend.emit()
