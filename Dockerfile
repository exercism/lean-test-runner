FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git 
    
ENV ELAN_HOME=/usr/local/elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"

RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --no-modify-path --default-toolchain leanprover/lean4:v4.25.2 \
    && elan default leanprover/lean4:v4.25.2 \
    && lean --version \
    && rm -rf "${ELAN_HOME}/toolchains/leanprover--lean4---v4.25.2/lib/lean/Lean" \
    && rm -rf "${ELAN_HOME}/toolchains/leanprover--lean4---v4.25.2/src/lean/Lean" 
    
WORKDIR /opt/test-runner
COPY lean-toolchain lakefile.toml ./
COPY vendor/ ./vendor/

RUN lake build LeanTest

FROM debian:bookworm-slim

ENV ELAN_HOME=/usr/local/elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"

COPY --from=builder /usr/local/elan /usr/local/elan

WORKDIR /opt/test-runner
COPY --from=builder /opt/test-runner /opt/test-runner

RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/icons

COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
