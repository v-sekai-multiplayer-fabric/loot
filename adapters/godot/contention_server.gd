extends SceneTree
# Post-fix: one listener, four sessions, per-session replies via set_target_peer.
const PORT = 54373
const ROUNDS = 64
var peer: WebTransportPeer
var rounds := {}    # round -> [[requester, ts, transport_peer_id], ...]
var resolved := {}

static func _fmt(t: int) -> String:
	var d = Time.get_datetime_dict_from_unix_time(t)
	return "%04d%02d%02d%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]

func _init():
	var crypto = Crypto.new()
	var key = crypto.generate_ecdsa()
	var now = int(Time.get_unix_time_from_system())
	var cert = crypto.generate_self_signed_certificate_san(key, "CN=contention-zone",
		_fmt(now), _fmt(now + 86400), PackedStringArray(["DNS:localhost", "IP:127.0.0.1"]))
	peer = WebTransportPeer.new()
	if peer.create_server(PORT, "/wt", cert, key) != OK:
		printerr("create_server failed"); quit(1); return
	print("CONTSRV ready on ", PORT)

func _process(_d: float) -> bool:
	if not peer: return false
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var parts = peer.get_packet().get_string_from_utf8().split(":")
		var from = peer.get_packet_peer()
		var rnd := int(parts[0]); var req := int(parts[1]); var ts := int(parts[2])
		if not rounds.has(rnd): rounds[rnd] = []
		rounds[rnd].append([req, ts, from])
		if rounds[rnd].size() == 4 and not resolved.has(rnd):
			resolved[rnd] = true
			var best = rounds[rnd][0]
			for r in rounds[rnd]:
				if r[1] < best[1] or (r[1] == best[1] and r[0] < best[0]):
					best = r
			for r in rounds[rnd]:
				peer.set_target_peer(r[2])
				peer.put_packet(("%d:%d" % [rnd, best[0]]).to_utf8_buffer())
			if resolved.size() == ROUNDS:
				print("CONTSRV done")
	return false
