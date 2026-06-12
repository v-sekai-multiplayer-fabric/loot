# openxr-monado adapter

A headless OpenXR runtime for testing the VR path with no headset and no display,
per the manuals decision
[20260612-headless-openxr-testing-with-monado](https://v-sekai-multiplayer-fabric.github.io/manuals/decisions/20260612-headless-openxr-testing-with-monado.html).
Monado runs with the null compositor and a simulated HMD on lavapipe (software
Vulkan), under default rootless podman security — the `cap_sys_nice` file
capability is stripped in the build so the binary execs without extra caps.

## CI smoke (plain podman)

```sh
./smoke.sh    # builds the image, starts monado-service, asserts xrCreateInstance
```

## As a systemd quadlet (self-hosted hosts)

```sh
podman build -t monado-headless -f Containerfile .
cp monado-headless.container ~/.config/containers/systemd/
systemctl --user daemon-reload && systemctl --user start monado-headless
```

The OpenXR IPC socket lands at `$XDG_RUNTIME_DIR/monado/monado_comp_ipc`; point an
OpenXR app's `XDG_RUNTIME_DIR` there (or run it in the same pod) to connect.

Scope: functional and integration coverage of the OpenXR path. The standalone
Quest 3 build stays the performance and comfort gate.
