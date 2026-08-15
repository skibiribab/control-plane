# go runtime image — skibiribab/pkg-manager:${version}-go.
# The Go ecosystem: golang toolchain.

FROM alpine:3.21 AS src
WORKDIR /src
COPY . .

FROM alpine:3.21 AS final

COPY --from=src /src/docker/runtime /install/
RUN apk add --no-cache bash \
    && bash /install/install-core.sh \
    && bash /install/install-go.sh
