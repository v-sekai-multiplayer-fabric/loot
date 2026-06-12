// r128 signed Q64.64 multiply on the GPU, a 1:1 transcription of LootCore.R128L
// (proven bit-exact to the host r128.c). Pure uint32 — no uint64 — so it lowers
// to SPIR-V for any conformant device.
struct U128 { uint w0; uint w1; uint w2; uint w3; };

uint mulhi(uint a, uint b) {
  uint a0 = a & 0xFFFFu, a1 = a >> 16, b0 = b & 0xFFFFu, b1 = b >> 16;
  uint p00 = a0*b0, p01 = a0*b1, p10 = a1*b0, p11 = a1*b1;
  uint mid = (p00 >> 16) + (p01 & 0xFFFFu) + (p10 & 0xFFFFu);
  return p11 + (p01 >> 16) + (p10 >> 16) + (mid >> 16);
}

U128 add128(U128 a, U128 b) {
  uint s0 = a.w0 + b.w0; uint k0 = (s0 < a.w0) ? 1u : 0u;
  uint s1 = a.w1 + b.w1; uint k1 = (s1 < a.w1) ? 1u : 0u; uint t1 = s1 + k0; k1 += (t1 < s1) ? 1u : 0u;
  uint s2 = a.w2 + b.w2; uint k2 = (s2 < a.w2) ? 1u : 0u; uint t2 = s2 + k1; k2 += (t2 < s2) ? 1u : 0u;
  uint s3 = a.w3 + b.w3 + k2;
  U128 r = { s0, t1, t2, s3 }; return r;
}

U128 negU(U128 a) {
  U128 n = { ~a.w0, ~a.w1, ~a.w2, ~a.w3 };
  U128 one = { 1u, 0u, 0u, 0u };
  return add128(n, one);
}

U128 umul64x64(uint a0, uint a1, uint b0, uint b1) {
  uint l00 = a0*b0, h00 = mulhi(a0,b0);
  uint l01 = a0*b1, h01 = mulhi(a0,b1);
  uint l10 = a1*b0, h10 = mulhi(a1,b0);
  uint l11 = a1*b1, h11 = mulhi(a1,b1);
  uint r0 = l00;
  uint s = h00 + l01; uint c = (s < h00) ? 1u : 0u; uint s2 = s + l10; c += (s2 < s) ? 1u : 0u;
  uint r1 = s2; uint carryC = c;
  uint w = h01 + h10;
  uint s3 = l11 + w; uint c2 = (s3 < l11) ? 1u : 0u; uint s4 = s3 + carryC; c2 += (s4 < s3) ? 1u : 0u;
  uint r2 = s4; uint r3 = h11 + c2;
  U128 res = { r0, r1, r2, r3 }; return res;
}

U128 umul(U128 a, U128 b) {
  U128 p0 = umul64x64(a.w0, a.w1, b.w0, b.w1);
  uint roundbit = p0.w1 >> 31;
  U128 acc = { p0.w2, p0.w3, 0u, 0u };
  U128 rnd = { roundbit, 0u, 0u, 0u };
  acc = add128(acc, rnd);
  acc = add128(acc, umul64x64(a.w2, a.w3, b.w0, b.w1));
  acc = add128(acc, umul64x64(a.w0, a.w1, b.w2, b.w3));
  U128 p3 = umul64x64(a.w2, a.w3, b.w2, b.w3);
  U128 p3s = { 0u, 0u, p3.w0, p3.w1 };
  return add128(acc, p3s);
}

U128 mulR128(U128 a, U128 b) {
  bool sa = (a.w3 >> 31) != 0u; bool sb = (b.w3 >> 31) != 0u;
  U128 ta = sa ? negU(a) : a;
  U128 tb = sb ? negU(b) : b;
  U128 tc = umul(ta, tb);
  return (sa != sb) ? negU(tc) : tc;
}

[[vk::binding(0,0)]] StructuredBuffer<uint> A;
[[vk::binding(1,0)]] StructuredBuffer<uint> B;
[[vk::binding(2,0)]] RWStructuredBuffer<uint> OUT;

[shader("compute")] [numthreads(64,1,1)]
void main(uint3 tid : SV_DispatchThreadID) {
  uint i = tid.x;
  U128 a = { A[i*4+0], A[i*4+1], A[i*4+2], A[i*4+3] };
  U128 b = { B[i*4+0], B[i*4+1], B[i*4+2], B[i*4+3] };
  U128 r = mulR128(a, b);
  OUT[i*4+0] = r.w0; OUT[i*4+1] = r.w1; OUT[i*4+2] = r.w2; OUT[i*4+3] = r.w3;
}
