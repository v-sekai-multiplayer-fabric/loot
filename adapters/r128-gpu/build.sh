#!/usr/bin/env bash
# Compile the r128 mul kernel to SPIR-V and build the Vulkan parity runner.
set -euo pipefail
cd "$(dirname "$0")"
bash ../parity/build.sh >/dev/null 2>&1 || true   # volk.c + Vulkan-Headers
[ -f r128.h ] || curl -fsSL https://raw.githubusercontent.com/fahickman/r128/master/r128.h -o r128.h
if command -v slangc >/dev/null; then SLANGC=slangc; else
  SLANG=2026.10.2
  [ -x ./slang/bin/slangc ] || { mkdir -p slang; curl -fsSL "https://github.com/shader-slang/slang/releases/download/v${SLANG}/slang-${SLANG}-linux-x86_64-glibc-2.27.tar.gz" | tar -xz -C slang; }
  SLANGC=./slang/bin/slangc
fi
"$SLANGC" r128_mul.slang -target spirv -profile glsl_450 -entry main -stage compute -o r128_mul.spv
gcc -O2 -w r128_gpu_parity.c ../parity/volk.c -I. -I../parity -I../parity/vh/include -ldl -o r128_gpu_parity
echo "built. run: ./r128_gpu_parity r128_mul.spv"
