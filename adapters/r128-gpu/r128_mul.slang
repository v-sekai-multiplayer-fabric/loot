struct U128 {
  uint w0;
  uint w1;
  uint w2;
  uint w3;
};

[[vk::binding(0, 0)]]
StructuredBuffer<uint> A;
[[vk::binding(1, 0)]]
StructuredBuffer<uint> B;
[[vk::binding(2, 0)]]
RWStructuredBuffer<uint> OUT;

U128 mkU128(uint w0, uint w1, uint w2, uint w3) {
  U128 r;
  r.w0 = w0;
  r.w1 = w1;
  r.w2 = w2;
  r.w3 = w3;
  return r;
}

uint mulhi(uint a, uint b) {
  uint a0 = (a & 65535u);
  uint a1 = (a >> 16u);
  uint b0 = (b & 65535u);
  uint b1 = (b >> 16u);
  uint p00 = (a0 * b0);
  uint p01 = (a0 * b1);
  uint p10 = (a1 * b0);
  uint p11 = (a1 * b1);
  uint mid = (((p00 >> 16u) + (p01 & 65535u)) + (p10 & 65535u));
  return (((p11 + (p01 >> 16u)) + (p10 >> 16u)) + (mid >> 16u));
}

U128 add128(U128 a, U128 b) {
  uint s0 = (a.w0 + b.w0);
  uint k0 = ((s0 < a.w0) ? 1u : 0u);
  uint s1 = (a.w1 + b.w1);
  uint k1 = ((s1 < a.w1) ? 1u : 0u);
  uint t1 = (s1 + k0);
  k1 = (k1 + ((t1 < s1) ? 1u : 0u));
  uint s2 = (a.w2 + b.w2);
  uint k2 = ((s2 < a.w2) ? 1u : 0u);
  uint t2 = (s2 + k1);
  k2 = (k2 + ((t2 < s2) ? 1u : 0u));
  uint s3 = ((a.w3 + b.w3) + k2);
  return mkU128(s0, t1, t2, s3);
}

U128 negU(U128 a) {
  return add128(mkU128((~a.w0), (~a.w1), (~a.w2), (~a.w3)), mkU128(1u, 0u, 0u, 0u));
}

U128 umul64x64(uint a0, uint a1, uint b0, uint b1) {
  uint l00 = (a0 * b0);
  uint h00 = mulhi(a0, b0);
  uint l01 = (a0 * b1);
  uint h01 = mulhi(a0, b1);
  uint l10 = (a1 * b0);
  uint h10 = mulhi(a1, b0);
  uint l11 = (a1 * b1);
  uint h11 = mulhi(a1, b1);
  uint r0 = l00;
  uint s = (h00 + l01);
  uint c = ((s < h00) ? 1u : 0u);
  uint s2 = (s + l10);
  c = (c + ((s2 < s) ? 1u : 0u));
  uint r1 = s2;
  uint carryC = c;
  uint w = (h01 + h10);
  uint s3 = (l11 + w);
  uint c2 = ((s3 < l11) ? 1u : 0u);
  uint s4 = (s3 + carryC);
  c2 = (c2 + ((s4 < s3) ? 1u : 0u));
  uint r2 = s4;
  uint r3 = (h11 + c2);
  return mkU128(r0, r1, r2, r3);
}

U128 umul(U128 a, U128 b) {
  U128 p0 = umul64x64(a.w0, a.w1, b.w0, b.w1);
  uint roundbit = (p0.w1 >> 31u);
  U128 acc = mkU128(p0.w2, p0.w3, 0u, 0u);
  acc = add128(acc, mkU128(roundbit, 0u, 0u, 0u));
  acc = add128(acc, umul64x64(a.w2, a.w3, b.w0, b.w1));
  acc = add128(acc, umul64x64(a.w0, a.w1, b.w2, b.w3));
  U128 p3 = umul64x64(a.w2, a.w3, b.w2, b.w3);
  return add128(acc, mkU128(0u, 0u, p3.w0, p3.w1));
}

U128 mulR128(U128 a, U128 b) {
  bool sa = ((a.w3 >> 31u) != 0u);
  bool sb = ((b.w3 >> 31u) != 0u);
  U128 ta = (sa ? negU(a) : a);
  U128 tb = (sb ? negU(b) : b);
  U128 tc = umul(ta, tb);
  return ((sa != sb) ? negU(tc) : tc);
}

[shader("compute")] [numthreads(64, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  uint i = tid.x;
  U128 a = mkU128(A[((i * 4u) + 0u)], A[((i * 4u) + 1u)], A[((i * 4u) + 2u)], A[((i * 4u) + 3u)]);
  U128 b = mkU128(B[((i * 4u) + 0u)], B[((i * 4u) + 1u)], B[((i * 4u) + 2u)], B[((i * 4u) + 3u)]);
  U128 r = mulR128(a, b);
  OUT[((i * 4u) + 0u)] = r.w0;
  OUT[((i * 4u) + 1u)] = r.w1;
  OUT[((i * 4u) + 2u)] = r.w2;
  OUT[((i * 4u) + 3u)] = r.w3;
  return;
}