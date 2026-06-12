# godot adapter

The loot hexagon on the wire: a server-authoritative roll inside the merged
double-precision Godot build (all `feat/*` modules assembled by
[merge](https://github.com/v-sekai-multiplayer-fabric/merge)), carried over
WebTransport/QUIC (`feat/module-http3`), and verified end to end against the
Lean core's golden vectors.

- `loot_server.gd` — a headless zone stand-in: builds its cert, listens with
  `WebTransportPeer.create_server`, and answers each seed with the proven
  xorshift32 + cumulative-weight roll (the algorithm of `core/LootCore/Loot.lean`).
- `loot_client.gd` — sends seeds over the wire and asserts every reply against
  `core` golden vectors (`lake exe loot_emit` writes them).

```sh
GODOT=bin/godot.linuxbsd.editor.double.x86_64   # merged build
$GODOT --headless --script loot_server.gd &
$GODOT --headless --script loot_client.gd
# -> LOOT WIRE PARITY PASS: 256 server-authoritative rolls match the Lean golden vectors
```

Verified with Godot 4.7.beta double (merged `multiplayer-fabric` assembly): the
transport echo demo passes, OpenXR initializes against headless Monado, and the
loot rolls match the Lean core bit-for-bit across the wire.
