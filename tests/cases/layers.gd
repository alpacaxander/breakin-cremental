extends RefCounted
## The layer rules of docs/architecture.md, checked on the files themselves.
##   - Rules (src/sim/, src/kinds/) are plain objects: no script there extends Node, names an autoload, or names a
##     screen-side class.
##   - Colours are defined in src/ui/palette.gd only: no other script, scene, resource or settings file holds a
##     colour literal.

const RULES := ["res://src/sim", "res://src/kinds"]
## Where the screen side lives. Every class_name under these is a name no rule may use, so a new screen class is
## covered without a change here.
const SCREENS := ["res://src/level/", "res://src/hub/", "res://src/menu/", "res://src/ui/", "res://src/main.gd", "res://src/play.gd"]
const PALETTE := "res://src/ui/palette.gd"
const SKIP := ["res://.godot", "res://tests/out"]
const SCANNED := ["gd", "tscn", "tres", "godot", "cfg"]
## What a colour literal looks like. `Color(c, 0.5)` and `Color(Palette.COINS, a)` pass: they start from a name.
const LITERALS := {
	"a Color built from numbers or a string": "\\bColor\\s*\\(\\s*[\"'0-9.)-]",
	"a Color8": "\\bColor8\\s*\\(",
	"a Color made from text or a code": "\\bColor\\.(html|hex|hex64|from_\\w+)\\s*\\(",
	"a named Color constant": "\\bColor\\.[A-Z]",
	"a PackedColorArray of numbers": "\\bPackedColorArray\\s*\\(\\s*[0-9]",
	"a hex colour string": "[\"']#?(?=[0-9]*[a-fA-F])([0-9a-fA-F]{6}|[0-9a-fA-F]{8})[\"']",
}


func run(t: Node) -> void:
	var forbidden: Array[String] = []
	for c in ProjectSettings.get_global_class_list():
		if SCREENS.any(func(dir: String) -> bool: return String(c.path).begins_with(dir)):
			forbidden.append(String(c["class"]))
	t.check(forbidden.has("Main") and forbidden.has("Palette"), "the class list names the screen side (%d classes)" % forbidden.size())
	for p in ProjectSettings.get_property_list():
		if String(p.name).begins_with("autoload/"):
			forbidden.append(String(p.name).trim_prefix("autoload/"))
	var names := RegEx.create_from_string("\\b(%s)\\b" % "|".join(forbidden))
	for dir: String in RULES:
		for path in _files(dir):
			if path.get_extension() != "gd":
				continue
			var script := load(path) as GDScript
			t.check(script != null, "%s loads" % path)
			if script and ClassDB.is_parent_class(script.get_instance_base_type(), &"Node"):
				t.check(false, "%s is a rule, so it does not extend Node" % path)
			var found := names.search(_code(path))
			if found:
				t.check(false, "%s is a rule, so it does not name %s" % [path, found.get_string()])

	var literals := {}
	for what: String in LITERALS:
		literals[what] = RegEx.create_from_string(LITERALS[what])
	for path in _files("res://"):
		if path == PALETTE or not path.get_extension() in SCANNED:
			continue
		var code := _code(path)
		for what: String in literals:
			var found: RegExMatch = literals[what].search(code)
			if found:
				var line := code.count("\n", 0, found.get_start()) + 1
				t.check(false, "%s:%d holds %s; colours come from Palette" % [path, line, what])


## Every file under `dir`, at any depth.
func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if dir in SKIP:
		return out
	for file in DirAccess.get_files_at(dir):
		out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(sub)))
	return out


## A file's text. A script's comments are left out, so a comment may show an example of what not to write.
func _code(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if path.get_extension() == "gd":
		text = RegEx.create_from_string("(?m)#.*$").sub(text, "", true)
	return text
