# r128 parity adapter

Differential test of the Lean `R128` (`core/LootCore/R128.lean`) against the
host `r128` (fahickman/r128, vendored at `thirdparty/misc/r128`). `R128` is a
bit-faithful port of r128's portable STDC path — same `lo`/`hi` representation,
same round-to-nearest multiply — so the host C and the Lean core agree
bit-for-bit, and the same algorithm lowers to a uint32-limb SPIR-V kernel.

```sh
./build.sh
( cd ../../core && lake exe r128_diff ) > vectors.csv
./r128_oracle vectors.csv     # -> R128 PARITY PASS over add/sub/neg/mul/cmp/shl/shr
```

Verified: 8,200 vectors x 7 ops, zero mismatches.
