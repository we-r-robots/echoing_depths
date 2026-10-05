class_name Pal
extends RefCounted
## Master palette as constants, generated from assets/palette/master.gpl (regenerate if the palette changes).
## Use these for any colour set in code so every screen stays on-palette.

const INK1 := Color(0.0431, 0.0392, 0.0784)
const INK2 := Color(0.0824, 0.0745, 0.1529)
const INK3 := Color(0.1216, 0.1137, 0.2275)
const INK4 := Color(0.1725, 0.1647, 0.3216)
const INK5 := Color(0.2392, 0.2314, 0.4196)
const INK6 := Color(0.3216, 0.3216, 0.5294)
const INK7 := Color(0.4314, 0.4392, 0.6392)
const INK8 := Color(0.5765, 0.5882, 0.7529)
const INK9 := Color(0.7490, 0.7608, 0.8627)
const INK10 := Color(0.9255, 0.9333, 0.9686)
const AMBER1 := Color(0.2314, 0.1216, 0.1020)
const AMBER2 := Color(0.4157, 0.2039, 0.1255)
const AMBER3 := Color(0.6392, 0.3137, 0.1647)
const AMBER4 := Color(0.8392, 0.4706, 0.1843)
const AMBER5 := Color(0.9490, 0.6471, 0.2549)
const AMBER6 := Color(0.9843, 0.8235, 0.4784)
const AMBER7 := Color(1.0000, 0.9451, 0.7686)
const CRYSTAL1 := Color(0.0706, 0.1961, 0.2902)
const CRYSTAL2 := Color(0.1098, 0.3529, 0.4510)
const CRYSTAL3 := Color(0.1647, 0.5608, 0.6392)
const CRYSTAL4 := Color(0.3098, 0.7686, 0.7882)
const CRYSTAL5 := Color(0.6353, 0.9373, 0.9020)
const LIFE1 := Color(0.1137, 0.2000, 0.1490)
const LIFE2 := Color(0.1843, 0.3529, 0.2275)
const LIFE3 := Color(0.3098, 0.5412, 0.2902)
const LIFE4 := Color(0.5451, 0.7490, 0.3529)
const BLOOD1 := Color(0.2902, 0.0784, 0.1412)
const BLOOD2 := Color(0.5412, 0.1216, 0.2000)
const BLOOD3 := Color(0.8235, 0.2314, 0.2706)
const BLOOD4 := Color(1.0000, 0.4784, 0.4196)
const FADE1 := Color(0.2902, 0.2902, 0.3137)
const FADE2 := Color(0.4667, 0.4667, 0.4941)
const FADE3 := Color(0.6549, 0.6549, 0.6784)
const FADE4 := Color(0.8314, 0.8314, 0.8471)
const SKIN1 := Color(0.3608, 0.2275, 0.1804)
const SKIN2 := Color(0.6039, 0.3922, 0.2824)
const SKIN3 := Color(0.8510, 0.6275, 0.4784)
const SKIN4 := Color(0.9529, 0.8118, 0.6902)
const VIOLET1 := Color(0.2314, 0.1216, 0.3608)
const VIOLET2 := Color(0.4196, 0.2275, 0.6275)
const VIOLET3 := Color(0.6549, 0.4275, 0.8784)
const VIOLET4 := Color(0.8784, 0.7020, 1.0000)

const BY_NAME := {
	"ink1": INK1,
	"ink2": INK2,
	"ink3": INK3,
	"ink4": INK4,
	"ink5": INK5,
	"ink6": INK6,
	"ink7": INK7,
	"ink8": INK8,
	"ink9": INK9,
	"ink10": INK10,
	"amber1": AMBER1,
	"amber2": AMBER2,
	"amber3": AMBER3,
	"amber4": AMBER4,
	"amber5": AMBER5,
	"amber6": AMBER6,
	"amber7": AMBER7,
	"crystal1": CRYSTAL1,
	"crystal2": CRYSTAL2,
	"crystal3": CRYSTAL3,
	"crystal4": CRYSTAL4,
	"crystal5": CRYSTAL5,
	"life1": LIFE1,
	"life2": LIFE2,
	"life3": LIFE3,
	"life4": LIFE4,
	"blood1": BLOOD1,
	"blood2": BLOOD2,
	"blood3": BLOOD3,
	"blood4": BLOOD4,
	"fade1": FADE1,
	"fade2": FADE2,
	"fade3": FADE3,
	"fade4": FADE4,
	"skin1": SKIN1,
	"skin2": SKIN2,
	"skin3": SKIN3,
	"skin4": SKIN4,
	"violet1": VIOLET1,
	"violet2": VIOLET2,
	"violet3": VIOLET3,
	"violet4": VIOLET4,
}

## Palette colour by name ("amber6"); unknown names return magenta so mistakes are loud.
static func c(name: String) -> Color:
	return BY_NAME.get(name, Color.MAGENTA)
