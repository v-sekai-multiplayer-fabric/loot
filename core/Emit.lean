import LootCore
open LootCore

def table : LootTable := [(101, 50), (202, 30), (303, 20)]

def main : IO Unit := do
  IO.FS.createDirAll "build"
  IO.FS.writeFile "build/kernel.slang" LootCore.Slang.lootRollSlang
  let mut out := "seed,index\n"
  for seed in [0:1024] do
    out := out ++ s!"{seed},{rollIndex (UInt32.ofNat seed) table}\n"
  IO.FS.writeFile "build/golden.csv" out
  IO.println s!"wrote build/kernel.slang + build/golden.csv (1024 rows); cumw={cumulativeOf table}"
