FROM alpine:3.23.6@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0 AS builder

RUN apk add --no-cache curl git

ARG VERSION=0.26.1

RUN curl -O "https://futhark-lang.org/releases/futhark-${VERSION}-linux-x86_64.tar.xz" && \
    tar -xJf "futhark-${VERSION}-linux-x86_64.tar.xz" && \
    cp "futhark-${VERSION}-linux-x86_64/bin/futhark" /usr/local/bin/

WORKDIR /opt/futhark-packages
RUN futhark pkg add github.com/diku-dk/sorts && \
    futhark pkg sync

FROM alpine:3.23.6@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0 AS runtime

RUN apk add --no-cache jq gcc musl-dev

COPY --from=builder /usr/local/bin/futhark /usr/local/bin/futhark

WORKDIR /opt/test-runner
COPY --from=builder /opt/futhark-packages/lib lib
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
