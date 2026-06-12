namespace LootCore.R128

/-- Signed Q64.64 fixed point, 128-bit, as `lo`/`hi` `UInt64` limbs. This is a
    bit-faithful port of the vendored `thirdparty/misc/r128` (fahickman/r128) in
    its portable STDC path, so the host C `r128` and this Lean version agree
    bit-for-bit. The same algorithm lowers to a uint32-limb SPIR-V kernel. -/
structure R128 where
  lo : UInt64
  hi : UInt64
  deriving DecidableEq, Repr, Inhabited

@[inline] def not64 (a : UInt64) : UInt64 := a ^^^ 0xFFFFFFFFFFFFFFFF

/-- 128-bit add with carry. -/
def add (a b : R128) : R128 :=
  let lo := a.lo + b.lo
  let carry : UInt64 := if lo < a.lo then 1 else 0
  ⟨lo, a.hi + b.hi + carry⟩

/-- Two's-complement negation. -/
def neg (a : R128) : R128 := add ⟨not64 a.lo, not64 a.hi⟩ ⟨1, 0⟩

def sub (a b : R128) : R128 := add a (neg b)

def isNeg (a : R128) : Bool := (a.hi >>> 63) != 0

/-- 64x64 -> 128 unsigned product (`r128__umul128`, STDC path). -/
def umul128 (a b : UInt64) : R128 :=
  let alo := a.toUInt32; let ahi := (a >>> 32).toUInt32
  let blo := b.toUInt32; let bhi := (b >>> 32).toUInt32
  let p0 := alo.toUInt64 * blo.toUInt64
  let p1 := alo.toUInt64 * bhi.toUInt64
  let p2 := ahi.toUInt64 * blo.toUInt64
  let p3 := ahi.toUInt64 * bhi.toUInt64
  let carry := (p1.toUInt32.toUInt64 + p2.toUInt32.toUInt64 + (p0 >>> 32)) >>> 32
  let lo := p0 + ((p1 + p2) <<< 32)
  let hi := p3 + ((p1 >>> 32).toUInt32 + (p2 >>> 32).toUInt32).toUInt64 + carry
  ⟨lo, hi⟩

/-- Unsigned Q64.64 multiply with round-to-nearest at bit 64 (`r128__umul`). -/
def umul (a b : R128) : R128 :=
  let q0 := umul128 a.lo b.lo
  let round : R128 := ⟨q0.lo >>> 63, 0⟩
  let acc := add ⟨q0.hi, 0⟩ round
  let acc := add acc (umul128 a.hi b.lo)
  let acc := add acc (umul128 a.lo b.hi)
  let p3 := umul128 a.hi b.hi
  add acc ⟨0, p3.lo⟩

/-- Signed Q64.64 multiply (`r128Mul`). -/
def mul (a b : R128) : R128 :=
  let sa := isNeg a; let sb := isNeg b
  let ta := if sa then neg a else a
  let tb := if sb then neg b else b
  let tc := umul ta tb
  if sa != sb then neg tc else tc

/-- Signed compare: returns -1, 0, or 1 (sign of `a - b`). -/
def cmp (a b : R128) : Int :=
  let na := isNeg a; let nb := isNeg b
  if na && !nb then -1
  else if !na && nb then 1
  else if a.hi != b.hi then (if a.hi < b.hi then -1 else 1)
  else if a.lo != b.lo then (if a.lo < b.lo then -1 else 1)
  else 0

/-- Logical left shift by `n mod 128`. -/
def shl (a : R128) (n : Nat) : R128 :=
  let n := n % 128
  if n == 0 then a
  else if n < 64 then
    let m := (UInt64.ofNat n)
    ⟨a.lo <<< m, (a.hi <<< m) ||| (a.lo >>> (64 - m))⟩
  else
    ⟨0, a.lo <<< (UInt64.ofNat (n - 64))⟩

/-- Logical right shift by `n mod 128`. -/
def shr (a : R128) (n : Nat) : R128 :=
  let n := n % 128
  if n == 0 then a
  else if n < 64 then
    let m := (UInt64.ofNat n)
    ⟨(a.lo >>> m) ||| (a.hi <<< (64 - m)), a.hi >>> m⟩
  else
    ⟨a.hi >>> (UInt64.ofNat (n - 64)), 0⟩

/-- An integer in Q64.64 (`r128FromInt` for the in-range case). -/
def ofInt (v : Int) : R128 := ⟨0, (Int.toNat (v % (2^64))).toUInt64⟩

def one : R128 := ⟨0, 1⟩
def zero : R128 := ⟨0, 0⟩

end LootCore.R128
