import LeanSlang.Types
import LeanSlang.AST
import LeanSlang.Emit
open LeanSlang

namespace LootCore.Slang

/-- The loot roll, authored in Lean and emitted as a Slang compute kernel.
    Per thread: a 32-bit xorshift RNG over the seed, then a weighted pick across
    the cumulative-weight table (unrolled for N = 3). `slangc -target spirv`
    lowers this to a `.spv` the runtime dispatches behind the flat C ABI.

    Note: lean-slang's `Scalar` has no `uint64`, so this kernel uses a 32-bit
    xorshift. Bit-exact parity with the host r128/UInt64 path needs a uint64
    extension to lean-slang. -/
def lootRollKernel : SlangShaderModule :=
  { globals :=
      [ ⟨"seeds",    .roBuf (.scalar .uint), Semantic.none, some 0, some 0, .qIn⟩
      , ⟨"cumw",     .roBuf (.scalar .uint), Semantic.none, some 1, some 0, .qIn⟩
      , ⟨"outRolls", .rwBuf (.scalar .uint), Semantic.none, some 2, some 0, .qIn⟩ ]
  , functions := [{
      attrs  := [.shaderCompute, .numthreads 64 1 1]
      name   := "main"
      params := [⟨"tid", .vec .uint 3, .svDispatchThreadId, none, none, .qIn⟩]
      body   :=
        [ .declare (.scalar .uint) "i" (some (.member (.var "tid") "x"))
        , .declare (.scalar .uint) "s" (some (.index (.var "seeds") (.var "i")))
        , .assign (.var "s") (.bin "^" (.var "s") (.bin "<<" (.var "s") (.litUint 13)))
        , .assign (.var "s") (.bin "^" (.var "s") (.bin ">>" (.var "s") (.litUint 17)))
        , .assign (.var "s") (.bin "^" (.var "s") (.bin "<<" (.var "s") (.litUint 5)))
        , .declare (.scalar .uint) "total" (some (.index (.var "cumw") (.litUint 2)))
        , .declare (.scalar .uint) "r" (some (.bin "%" (.var "s") (.var "total")))
        , .declare (.scalar .uint) "item"
            (some (.ternary (.bin "<" (.var "r") (.index (.var "cumw") (.litUint 0)))
              (.litUint 0)
              (.ternary (.bin "<" (.var "r") (.index (.var "cumw") (.litUint 1)))
                (.litUint 1) (.litUint 2))))
        , .assign (.index (.var "outRolls") (.var "i")) (.var "item")
        , .ret none ]
    }] }

/-- The emitted Slang source for the loot roll kernel. -/
def lootRollSlang : String := LeanSlang.emit lootRollKernel

end LootCore.Slang
