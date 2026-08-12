# base runtime image — binarylifter/gardusig-cli:${version} (also :base-${version}).
# Lean Alpine with the bash CLI + core shelling tools + no-language validators.
# The src stage holds the build context; the final stage ships only the
# relevant artifacts (/cli /lib /commands /VERSION) plus installed tools.

FROM alpine:3.21 AS src
WORKDIR /src
COPY . .

FROM alpine:3.21 AS final

ENV CLI_RUNTIME=base

COPY --from=src /src/docker/runtime /install/
RUN apk add --no-cache bash && bash /install/install-base.sh

WORKDIR /workspace
COPY --from=src /src/src/cli /opt/cli/cli
COPY --from=src /src/src/lib /opt/cli/lib
COPY --from=src /src/src/commands /opt/cli/commands
COPY --from=src /src/VERSION /opt/cli/VERSION
RUN ln -sf /opt/cli/cli /usr/local/bin/cli

ENTRYPOINT ["cli"]
CMD ["--help"]
