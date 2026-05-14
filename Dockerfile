FROM debian:trixie-slim@sha256:109e2c65005bf160609e4ba6acf7783752f8502ad218e298253428690b9eaa4b AS builder

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

RUN lake build LeanTest

FROM debian:trixie-slim@sha256:109e2c65005bf160609e4ba6acf7783752f8502ad218e298253428690b9eaa4b

RUN apt-get update && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/* /usr/share/icons

ENV ELAN_HOME=/usr/local/elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"

COPY --from=builder /usr/local/elan /usr/local/elan
COPY --from=builder /opt/test-runner /opt/test-runner

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
