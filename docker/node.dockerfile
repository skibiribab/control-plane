# node runtime image — skibiribab/cli:${version}-node.
# The markdown/JSON/JS ecosystem: node/npm + markdownlint. All generic
# content validators (md link/table, tree, json) are node-based.

FROM alpine:3.21 AS src
WORKDIR /src
COPY . .

FROM alpine:3.21 AS final

ENV CLI_RUNTIME=node

COPY --from=src /src/docker/runtime /install/
RUN apk add --no-cache bash \
    && bash /install/install-core.sh \
    && bash /install/install-node.sh

WORKDIR /workspace
COPY --from=src /src/src/cli /opt/cli/cli
COPY --from=src /src/src/lib /opt/cli/lib
COPY --from=src /src/src/commands /opt/cli/commands
COPY --from=src /src/VERSION /opt/cli/VERSION
RUN ln -sf /opt/cli/cli /usr/local/bin/cli

ENTRYPOINT ["cli"]
CMD ["--help"]
