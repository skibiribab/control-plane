# cpp runtime image — skibiribab/cli:${version}-cpp.
# gcc/g++/make/cmake/clang for C/C++ lint/test.

FROM alpine:3.21 AS src
WORKDIR /src
COPY . .

FROM alpine:3.21 AS final

ENV CLI_RUNTIME=cpp

COPY --from=src /src/docker/runtime /install/
RUN apk add --no-cache bash \
    && bash /install/install-core.sh \
    && bash /install/install-cpp.sh

WORKDIR /workspace
COPY --from=src /src/src/cli /opt/cli/cli
COPY --from=src /src/src/lib /opt/cli/lib
COPY --from=src /src/src/commands /opt/cli/commands
COPY --from=src /src/VERSION /opt/cli/VERSION
RUN ln -sf /opt/cli/cli /usr/local/bin/cli

ENTRYPOINT ["cli"]
CMD ["--help"]
