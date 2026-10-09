FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f AS builder

RUN apt-get update && apt-get install --yes --no-install-recommends ca-certificates curl
    
ENV ELAN_HOME=/usr/local/elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"

ADD https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh /tmp/elan-init.sh
RUN sh /tmp/elan-init.sh -y --no-modify-path --default-toolchain leanprover/lean4:v4.29.0 \
    && elan default leanprover/lean4:v4.29.0 \
    && lean --version \
    && rm -rf "${ELAN_HOME}/toolchains/leanprover--lean4---v4.29.0/lib/lean/Lean" \
    && rm -rf "${ELAN_HOME}/toolchains/leanprover--lean4---v4.29.0/src/lean/Lean" 
    
WORKDIR /opt/test-runner
COPY lean-toolchain lakefile.toml ./
COPY vendor/ ./vendor/

RUN lake build LeanTest:static

FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f

RUN apt-get update && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/* /usr/share/icons

ENV ELAN_HOME=/usr/local/elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"

COPY --from=builder /usr/local/elan /usr/local/elan
COPY --from=builder /opt/test-runner /opt/test-runner

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
