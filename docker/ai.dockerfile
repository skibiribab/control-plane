# ai runtime image — skibiribab/cli:${version}-ai.
# The AI agent home: opencode (code-gen engine) + the ops CLIs the agent loop
# needs (pull → plan → build → git → gh). No language toolchains — the agent
# shells out to skibiribab/cli:<v>-<lang> images via docker for builds/tests.

FROM alpine:3.21 AS src
WORKDIR /src
COPY . .

FROM alpine:3.21 AS final

ENV CLI_RUNTIME=ai

COPY --from=src /src/docker/runtime /install/
RUN apk add --no-cache bash \
    && bash /install/install-core.sh \
    && bash /install/install-ai.sh

WORKDIR /workspace
COPY --from=src /src/src/cli /opt/cli/cli
COPY --from=src /src/src/lib /opt/cli/lib
COPY --from=src /src/src/commands /opt/cli/commands
COPY --from=src /src/VERSION /opt/cli/VERSION
RUN ln -sf /opt/cli/cli /usr/local/bin/cli

ENTRYPOINT ["cli"]
CMD ["--help"]
