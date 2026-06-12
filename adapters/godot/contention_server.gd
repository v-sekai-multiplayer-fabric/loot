extends SceneTree
# Four-player first-touch contention, server-authoritative: collects the four
# requests of each round, resolves with the LootCore.resolve algorithm
# (earliest receipt, ties to the lowest requester id), replies the winner to
# every requester.
const BASE_PORT = 54372
const ROUNDS = 64
var peers := []    # one server endpoint per player (multi-session-per-listener
                   # crashes the http3 module; single authority, four endpoints)
var rounds := {}   # round -> Array of [requester, ts, endpoint_index]
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
	var p = WebTransportPeer.new()
	if p.create_server(BASE_PORT, "/wt", cert, key) != OK:
		printerr("create_server failed"); quit(1); return
	peers.append(p)
	print("CONTSRV ready on ", BASE_PORT)

func _process(_d: float) -> bool:
	if peers.is_empty(): return false
	var p = peers[0]
	p.poll()
	while p.get_available_packet_count() > 0:
		var parts = p.get_packet().get_string_from_utf8().split(":")
		var rnd := int(parts[0]); var req := int(parts[1]); var ts := int(parts[2])
		if not rounds.has(rnd): rounds[rnd] = []
		rounds[rnd].append([req, ts])
		if rounds[rnd].size() == 4 and not resolved.has(rnd):
			resolved[rnd] = true
			var best = rounds[rnd][0]
			for r in rounds[rnd]:
				if r[1] < best[1] or (r[1] == best[1] and r[0] < best[0]):
					best = r
			print("RESOLVED %d:%d" % [rnd, best[0]])
			if resolved.size() == ROUNDS:
				print("CONTSRV done: ", ROUNDS, " rounds resolved")
	return false
