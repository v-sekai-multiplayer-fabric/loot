# loot

The loot hexagon of the instanced loot-action core loop: a dependency-free core
that rolls drops from a seeded weighted table and resolves first-touch contention,
behind narrow ports, with adapters that bind the engine, the wire, and a recorded
fixture.

It follows the V-Sekai `core/` + `ports/` + `adapters/` triad
([hexagonal decision](https://v-sekai-multiplayer-fabric.github.io/manuals/decisions/20260610-hexagonal-core-ports-adapters.html))
and the [loot hexagon decision](https://v-sekai-multiplayer-fabric.github.io/manuals/decisions/20260611-hexagon-loot-core.html).

## Layout

```
core/        Lean domain logic + lean-slang codegen (the dependency-free core)
ports/       header-only C vtables: *_source (driving) / *_sink (driven)
adapters/    parity (SPIR-V vs golden) and fixture (recorded vectors)
```

## The core

The core is a pure reducer over deterministic state
([core contract](https://v-sekai-multiplayer-fabric.github.io/manuals/decisions/20260611-core-contract-pure-reducer-byte-state.html)):

- `Rng` — a 32-bit xorshift, the exact RNG the SPIR-V kernel runs.
- `Loot` — the weighted seeded `roll`, `rollIndex`, and first-touch `resolve`.
- `Fixed` — Q32.32 fixed point, the Lean stand-in for the host `r128`
  ([r128 Lean library decision](https://v-sekai-multiplayer-fabric.github.io/manuals/decisions/20260612-r128-fixed-point-as-lean-library.html)).
- `Slang` — the loot roll authored in Lean and emitted as a Slang compute kernel
  via [lean-slang](https://github.com/V-Sekai-fire/lean-slang); `slangc -target spirv`
  lowers it to a `.spv`
  ([codegen decision](https://v-sekai-multiplayer-fabric.github.io/manuals/decisions/20260611-core-codegen-lean-slang.html)).

`Main.lean` carries the Plausible properties (membership, exactly-one contention,
first-touch) and `#guard` fixtures. `Emit.lean` writes `kernel.slang` and the
golden vectors.

```sh
cd core
lake exe loot_demo   # Plausible properties + the C-ABI smoke
lake exe loot_emit   # writes build/kernel.slang and build/golden.csv
```

## SPIR-V parity

The Lean spec and the Slang kernel are the same 32-bit algorithm, so the SPIR-V
kernel reproduces the Plausible-verified outputs bit-for-bit. `adapters/parity`
compiles `kernel.slang` to SPIR-V and dispatches it on Vulkan (via
[volk](https://github.com/zeux/volk)), checking every output against the golden
vectors.

```sh
# local Vulkan (lavapipe is deterministic; the RTX 4090 works too)
cd adapters/parity && ./build.sh
slangc kernel.slang -target spirv -profile glsl_450 -entry main -stage compute -o kernel.spv
./parity_runner kernel.spv golden.csv      # -> PARITY PASS on 1024 seeds
```

In a podman quadlet on software Vulkan, no GPU passthrough:

```sh
podman build -t loot-parity -f Containerfile .
podman run --rm loot-parity                # runs the parity on lavapipe
# or install loot-parity.container as a systemd quadlet
```

CI (`.github/workflows/parity.yml`) runs the parity on lavapipe (Linux) and on
MoltenVK (macOS).

## Note on uint64

`lean-slang`'s `Scalar` has no `uint64`, so the kernel and the core both run a
32-bit xorshift to stay bit-exact. Matching the host r128 / 64-bit path needs a
uint64 extension to lean-slang — tracked as the next step.
