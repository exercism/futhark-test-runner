FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS base

FROM base AS builder

RUN apk add --no-cache curl git

ARG VERSION=0.26.1

RUN curl -O "https://futhark-lang.org/releases/futhark-${VERSION}-linux-x86_64.tar.xz" && \
    tar -xJf "futhark-${VERSION}-linux-x86_64.tar.xz" && \
    cp "futhark-${VERSION}-linux-x86_64/bin/futhark" /usr/local/bin/

WORKDIR /opt/futhark-packages
RUN futhark pkg add github.com/diku-dk/sorts && \
    futhark pkg sync

FROM base AS runtime

RUN apk add --no-cache jq gcc musl-dev

COPY --from=builder /usr/local/bin/futhark /usr/local/bin/futhark

WORKDIR /opt/test-runner
COPY --from=builder /opt/futhark-packages/lib lib
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
