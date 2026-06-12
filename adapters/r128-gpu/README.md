# r128 GPU parity adapter

`r128_mul.slang` is a 1:1 transcription of `core/LootCore/R128L` (the uint32-limb
Q64.64 multiply, proven bit-exact to the host r128). It compiles to SPIR-V and runs
on Vulkan; `r128_gpu_parity.c` links the host `r128.c`, generates random pairs,
multiplies them on the CPU and the GPU, and asserts the limbs match.

```sh
./build.sh
./r128_gpu_parity r128_mul.spv     # -> R128 GPU PARITY PASS on 4096 multiplies
```

Verified on lavapipe (software Vulkan) and intended for the RTX 4090 / MoltenVK too.
Integer ops are exact across conformant Vulkan implementations, so the GPU result
equals the host r128 bit-for-bit.
