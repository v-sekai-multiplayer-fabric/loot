import LootCore
open LootCore.R128

/-- splitmix64 for deterministic test vectors. -/
def sm (s : UInt64) : UInt64 × UInt64 :=
  let z := s + 0x9E3779B97F4A7C15
  let a := (z ^^^ (z >>> 30)) * 0xBF58476D1CE4E5B9
  let b := (a ^^^ (a >>> 27)) * 0x94D049BB133111EB
  (z, b ^^^ (b >>> 31))

def row (a b : R128) (amt : Nat) : String :=
  let r := add a b; let s := sub a b; let ng := neg a
  let m := mul a b; let c := cmp a b; let sl := shl a amt; let sr := shr a amt
  s!"{a.lo},{a.hi},{b.lo},{b.hi},{amt},{r.lo},{r.hi},{s.lo},{s.hi},{ng.lo},{ng.hi},{m.lo},{m.hi},{c},{sl.lo},{sl.hi},{sr.lo},{sr.hi}"

def edges : List (R128 × R128 × Nat) :=
  [ (⟨0,0⟩, ⟨0,0⟩, 0), (one, one, 1), (one, ofInt 5, 7),
    (⟨0xFFFFFFFFFFFFFFFF,0xFFFFFFFFFFFFFFFF⟩, one, 1),
    (⟨0,0x8000000000000000⟩, ⟨0,2⟩, 63),
    (⟨0xFFFFFFFFFFFFFFFF,0⟩, ⟨0xFFFFFFFFFFFFFFFF,0⟩, 32),
    (ofInt 3, ofInt (-7), 64), (neg one, neg one, 100) ]

def main : IO Unit := do
  IO.println "a_lo,a_hi,b_lo,b_hi,amt,add_lo,add_hi,sub_lo,sub_hi,neg_lo,neg_hi,mul_lo,mul_hi,cmp,shl_lo,shl_hi,shr_lo,shr_hi"
  for e in edges do
    let (a, b, amt) := e
    IO.println (row a b amt)
  let mut s : UInt64 := 0x1234567
  for _ in [0:8192] do
    let (s1, alo) := sm s; let (s2, ahi) := sm s1
    let (s3, blo) := sm s2; let (s4, bhi) := sm s3
    let (s5, amtR) := sm s4; s := s5
    IO.println (row ⟨alo,ahi⟩ ⟨blo,bhi⟩ (amtR.toNat % 128))
