extends Node
## The headless self-check. Run it with: tests/run.sh test          (every case)
##                                       tests/run.sh test rules    (only tests/cases/rules.gd)
## It is a scene, not a `godot -s` script, because a -s script cannot see the autoloads.
##
## ADDING TESTS. Each lane adds one file, tests/cases/<lane>.gd, and never edits this one or another lane's
## case. A case is a script with one function:
##
##     extends RefCounted
##     func run(t: Node) -> void:        # may use await
##         t.check(1 + 1 == 2, "sums work")
##
## `t` is this node. A case reports through t.check and may use t.tree() and t.OUT. There is no framework.
## A case fails if a check fails, if its file does not load, or if Godot logs an error while it runs, so a
## script error in the rules can't pass unseen.
##
## Before each case Progress and Settings are pointed at fresh files under tests/out/, so a case starts from a
## fresh save and can never touch the player's files. Anything a case writes goes under OUT. Kinds is reset
## too, so a kind a case made with Kinds.add is gone before the next case.
##
## A case that needs a screen makes the real Main (load("res://src/main.tscn").instantiate(), added under t) and
## frees it at the end. Headless, the window is 64 x 64 and nothing is drawn, so send input straight into the
## viewport in 1280 x 720 coordinates, t.get_viewport().push_input(event, true), not through Input. For
## anything that has to be seen, add a shot (tests/shots.gd).
##
## Output: "ok <case>" or "FAIL <case>: <message>" lines, then a last line that is "ok" or "FAIL". The exit
## code is 1 on a failure.

const CASES := "res://tests/cases"
## The folder tests may write into. Git and Godot's importer both ignore it.
const OUT := "res://tests/out"

var _case := ""
var _failed := 0
var _errors := ErrorCount.new()


## Counts what Godot logs as an error while a case runs. Warnings are let through.
class ErrorCount:
	extends Logger
	var n := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			n += 1


## Records a failure with `message` unless `ok` is true. Write the message as the rule that should hold.
func check(ok: bool, message: String) -> void:
	if not ok:
		_failed += 1
		print("FAIL %s: %s" % [_case, message])


## The scene tree, for a case that needs a node in the tree or a frame to pass.
func tree() -> SceneTree:
	return get_tree()


func _ready() -> void:
	OS.add_logger(_errors)
	var only := OS.get_cmdline_user_args()
	var files := Array(DirAccess.get_files_at(CASES)).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	files.sort()
	for file: String in files:
		_case = file.get_basename()
		if not only.is_empty() and not _case in only:
			continue
		var failed_before := _failed
		var errors_before := _errors.n
		_fresh_state()
		var script := load(CASES.path_join(file)) as GDScript
		if script == null or not script.can_instantiate():
			check(false, "the case file does not load")
		else:
			@warning_ignore("redundant_await")
			await script.new().run(self)
		check(_errors.n == errors_before, "Godot logged %d error(s) while it ran; they are printed above" % (_errors.n - errors_before))
		if _failed == failed_before:
			print("ok ", _case)
	OS.remove_logger(_errors)
	print("ok" if _failed == 0 else "FAIL: %d check(s) failed" % _failed)
	get_tree().quit(1 if _failed else 0)


func _fresh_state() -> void:
	for file: String in ["test_save.json", "test_settings.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT.path_join(file)))
	Progress.use(OUT.path_join("test_save.json"))
	Settings.use(OUT.path_join("test_settings.cfg"))
	Kinds.reset()
