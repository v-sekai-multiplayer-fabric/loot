extends SceneTree
var GOLDEN: String = OS.get_environment("CONT_GOLDEN")
var MY_ID: int = int(OS.get_environment("PLAYER_ID"))
var peer: WebTransportPeer
var my_ts := {}; var winners := {}
var got := 0; var sent := false; var t0 := 0

func _init():
	var f = FileAccess.open(GOLDEN, FileAccess.READ)
	f.get_line()
	while not f.eof_reached():
		var p = f.get_line().split(",")
		if p.size() == 6:
			my_ts[int(p[0])] = int(p[MY_ID])
			winners[int(p[0])] = int(p[5])
	peer = WebTransportPeer.new()
	if peer.create_client("127.0.0.1", 54373, "/wt") != OK:
		printerr("client create failed"); quit(1)
	t0 = Time.get_ticks_msec()

func _process(_d: float) -> bool:
	if not peer: return false
	peer.poll()
	if Time.get_ticks_msec() - t0 > 45000:
		printerr("TIMEOUT player=", MY_ID, " got=", got); quit(1); return false
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if not sent:
			sent = true
			for rnd in my_ts:
				peer.put_packet(("%d:%d:%d" % [rnd, MY_ID, my_ts[rnd]]).to_utf8_buffer())
		while peer.get_available_packet_count() > 0:
			var p = peer.get_packet().get_string_from_utf8().split(":")
			var rnd := int(p[0]); var w := int(p[1])
			if winners[rnd] != w:
				printerr("MISMATCH player=", MY_ID, " round=", rnd, " wire=", w, " golden=", winners[rnd])
				quit(1); return false
			got += 1
			if got == winners.size():
				print("P", MY_ID, " PASS: ", got, " per-client winner announcements match the Lean golden")
				quit(0)
	return false
