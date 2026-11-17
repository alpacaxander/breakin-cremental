class_name Hit
extends RefCounted
## One contact between a ball and something solid. It is what Collide.sweep returns, what a placeable's
## on_ball_hit hook is given, and the payload of Round.ball_bounced.

enum Surface {
	WALL,  ## The top, bottom or back wall. `normal` says which: DOWN, UP or LEFT
	PADDLE,
	BRICK,  ## `cell` is set
	ITEM,  ## A free-form placed item. `item` is set
}

var surface: Surface
## The ball's centre at the moment of contact, in round units.
var point: Vector2
## A unit vector pointing from the surface back toward the ball. A brick hit resolves against exactly one edge,
## so for BRICK and WALL this is always one of LEFT, RIGHT, UP, DOWN. For a gate the ball went through (the
## Booster) there is no surface, and it points back along the ball's way.
var normal: Vector2
## How far the ball travelled along its direction before the contact, in units.
var travel: float
## BRICK only: the brick cell that was hit.
var cell: Vector2i
## ITEM only: the placed item that was hit.
var item: Layout.Item
