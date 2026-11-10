## Plays one strip from assets/pixel/png/anim_<name>.png as an AnimatedSprite2D at 2x. Frame sizes and fps: docs/animations.md.
extends Node

const DIR := "res://assets/pixel/png/anim_%s.png"
const SCALE := 2.0  # sprites are drawn on a 640x360 canvas, shown at 1280x720
static var _cache := {}


## fw: frame width in strip pixels. One-shot unless loop; one-shots free themselves when done unless hold keeps the last frame.
static func play(parent: Node, name: String, fw: int, fps: int, pos: Vector2, rot := 0.0, loop := false, hold := false) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _frames(name, fw)
	s.sprite_frames.set_animation_speed("default", fps)
	s.sprite_frames.set_animation_loop("default", loop)
	s.position = pos
	s.rotation = rot
	s.scale = Vector2.ONE * SCALE
	s.z_index = 1
	if not loop and not hold:
		s.animation_finished.connect(s.queue_free)
	parent.add_child(s)
	s.play("default")
	return s


## One frame of a strip as a texture, for a still face.
static func frame(name: String, fw: int, i: int) -> Texture2D:
	return _frames(name, fw).get_frame_texture("default", i)


# ponytail: one SpriteFrames per strip, shared; every use of a strip has the same fps so sharing is safe.
static func _frames(name: String, fw: int) -> SpriteFrames:
	if name in _cache:
		return _cache[name]
	var tex: Texture2D = load(DIR % name)
	var sf := SpriteFrames.new()
	for i in int(tex.get_width()) / fw:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, tex.get_height())
		sf.add_frame("default", at)
	_cache[name] = sf
	return sf
