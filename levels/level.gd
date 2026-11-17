@tool
extends TileMapLayer
## The root of every level scene (levels/level_<n>.tscn). A level is painted in the editor: one tile per brick,
## on bricks.tres, whose tiles are brick cells (16 x 64), so a brick can only land on a legal cell. Each tile
## shows its HP as a digit, and its custom data `hp` is what Levels.read() uses. Here the tiles are tinted with
## the game's HP colours (Palette.hp) and the grid's edge is outlined, so what you paint looks like the board.
## To add an HP step: add a tile to bricks.tres with its digit and set its `hp`. The tile with `hp` 0, hollow
## with a cross, is not a brick but a mark for the balance bot to aim at (see Levels), tinted cyan here.
## The game never shows this scene; Levels.read() turns it into a Board.

## The name in the hub and on the level screen.
@export var title := ""
## The score a round needs to clear the level (Round.target).
@export var target := 0
## Grid rows: even. Columns are always rows x 4; the outline shows where the grid ends.
@export_range(2, 64, 2) var rows := 16:
	set(value):
		rows = value
		queue_redraw()


func _draw() -> void:
	draw_rect(Board.new(rows).grid(), Palette.BORDER, false, 2.0)


func _use_tile_data_runtime_update(_coords: Vector2i) -> bool:
	return true


func _tile_data_runtime_update(_coords: Vector2i, tile_data: TileData) -> void:
	var hp: int = tile_data.get_custom_data(&"hp")
	tile_data.modulate = Palette.hp(hp) if hp > 0 else Palette.PLAYER  # 0 is the bot's aim mark, see Levels
