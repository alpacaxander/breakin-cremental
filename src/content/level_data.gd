class_name LevelData
extends RefCounted
## One level as the game uses it: what Levels.read() returns. The level's scene is only how the level is written
## down; nothing outside Levels opens it.

## 1 for the first level.
var number: int
## "Two Columns"
var title: String
## The score a round needs to clear it (Round.target).
var target: int
## The level's bricks and its size (board.rows). Every brick has `placed` false and no mod. Treat it as
## read-only: Round copies it, and so should anything else that wants to change it.
var board: Board
## Cells a skilled player aims the ball at, sorted (the aim tile, see Levels). Not bricks: the board leaves them
## out, and only the balance bot reads them.
var aims: Array[Vector2i] = []
