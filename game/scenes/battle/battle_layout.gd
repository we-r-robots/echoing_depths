extends RefCounted
## Battle field geometry: the FF1-style side view. Each side has a 2-column (front/back) x 4-row grid.
## The field is drawn in world pixels and shown through a 2x integer camera zoom, so units stand
## large on screen. Rows step toward the viewer and lean right (an oblique ground plane), which
## spreads adjacent rows apart horizontally so units never overlap at rest. The back column sits
## further from the centre line. Shared by every battle node.

const ZOOM := 2
const CX := 320
const CY := 180                       # camera centre (world); visible world = 320 x 180
const ROW_Y := [170, 192, 214, 236]
const DX := [40.0, 88.0]              # centre-line distance of [front, back] column
const SKEW := 20.0                    # x shift per row toward the viewer (matches bg floor seams)
const SLOPE := SKEW / 22.0            # floor seam slope: x per y
const BG_MARGIN := 16                 # bg_vault.png (screen space, 1x) has a 16 px shake margin


static func depth_scale(_row: int) -> float:
	return 1.0


## Feet position of slot (col 0 front / 1 back, row 0..3) for side 0 (left) or 1 (right).
static func slot_pos(side: int, col: int, row: int) -> Vector2:
	var s := -1.0 if side == 0 else 1.0
	return Vector2(roundf(CX + s * DX[col] + SKEW * (row - 1.5)), ROW_Y[row])


## Where a melee attacker stands to strike a unit at `target_pos` (in front of it, toward the centre).
static func strike_pos(target_pos: Vector2, attacker_side: int, reach: float = 24.0) -> Vector2:
	var s := -1.0 if attacker_side == 0 else 1.0
	return Vector2(roundf(target_pos.x + s * reach), target_pos.y + 1)


## World point -> screen pixel (for the 1x background layer).
static func to_screen(p: Vector2) -> Vector2:
	return (p - Vector2(CX - 160, CY - 90)) * ZOOM
