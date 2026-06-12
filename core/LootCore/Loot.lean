import LootCore.Rng
import LootCore.Fixed

namespace LootCore
open LootCore.Rng

abbrev Item := Nat
abbrev Weight := Nat
abbrev LootTable := List (Item × Weight)

def totalWeight (t : LootTable) : Nat := t.foldl (fun acc e => acc + e.2) 0

/-- Walk the cumulative weights and return the bucket holding `r`. -/
def pick : LootTable → Nat → Nat → Item
  | [], _, _ => 0
  | (item, w) :: rest, r, acc => if r < acc + w then item else pick rest r (acc + w)

/-- Deterministic seeded roll against a weighted table. -/
def roll (seed : UInt32) (t : LootTable) : Item :=
  let tot := totalWeight t
  if tot == 0 then 0 else pick t (Rng.range seed tot) 0

/-- Cumulative weights — the table layout the Slang kernel reads (`cumw`). -/
def cumulativeOf (t : LootTable) : List Nat :=
  (t.foldl (fun (p : List Nat × Nat) e => (p.1 ++ [p.2 + e.2], p.2 + e.2)) ([], 0)).1

/-- The bucket index the seed rolls into — exactly what the Slang kernel writes. -/
def rollIndex (seed : UInt32) (t : LootTable) : Nat :=
  let tot := totalWeight t
  let r := Rng.range seed tot
  ((cumulativeOf t).findIdx? (fun c => r < c)).getD (t.length - 1)

/-- A loot request: who asked, and the receipt timestamp. -/
abbrev Request := Nat × Nat -- (requester, timestamp)

structure Resolution where
  winner : Nat
  winnerTs : Nat
  rejected : List Nat
  deriving Repr

/-- The request with the smallest receipt timestamp, ties broken by requester id. -/
def winnerEntry (reqs : List Request) : Option Request :=
  reqs.foldl (init := none) fun acc r =>
    match acc with
    | none => some r
    | some b => if r.2 < b.2 || (r.2 == b.2 && r.1 < b.1) then some r else some b

/-- First-touch contention: the earliest receipt wins, the rest are rejected. -/
def resolve (reqs : List Request) : Option Resolution :=
  match winnerEntry reqs with
  | none => none
  | some w => some { winner := w.1, winnerTs := w.2, rejected := (reqs.erase w).map Prod.fst }

/-- Flat C-ABI port: a uniform roll over `nItems` from a 64-bit seed. -/
@[export loot_roll_u32]
def loot_roll_u32 (seed : UInt32) (nItems : UInt32) : UInt32 :=
  if nItems == 0 then 0 else Rng.next32 seed % nItems

end LootCore
