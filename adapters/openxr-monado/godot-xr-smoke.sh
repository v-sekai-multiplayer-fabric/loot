#!/usr/bin/env bash
# Smoke: a Godot build's OpenXR initializes against the headless Monado runtime.
# Usage: GODOT=/path/to/godot ./godot-xr-smoke.sh   (Monado must be running)
set -euo pipefail
GODOT="${GODOT:?set GODOT to a Godot binary with OpenXR compiled in}"
command -v xvfb-run >/dev/null || { echo "need xvfb-run (xorg-x11-server-Xvfb)"; exit 1; }
sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/monado_comp_ipc"
[ -S "$sock" ] || { echo "Monado not running ($sock); start it per decision 20260612"; exit 1; }
P="$(mktemp -d)"; trap 'rm -rf "$P"' EXIT
cat > "$P/project.godot" <<'PRJ'
config_version=5
[application]
config/name="xrsmoke"
run/main_scene="res://main.tscn"
[xr]
openxr/enabled=true
PRJ
cat > "$P/main.gd" <<'GD'
extends Node
func _ready() -> void:
	var xr := XRServer.find_interface("OpenXR")
	var ok := xr != null and (xr.is_initialized() or xr.initialize())
	print("XRSMOKE: RESULT initialized=", ok)
	get_tree().quit(0 if ok else 2)
GD
cat > "$P/main.tscn" <<'TSCN'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://main.gd" id="1"]
[node name="Main" type="Node"]
script = ExtResource("1")
TSCN
out="$(timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$P" --xr-mode on --rendering-driver vulkan 2>&1)"
echo "$out" | grep -E 'Running on OpenXR runtime|Using Device|XRSMOKE: RESULT' || true
echo "$out" | grep -q 'XRSMOKE: RESULT initialized=true' \
  && echo "GODOT <-> MONADO OPENXR SMOKE PASSED" || { echo "FAILED"; exit 1; }
