# fixture adapter

The recorded fixtures that drive the core with no engine and no device:

- `../parity/golden.csv` — the Plausible-verified `(seed, bucket index)` outputs of
  the Lean reducer for the canonical table `[(101,50),(202,30),(303,20)]`.
- `../parity/kernel.slang` — the lean-slang-emitted compute kernel.

CI replays these through the core's `ctypes` spec (Plausible properties in
`../../core/Main.lean`) and through the SPIR-V parity runner.
