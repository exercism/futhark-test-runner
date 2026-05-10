FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS builder

RUN apk add --no-cache curl git

ARG VERSION=0.26.1

RUN curl -O "https://futhark-lang.org/releases/futhark-${VERSION}-linux-x86_64.tar.xz" && \
    tar -xJf "futhark-${VERSION}-linux-x86_64.tar.xz" && \
    cp "futhark-${VERSION}-linux-x86_64/bin/futhark" /usr/local/bin/

WORKDIR /opt/futhark-packages
RUN futhark pkg add github.com/diku-dk/sorts && \
    futhark pkg sync

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS runtime

RUN apk add --no-cache jq gcc musl-dev

COPY --from=builder /usr/local/bin/futhark /usr/local/bin/futhark

WORKDIR /opt/test-runner
COPY --from=builder /opt/futhark-packages/lib lib
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
