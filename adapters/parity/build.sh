#!/usr/bin/env bash
# Fetch volk + Vulkan-Headers and build the SPIR-V parity runner.
set -euo pipefail
cd "$(dirname "$0")"
[ -f volk.h ] || curl -fsSL https://raw.githubusercontent.com/zeux/volk/master/volk.h -o volk.h
[ -f volk.c ] || curl -fsSL https://raw.githubusercontent.com/zeux/volk/master/volk.c -o volk.c
[ -d vh ]     || git clone --depth 1 https://github.com/KhronosGroup/Vulkan-Headers.git vh
gcc -O2 parity_runner.c volk.c -Ivh/include -I. -ldl -o parity_runner
echo "built ./parity_runner"
