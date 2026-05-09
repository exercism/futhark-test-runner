FROM alpine:3.20.10@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc AS builder

RUN apk add --no-cache curl git

ARG VERSION=0.25.31

RUN curl -O "https://futhark-lang.org/releases/futhark-${VERSION}-linux-x86_64.tar.xz" && \
    tar -xJf "futhark-${VERSION}-linux-x86_64.tar.xz" && \
    cp "futhark-${VERSION}-linux-x86_64/bin/futhark" /usr/local/bin/

WORKDIR /opt/futhark-packages
RUN futhark pkg add github.com/diku-dk/sorts && \
    futhark pkg sync

FROM alpine:3.20.10@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc AS runtime

RUN apk add --no-cache jq gcc musl-dev

COPY --from=builder /usr/local/bin/futhark /usr/local/bin/futhark

WORKDIR /opt/test-runner
COPY --from=builder /opt/futhark-packages/lib lib
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
