namespace LootCore.Rng

/-- Deterministic xorshift32. This is the exact RNG the Slang kernel runs, so the
    Lean spec and the SPIR-V kernel agree bit-for-bit (lean-slang has no uint64,
    so the whole core stays 32-bit for parity). -/
def next32 (s : UInt32) : UInt32 :=
  let s := s ^^^ (s <<< 13)
  let s := s ^^^ (s >>> 17)
  let s := s ^^^ (s <<< 5)
  s

/-- A pseudo-random `Nat` in `[0, bound)` from a 32-bit seed (`bound = 0` gives 0). -/
def range (seed : UInt32) (bound : Nat) : Nat :=
  if bound == 0 then 0 else (next32 seed).toNat % bound

end LootCore.Rng
