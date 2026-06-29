FROM alpine:3.23.5@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40 AS builder

RUN apk add --no-cache curl git

ARG VERSION=0.26.1

RUN curl -O "https://futhark-lang.org/releases/futhark-${VERSION}-linux-x86_64.tar.xz" && \
    tar -xJf "futhark-${VERSION}-linux-x86_64.tar.xz" && \
    cp "futhark-${VERSION}-linux-x86_64/bin/futhark" /usr/local/bin/

WORKDIR /opt/futhark-packages
RUN futhark pkg add github.com/diku-dk/sorts && \
    futhark pkg sync

FROM alpine:3.23.5@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40 AS runtime

RUN apk add --no-cache jq gcc musl-dev

COPY --from=builder /usr/local/bin/futhark /usr/local/bin/futhark

WORKDIR /opt/test-runner
COPY --from=builder /opt/futhark-packages/lib lib
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
