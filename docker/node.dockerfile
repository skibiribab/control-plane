# node runtime image — skibiribab/pkg-manager:${version}-node.
# The Node ecosystem: node/npm + markdownlint-cli.

FROM alpine:3.21 AS src
WORKDIR /src
COPY . .

FROM alpine:3.21 AS final

COPY --from=src /src/docker/runtime /install/
RUN apk add --no-cache bash \
    && bash /install/install-core.sh \
    && bash /install/install-node.sh
