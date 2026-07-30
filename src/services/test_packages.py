"""CLI package registry for selective test resolution.

The registry is intentionally deterministic: it maps repo-relative changed
paths to CLI packages and suggested test surfaces without invoking git or
AI providers.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from fnmatch import fnmatchcase
from pathlib import Path, PurePosixPath
import shlex
import subprocess
from typing import Any

from src.utils.config import project_root

_REPO_ROOT = project_root()
_DEFAULT_PACKAGE_LIMIT = 4
_COMMON_ENV = {"CLI_PROFILE": "test"}
_CORE_INTEGRATION_CHECKS = (
    "tests/integration/check_integration_coverage.py",
    "tests/integration/check_public_commands.py",
)
_PACKAGE_INTEGRATION = "package-integration"


@dataclass(frozen=True)
class TestPackage:
    """One selective-test package mapped from source and test paths."""

    name: str
    source_globs: tuple[str, ...]
    unit_test_paths: tuple[str, ...]
    integration_checks: tuple[str, ...] = ()
    notes: tuple[str, ...] = ()
    broad: bool = False
    requires_ai: bool = False
    costs_api_tokens: bool = False

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "source_globs": list(self.source_globs),
            "unit_test_paths": list(self.unit_test_paths),
            "integration_checks": list(self.integration_checks),
            "notes": list(self.notes),
            "broad": self.broad,
            "requires_ai": self.requires_ai,
            "costs_api_tokens": self.costs_api_tokens,
        }


@dataclass(frozen=True)
class TestPackageMatch:
    """A package selected by one or more changed paths."""

    package: TestPackage
    reasons: tuple[str, ...] = field(default_factory=tuple)

    def as_dict(self) -> dict[str, Any]:
        return {**self.package.as_dict(), "reasons": list(self.reasons)}


@dataclass(frozen=True)
class TestCommand:
    """One repo-local command for package or full-suite execution."""

    kind: str
    label: str
    command: tuple[str, ...]
    package: str | None = None
    env: dict[str, str] = field(default_factory=lambda: dict(_COMMON_ENV))

    def as_dict(self) -> dict[str, Any]:
        return {
            "kind": self.kind,
            "label": self.label,
            "package": self.package,
            "command": list(self.command),
            "env": dict(self.env),
        }


def _pkg(
    name: str,
    *,
    source: tuple[str, ...],
    tests: tuple[str, ...],
    checks: tuple[str, ...] = (),
    notes: tuple[str, ...] = (),
    broad: bool = False,
    requires_ai: bool = False,
    costs_api_tokens: bool = False,
) -> TestPackage:
    return TestPackage(
        name=name,
        source_globs=source,
        unit_test_paths=tests,
        integration_checks=checks,
        notes=notes,
        broad=broad,
        requires_ai=requires_ai,
        costs_api_tokens=costs_api_tokens,
    )


TEST_PACKAGES: tuple[TestPackage, ...] = (
    _pkg(
        "links",
        source=("src/commands/links.py", "src/utils/catalog.py", "docs/**", "README.md"),
        tests=("tests/cli/test_links.py",),
        checks=("links",),
    ),
    _pkg(
        "git",
        source=("src/commands/git.py", "src/services/git_*.py", "src/services/tag_policy.py"),
        tests=("tests/git/",),
        checks=(_PACKAGE_INTEGRATION,),
    ),
    _pkg(
        "gh",
        source=(
            "src/commands/gh.py",
            "src/providers/gh*.py",
            "src/services/gh_*.py",
            "docs/gh.md",
        ),
        tests=("tests/gh/",),
        checks=("gh --help", "gh policy list"),
    ),
    _pkg(
        "opencode",
        source=(
            "src/commands/opencode_cmd.py",
            "src/commands/chat.py",
            "src/providers/opencode.py",
            "src/providers/deepseek.py",
            "src/services/chat_distill.py",
            "src/data/deepseek/**",
            "src/data/opencode/**",
        ),
        tests=("tests/services/test_chat_distill.py",),
        checks=("opencode --help",),
        notes=(
            "Keep token-spending commands under cli opencode.",
            "Prefer a dedicated src/commands/opencode/ package before adding more AI flows.",
        ),
        requires_ai=True,
        costs_api_tokens=True,
    ),
    _pkg(
        "lint",
        source=("src/commands/lint.py", "src/commands/_toolkit.py", "src/services/toolkit/**"),
        tests=("tests/services/test_toolkit.py", "tests/cli/test_toolkit_commands.py"),
        checks=("lint --help",),
    ),
    _pkg(
        "test",
        source=(
            "src/commands/test_cmd.py",
            "src/services/test_packages.py",
            "src/commands/_toolkit.py",
            "src/services/toolkit/**",
        ),
        tests=(
            "tests/integration/test_test_packages.py",
            "tests/cli/test_test_packages_command.py",
            "tests/cli/test_toolkit_commands.py",
        ),
        checks=("test --help",),
    ),
    _pkg(
        "structure",
        source=("src/commands/structure.py", "src/commands/_toolkit.py", "src/services/toolkit/**"),
        tests=("tests/services/test_toolkit.py", "tests/meta/test_bootstrap_structure.py"),
        checks=("structure --help",),
    ),
    _pkg(
        "validate",
        source=("src/commands/validate.py", "src/commands/_toolkit.py", "src/services/toolkit/**"),
        tests=("tests/services/test_toolkit.py",),
        checks=("validate --help",),
    ),
    _pkg(
        "languages",
        source=("src/commands/languages.py", "src/commands/_toolkit.py", "src/services/toolkit/**"),
        tests=("tests/services/test_toolkit.py",),
        checks=("languages --help", "languages list"),
    ),
    _pkg(
        "release",
        source=(
            "src/commands/release_cmd.py",
            "src/services/pypi_publish.py",
            "docs/release.md",
            "docs/ci-workflows.md",
        ),
        tests=("tests/cli/test_release_commands.py",),
        checks=("release --help",),
    ),
    _pkg(
        "restore",
        source=("src/commands/restore.py", "src/workflows/**"),
        tests=("tests/backup/",),
        checks=("restore",),
    ),
    _pkg(
        "drive",
        source=(
            "src/commands/drive.py",
            "src/services/drive_*.py",
            "src/services/backup_*.py",
            "src/services/replica_deploy.py",
            "src/providers/google_drive.py",
            "src/providers/onedrive.py",
            "src/providers/drive_http.py",
        ),
        tests=("tests/drive/", "tests/backup/", "tests/providers/test_google_drive.py", "tests/providers/test_onedrive.py"),
        checks=(_PACKAGE_INTEGRATION,),
    ),
    _pkg(
        "notion",
        source=("src/commands/notion.py", "src/services/notion_*.py", "src/models/task.py"),
        tests=("tests/notion/",),
        checks=(_PACKAGE_INTEGRATION,),
    ),
    _pkg(
        "chrome",
        source=(
            "src/commands/chrome.py",
            "src/services/bookmark_sync.py",
            "src/services/photos_sync.py",
            "src/models/bookmark.py",
        ),
        tests=("tests/chrome/", "tests/harness/chrome_harness.py"),
        checks=(_PACKAGE_INTEGRATION,),
    ),
    _pkg(
        "docker",
        source=("src/commands/docker.py", "src/services/docker_runtime.py", "src/integration/docker_*.py"),
        tests=("tests/docker/",),
        checks=(_PACKAGE_INTEGRATION, "tests/integration/check_docker_commands.py"),
    ),
    _pkg(
        "contest",
        source=("src/commands/contest.py", "src/services/contest_*.py", "src/integration/contest_*.py"),
        tests=("tests/contest/",),
        checks=(_PACKAGE_INTEGRATION,),
    ),
    _pkg(
        "configure",
        source=("src/commands/configure_cmd.py", "src/utils/config.py"),
        tests=("tests/cli/",),
        checks=("configure --help",),
    ),
    _pkg(
        "config",
        source=("src/commands/config_cmd.py", "src/utils/config.py", "src/data/config/**"),
        tests=("tests/cli/",),
        checks=("config --help",),
    ),
    _pkg(
        "pypi",
        source=(
            "src/commands/pypi.py",
            "src/services/pypi_*.py",
            "pyproject.toml",
            "README.md",
            "docs/release.md",
            "docs/setup.md",
            "docs/ci-workflows.md",
        ),
        tests=("tests/pypi/", "tests/cli/test_release_commands.py"),
        checks=(_PACKAGE_INTEGRATION, "pypi --help"),
    ),
    _pkg(
        "puzzles",
        source=("src/commands/puzzles.py",),
        tests=("tests/contest/",),
        checks=("puzzles --help",),
    ),
    _pkg(
        "tasks",
        source=("src/commands/tasks.py", "src/models/task.py"),
        tests=(
            "tests/cli/test_tasks_commands.py",
            "tests/notion/test_pairs.py",
        ),
        checks=("tasks --help",),
    ),
    _pkg(
        "wiki",
        source=("src/commands/wiki.py",),
        tests=("tests/cli/",),
        checks=("wiki --help",),
    ),
    _pkg(
        "cli",
        source=("src/cli.py", "src/__init__.py"),
        tests=("tests/cli/", "tests/meta/test_public_commands_integration.py"),
        checks=(_PACKAGE_INTEGRATION,),
        notes=("Root CLI registration change: run broad command-surface checks.",),
        broad=True,
    ),
    _pkg(
        "meta",
        source=(
            "tests/conftest.py",
            "tests/constants.py",
            "tests/meta/**",
            "coverage-unit.ini",
            "requirements-dev.txt",
        ),
        tests=("tests/meta/",),
        checks=("tests/integration/check_integration_coverage.py",),
        notes=("Test harness or coverage changes may require the full unit suite.",),
        broad=True,
    ),
    _pkg(
        "internal",
        source=("src/internal/**",),
        tests=("tests/internal/", "tests/cli/"),
        checks=("python -m src.services.cli_smoke",),
        notes=("Read/write gate internals affect many commands.",),
        broad=True,
    ),
    _pkg(
        "toolkit",
        source=("src/commands/_toolkit.py", "src/services/toolkit/**"),
        tests=("tests/services/test_toolkit.py", "tests/cli/test_toolkit_commands.py"),
        checks=("lint --help", "test --help", "structure --help", "validate --help"),
        notes=("Shared toolkit changes should run all toolkit-backed command tests.",),
        broad=True,
    ),
    _pkg(
        "compress",
        source=("src/commands/compress.py", "src/services/compress.py", "src/services/scanner.py"),
        tests=("tests/compress/",),
        checks=("compress --help",),
    ),
    _pkg(
        "scan",
        source=("src/commands/scan.py", "src/services/scanner.py", "src/services/compress.py"),
        tests=("tests/scan/",),
        checks=("scan --help",),
    ),
    _pkg(
        "export",
        source=("src/commands/export_cmd.py", "src/services/backup_zip.py"),
        tests=("tests/export/",),
        checks=("export --help",),
    ),
)


def normalize_changed_path(path: str) -> str:
    """Return a stable repo-relative POSIX path for matching."""
    raw = path.strip().replace("\\", "/")
    if not raw:
        return ""
    if Path(raw).is_absolute():
        try:
            return Path(raw).resolve(strict=False).relative_to(_REPO_ROOT).as_posix()
        except ValueError:
            pass
    raw = raw.removeprefix("./").removeprefix("/")
    return str(PurePosixPath(raw))


def test_package_registry() -> tuple[TestPackage, ...]:
    """Return all package definitions in stable order."""
    return TEST_PACKAGES


def package_names() -> set[str]:
    return {pkg.name for pkg in TEST_PACKAGES}


def package_by_name(name: str) -> TestPackage:
    for pkg in TEST_PACKAGES:
        if pkg.name == name:
            return pkg
    raise KeyError(f"unknown test package: {name}")


def _matches(pattern: str, changed_path: str) -> bool:
    pattern = pattern.rstrip("/")
    if changed_path == pattern:
        return True
    if pattern.endswith("/**"):
        return changed_path.startswith(pattern[:-3].rstrip("/") + "/")
    if not any(ch in pattern for ch in "*?[]"):
        return changed_path.startswith(pattern + "/")
    return fnmatchcase(changed_path, pattern)


def matching_patterns(pkg: TestPackage, changed_path: str) -> tuple[str, ...]:
    path = normalize_changed_path(changed_path)
    patterns = (*pkg.source_globs, *pkg.unit_test_paths)
    return tuple(pattern for pattern in patterns if _matches(pattern, path))


def resolve_test_package_matches(changed_paths: list[str]) -> list[TestPackageMatch]:
    """Resolve changed paths to package matches with reasons."""
    normalized = [normalize_changed_path(path) for path in changed_paths if path.strip()]
    matches: list[TestPackageMatch] = []
    for pkg in TEST_PACKAGES:
        reasons: list[str] = []
        for path in normalized:
            for pattern in matching_patterns(pkg, path):
                reasons.append(f"{path} matches {pattern}")
        if reasons:
            matches.append(TestPackageMatch(pkg, tuple(dict.fromkeys(reasons))))
    return matches


def resolve_test_packages(changed_paths: list[str]) -> set[str]:
    """Resolve changed paths to package names."""
    return {match.package.name for match in resolve_test_package_matches(changed_paths)}


def changed_paths_from_git(base: str, head: str, repo_root: Path | None = None) -> list[str]:
    """Return changed repo-relative paths for a git revision range."""
    root = (repo_root or _REPO_ROOT).expanduser().resolve()
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...{head}"],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git diff failed")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def package_resolution_payload(
    changed_paths: list[str],
    *,
    package_limit: int = _DEFAULT_PACKAGE_LIMIT,
) -> dict[str, Any]:
    """Build a JSON-friendly resolver response for CLI and CI callers."""
    normalized = [normalize_changed_path(path) for path in changed_paths if path.strip()]
    matches = resolve_test_package_matches(normalized)
    packages = [match.as_dict() for match in matches]
    unit_paths = sorted(
        {test_path for match in matches for test_path in match.package.unit_test_paths}
    )
    integration_checks = sorted(
        {check for match in matches for check in match.package.integration_checks}
    )
    requires_ai = any(match.package.requires_ai for match in matches)
    costs_api_tokens = any(match.package.costs_api_tokens for match in matches)
    broad = any(match.package.broad for match in matches)
    package_names_list = [match.package.name for match in matches]
    full_suite_reasons = full_suite_reasons_for_matches(matches, package_limit=package_limit)
    return {
        "changed_paths": normalized,
        "packages": packages,
        "package_names": package_names_list,
        "unit_test_paths": unit_paths,
        "integration_checks": integration_checks,
        "requires_ai": requires_ai,
        "costs_api_tokens": costs_api_tokens,
        "broad": broad,
        "full_suite": bool(full_suite_reasons),
        "full_suite_reasons": full_suite_reasons,
        "package_limit": package_limit,
        "instructions": _instructions(unit_paths, integration_checks, broad, costs_api_tokens),
        "pipeline_contract": pipeline_contract(),
    }


def full_suite_reasons_for_matches(
    matches: list[TestPackageMatch],
    *,
    package_limit: int = _DEFAULT_PACKAGE_LIMIT,
) -> list[str]:
    """Explain why selective CI should fall back to the full suite."""
    if not matches:
        return ["no package mapping matched"]
    reasons: list[str] = []
    broad_packages = [match.package.name for match in matches if match.package.broad]
    if broad_packages:
        reasons.append("broad package matched: " + ", ".join(broad_packages))
    if len(matches) > package_limit:
        reasons.append(f"package count {len(matches)} exceeds limit {package_limit}")
    return reasons


def pipeline_contract() -> dict[str, Any]:
    """Describe the stable contract consumed by gardusig/cli hub CI."""
    return {
        "owner": "gardusig/cli",
        "repo_local_commands": {
            "resolve_paths": "cli test packages resolve --changed-path PATH",
            "resolve_range": "cli test packages resolve --base BASE --head HEAD",
            "run_package": "cli test packages run PACKAGE",
            "full_suite": "cli test packages suite",
        },
        "stable_check_names": [
            "selective-plan",
            "unit-package",
            "integration-package",
            "pypi-package",
            "full-suite",
        ],
    }


def package_command_payload(
    package_name: str,
    *,
    include_unit: bool = True,
    include_integration: bool = True,
) -> dict[str, Any]:
    """Build executable command metadata for one package."""
    pkg = package_by_name(package_name)
    commands = package_commands(
        pkg,
        include_unit=include_unit,
        include_integration=include_integration,
    )
    return {
        "package": pkg.as_dict(),
        "commands": [command.as_dict() for command in commands],
        "pipeline_contract": pipeline_contract(),
    }


def package_commands(
    package: TestPackage,
    *,
    include_unit: bool = True,
    include_integration: bool = True,
) -> list[TestCommand]:
    commands: list[TestCommand] = []
    if include_unit and package.unit_test_paths:
        commands.append(
            TestCommand(
                kind="unit",
                package=package.name,
                label=f"{package.name} unit",
                command=("python3", "-m", "pytest", "-q", *package.unit_test_paths),
            )
        )
    if include_integration:
        commands.extend(
            _integration_command(package.name, check)
            for check in package.integration_checks
        )
    return commands


def core_gate_commands() -> list[TestCommand]:
    """Always-run command-surface and registry gates for selective CI."""
    return [
        TestCommand(
            kind="core",
            package=None,
            label=Path(check).stem,
            command=("python3", check),
        )
        for check in _CORE_INTEGRATION_CHECKS
    ]


def live_suite_commands() -> list[TestCommand]:
    """Optional live-daemon legs for nightly full-suite runs."""
    return [
        TestCommand(
            kind="live",
            package="docker",
            label="docker live",
            command=("python3", "tests/integration/check_docker_commands.py", "--live"),
        ),
    ]


def full_suite_payload() -> dict[str, Any]:
    """Describe the repo-local full-suite composition for gardusig/cli."""
    package_payloads = [
        package_command_payload(package.name) for package in TEST_PACKAGES
    ]
    commands = [command.as_dict() for command in core_gate_commands()]
    for payload in package_payloads:
        commands.extend(payload["commands"])
    live_commands = [command.as_dict() for command in live_suite_commands()]
    commands.extend(live_commands)
    return {
        "packages": [package.name for package in TEST_PACKAGES],
        "core_commands": [command.as_dict() for command in core_gate_commands()],
        "live_commands": live_commands,
        "commands": commands,
        "pipeline_contract": pipeline_contract(),
        "notes": [
            "gardusig/cli owns schedules, workflow YAML, Dockerfiles, and job graphs.",
            "This repo owns the command contract and package mappings.",
            "Order: core gates → package unit/integration → optional live docker.",
        ],
    }


def _integration_command(package_name: str, check: str) -> TestCommand:
    if check == _PACKAGE_INTEGRATION:
        command = ("python3", "tests/integration/check_package_integration.py", "--package", package_name)
    elif check.startswith("python -m "):
        module = check.removeprefix("python -m ").strip()
        command = ("python3", "-m", module)
    elif check.startswith("tests/") and check.endswith(".py"):
        command = ("python3", check)
    else:
        command = ("python3", "-m", "src", *shlex.split(check))
    return TestCommand(
        kind="integration",
        package=package_name,
        label=f"{package_name} {check}",
        command=command,
    )


def _instructions(
    unit_paths: list[str],
    integration_checks: list[str],
    broad: bool,
    costs_api_tokens: bool,
) -> list[str]:
    if not unit_paths:
        return ["No package mapping found; run cli test python unit ."]
    instructions = ["Run focused pytest paths first: " + " ".join(unit_paths)]
    if integration_checks:
        instructions.append("Relevant integration checks: " + ", ".join(integration_checks))
    if broad:
        instructions.append("A broad package matched; run cli test python unit . before merging.")
    if costs_api_tokens:
        instructions.append("OpenCode package matched; do not call paid AI commands unless requested.")
    return instructions


def assert_registry_covers_top_level_commands() -> None:
    """Ensure every public top-level CLI has a package entry."""
    from src.integration.public_endpoints import TOP_LEVEL_COMMANDS

    expected = set(TOP_LEVEL_COMMANDS)
    actual = package_names()
    missing = expected - actual
    if missing:
        raise AssertionError(f"test package registry missing top-level commands: {sorted(missing)}")
