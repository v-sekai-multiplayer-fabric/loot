#!/usr/bin/env bash
# Fetch the vendored host r128 header and build the differential oracle.
set -euo pipefail
cd "$(dirname "$0")"
[ -f r128.h ] || curl -fsSL https://raw.githubusercontent.com/fahickman/r128/master/r128.h -o r128.h
gcc -O2 -w r128_oracle.c -I. -o r128_oracle
echo "built ./r128_oracle"
