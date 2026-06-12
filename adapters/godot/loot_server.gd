extends SceneTree
# Loot-over-the-wire smoke: server-authoritative seeded roll.
# Receives an ASCII seed per datagram, rolls with the proven xorshift32 +
# cumulative-weight algorithm (LootCore.R128-verified loot core), replies
# "seed:index".
const PORT = 54370
const CUMW = [50, 80, 100]
var peer: WebTransportPeer

static func _fmt(t: int) -> String:
	var d = Time.get_datetime_dict_from_unix_time(t)
	return "%04d%02d%02d%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]

static func roll(seed: int) -> int:
	var s := seed & 0xFFFFFFFF
	s = (s ^ ((s << 13) & 0xFFFFFFFF))
	s = (s ^ (s >> 17))
	s = (s ^ ((s << 5) & 0xFFFFFFFF))
	var r := s % CUMW[2]
	if r < CUMW[0]: return 0
	elif r < CUMW[1]: return 1
	return 2

func _init():
	var crypto = Crypto.new()
	var key = crypto.generate_ecdsa()
	var now = int(Time.get_unix_time_from_system())
	var san = PackedStringArray(["DNS:localhost", "IP:127.0.0.1"])
	var cert = crypto.generate_self_signed_certificate_san(
		key, "CN=loot-zone", _fmt(now), _fmt(now + 86400), san)
	peer = WebTransportPeer.new()
	var err = peer.create_server(PORT, "/wt", cert, key)
	if err != OK:
		printerr("create_server failed: ", err); quit(1); return
	print("LOOTSRV ready on ", PORT)

func _process(_d: float) -> bool:
	if not peer: return false
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var seed := int(peer.get_packet().get_string_from_utf8())
		peer.put_packet(("%d:%d" % [seed, roll(seed)]).to_utf8_buffer())
	return false
