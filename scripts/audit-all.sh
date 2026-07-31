#!/usr/bin/env bash
#
# Run every local check across all Steps.
#
# Mirrors what Bitrise's own CI runs, so a green run here means the StepLib
# submission should be green too:
#
#   shared sources in sync    scripts/build.sh --check
#   shell lint                every step.sh and helper
#   yamllint                  Bitrise's own .yamllint.yml
#   stepman audit             step.yml, per Step
#   bitrise validate          bitrise.yml, per Step
#   offline tests             tests/run.sh
#
# `bitrise run check` (the full steps-check linter, including the JSON schema
# validation) is not run here because it clones a repo per Step and takes about
# a minute each. Run it before a release:  cd steps/<id> && bitrise run check
#
#   scripts/audit-all.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# `bitrise setup` installs stepman and envman here rather than onto the PATH.
export PATH="${HOME}/.bitrise/tools:${HOME}/.local/bin:${PATH}"

status=0

run() {
  # run <description> <command...>
  local desc="$1"
  shift
  printf '\n==> %s\n' "$desc"
  if "$@"; then
    printf '    ok\n'
  else
    printf '    FAILED\n' >&2
    status=1
  fi
}

run "Shared sources in sync" ./scripts/build.sh --check

if command -v shellcheck >/dev/null 2>&1; then
  run "shellcheck" shellcheck -x lib/testingbot.bash scripts/*.sh tests/run.sh steps/*/step.sh
else
  echo "warning: shellcheck not installed (brew install shellcheck) -- skipping" >&2
fi

if command -v yamllint >/dev/null 2>&1; then
  run "yamllint (Bitrise config)" yamllint -c .yamllint.yml steps/
else
  echo "warning: yamllint not installed (pipx install yamllint) -- skipping" >&2
fi

if command -v stepman >/dev/null 2>&1; then
  for step_yml in steps/*/step.yml; do
    run "stepman audit $(basename "$(dirname "$step_yml")")" \
      stepman audit --step-yml "$step_yml"
  done
else
  echo "warning: stepman not installed (brew install bitrise && bitrise setup) -- skipping" >&2
fi

if command -v bitrise >/dev/null 2>&1; then
  for bitrise_yml in steps/*/bitrise.yml; do
    run "bitrise validate $(basename "$(dirname "$bitrise_yml")")" \
      bitrise validate --config "$bitrise_yml"
  done
else
  echo "warning: the Bitrise CLI is not installed -- skipping config validation" >&2
fi

run "Offline tests" ./tests/run.sh

echo
if [ "$status" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some checks failed." >&2
fi
exit "$status"
