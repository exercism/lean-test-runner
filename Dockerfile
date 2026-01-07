FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

ENV ELAN_HOME=/usr/local/elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"

RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --no-modify-path --default-toolchain leanprover/lean4:v4.25.2 \
    && elan default leanprover/lean4:v4.25.2 \
    && lean --version \
    && rm -rf ${ELAN_HOME}/downloads/* /tmp/* /var/tmp/* \
    && find ${ELAN_HOME} -name "*.a" -delete \
    && rm -rf ${ELAN_HOME}/toolchains/*/lib/libLLVM* \
    && rm -rf ${ELAN_HOME}/toolchains/*/lib/libclang* \
    && rm -rf ${ELAN_HOME}/toolchains/*/src

WORKDIR /opt/test-runner
