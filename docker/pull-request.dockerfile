# Pull-request / development pipeline — build the bash CLI, run bats tests, and
# publish runtime images to Docker Hub. Not meant for end users; the usable
# runtime images live in docker/{orphanage,ai,node,python,rust,cpp,go,java,media}.dockerfile.
# docker build -f docker/pull-request.dockerfile --target <stage> .

FROM alpine:3.21 AS base

ENV CLI_PROFILE=test \
    CI_UNIT_TIMEOUT=5m \
    CI_INTEGRATION_TIMEOUT=3m \
    CI_DOCKER_BUILD_TIMEOUT=5m \
    CI_VERSION_CHECK_TIMEOUT=2m \
    CI_RESOLVE_TIMEOUT=2m

WORKDIR /workspace
COPY . .
RUN . /workspace/docker/runtime/versions.env \
    && apk add --no-cache \
      "bash=${APK_BASH}" \
      "git=${APK_GIT}" \
      "ca-certificates=${APK_CA_CERTIFICATES}" \
      "curl=${APK_CURL}" \
      "coreutils=${APK_COREUTILS}" \
      "bats=${APK_BATS}" \
      "shellcheck=${APK_SHELLCHECK}" \
      "actionlint=${APK_ACTIONLINT}"

FROM base AS resolve

ENTRYPOINT ["bash", "src/scripts/pull-request/resolve-version.sh"]

FROM base AS resolve-release

ENTRYPOINT ["bash", "src/scripts/release/resolve-tag-version.sh"]

FROM base AS version-check

ARG GIT_VERSION=
ARG DOCKER_VERSION=
ENV GIT_VERSION=${GIT_VERSION} \
    DOCKER_VERSION=${DOCKER_VERSION}
RUN bash src/scripts/pull-request/version-check.sh

FROM base AS unit-test

RUN bash src/scripts/pull-request/unit-test.sh

FROM base AS integration-smoke

RUN ln -sf /workspace/src/cli /usr/local/bin/cli \
    && bash src/scripts/pull-request/integration-test.sh

FROM docker:27-cli AS ci-tools

ENV CI_DOCKER_PUSH_TIMEOUT=5m \
    CI_RELEASE_SMOKE_TIMEOUT=12m \
    DOCKER_REGISTRY_SETTLE_SECONDS=20 \
    DOCKER_PULL_ATTEMPTS=12 \
    DOCKER_PULL_INITIAL_DELAY=4 \
    DOCKER_PULL_BACKOFF_MULTIPLIER=2 \
    DOCKER_PULL_MAX_DELAY=45

WORKDIR /workspace
COPY . .
RUN . /workspace/docker/runtime/versions.env \
    && apk add --no-cache \
      "bash=${APK_BASH}" \
      "github-cli=${APK_GITHUB_CLI}" \
      "coreutils=${APK_COREUTILS}" \
      "curl=${APK_CURL}"

FROM ci-tools AS ci-push
ENTRYPOINT ["bash", "src/scripts/release/push-runtime-image.sh"]

FROM ci-tools AS ci-smoke
ENTRYPOINT ["bash", "src/scripts/release/publish-smoke.sh"]

FROM ci-tools AS ci-github-release
ENTRYPOINT ["bash", "src/scripts/release/create-github-release.sh"]

FROM ci-tools AS ci-status-update
RUN . /workspace/docker/runtime/versions.env \
    && apk add --no-cache "jq=${APK_JQ}"
ENTRYPOINT ["bash", "src/scripts/status/update-status.sh"]
