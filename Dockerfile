FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4 AS builder

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

FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

RUN apt-get update && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/* /usr/share/icons

ENV ELAN_HOME=/usr/local/elan
ENV PATH="${ELAN_HOME}/bin:${PATH}"

COPY --from=builder /usr/local/elan /usr/local/elan
COPY --from=builder /opt/test-runner /opt/test-runner

WORKDIR /opt/test-runner
COPY . .

# List the toolchain files every run reads, for bin/run.sh to load into the page cache
# at the start of each run: the Init library's .olean, .ir and related files, the shared
# Lean library, and clang's LLVM libraries and linker.
RUN toolchain=$(lean --print-prefix) \
    && { echo "${toolchain}/lib/lean/libleanshared.so"; \
         find "${toolchain}/lib/lean" -maxdepth 1 -type f -name 'Init.*' ! -name '*.ilean'; \
         find "${toolchain}/lib/lean/Init" -type f ! -name '*.ilean'; \
         find "${toolchain}/lib" -maxdepth 1 -type f \( -name 'libLLVM.so.*' -o -name 'libclang-cpp.so.*' \); \
         echo "${toolchain}/bin/ld.lld"; } > /opt/test-runner/prefetch-files.txt \
    && xargs ls > /dev/null < /opt/test-runner/prefetch-files.txt
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
