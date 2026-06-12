import LootCore
import Plausible
open LootCore Plausible

/-- A fixed nonempty table with positive weights. -/
def table : LootTable := [(101, 50), (202, 30), (303, 20)]
def itemIds : List Nat := table.map Prod.fst

-- Deterministic fixtures: these fail the build if false.
#guard (roll 12345 table) ∈ itemIds
#guard (resolve [(7, 5), (3, 2), (9, 5)]).map (·.winner) = some 3
#guard (resolve [(7, 5), (3, 2), (9, 5)]).map (·.rejected.length) = some 2
#guard LootCore.Fixed.lt (LootCore.Fixed.ofRatio 1 4) (LootCore.Fixed.ofRatio 1 2)

def checkMembership (seed : Nat) : Bool := decide (roll (UInt32.ofNat seed) table ∈ itemIds)

def checkExactlyOne (reqs : List Request) : Bool :=
  match resolve reqs with
  | none => reqs.isEmpty
  | some res => res.rejected.length + 1 == reqs.length

def checkFirstTouch (reqs : List Request) : Bool :=
  match resolve reqs with
  | none => true
  | some res => reqs.all (fun r => decide (res.winnerTs ≤ r.2))

-- Plausible properties (run at build via #eval; print Success or a counterexample).
#eval Testable.check (∀ seed : Nat, checkMembership seed = true)
#eval Testable.check (∀ reqs : List Request, checkExactlyOne reqs = true)
#eval Testable.check (∀ reqs : List Request, checkFirstTouch reqs = true)

def main : IO Unit := do
  IO.println s!"C-ABI loot_roll_u32 12345 3 = {loot_roll_u32 12345 3}"
  IO.println "loot core: built, fixtures guarded, properties checked"
  IO.println "-- emitted Slang (lean-slang, lowers via slangc -target spirv) --"
  IO.println LootCore.Slang.lootRollSlang
