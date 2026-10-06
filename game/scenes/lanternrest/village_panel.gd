class_name VillagePanel
extends PanelContainer
## A place's menu, opened over the village (the screen dims the village behind it): a title row
## with Close, then `body`. Subclasses fill `body` in _build(). Emits `changed` when it altered
## meta (the screen refreshes its bar and the banner), `closed` when the player closes it.

signal closed
signal changed

var place_id := ""
var title := ""
var width := 280.0
var closable := true
var body: VBoxContainer
var close_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := FlowUI.vbox(5)
	v.custom_minimum_size.x = width
	var head := FlowUI.hbox(6)
	var t := FlowUI.label(title, &"HeadingLabel", null, width - (64.0 if closable else 0.0))
	t.name = "Title"
	head.add_child(t)
	if closable:
		close_button = FlowUI.button("Close", 58, 22)
		close_button.name = "Close"
		close_button.pressed.connect(close)
		head.add_child(close_button)
	v.add_child(head)
	body = FlowUI.vbox(5)
	v.add_child(body)
	add_child(FlowUI.margin(v, 8))
	_build()


## Subclasses add their rows to `body` here.
func _build() -> void:
	pass


func close() -> void:
	closed.emit()


## A short note card: a title and one wrapped line (empty plots, the mist).
static func note(id: String, heading: String, text: String, w := 230.0) -> VillagePanel:
	var p := VillagePanel.new()
	p.place_id = id
	p.title = heading
	p.width = w
	p.ready.connect(func() -> void: p.body.add_child(FlowUI.para(text, w, Pal.INK9)))
	return p
