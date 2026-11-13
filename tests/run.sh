#!/usr/bin/env bash
# Runs Godot on this checkout with user:// moved inside it (tests/out/user), so worktrees that run at the same
# time never share a save, a log or a shader cache, and nothing here can touch the player's real files.
#
#   tests/run.sh import             import assets. Run it once in a new checkout and after adding files
#   tests/run.sh test [case...]     the headless self-check: ok or FAIL lines, exit 1 on a failure
#   tests/run.sh boot               the main scene, headless, for 5 seconds; exit 1 on any error
#   tests/run.sh shots [list...]    screenshots into tests/out/shots/ (see tests/shots.gd)
#   tests/run.sh bot [args...]      the balance bot, tests/balance.tscn, headless
#   tests/run.sh <godot args...>    anything else goes to godot as it is
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
export XDG_DATA_HOME="$root/tests/out/user"
mkdir -p "$XDG_DATA_HOME"

# Godot and xvfb-run come from the Nix dev shell; use it unless we are already inside it.
shell=()
command -v godot >/dev/null || shell=(nix develop "$root" -c)
godot=("${shell[@]}" godot --path "$root")

# Runs a command, shows its output, and fails if Godot logged an error (Godot itself still exits 0 on those).
clean() {
	local out status=0
	out=$("$@" 2>&1) || status=$?
	printf '%s\n' "$out"
	if grep -qE '^(SCRIPT )?ERROR' <<<"$out"; then
		echo "run.sh: errors above" >&2
		return 1
	fi
	return $status
}

cmd=${1:-}
shift || true
case "$cmd" in
	import) clean "${godot[@]}" --headless --import ;;
	test) exec "${godot[@]}" --headless res://tests/test.tscn -- "$@" ;;
	boot) clean "${godot[@]}" --headless --max-fps 60 --quit-after 300 ;;
	shots) clean "${shell[@]}" xvfb-run -a godot --path "$root" --display-driver x11 --fixed-fps 60 res://tests/shots.tscn -- "$@" ;;
	bot) exec "${godot[@]}" --headless res://tests/balance.tscn -- "$@" ;;
	*) exec "${godot[@]}" ${cmd:+"$cmd"} "$@" ;;
esac
