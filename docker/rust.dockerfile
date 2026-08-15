# rust runtime image — skibiribab/pkg-manager:${version}-rust.
# The Rust ecosystem: rust/cargo toolchain.

FROM alpine:3.21 AS src
WORKDIR /src
COPY . .

FROM alpine:3.21 AS final

COPY --from=src /src/docker/runtime /install/
RUN apk add --no-cache bash \
    && bash /install/install-core.sh \
    && bash /install/install-rust.sh
