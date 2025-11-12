# ------------------------------------------------------------
# Stage 1: Base builder with Rust + uv
# ------------------------------------------------------------
FROM debian:bookworm AS base

RUN apt-get update && apt-get install -y \
    curl build-essential pkg-config wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy prebuilt toolchains directly from build context
COPY Toolchains Toolchains
RUN dpkg -i Toolchains/deb/*.deb

# Install Rust + uv
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
# Advantech routers have ARMv5, ARMv7, and AArch64 CPUs
# RUN rustup target add armv5-unknown-linux-gnueabi  # ARMv5 is not supported by rustup
RUN rustup target add armv7-unknown-linux-gnueabi
RUN rustup target add aarch64-unknown-linux-gnu
# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# ------------------------------------------------------------
# Stage 2: Build wheels for all Python versions and packages
# ------------------------------------------------------------
FROM base AS wheel-builder

WORKDIR /opt
COPY python-builds/python3*.tgz /opt/
# Reuse toolchains from base stage
COPY --from=base /opt/toolchain /opt/toolchain

WORKDIR /build
RUN apt-get update && apt-get install -y python3 python3-pip
RUN uv tool install maturin

COPY scripts/build_wheels.sh /usr/local/bin/build_wheels.sh
COPY package-list.txt /tmp/package-list.txt

RUN chmod +x /usr/local/bin/build_wheels.sh

RUN ls -l /opt && ls -l /opt/toolchain

ARG PACKAGES="/tmp/package-list.txt"
RUN /usr/local/bin/build_wheels.sh

# ------------------------------------------------------------
# Final stage: output wheels
# ------------------------------------------------------------
FROM debian:bookworm-slim AS final
COPY --from=wheel-builder /dist /dist
