#!/usr/bin/env bash
#
# Regenerate every Step's README.md with Bitrise's own steps-readme-generator,
# via each Step's `generate_readme` workflow.
#
# We use the official generator rather than rolling our own so the output matches
# what StepLib CI expects. It needs the Bitrise CLI and network access, which is
# why it is a separate script instead of part of scripts/build.sh.
#
# Note: the generator calls `githubName` on the Step's `website`, so that field
# must be a github.com/<owner>/<repo> URL or it crashes.
#
#   scripts/gen-readme.sh              # every Step
#   scripts/gen-readme.sh <step-id>    # just one

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME}/.bitrise/tools:${PATH}"

command -v bitrise >/dev/null 2>&1 || {
  echo "error: the Bitrise CLI is not installed (brew install bitrise && bitrise setup)" >&2
  exit 1
}

status=0
targets=()
if [ "$#" -gt 0 ]; then
  targets=("${REPO_ROOT}/steps/$1")
else
  for d in "${REPO_ROOT}"/steps/*/; do targets+=("$d"); done
fi

for step_dir in "${targets[@]}"; do
  [ -f "${step_dir}/step.yml" ] || continue
  step_id="$(basename "$step_dir")"
  printf '==> %s\n' "$step_id"
  if (cd "$step_dir" && bitrise run generate_readme >/dev/null 2>&1); then
    echo "    ok"
  else
    echo "    FAILED -- rerun in steps/${step_id} to see why" >&2
    status=1
  fi
done

exit "$status"
