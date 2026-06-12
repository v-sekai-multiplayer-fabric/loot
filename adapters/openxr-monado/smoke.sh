#!/usr/bin/env bash
# Build the headless Monado container and confirm an OpenXR client connects.
# CI-friendly (plain podman run; no systemd). Implements the manuals decision
# 20260612-headless-openxr-testing-with-monado.
set -euo pipefail
cd "$(dirname "$0")"
podman build -t monado-headless -f Containerfile .
podman run --rm monado-headless bash -lc '
  tail -f /dev/null | monado-service >/tmp/svc.log 2>&1 &
  for i in $(seq 1 24); do [ -S "$XDG_RUNTIME_DIR/monado_comp_ipc" ] && break; sleep 0.5; done
  [ -S "$XDG_RUNTIME_DIR/monado_comp_ipc" ] || { echo "no socket"; tail /tmp/svc.log; exit 1; }
  timeout 12 openxr_runtime_list 2>&1 | grep -q "Instance created" || { tail /tmp/svc.log; exit 1; }
'
echo "headless OpenXR smoke passed"
