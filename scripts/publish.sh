#!/usr/bin/env bash
#
# Mirror one Step from this monorepo into its own public repository, tag the
# release there, and print the Bitrise StepLib share commands.
#
# A published Step's git repository must have step.yml at its root, which is why
# each steps/<id>/ directory is split out rather than published from here.
#
# Usage:
#   scripts/publish.sh <step-id> <version>            # dry run (default)
#   scripts/publish.sh <step-id> <version> --push     # actually push and tag
#
# Example:
#   scripts/publish.sh testingbot-upload-app 1.0.0 --push

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# The StepLib fork that `bitrise share` writes into.
STEPLIB_FORK="${MY_STEPLIB_REPO_FORK_GIT_URL:-https://github.com/testingbot/bitrise-steplib.git}"

# step-id -> publish repository. Kept as a case rather than an associative array
# so this runs on the macOS system bash.
repo_for_step() {
  case "$1" in
  testingbot-upload-app) echo "git@github.com:testingbot/bitrise-step-testingbot-app-upload.git" ;;
  testingbot-espresso) echo "git@github.com:testingbot/bitrise-step-testingbot-espresso.git" ;;
  testingbot-xcuitest) echo "git@github.com:testingbot/bitrise-step-testingbot-xcuitest.git" ;;
  testingbot-maestro) echo "git@github.com:testingbot/bitrise-step-testingbot-maestro.git" ;;
  testingbot-tunnel) echo "git@github.com:testingbot/bitrise-step-testingbot-tunnel.git" ;;
  testingbot-tunnel-stop) echo "git@github.com:testingbot/bitrise-step-testingbot-tunnel-stop.git" ;;
  *) return 1 ;;
  esac
}

die() {
  echo "error: $*" >&2
  exit 1
}

# remote_default_branch <url> -- the branch to push into. Not every mirror uses
# the same name: bitrise-step-testingbot-app-upload predates the main/master
# switch, so ask the remote rather than assuming.
remote_default_branch() {
  local ref
  ref="$(git ls-remote --symref "$1" HEAD 2>/dev/null |
    sed -n 's#^ref: refs/heads/\([^[:space:]]*\).*#\1#p' | head -1)"
  echo "${ref:-main}"
}

STEP_ID="${1:-}"
VERSION="${2:-}"
PUSH=false
[ "${3:-}" = "--push" ] && PUSH=true

[ -n "$STEP_ID" ] && [ -n "$VERSION" ] || die "usage: scripts/publish.sh <step-id> <version> [--push]"
[ -d "steps/${STEP_ID}" ] || die "no such step: steps/${STEP_ID}"

case "$VERSION" in
[0-9]*.[0-9]*.[0-9]*) ;;
*) die "version must be semver MAJOR.MINOR.PATCH, got '${VERSION}'" ;;
esac

STEP_REPO="$(repo_for_step "$STEP_ID")" || die "no publish repository registered for '${STEP_ID}'"

# --- preflight ---------------------------------------------------------------

echo "==> Preflight"

[ -z "$(git status --porcelain)" ] || die "working tree is dirty -- commit or stash first"

./scripts/build.sh --check || die "steps are out of sync with lib/ -- run scripts/build.sh"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "steps/${STEP_ID}/step.sh" || die "shellcheck failed"
else
  echo "  warning: shellcheck not installed, skipping"
fi

# The version in the Step's bitrise.yml is what `bitrise share create` reads.
declared="$(sed -n 's/^ *- BITRISE_STEP_VERSION: *"\{0,1\}\([0-9][^"]*\)"\{0,1\} *$/\1/p' "steps/${STEP_ID}/bitrise.yml" | head -1)"
if [ "$declared" != "$VERSION" ]; then
  die "steps/${STEP_ID}/bitrise.yml declares BITRISE_STEP_VERSION '${declared}', not '${VERSION}'"
fi

STEP_BRANCH="$(remote_default_branch "$STEP_REPO")"

echo "  step:     ${STEP_ID}"
echo "  version:  ${VERSION}"
echo "  mirror:   ${STEP_REPO} (${STEP_BRANCH})"
echo "  steplib:  ${STEPLIB_FORK}"

# --- mirror ------------------------------------------------------------------

if ! $PUSH; then
  cat <<EOF

Dry run -- nothing was pushed. Re-run with --push to perform:

  git subtree push --prefix=steps/${STEP_ID} ${STEP_REPO} ${STEP_BRANCH}
  git -C <clone> tag ${VERSION} && git -C <clone> push origin ${VERSION}

Then share to the StepLib:

  bitrise share start  -c ${STEPLIB_FORK}
  bitrise share create --stepid ${STEP_ID} --tag ${VERSION} --git ${STEP_REPO}
  bitrise share audit  -c ${STEPLIB_FORK}
  bitrise share finish

and open a pull request against bitrise-io/bitrise-steplib titled
"${STEP_ID}-${VERSION}". One Step per pull request.
EOF
  exit 0
fi

echo
echo "==> Mirroring steps/${STEP_ID} to ${STEP_REPO}"
git subtree push --prefix="steps/${STEP_ID}" "$STEP_REPO" "$STEP_BRANCH"

# Tagging happens in the mirror, because the StepLib resolves `--tag` against the
# published repository. A tag that has already been shared must never be moved.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo
echo "==> Tagging ${VERSION} in the mirror"
git clone --quiet "$STEP_REPO" "${work}/mirror"
if git -C "${work}/mirror" rev-parse "refs/tags/${VERSION}" >/dev/null 2>&1; then
  die "tag ${VERSION} already exists in ${STEP_REPO} -- shared versions must never be re-tagged; bump the version instead"
fi
git -C "${work}/mirror" tag "$VERSION"
git -C "${work}/mirror" push origin "$VERSION"

cat <<EOF

==> Mirrored and tagged.

Now share it to the StepLib:

  bitrise share start  -c ${STEPLIB_FORK}
  bitrise share create --stepid ${STEP_ID} --tag ${VERSION} --git ${STEP_REPO}
  bitrise share audit  -c ${STEPLIB_FORK}
  bitrise share finish

then open a pull request against bitrise-io/bitrise-steplib titled
"${STEP_ID}-${VERSION}". One Step per pull request.
EOF
