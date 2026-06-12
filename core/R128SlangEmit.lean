import LootCore
def main : IO Unit := do
  IO.FS.createDirAll "build"
  IO.FS.writeFile "build/r128_mul_gen.slang" LootCore.R128Slang.slang
  IO.println "wrote build/r128_mul_gen.slang"
