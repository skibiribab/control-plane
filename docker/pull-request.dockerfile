# Pull-request / development pipeline — build the bash CLI, run bats tests, and
# publish runtime images to Docker Hub. Not meant for end users; the usable
# runtime images live in docker/{base,rust,node,python,media,cpp,go,java}.dockerfile.
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

ENTRYPOINT ["bash", "scripts/pull-request/resolve-version.sh"]

FROM base AS resolve-release

ENTRYPOINT ["bash", "scripts/release/resolve-tag-version.sh"]

FROM base AS version-check

ARG BASE_VERSION=
ENV BASE_VERSION=${BASE_VERSION}
RUN bash scripts/pull-request/version-check.sh

FROM base AS unit-test

RUN bash scripts/pull-request/unit-test.sh

FROM base AS integration-smoke

RUN ln -sf /workspace/cli /usr/local/bin/cli \
    && bash scripts/pull-request/integration-test.sh

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
ENTRYPOINT ["bash", "scripts/release/push-runtime-image.sh"]

FROM ci-tools AS ci-smoke
ENTRYPOINT ["bash", "scripts/release/smoke-runtime-image.sh"]

FROM ci-tools AS ci-github-release
ENTRYPOINT ["bash", "scripts/release/create-github-release.sh"]
