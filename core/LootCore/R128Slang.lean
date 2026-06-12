import LeanSlang.Types
import LeanSlang.AST
import LeanSlang.Emit
open LeanSlang

/- The r128 signed Q64.64 multiply, authored in Lean and emitted as a Slang
    compute kernel via lean-slang. A 1:1 build of `LootCore.R128L` (proven
    bit-exact to the host r128). `slangc -target spirv` lowers it to the `.spv`
    the GPU parity runner checks against `r128.c`. -/
namespace LootCore.R128Slang

private def U : SlangType := .named "U128"
private def uT : SlangType := .scalar .uint
private def bT : SlangType := .scalar .bool
private def u (n : Nat) : SlangExpr := .litUint n
private def vr (s : String) : SlangExpr := .var s
private def fld (r f : String) : SlangExpr := .member (.var r) f
private def bn (op : String) (l r : SlangExpr) : SlangExpr := .bin op l r
private def un (op : String) (e : SlangExpr) : SlangExpr := .un op e
private def cl (f : String) (a : List SlangExpr) : SlangExpr := .call f a
private def tn (c t f : SlangExpr) : SlangExpr := .ternary c t f
private def lt (l r : SlangExpr) : SlangExpr := bn "<" l r
private def carry (s a : String) : SlangExpr := tn (lt (vr s) (vr a)) (u 1) (u 0)
private def dcl (t : SlangType) (n : String) (e : SlangExpr) : SlangStmt := .declare t n (some e)
private def dclN (t : SlangType) (n : String) : SlangStmt := .declare t n none
private def st (l r : SlangExpr) : SlangStmt := .assign l r
private def rt (e : SlangExpr) : SlangStmt := .ret (some e)
private def par (n : String) (t : SlangType) : SlangBinding := { name := n, type := t }
private def idx (buf : String) (i : SlangExpr) : SlangExpr := .index (.var buf) i
private def ix4 (base : String) (i k : Nat) : SlangExpr :=
  idx base (bn "+" (bn "*" (vr "i") (u 4)) (u k))

private def fMkU128 : SlangFunctionDecl :=
  { retType := U, name := "mkU128", params := [par "w0" uT, par "w1" uT, par "w2" uT, par "w3" uT],
    body := [ dclN U "r", st (fld "r" "w0") (vr "w0"), st (fld "r" "w1") (vr "w1"),
              st (fld "r" "w2") (vr "w2"), st (fld "r" "w3") (vr "w3"), rt (vr "r") ] }

private def fMulhi : SlangFunctionDecl :=
  { retType := uT, name := "mulhi", params := [par "a" uT, par "b" uT],
    body := [
      dcl uT "a0" (bn "&" (vr "a") (u 0xFFFF)), dcl uT "a1" (bn ">>" (vr "a") (u 16)),
      dcl uT "b0" (bn "&" (vr "b") (u 0xFFFF)), dcl uT "b1" (bn ">>" (vr "b") (u 16)),
      dcl uT "p00" (bn "*" (vr "a0") (vr "b0")), dcl uT "p01" (bn "*" (vr "a0") (vr "b1")),
      dcl uT "p10" (bn "*" (vr "a1") (vr "b0")), dcl uT "p11" (bn "*" (vr "a1") (vr "b1")),
      dcl uT "mid" (bn "+" (bn "+" (bn ">>" (vr "p00") (u 16)) (bn "&" (vr "p01") (u 0xFFFF))) (bn "&" (vr "p10") (u 0xFFFF))),
      rt (bn "+" (bn "+" (bn "+" (vr "p11") (bn ">>" (vr "p01") (u 16))) (bn ">>" (vr "p10") (u 16))) (bn ">>" (vr "mid") (u 16))) ] }

private def fAdd128 : SlangFunctionDecl :=
  { retType := U, name := "add128", params := [par "a" U, par "b" U],
    body := [
      dcl uT "s0" (bn "+" (fld "a" "w0") (fld "b" "w0")), dcl uT "k0" (tn (lt (vr "s0") (fld "a" "w0")) (u 1) (u 0)),
      dcl uT "s1" (bn "+" (fld "a" "w1") (fld "b" "w1")), dcl uT "k1" (tn (lt (vr "s1") (fld "a" "w1")) (u 1) (u 0)),
      dcl uT "t1" (bn "+" (vr "s1") (vr "k0")), st (vr "k1") (bn "+" (vr "k1") (tn (lt (vr "t1") (vr "s1")) (u 1) (u 0))),
      dcl uT "s2" (bn "+" (fld "a" "w2") (fld "b" "w2")), dcl uT "k2" (tn (lt (vr "s2") (fld "a" "w2")) (u 1) (u 0)),
      dcl uT "t2" (bn "+" (vr "s2") (vr "k1")), st (vr "k2") (bn "+" (vr "k2") (tn (lt (vr "t2") (vr "s2")) (u 1) (u 0))),
      dcl uT "s3" (bn "+" (bn "+" (fld "a" "w3") (fld "b" "w3")) (vr "k2")),
      rt (cl "mkU128" [vr "s0", vr "t1", vr "t2", vr "s3"]) ] }

private def fNegU : SlangFunctionDecl :=
  { retType := U, name := "negU", params := [par "a" U],
    body := [ rt (cl "add128"
        [ cl "mkU128" [un "~" (fld "a" "w0"), un "~" (fld "a" "w1"), un "~" (fld "a" "w2"), un "~" (fld "a" "w3")],
          cl "mkU128" [u 1, u 0, u 0, u 0] ]) ] }

private def fUmul64 : SlangFunctionDecl :=
  { retType := U, name := "umul64x64", params := [par "a0" uT, par "a1" uT, par "b0" uT, par "b1" uT],
    body := [
      dcl uT "l00" (bn "*" (vr "a0") (vr "b0")), dcl uT "h00" (cl "mulhi" [vr "a0", vr "b0"]),
      dcl uT "l01" (bn "*" (vr "a0") (vr "b1")), dcl uT "h01" (cl "mulhi" [vr "a0", vr "b1"]),
      dcl uT "l10" (bn "*" (vr "a1") (vr "b0")), dcl uT "h10" (cl "mulhi" [vr "a1", vr "b0"]),
      dcl uT "l11" (bn "*" (vr "a1") (vr "b1")), dcl uT "h11" (cl "mulhi" [vr "a1", vr "b1"]),
      dcl uT "r0" (vr "l00"),
      dcl uT "s" (bn "+" (vr "h00") (vr "l01")),
      dcl uT "c" (tn (lt (vr "s") (vr "h00")) (u 1) (u 0)),
      dcl uT "s2" (bn "+" (vr "s") (vr "l10")),
      st (vr "c") (bn "+" (vr "c") (tn (lt (vr "s2") (vr "s")) (u 1) (u 0))),
      dcl uT "r1" (vr "s2"), dcl uT "carryC" (vr "c"),
      dcl uT "w" (bn "+" (vr "h01") (vr "h10")),
      dcl uT "s3" (bn "+" (vr "l11") (vr "w")),
      dcl uT "c2" (tn (lt (vr "s3") (vr "l11")) (u 1) (u 0)),
      dcl uT "s4" (bn "+" (vr "s3") (vr "carryC")),
      st (vr "c2") (bn "+" (vr "c2") (tn (lt (vr "s4") (vr "s3")) (u 1) (u 0))),
      dcl uT "r2" (vr "s4"), dcl uT "r3" (bn "+" (vr "h11") (vr "c2")),
      rt (cl "mkU128" [vr "r0", vr "r1", vr "r2", vr "r3"]) ] }

private def fUmul : SlangFunctionDecl :=
  { retType := U, name := "umul", params := [par "a" U, par "b" U],
    body := [
      dcl U "p0" (cl "umul64x64" [fld "a" "w0", fld "a" "w1", fld "b" "w0", fld "b" "w1"]),
      dcl uT "roundbit" (bn ">>" (fld "p0" "w1") (u 31)),
      dcl U "acc" (cl "mkU128" [fld "p0" "w2", fld "p0" "w3", u 0, u 0]),
      st (vr "acc") (cl "add128" [vr "acc", cl "mkU128" [vr "roundbit", u 0, u 0, u 0]]),
      st (vr "acc") (cl "add128" [vr "acc", cl "umul64x64" [fld "a" "w2", fld "a" "w3", fld "b" "w0", fld "b" "w1"]]),
      st (vr "acc") (cl "add128" [vr "acc", cl "umul64x64" [fld "a" "w0", fld "a" "w1", fld "b" "w2", fld "b" "w3"]]),
      dcl U "p3" (cl "umul64x64" [fld "a" "w2", fld "a" "w3", fld "b" "w2", fld "b" "w3"]),
      rt (cl "add128" [vr "acc", cl "mkU128" [u 0, u 0, fld "p3" "w0", fld "p3" "w1"]]) ] }

private def fMul : SlangFunctionDecl :=
  { retType := U, name := "mulR128", params := [par "a" U, par "b" U],
    body := [
      dcl bT "sa" (bn "!=" (bn ">>" (fld "a" "w3") (u 31)) (u 0)),
      dcl bT "sb" (bn "!=" (bn ">>" (fld "b" "w3") (u 31)) (u 0)),
      dcl U "ta" (tn (vr "sa") (cl "negU" [vr "a"]) (vr "a")),
      dcl U "tb" (tn (vr "sb") (cl "negU" [vr "b"]) (vr "b")),
      dcl U "tc" (cl "umul" [vr "ta", vr "tb"]),
      rt (tn (bn "!=" (vr "sa") (vr "sb")) (cl "negU" [vr "tc"]) (vr "tc")) ] }

private def fMain : SlangFunctionDecl :=
  { attrs := [.shaderCompute, .numthreads 64 1 1], name := "main",
    params := [⟨"tid", .vec .uint 3, .svDispatchThreadId, none, none, .qIn⟩],
    body := [
      dcl uT "i" (fld "tid" "x"),
      dcl U "a" (cl "mkU128" [ix4 "A" 0 0, ix4 "A" 0 1, ix4 "A" 0 2, ix4 "A" 0 3]),
      dcl U "b" (cl "mkU128" [ix4 "B" 0 0, ix4 "B" 0 1, ix4 "B" 0 2, ix4 "B" 0 3]),
      dcl U "r" (cl "mulR128" [vr "a", vr "b"]),
      st (ix4 "OUT" 0 0) (fld "r" "w0"), st (ix4 "OUT" 0 1) (fld "r" "w1"),
      st (ix4 "OUT" 0 2) (fld "r" "w2"), st (ix4 "OUT" 0 3) (fld "r" "w3"),
      .ret none ] }

def module : SlangShaderModule :=
  { structs := [{ name := "U128", fields := [par "w0" uT, par "w1" uT, par "w2" uT, par "w3" uT] }]
  , globals :=
      [ ⟨"A",   .roBuf (.scalar .uint), Semantic.none, some 0, some 0, .qIn⟩
      , ⟨"B",   .roBuf (.scalar .uint), Semantic.none, some 1, some 0, .qIn⟩
      , ⟨"OUT", .rwBuf (.scalar .uint), Semantic.none, some 2, some 0, .qIn⟩ ]
  , functions := [fMkU128, fMulhi, fAdd128, fNegU, fUmul64, fUmul, fMul, fMain] }

def slang : String := LeanSlang.emit module

end LootCore.R128Slang
