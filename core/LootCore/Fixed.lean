namespace LootCore.Fixed

/-- Q32.32 fixed point, Int-backed. The Lean stand-in for the host `r128`
    (`thirdparty/misc/r128`); the cores avoid floating point for determinism. -/
abbrev shift : Int := 4294967296 -- 2^32

structure Fx where
  raw : Int
  deriving DecidableEq, Repr

def ofInt (n : Int) : Fx := ⟨n * shift⟩
def ofRatio (n d : Int) : Fx := ⟨n * shift / d⟩
def one : Fx := ⟨shift⟩
def zero : Fx := ⟨0⟩
def lt (a b : Fx) : Bool := a.raw < b.raw
def add (a b : Fx) : Fx := ⟨a.raw + b.raw⟩
def mul (a b : Fx) : Fx := ⟨a.raw * b.raw / shift⟩

end LootCore.Fixed
