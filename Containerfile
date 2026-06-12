# Loot SPIR-V parity on software Vulkan (lavapipe): compile the lean-slang kernel
# to SPIR-V with slangc, dispatch it on lavapipe via the volk runner, and check
# every output against the Lean golden vectors. No GPU passthrough required.
FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      mesa-vulkan-drivers libvulkan1 vulkan-tools gcc curl ca-certificates git \
    && rm -rf /var/lib/apt/lists/*
ARG SLANG=2026.10.2
RUN curl -fsSL "https://github.com/shader-slang/slang/releases/download/v${SLANG}/slang-${SLANG}-linux-x86_64-glibc-2.27.tar.gz" \
      | tar -xz -C /usr/local bin/slangc lib/ 2>/dev/null || \
    curl -fsSL "https://github.com/shader-slang/slang/releases/download/v${SLANG}/slang-${SLANG}-linux-x86_64-glibc-2.27.tar.gz" \
      | tar -xz -C /usr/local
WORKDIR /loot
COPY . /loot
RUN bash adapters/parity/build.sh
RUN /usr/local/bin/slangc adapters/parity/kernel.slang -target spirv -profile glsl_450 \
      -entry main -stage compute -o adapters/parity/kernel.spv
CMD ["./adapters/parity/parity_runner", "adapters/parity/kernel.spv", "adapters/parity/golden.csv"]
