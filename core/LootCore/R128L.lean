import LootCore.R128
namespace LootCore.R128L

/-- Q64.64 over four `UInt32` limbs (`w0` least significant). This is the exact
    algorithm the SPIR-V kernel runs: no `UInt64` anywhere, so it lowers through
    lean-slang to a uint32 GPU kernel. Proven equal to the `UInt64` `R128` (which
    is proven equal to the host `r128.c`). -/
structure R128L where
  w0 : UInt32
  w1 : UInt32
  w2 : UInt32
  w3 : UInt32
  deriving DecidableEq, Repr, Inhabited

abbrev Q := LootCore.R128.R128

def toR128 (x : R128L) : Q :=
  ⟨x.w0.toUInt64 ||| (x.w1.toUInt64 <<< 32), x.w2.toUInt64 ||| (x.w3.toUInt64 <<< 32)⟩

def ofR128 (x : Q) : R128L :=
  ⟨x.lo.toUInt32, (x.lo >>> 32).toUInt32, x.hi.toUInt32, (x.hi >>> 32).toUInt32⟩

/-- Low 32 of a 32x32 product. -/
@[inline] def mullo (a b : UInt32) : UInt32 := a * b

/-- High 32 of a 32x32 product, via a 16-bit split — pure uint32, GPU-portable. -/
def mulhi (a b : UInt32) : UInt32 :=
  let a0 := a &&& 0xFFFF; let a1 := a >>> 16
  let b0 := b &&& 0xFFFF; let b1 := b >>> 16
  let p00 := a0 * b0; let p01 := a0 * b1
  let p10 := a1 * b0; let p11 := a1 * b1
  let mid := (p00 >>> 16) + (p01 &&& 0xFFFF) + (p10 &&& 0xFFFF)
  p11 + (p01 >>> 16) + (p10 >>> 16) + (mid >>> 16)

/-- Sum a list of uint32, returning (low 32, carry count). -/
def sum32 (xs : List UInt32) : UInt32 × UInt32 :=
  xs.foldl (fun (p : UInt32 × UInt32) x =>
    let s := p.1 + x
    (s, if s < p.1 then p.2 + 1 else p.2)) (0, 0)

/-- 128-bit add (four limbs with carry). -/
def add (a b : R128L) : R128L :=
  let (r0, c0) := sum32 [a.w0, b.w0]
  let (r1, c1) := sum32 [a.w1, b.w1, c0]
  let (r2, c2) := sum32 [a.w2, b.w2, c1]
  let (r3, _)  := sum32 [a.w3, b.w3, c2]
  ⟨r0, r1, r2, r3⟩

def notL (a : R128L) : R128L :=
  ⟨a.w0 ^^^ 0xFFFFFFFF, a.w1 ^^^ 0xFFFFFFFF, a.w2 ^^^ 0xFFFFFFFF, a.w3 ^^^ 0xFFFFFFFF⟩

def negL (a : R128L) : R128L := add (notL a) ⟨1, 0, 0, 0⟩

def isNegL (a : R128L) : Bool := (a.w3 >>> 31) != 0

/-- 64x64 -> 128 unsigned product as four limbs (a = (a0,a1), b = (b0,b1)). -/
def umul64x64 (a0 a1 b0 b1 : UInt32) : R128L :=
  let l00 := mullo a0 b0; let h00 := mulhi a0 b0
  let l01 := mullo a0 b1; let h01 := mulhi a0 b1
  let l10 := mullo a1 b0; let h10 := mulhi a1 b0
  let l11 := mullo a1 b1; let h11 := mulhi a1 b1
  let r0 := l00
  let (r1, carryC) := sum32 [h00, l01, l10]
  -- r128 adds high32(p1)+high32(p2) as a wrapped uint32 (carry discarded), matching
  -- C's `(R128_U32)+(R128_U32)`; replicate that exactly.
  let w := h01 + h10
  let (r2, c2) := sum32 [l11, w, carryC]
  let r3 := h11 + c2
  ⟨r0, r1, r2, r3⟩

/-- Unsigned Q64.64 multiply with round-to-nearest at bit 64 (the `r128__umul`
    accumulation, limb form). -/
def umul (a b : R128L) : R128L :=
  let p0 := umul64x64 a.w0 a.w1 b.w0 b.w1
  let roundbit : UInt32 := p0.w1 >>> 31
  let acc := add ⟨p0.w2, p0.w3, 0, 0⟩ ⟨roundbit, 0, 0, 0⟩
  let acc := add acc (umul64x64 a.w2 a.w3 b.w0 b.w1)
  let acc := add acc (umul64x64 a.w0 a.w1 b.w2 b.w3)
  let p3 := umul64x64 a.w2 a.w3 b.w2 b.w3
  add acc ⟨0, 0, p3.w0, p3.w1⟩

/-- Signed Q64.64 multiply (`r128Mul`, limb form). -/
def mul (a b : R128L) : R128L :=
  let sa := isNegL a; let sb := isNegL b
  let ta := if sa then negL a else a
  let tb := if sb then negL b else b
  let tc := umul ta tb
  if sa != sb then negL tc else tc

end LootCore.R128L
