import LootCore
import Plausible
open LootCore.R128L Plausible

def smx (s : UInt64) : UInt64 :=
  let z := s + 0x9E3779B97F4A7C15
  let a := (z ^^^ (z >>> 30)) * 0xBF58476D1CE4E5B9
  let b := (a ^^^ (a >>> 27)) * 0x94D049BB133111EB
  b ^^^ (b >>> 31)

def seedR128 (n : Nat) (k : UInt64) : Q := ⟨smx (n.toUInt64 + k), smx (n.toUInt64 + k + 1)⟩

/-- The uint32-limb algorithm reproduces the UInt64 R128 (bit-exact to r128.c). -/
def limbMatches (n : Nat) : Bool :=
  let a := seedR128 n 0; let b := seedR128 n 1000
  let al := ofR128 a; let bl := ofR128 b
  (toR128 (add al bl) == LootCore.R128.add a b)
  && (toR128 (negL al) == LootCore.R128.neg a)
  && (toR128 (mul al bl) == LootCore.R128.mul a b)

#eval Testable.check (∀ n : Nat, limbMatches n = true)

def main : IO Unit := do
  let mut bad := 0
  for n in [0:50000] do
    if limbMatches n then pure () else bad := bad + 1
  IO.println s!"uint32-limb R128L == UInt64 R128 (== r128.c): {50000 - bad}/50000 match, {bad} mismatches"
