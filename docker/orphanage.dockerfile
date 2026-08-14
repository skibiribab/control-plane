# orphanage runtime image — skibiribab/cli:${version}-orphanage.
# The language-agnostic, not-AI general image: every standalone utility CLI —
# ops passthroughs (git/gh/docker), generic linters (shellcheck/actionlint),
# JSON/PDF/link utilities (jq/qpdf/poppler/lychee) and the TeX typesetting stack.
# The src stage holds the build context; the final stage ships only the
# relevant artifacts (/cli /lib /commands /VERSION) plus installed tools.

FROM alpine:3.21 AS src
WORKDIR /src
COPY . .

FROM alpine:3.21 AS final

ENV CLI_RUNTIME=orphanage

COPY --from=src /src/docker/runtime /install/
RUN apk add --no-cache bash \
    && bash /install/install-core.sh \
    && bash /install/install-orphanage.sh

WORKDIR /workspace
COPY --from=src /src/src/cli /opt/cli/cli
COPY --from=src /src/src/lib /opt/cli/lib
COPY --from=src /src/src/commands /opt/cli/commands
COPY --from=src /src/VERSION /opt/cli/VERSION
RUN ln -sf /opt/cli/cli /usr/local/bin/cli

ENTRYPOINT ["cli"]
CMD ["--help"]
