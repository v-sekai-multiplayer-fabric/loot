extends SceneTree
# Sends seeds 0..N-1 to the loot server, verifies every reply against the
# golden vectors emitted by the Lean core (build/golden.csv).
const N = 256  # seeds 0..N-1; golden.csv covers 1024
var GOLDEN: String = OS.get_environment("LOOT_GOLDEN") if OS.get_environment("LOOT_GOLDEN") != "" else "res://golden.csv"
var peer: WebTransportPeer
var expected := {}
var got := 0
var sent := false
var t0 := 0

func _init():
	var f = FileAccess.open(GOLDEN, FileAccess.READ)
	f.get_line() # header
	while not f.eof_reached():
		var parts = f.get_line().split(",")
		if parts.size() == 2: expected[int(parts[0])] = int(parts[1])
	peer = WebTransportPeer.new()
	if peer.create_client("127.0.0.1", 54370, "/wt") != OK:
		printerr("client create failed"); quit(1)
	t0 = Time.get_ticks_msec()

func _process(_d: float) -> bool:
	if not peer: return false
	peer.poll()
	if Time.get_ticks_msec() - t0 > 30000:
		printerr("TIMEOUT got=", got); quit(1); return false
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if not sent:
			sent = true
			for i in N: peer.put_packet(str(i).to_utf8_buffer())
		while peer.get_available_packet_count() > 0:
			var parts = peer.get_packet().get_string_from_utf8().split(":")
			var seed := int(parts[0]); var idx := int(parts[1])
			if expected[seed] != idx:
				printerr("MISMATCH seed=", seed, " wire=", idx, " golden=", expected[seed])
				quit(1); return false
			got += 1
			if got == N:
				print("LOOT WIRE PARITY PASS: ", N, " server-authoritative rolls match the Lean golden vectors")
				quit(0)
	return false
