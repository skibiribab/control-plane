# Tests

bats-core tests exercising the bash CLI.

| File | Focus |
| --- | --- |
| `cli.bats` | dispatcher: version, help, unknown noun, integration list, gh policy, git passthrough, missing-tool recommendation |
| `lint.bats` | `cli sh lint` happy/sad paths, `--json` output, `structure lint` |
| `lib.bats` | `json_object`/`json_field`/`env_or` helpers |

`tests/fixtures/runtime/` holds the fixture files used by the runtime image
smoke (`scripts/release/runtime-smoke.sh`): `good.yaml`, `bad.yaml`,
`good.json`, `README.md`, `Dockerfile`, `ok.sh`.

Run in the CI pipeline via `docker build -f src/docker/pull-request.dockerfile --target unit-test .`
(`scripts/pull-request/unit-test.sh` → `bats tests`).
