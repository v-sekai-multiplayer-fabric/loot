[[vk::binding(0, 0)]]
StructuredBuffer<uint> seeds;
[[vk::binding(1, 0)]]
StructuredBuffer<uint> cumw;
[[vk::binding(2, 0)]]
RWStructuredBuffer<uint> outRolls;

[shader("compute")] [numthreads(64, 1, 1)]
void main(uint3 tid : SV_DispatchThreadID) {
  uint i = tid.x;
  uint s = seeds[i];
  s = (s ^ (s << 13u));
  s = (s ^ (s >> 17u));
  s = (s ^ (s << 5u));
  uint total = cumw[2u];
  uint r = (s % total);
  uint item = ((r < cumw[0u]) ? 0u : ((r < cumw[1u]) ? 1u : 2u));
  outRolls[i] = item;
  return;
}