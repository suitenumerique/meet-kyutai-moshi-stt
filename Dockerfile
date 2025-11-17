FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04 AS base

FROM base AS deps

# https://github.com/huggingface/candle/blob/60252ccf0f92df00a08eab4f9f83b79b9f339d2f/candle-flash-attn-v3/build.rs#L315
# NOTE: The candle Rust project attempts to auto-detect the CUDA compute capability
# by parsing nvidia-smi output if CUDA_COMPUTE_CAP is not explicitly provided.
# Since nvidia-smi is not available in the host build environment, you must pass
# this argument explicitly (e.g., --build-arg CUDA_COMPUTE_CAP=90 for H100 GPUs).
ARG CUDA_COMPUTE_CAP
ARG PYTHON_VERSION="3.12"

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TORCH_COMPILE_DISABLE=1 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

# Update, upgrade, and install packages
RUN apt-get update && apt-get install -y \
    "python${PYTHON_VERSION}-dev" \
    "python${PYTHON_VERSION}-venv" \
    curl \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
RUN rustc --version

# Install moshi server
RUN CUDA_COMPUTE_CAP=${CUDA_COMPUTE_CAP} cargo install --features cuda moshi-server

FROM deps AS core

ARG DOCKER_USER=1001
ARG APP_USER=appuser

RUN groupadd -r ${APP_USER} && \
    useradd -r \
      -g ${APP_USER} \
      -u ${DOCKER_USER} \
      -s /usr/sbin/nologin \
      -c "Application runtime user" \
      -m \
      ${APP_USER}

ARG HF_HOME=/data/models
ENV HF_HOME=${HF_HOME}
ENV TRANSFORMERS_CACHE=${HF_HOME}

RUN mkdir -p ${HF_HOME} /app && \
    # Set ownership to unprivileged user
    chown -R ${APP_USER}:${APP_USER} ${HF_HOME} /app && \
    chmod -R 700 ${HF_HOME} && \
    chmod -R 755 /app

WORKDIR /app

COPY --chown=${APP_USER}:${APP_USER} /configs /app/configs
COPY --chown=${APP_USER}:${APP_USER} entrypoint.sh /app/entrypoint.sh

# Ensure entrypoint is executable
RUN chmod 755 entrypoint.sh

USER ${APP_USER}

ARG SERVER_PORT=8000
ENV SERVER_PORT=$SERVER_PORT

EXPOSE $SERVER_PORT

ENTRYPOINT ["/app/entrypoint.sh"]
